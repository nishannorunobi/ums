-- ──────────────────────────────────────────────────────────
-- V2: Audit log table
-- ──────────────────────────────────────────────────────────

CREATE TABLE audit_logs (
    id          BIGSERIAL    PRIMARY KEY,
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

CREATE INDEX idx_audit_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_user   ON audit_logs(user_id);
CREATE INDEX idx_audit_ts     ON audit_logs(timestamp DESC);
