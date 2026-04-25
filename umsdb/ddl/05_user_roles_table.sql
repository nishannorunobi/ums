-- DDL: user_roles_table
-- Run independently: psql -U postgres -d umsdb -f ddl/05_user_roles_table.sql
-- Depends on: 03_roles_table.sql, 04_users_table.sql

-- Table (composite PK — no sequence)
CREATE TABLE IF NOT EXISTS user_roles (
    user_id UUID    NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    role_id INTEGER NOT NULL REFERENCES roles (id),
    PRIMARY KEY (user_id, role_id)
);

-- Grants
GRANT SELECT, INSERT, UPDATE, DELETE ON user_roles TO ums_user;

-- Comments
COMMENT ON TABLE user_roles IS 'Many-to-many join: users <-> roles';
