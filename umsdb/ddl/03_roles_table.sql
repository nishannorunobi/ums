-- DDL: roles_table
-- Run independently: psql -U postgres -d umsdb -f ddl/03_roles_table.sql

-- Sequence
CREATE SEQUENCE IF NOT EXISTS roles_id_seq
    START 1 INCREMENT 1;

-- Table
CREATE TABLE IF NOT EXISTS roles (
    id   INTEGER     PRIMARY KEY DEFAULT nextval('roles_id_seq'),
    name VARCHAR(30) NOT NULL UNIQUE
);

ALTER SEQUENCE roles_id_seq OWNED BY roles.id;

-- Indexes
CREATE UNIQUE INDEX IF NOT EXISTS idx_roles_name ON roles (name);

-- Grants
GRANT SELECT, INSERT, UPDATE, DELETE ON roles          TO ums_user;
GRANT USAGE, SELECT                  ON SEQUENCE roles_id_seq TO ums_user;

-- Comments
COMMENT ON TABLE  roles      IS 'Application roles — ROLE_USER, ROLE_MODERATOR, ROLE_ADMIN';
COMMENT ON COLUMN roles.name IS 'Must match ERole enum in the Spring app';
