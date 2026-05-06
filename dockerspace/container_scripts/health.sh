#!/bin/bash
# health.sh — Check health of the running UMS Spring Boot app and its dependencies.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PID_FILE="$PROJECT_ROOT/.ums.pid"
APP_PORT="${SERVER_PORT:-8080}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${POSTGRES_DB:-umsdb}"
REDIS_HOST="${REDIS_HOST:-localhost}"
REDIS_PORT="${REDIS_PORT:-6379}"

source "$SCRIPT_DIR/common.sh"

PASS="${GREEN}✔${RESET}"
FAIL="${RED}✘${RESET}"
SKIP="${YELLOW}—${RESET}"

check() {
    local label="$1"; local result="$2"; local detail="${3:-}"
    printf "  %-20s %b" "$label" "$result"
    [ -n "$detail" ] && echo "  ($detail)" || echo ""
}

banner "UMS Health Check"

# ── Process ───────────────────────────────────────────────────────────────────
echo -e "${BOLD}Process${RESET}"
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        check "UMS process" "$PASS" "PID $PID"
    else
        check "UMS process" "$FAIL" "PID $PID not running (stale .ums.pid)"
    fi
else
    check "UMS process" "$SKIP" "no .ums.pid — may be in foreground mode"
fi

# ── Spring Actuator ───────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Spring Boot Actuator${RESET}"
HEALTH_RESP=$(curl -sf "http://localhost:$APP_PORT/actuator/health" 2>/dev/null || echo "")

if [ -z "$HEALTH_RESP" ]; then
    check "HTTP :$APP_PORT/health" "$FAIL" "not reachable"
else
    OVERALL=$(echo "$HEALTH_RESP" | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4)
    if [ "$OVERALL" = "UP" ]; then
        check "Overall status" "$PASS" "$OVERALL"
    else
        check "Overall status" "$FAIL" "${OVERALL:-unknown}"
    fi

    # Component-level detail
    DB_STATUS=$(echo  "$HEALTH_RESP" | grep -o '"db":{"status":"[^"]*"'     | cut -d'"' -f6 || echo "")
    REDIS_STATUS=$(echo "$HEALTH_RESP" | grep -o '"redis":{"status":"[^"]*"' | cut -d'"' -f6 || echo "")

    [ -n "$DB_STATUS"    ] && check "  DB component"    "$( [ "$DB_STATUS"    = "UP" ] && echo "$PASS" || echo "$FAIL" )" "$DB_STATUS"
    [ -n "$REDIS_STATUS" ] && check "  Redis component" "$( [ "$REDIS_STATUS" = "UP" ] && echo "$PASS" || echo "$FAIL" )" "$REDIS_STATUS"
fi

# ── PostgreSQL direct ─────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}PostgreSQL${RESET}"
if pg_isready -h "$DB_HOST" -p "$DB_PORT" -q 2>/dev/null; then
    check "pg_isready" "$PASS" "$DB_HOST:$DB_PORT"
    DB_EXISTS=$(psql -U postgres -h "$DB_HOST" -p "$DB_PORT" -tc \
        "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" 2>/dev/null | tr -d ' ' || echo "")
    check "Database '$DB_NAME'" "$( [ "$DB_EXISTS" = "1" ] && echo "$PASS" || echo "$FAIL" )"
else
    check "pg_isready" "$FAIL" "$DB_HOST:$DB_PORT not reachable"
fi

# ── Redis direct ──────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Redis${RESET}"
if redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" ping 2>/dev/null | grep -q PONG; then
    check "redis-cli ping" "$PASS" "$REDIS_HOST:$REDIS_PORT"
else
    check "redis-cli ping" "$SKIP" "not running (cache disabled is OK)"
fi

# ── Endpoints ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Key Endpoints${RESET}"
echo -e "  Swagger UI   →  http://localhost:$APP_PORT/swagger-ui.html"
echo -e "  Health       →  http://localhost:$APP_PORT/actuator/health"
echo -e "  Metrics      →  http://localhost:$APP_PORT/actuator/prometheus"
echo ""
