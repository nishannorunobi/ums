#!/bin/bash
# stop_admin_ui.sh — Stop the UMS Admin UI static server.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UI_DIR="$(cd "$SCRIPT_DIR/../../ums-ui" && pwd)"
PID_FILE="$UI_DIR/.admin-ui.pid"

source "$SCRIPT_DIR/common.sh"

if [ ! -f "$PID_FILE" ]; then
    warn "Admin UI is not running (no PID file)."
    exit 0
fi

PID=$(cat "$PID_FILE")
if kill -0 "$PID" 2>/dev/null; then
    kill "$PID"
    rm -f "$PID_FILE"
    success "Admin UI stopped (PID $PID)."
else
    rm -f "$PID_FILE"
    warn "Process $PID not found — PID file removed."
fi
