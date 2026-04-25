-- DDL: audit_logs_table
-- Run independently: psql -U postgres -d umsdb -f ddl/06_audit_logs_table.sql

-- Sequence
CREATE SEQUENCE IF NOT EXISTS audit_logs_id_seq
    START 1 INCREMENT 1;

-- Table
CREATE TABLE IF NOT EXISTS audit_logs (
    id          BIGINT       PRIMARY KEY DEFAULT nextval('audit_logs_id_seq'),
    action      VARCHAR(20)  NOT NULL,
    entity_type VARCHAR(50)  NOT NULL,
    entity_id   VARCHAR(100),
    user_id     VARCHAR(100),
    username    VARCHAR(100),
    old_value   TEXT,
    new_value   TEXT,
    ip_address  VARCHAR(45),
    request_id  VARCHAR(100),
    timestamp   TIMESTAMP    NOT NULL DEFAULT NOW()
);

ALTER SEQUENCE audit_logs_id_seq OWNED BY audit_logs.id;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_audit_entity ON audit_logs (entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_user   ON audit_logs (user_id);
CREATE INDEX IF NOT EXISTS idx_audit_ts     ON audit_logs (timestamp DESC);

-- Grants
GRANT SELECT, INSERT, UPDATE, DELETE ON audit_logs             TO ums_user;
GRANT USAGE, SELECT                  ON SEQUENCE audit_logs_id_seq TO ums_user;

-- Comments
COMMENT ON TABLE  audit_logs             IS 'Immutable audit trail — do not UPDATE or DELETE rows';
COMMENT ON COLUMN audit_logs.action      IS 'CREATE | UPDATE | DELETE | READ';
COMMENT ON COLUMN audit_logs.entity_type IS 'e.g. User, Role';
