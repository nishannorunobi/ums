#!/bin/bash
# start_admin_ui.sh — Install dependencies, build, and serve the UMS Admin UI.
# Run INSIDE the ums-app container.  Port 3000.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UI_DIR="$(cd "$SCRIPT_DIR/../../ums-ui" && pwd)"
PID_FILE="$UI_DIR/.admin-ui.pid"
LOG_FILE="$UI_DIR/admin-ui.log"
PORT="${ADMIN_UI_PORT:-3000}"

source "$SCRIPT_DIR/common.sh"

# ── Guard: already running ─────────────────────────────────────────────────────
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        warn "Admin UI already running (PID $OLD_PID). Run stop_admin_ui.sh first."
        exit 0
    else
        rm -f "$PID_FILE"
    fi
fi

banner "UMS Admin UI — START"

# ── Ensure environment is ready (delegates to build_env_ui.sh if needed) ──────
if ! command -v node &>/dev/null || [ ! -d "$UI_DIR/node_modules" ]; then
    info "Environment not ready — running build_env_ui.sh..."
    bash "$SCRIPT_DIR/build_env_ui.sh"
fi
success "Node $(node --version)"

# ── Build ──────────────────────────────────────────────────────────────────────
info "Building production bundle..."
npm run build
success "Build complete → dist/"

# ── Serve ─────────────────────────────────────────────────────────────────────
info "Starting static file server on port $PORT..."
mkdir -p "$(dirname "$LOG_FILE")"

nohup npx serve -s dist -l "$PORT" > "$LOG_FILE" 2>&1 &
echo $! > "$PID_FILE"
SRV_PID=$(cat "$PID_FILE")

sleep 2
if ! kill -0 "$SRV_PID" 2>/dev/null; then
    error "serve failed to start. Check log: $LOG_FILE"
    exit 1
fi

success "Admin UI is UP  (PID $SRV_PID)  →  http://localhost:$PORT"
