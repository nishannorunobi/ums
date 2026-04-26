#!/bin/bash
# login_docker.sh — Open a shell inside the running UMS container.
# Run on the HOST.
set -euo pipefail

CONTAINER_NAME="ums-app"

if ! docker container inspect "$CONTAINER_NAME" &>/dev/null; then
    echo "Container '$CONTAINER_NAME' is not running."
    exit 1
fi

docker exec -it "$CONTAINER_NAME" bash
