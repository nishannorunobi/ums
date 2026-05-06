#!/bin/bash
# stop.sh — Stop a running ums-agent process inside the container.
set -euo pipefail

GREEN="\033[32m"; YELLOW="\033[33m"; RESET="\033[0m"

if pkill -f "ums-agent/server.py\|ums-agent.*uvicorn" 2>/dev/null || pkill -f "uvicorn server:app" 2>/dev/null; then
    echo -e "${GREEN}[ OK ]${RESET}  UMS agent stopped."
else
    echo -e "${YELLOW}[WARN]${RESET}  No running ums-agent server found."
fi
