#!/bin/bash
# prepare_db.sh — Create DB user, database, tables (DDL), and seed data (DML).
# Run INSIDE the postgres:16 container.  Safe to run multiple times.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DDL_DIR="$PROJECT_DIR/ddl"
DML_DIR="$PROJECT_DIR/dml"

source "$PROJECT_DIR/.env"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

PSQL_SUPER="psql -U $PG_SUPERUSER -h $PG_HOST -p $PG_PORT"
PSQL_APP="psql -U $PG_SUPERUSER -h $PG_HOST -p $PG_PORT -d $UMS_DB"

echo ""
echo -e "${BOLD}╔══════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║       UMS DB — PREPARE               ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════╝${RESET}"
echo ""

# ── 1. PostgreSQL ready? ──────────────────────────────────────────────────────
info "Checking PostgreSQL at $PG_HOST:$PG_PORT..."
if ! pg_isready -h "$PG_HOST" -p "$PG_PORT" -q; then
    error "PostgreSQL is not ready. Start it first."
    exit 1
fi
success "PostgreSQL is ready."

# ── DDL ───────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── DDL ─────────────────────────────────${RESET}"

# 2. Create application user
info "ddl/01_create_user.sql"
$PSQL_SUPER \
    -v UMS_USER="$UMS_USER" \
    -v UMS_PASSWORD="$UMS_PASSWORD" \
    -f "$DDL_DIR/01_create_user.sql" -q

success "  user '$UMS_USER' ready."

# 3. Create database
info "ddl/02_create_database.sql"
DB_EXISTS=$($PSQL_SUPER -tc \
    "SELECT 1 FROM pg_database WHERE datname='$UMS_DB'" | tr -d '[:space:]')

if [ "$DB_EXISTS" = "1" ]; then
    warn "  database '$UMS_DB' already exists — skipping."
else
    $PSQL_SUPER \
        -v UMS_DB="$UMS_DB" \
        -v UMS_USER="$UMS_USER" \
        -f "$DDL_DIR/02_create_database.sql" -q
    success "  database '$UMS_DB' created."
fi

# 4. Tables — each script is self-contained (no -v flags needed)
run_table() {
    local FILE="$1"
    info "ddl/$FILE"
    $PSQL_APP -f "$DDL_DIR/$FILE" -q
    success "  done."
}

run_table "03_roles_table.sql"
run_table "04_users_table.sql"
run_table "05_user_roles_table.sql"
run_table "06_audit_logs_table.sql"

# 5. Standalone sequences (not owned by any table)
info "ddl/07_sequences.sql"
$PSQL_APP -f "$DDL_DIR/07_sequences.sql" -q
success "  sequences done."

# 6. Grants
info "Applying grants to '$UMS_USER'..."
$PSQL_APP -q << SQL
GRANT CONNECT ON DATABASE "$UMS_DB" TO "$UMS_USER";
GRANT USAGE   ON SCHEMA public       TO "$UMS_USER";
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES    IN SCHEMA public TO "$UMS_USER";
GRANT USAGE, SELECT                  ON ALL SEQUENCES IN SCHEMA public TO "$UMS_USER";
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES    TO "$UMS_USER";
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT USAGE, SELECT                  ON SEQUENCES TO "$UMS_USER";
SQL
success "  grants applied."

# ── DML ───────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── DML ─────────────────────────────────${RESET}"

info "dml/01_seed_data.sql"
$PSQL_APP -f "$DML_DIR/01_seed_data.sql" -q
success "  seed data applied."

# ── pgweb ─────────────────────────────────────────────────────────────────────
echo ""
"$SCRIPT_DIR/db_ui.sh" --install-only

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
success "Database is ready!"
echo ""
echo -e "  ${BOLD}Host      ${RESET}  $PG_HOST:$PG_PORT"
echo -e "  ${BOLD}Database  ${RESET}  $UMS_DB"
echo -e "  ${BOLD}User      ${RESET}  $UMS_USER"
echo -e "  ${BOLD}Tables    ${RESET}  $TABLE_ROLES  $TABLE_USERS  $TABLE_USER_ROLES  $TABLE_AUDIT_LOGS"
echo -e "  ${BOLD}Sequences ${RESET}  $SEQ_ROLES_ID  $SEQ_AUDIT_LOGS_ID"
echo -e "  ${BOLD}Connect   ${RESET}  ./scripts/connect.sh"
echo -e "  ${BOLD}Browse    ${RESET}  ./scripts/db_ui.sh"
echo ""
