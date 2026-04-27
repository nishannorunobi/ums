#!/bin/bash
# login_docker.sh — Open a shell inside the running UMS container.
# Run on the HOST.
set -euo pipefail

CONTAINER_NAME="ums-app"

state=$(docker inspect -f '{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null || true)

if [ -z "$state" ]; then
    echo "Container '$CONTAINER_NAME' does not exist."
    exit 1
fi

if [ "$state" != "running" ]; then
    echo "Container '$CONTAINER_NAME' is $state, not running."
    exit 1
fi

docker exec -it "$CONTAINER_NAME" sh
