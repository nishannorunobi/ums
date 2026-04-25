#!/bin/bash
# start_docker.sh — Start the full UMS Docker Compose stack on your local machine.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

# ── .env ──────────────────────────────────────────────────────────────────────
if [ ! -f .env ]; then
    if [ -f .env.example ]; then
        warn ".env not found — copying from .env.example"
        cp .env.example .env
    else
        error ".env.example missing. Cannot start."
        exit 1
    fi
fi

APP_PORT="${SERVER_PORT:-8080}"

# ── Build flag ────────────────────────────────────────────────────────────────
BUILD_FLAG=""
[ "${1:-}" = "--build" ] && BUILD_FLAG="--build"

echo ""
echo -e "${BOLD}╔══════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║    UMS Docker Stack — START          ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════╝${RESET}"
echo ""

info "Starting containers..."
docker compose up -d $BUILD_FLAG

# ── Wait for health ───────────────────────────────────────────────────────────
info "Waiting for UMS to become healthy..."
MAX_WAIT=120
ELAPSED=0

until curl -sf "http://localhost:$APP_PORT/actuator/health" \
           | grep -q '"status":"UP"' 2>/dev/null; do
    if [ "$ELAPSED" -ge "$MAX_WAIT" ]; then
        error "UMS did not become healthy within ${MAX_WAIT}s."
        error "Check logs: docker compose logs ums"
        exit 1
    fi
    printf "  waiting... %ds\r" "$ELAPSED"
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

echo ""
success "Stack is UP!"
echo ""
echo -e "  ${BOLD}Swagger UI ${RESET}→  http://localhost:$APP_PORT/swagger-ui.html"
echo -e "  ${BOLD}Health     ${RESET}→  http://localhost:$APP_PORT/actuator/health"
echo -e "  ${BOLD}Grafana    ${RESET}→  http://localhost:3000  (admin / admin)"
echo -e "  ${BOLD}Zipkin     ${RESET}→  http://localhost:9411"
echo -e "  ${BOLD}Stop       ${RESET}→  ./stop_docker.sh"
echo ""
