#!/bin/bash
# health_admin_ui.sh — Quick health check for the Admin UI server.
PORT="${ADMIN_UI_PORT:-3000}"
if curl -sf "http://localhost:$PORT" -o /dev/null; then
    echo "OK  Admin UI is up on port $PORT"
    exit 0
else
    echo "FAIL  Admin UI not reachable on port $PORT"
    exit 1
fi
