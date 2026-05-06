#!/bin/bash
# health.sh — Check UMS service, Admin UI, and ums-agent health.
# Run INSIDE ums-app container.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

GREEN="\033[32m"; RED="\033[31m"; YELLOW="\033[33m"; CYAN="\033[36m"; RESET="\033[0m"

ok()   { echo -e "${GREEN}[ OK ]${RESET}  $*"; }
fail() { echo -e "${RED}[FAIL]${RESET}  $*"; }
warn() { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
info() { echo -e "${CYAN}[INFO]${RESET}  $*"; }

echo ""
echo "── UMS Spring Boot ──────────────────────────────────"

if curl -sf http://localhost:8080/actuator/health -o /dev/null 2>/dev/null; then
    STATUS=$(curl -sf http://localhost:8080/actuator/health 2>/dev/null | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "UP")
    ok "Spring Boot is running on localhost:8080  (status=$STATUS)"
else
    fail "Spring Boot is not responding — start with: ./start.sh or run_script start_ums"
fi

echo ""
echo "── Admin UI ─────────────────────────────────────────"

if curl -sf http://localhost:3000 -o /dev/null 2>/dev/null; then
    ok "Admin UI is running on localhost:3000"
else
    warn "Admin UI not running — start with: run_script start_ui"
fi

echo ""
echo "── UMS Agent ────────────────────────────────────────"

if [ -d ".venv" ] && .venv/bin/python -c "import anthropic, fastapi" 2>/dev/null; then
    ok "Python dependencies installed"
else
    warn "Dependencies not installed — run ./build.sh"
fi

if [ -f "agent.conf" ]; then
    source agent.conf
    if [ -n "${ANTHROPIC_API_KEY:-}" ] && [ "$ANTHROPIC_API_KEY" != "your-api-key-here" ]; then
        ok "agent.conf configured"
    else
        warn "agent.conf present but ANTHROPIC_API_KEY not set"
    fi
else
    warn "agent.conf not found — run ./build.sh"
fi

if curl -sf http://localhost:8891/health -o /dev/null 2>/dev/null; then
    ok "UMS agent server is running on localhost:8891"
else
    info "UMS agent server is not running (start with: ./start.sh)"
fi

echo ""
