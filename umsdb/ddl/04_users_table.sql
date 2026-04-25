-- DDL: users_table
-- Run independently: psql -U postgres -d umsdb -f ddl/04_users_table.sql

-- Extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";  -- gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS "pg_trgm";   -- trigram indexes for LIKE search

-- Table (UUID primary key — no integer sequence needed)
CREATE TABLE IF NOT EXISTS users (
    id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    username     VARCHAR(50)  NOT NULL UNIQUE,
    email        VARCHAR(100) NOT NULL UNIQUE,
    password     VARCHAR(255) NOT NULL,
    enabled      BOOLEAN      NOT NULL DEFAULT TRUE,
    first_name   VARCHAR(80),
    last_name    VARCHAR(80),
    phone_number VARCHAR(20),
    created_at   TIMESTAMP,
    updated_at   TIMESTAMP,
    created_by   VARCHAR(100),
    updated_by   VARCHAR(100),
    version      BIGINT       NOT NULL DEFAULT 0
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_users_email         ON users (email);
CREATE INDEX IF NOT EXISTS idx_users_username      ON users (username);
CREATE INDEX IF NOT EXISTS idx_users_username_trgm ON users USING gin (username gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_users_email_trgm    ON users USING gin (email    gin_trgm_ops);

-- Grants
GRANT SELECT, INSERT, UPDATE, DELETE ON users TO ums_user;

-- Comments
COMMENT ON TABLE  users          IS 'Application user accounts';
COMMENT ON COLUMN users.password IS 'BCrypt-hashed — never store plain text';
COMMENT ON COLUMN users.version  IS 'Optimistic locking counter (JPA @Version)';
