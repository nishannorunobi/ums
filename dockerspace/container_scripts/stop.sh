#!/bin/bash
# stop.sh — Stop the manually running UMS Spring Boot process.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PID_FILE="$PROJECT_ROOT/.ums.pid"

source "$SCRIPT_DIR/common.sh"

if [ ! -f "$PID_FILE" ]; then
    warn "No PID file found — UMS may not be running."
    exit 0
fi

PID=$(cat "$PID_FILE")

if ! kill -0 "$PID" 2>/dev/null; then
    warn "Process $PID is not running. Cleaning up stale PID file."
    rm -f "$PID_FILE"
    exit 0
fi

info "Stopping UMS (PID $PID)..."
kill -TERM "$PID"

# Wait up to 20s for graceful shutdown
ELAPSED=0
while kill -0 "$PID" 2>/dev/null; do
    if [ "$ELAPSED" -ge 20 ]; then
        warn "Graceful stop timed out — sending KILL..."
        kill -KILL "$PID" 2>/dev/null || true
        break
    fi
    sleep 1
    ELAPSED=$((ELAPSED + 1))
done

rm -f "$PID_FILE"
success "UMS stopped."
