#!/bin/bash
# build_env_ui.sh — Install Node.js, npm, and all ums-ui dependencies.
# Run INSIDE the ums-app container — once, before start_admin_ui.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UI_DIR="$(cd "$SCRIPT_DIR/../../ums-ui" && pwd)"

source "$SCRIPT_DIR/common.sh"

banner "UMS Admin UI — Build Environment"

# ── Install Node.js if missing ────────────────────────────────────────────────
if ! command -v node &>/dev/null; then
    info "Node.js not found — installing..."

    if command -v apt-get &>/dev/null; then
        apt-get update -qq
        # Use NodeSource for a recent LTS instead of the OS default (often outdated)
        if command -v curl &>/dev/null; then
            curl -fsSL https://deb.nodesource.com/setup_20.x | bash - -qq
            apt-get install -y nodejs -qq
        else
            apt-get install -y nodejs npm -qq
        fi
    elif command -v apk &>/dev/null; then
        apk add --no-cache nodejs npm
    elif command -v dnf &>/dev/null; then
        dnf install -y nodejs npm -q
    else
        error "No supported package manager found (apt-get / apk / dnf)."
        exit 1
    fi
else
    info "Node.js already installed."
fi

NODE_VER=$(node --version 2>/dev/null || echo "unknown")
NPM_VER=$(npm --version  2>/dev/null || echo "unknown")
success "Node $NODE_VER  ·  npm $NPM_VER"

# ── Verify minimum Node version (18+) ─────────────────────────────────────────
NODE_MAJOR=$(node --version | sed 's/v//' | cut -d. -f1)
if [ "$NODE_MAJOR" -lt 18 ]; then
    error "Node.js 18+ required (found $NODE_VER). Please upgrade."
    exit 1
fi

# ── Install npm dependencies ───────────────────────────────────────────────────
if [ ! -f "$UI_DIR/package.json" ]; then
    error "package.json not found at $UI_DIR/package.json"
    exit 1
fi

cd "$UI_DIR"

if [ -d "node_modules" ]; then
    info "node_modules already exists — running npm install to sync..."
else
    info "Installing npm dependencies..."
fi

npm install --prefer-offline 2>&1 | grep -v "^npm warn" || true
success "npm dependencies installed."

# ── Install 'serve' globally if not present ────────────────────────────────────
if ! command -v serve &>/dev/null && ! npx --yes serve --version &>/dev/null 2>&1; then
    info "Installing 'serve' globally for static file serving..."
    npm install -g serve --silent
fi
success "'serve' is available."

success "Environment ready."
