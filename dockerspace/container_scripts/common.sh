#!/bin/bash
# common.sh — Shared colours, logging helpers, and banner printer.
# Source this from every container script:
#   source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[ OK ]${RESET}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

banner() {
    local title="$1"
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════╗${RESET}"
    printf "${BOLD}║  %-36s║${RESET}\n" "$title"
    echo -e "${BOLD}╚══════════════════════════════════════╝${RESET}"
    echo ""
}
