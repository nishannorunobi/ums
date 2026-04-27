#!/bin/bash
# health_from_host.sh — Check UMS container health from the host.
set -euo pipefail

CONTAINER_NAME="ums-app"
HOST="localhost"
PORT="8080"
TIMEOUT=5

OK=0
FAIL=1

pass() { echo "[  OK  ] $1"; }
fail() { echo "[ FAIL ] $1"; }
info() { echo "[ INFO ] $1"; }

overall=$OK

# ── 1. Container state ────────────────────────────────────────────────────────
if ! docker container inspect "$CONTAINER_NAME" &>/dev/null; then
    fail "Container '$CONTAINER_NAME' does not exist or is not running"
    exit $FAIL
fi

state=$(docker inspect -f '{{.State.Status}}' "$CONTAINER_NAME")
if [ "$state" = "running" ]; then
    pass "Container is $state"
else
    fail "Container state: $state"
    overall=$FAIL
fi

# ── 2. Port reachability ──────────────────────────────────────────────────────
if curl -sf --max-time "$TIMEOUT" "http://$HOST:$PORT" -o /dev/null 2>/dev/null; then
    pass "HTTP $HOST:$PORT is reachable"
elif curl -sf --max-time "$TIMEOUT" "http://$HOST:$PORT" -o /dev/null -w "%{http_code}" 2>/dev/null | grep -qE "^[2345]"; then
    pass "HTTP $HOST:$PORT is reachable"
else
    http_code=$(curl -s --max-time "$TIMEOUT" -o /dev/null -w "%{http_code}" "http://$HOST:$PORT" 2>/dev/null || echo "000")
    if [ "$http_code" = "000" ]; then
        fail "HTTP $HOST:$PORT unreachable (no response within ${TIMEOUT}s)"
        overall=$FAIL
    else
        pass "HTTP $HOST:$PORT responded with status $http_code"
    fi
fi

# ── 3. Uptime ─────────────────────────────────────────────────────────────────
started=$(docker inspect -f '{{.State.StartedAt}}' "$CONTAINER_NAME" 2>/dev/null || true)
if [ -n "$started" ]; then
    info "Container started at: $started"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo "──────────────────────────────────────"
if [ "$overall" -eq "$OK" ]; then
    echo "Status: HEALTHY"
else
    echo "Status: UNHEALTHY"
fi

exit $overall
