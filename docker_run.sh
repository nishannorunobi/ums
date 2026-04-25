#!/bin/bash
# docker_run.sh — Manage the UMS Docker Compose stack (app + postgres + redis + observability).
# Independent of start.sh / stop.sh (those run the app directly inside the dev container).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

usage() {
    echo ""
    echo -e "${BOLD}Usage:${RESET} $0 <command> [options]"
    echo ""
    echo -e "${BOLD}Commands:${RESET}"
    echo "  up        Start all services (default: detached)"
    echo "  down      Stop and remove containers"
    echo "  restart   Stop then start"
    echo "  status    Show running containers and ports"
    echo "  logs      Follow logs (all services or specify: logs ums)"
    echo "  build     Rebuild Docker image only"
    echo "  ps        Alias for status"
    echo ""
    echo -e "${BOLD}Options (for 'up'):${RESET}"
    echo "  --build   Force image rebuild before starting"
    echo "  --volumes Also remove volumes on 'down'"
    echo ""
    echo -e "${BOLD}Examples:${RESET}"
    echo "  $0 up"
    echo "  $0 up --build"
    echo "  $0 down --volumes"
    echo "  $0 logs ums"
    echo ""
}

# ── .env guard ────────────────────────────────────────────────────────────────
if [ ! -f .env ]; then
    if [ -f .env.example ]; then
        warn ".env not found — copying from .env.example"
        cp .env.example .env
    else
        error ".env.example missing. Cannot start Docker stack."
        exit 1
    fi
fi

COMMAND="${1:-help}"
shift || true

case "$COMMAND" in

    up)
        BUILD_FLAG=""
        for arg in "$@"; do
            [ "$arg" = "--build" ] && BUILD_FLAG="--build"
        done
        echo ""
        echo -e "${BOLD}╔══════════════════════════════════════╗${RESET}"
        echo -e "${BOLD}║     UMS Docker Stack — UP            ║${RESET}"
        echo -e "${BOLD}╚══════════════════════════════════════╝${RESET}"
        echo ""
        info "Starting Docker Compose stack..."
        docker compose up -d $BUILD_FLAG

        APP_PORT="${SERVER_PORT:-8080}"
        info "Waiting for UMS container to be healthy..."
        MAX_WAIT=120; ELAPSED=0
        until curl -sf "http://localhost:$APP_PORT/actuator/health" \
                   | grep -q '"status":"UP"' 2>/dev/null; do
            if [ "$ELAPSED" -ge "$MAX_WAIT" ]; then
                error "UMS did not become healthy within ${MAX_WAIT}s."
                error "  docker compose logs ums"
                exit 1
            fi
            printf "  waiting... %ds\r" "$ELAPSED"
            sleep 5; ELAPSED=$((ELAPSED + 5))
        done
        echo ""
        success "Stack is UP!"
        echo ""
        echo -e "  ${BOLD}Swagger UI ${RESET}→  http://localhost:$APP_PORT/swagger-ui.html"
        echo -e "  ${BOLD}Health     ${RESET}→  http://localhost:$APP_PORT/actuator/health"
        echo -e "  ${BOLD}Grafana    ${RESET}→  http://localhost:3000  (admin / admin)"
        echo -e "  ${BOLD}Zipkin     ${RESET}→  http://localhost:9411"
        echo ""
        ;;

    down)
        VOLUME_FLAG=""
        for arg in "$@"; do
            [ "$arg" = "--volumes" ] && VOLUME_FLAG="--volumes"
        done
        info "Stopping Docker Compose stack..."
        docker compose down $VOLUME_FLAG
        success "Stack stopped."
        [ -n "$VOLUME_FLAG" ] && warn "Volumes removed — database data is gone."
        ;;

    restart)
        info "Restarting stack..."
        docker compose down
        docker compose up -d
        success "Stack restarted."
        ;;

    build)
        info "Rebuilding UMS Docker image..."
        docker compose build
        success "Build complete."
        ;;

    logs)
        SERVICE="${1:-}"
        docker compose logs -f $SERVICE
        ;;

    status|ps)
        echo ""
        docker compose ps
        echo ""
        ;;

    help|-h|--help)
        usage
        ;;

    *)
        error "Unknown command: $COMMAND"
        usage
        exit 1
        ;;
esac
