#!/bin/bash
# stop_docker.sh — Stop the UMS Docker Compose stack on your local machine.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }

echo ""
echo -e "${BOLD}╔══════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║    UMS Docker Stack — STOP           ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════╝${RESET}"
echo ""

# --volumes flag removes persistent data (postgres + redis volumes)
VOLUME_FLAG=""
if [ "${1:-}" = "--volumes" ]; then
    warn "--volumes flag set: database and cache data will be deleted."
    VOLUME_FLAG="--volumes"
fi

info "Stopping containers..."
docker compose down $VOLUME_FLAG

success "Stack stopped."
[ -n "$VOLUME_FLAG" ] && warn "Volumes removed — all data is gone."
echo ""
