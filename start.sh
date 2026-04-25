#!/bin/bash
# start.sh — Build and run UMS Spring Boot app directly (inside dev container).
# PostgreSQL is expected to be running in the container (postgres:16 base image).
# Redis is optional — disabled automatically if not reachable.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PID_FILE="$SCRIPT_DIR/.ums.pid"
LOG_FILE="$SCRIPT_DIR/logs/ums.log"
APP_PORT="${SERVER_PORT:-8080}"
PROFILE="${SPRING_PROFILES_ACTIVE:-dev}"

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

# ── Guard: already running ────────────────────────────────────────────────────
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        warn "UMS is already running (PID $OLD_PID). Run ./stop.sh first."
        exit 1
    else
        rm -f "$PID_FILE"
    fi
fi

echo ""
echo -e "${BOLD}╔══════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║     UMS Spring Boot — START          ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════╝${RESET}"
echo ""

# ── Parse args ────────────────────────────────────────────────────────────────
SKIP_BUILD=false
FOREGROUND=false

for arg in "$@"; do
    case "$arg" in
        --skip-build|-s) SKIP_BUILD=true ;;
        --foreground|-f) FOREGROUND=true ;;
        --help|-h)
            echo "Usage: $0 [--skip-build|-s] [--foreground|-f]"
            echo "  --skip-build   Skip Maven build (use existing jar in target/)"
            echo "  --foreground   Run in foreground instead of background"
            exit 0 ;;
    esac
done

# ── Check PostgreSQL ──────────────────────────────────────────────────────────
info "Checking PostgreSQL..."
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${POSTGRES_DB:-umsdb}"
DB_USER="${DB_USERNAME:-ums_user}"
DB_PASS="${DB_PASSWORD:-ums_pass}"

if ! pg_isready -h "$DB_HOST" -p "$DB_PORT" -q 2>/dev/null; then
    error "PostgreSQL is not reachable at $DB_HOST:$DB_PORT"
    error "Start it with: pg_ctlcluster \$(pg_lsclusters -h | awk 'NR==1{print \$1,\$2}') start"
    exit 1
fi
success "PostgreSQL is up."

# ── Ensure DB + user exist ────────────────────────────────────────────────────
info "Ensuring database '$DB_NAME' and user '$DB_USER' exist..."
psql -U postgres -h "$DB_HOST" -p "$DB_PORT" -tc \
    "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" \
    | grep -q 1 || \
    psql -U postgres -h "$DB_HOST" -p "$DB_PORT" \
         -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';" -q

psql -U postgres -h "$DB_HOST" -p "$DB_PORT" -tc \
    "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" \
    | grep -q 1 || \
    psql -U postgres -h "$DB_HOST" -p "$DB_PORT" \
         -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;" -q
success "Database ready."

# ── Check Redis (optional) ────────────────────────────────────────────────────
REDIS_HOST="${REDIS_HOST:-localhost}"
REDIS_PORT="${REDIS_PORT:-6379}"
EXTRA_ARGS=""

if redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" ping 2>/dev/null | grep -q PONG; then
    success "Redis is up — caching enabled."
else
    warn "Redis not reachable — disabling cache (spring.cache.type=none)."
    EXTRA_ARGS="--spring.cache.type=none"
fi

# ── Build ─────────────────────────────────────────────────────────────────────
if [ "$SKIP_BUILD" = false ]; then
    info "Building project (skipping tests)..."
    ./mvnw package -DskipTests -q
    success "Build complete."
fi

JAR=$(ls target/ums-*.jar 2>/dev/null | head -1)
if [ -z "$JAR" ]; then
    error "No jar found in target/. Run without --skip-build."
    exit 1
fi

# ── Start app ─────────────────────────────────────────────────────────────────
mkdir -p "$(dirname "$LOG_FILE")"

JAVA_CMD="java \
    -XX:+UseContainerSupport \
    -XX:MaxRAMPercentage=75.0 \
    -Dspring.profiles.active=$PROFILE \
    -Dserver.port=$APP_PORT \
    -DDB_URL=jdbc:postgresql://$DB_HOST:$DB_PORT/$DB_NAME \
    -DDB_USERNAME=$DB_USER \
    -DDB_PASSWORD=$DB_PASS \
    $EXTRA_ARGS \
    -jar $JAR"

if [ "$FOREGROUND" = true ]; then
    info "Starting UMS in foreground (profile=$PROFILE, port=$APP_PORT)..."
    echo ""
    exec $JAVA_CMD
else
    info "Starting UMS in background (profile=$PROFILE, port=$APP_PORT)..."
    nohup $JAVA_CMD > "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    APP_PID=$(cat "$PID_FILE")
    info "PID $APP_PID — logs: $LOG_FILE"

    # ── Wait for health ───────────────────────────────────────────────────────
    echo ""
    info "Waiting for UMS to become healthy..."
    MAX_WAIT=120
    ELAPSED=0

    until curl -sf "http://localhost:$APP_PORT/actuator/health" \
               | grep -q '"status":"UP"' 2>/dev/null; do
        if [ "$ELAPSED" -ge "$MAX_WAIT" ]; then
            error "UMS did not start within ${MAX_WAIT}s. Check logs:"
            error "  tail -50 $LOG_FILE"
            exit 1
        fi
        if ! kill -0 "$APP_PID" 2>/dev/null; then
            error "UMS process died. Check logs:"
            error "  tail -50 $LOG_FILE"
            exit 1
        fi
        printf "  waiting... %ds\r" "$ELAPSED"
        sleep 3
        ELAPSED=$((ELAPSED + 3))
    done

    echo ""
    success "UMS is UP! (PID $APP_PID)"
    echo ""
    echo -e "  ${BOLD}Swagger UI ${RESET}→  http://localhost:$APP_PORT/swagger-ui.html"
    echo -e "  ${BOLD}Health     ${RESET}→  http://localhost:$APP_PORT/actuator/health"
    echo -e "  ${BOLD}Logs       ${RESET}→  tail -f $LOG_FILE"
    echo -e "  ${BOLD}Stop       ${RESET}→  ./stop.sh"
    echo ""
fi
