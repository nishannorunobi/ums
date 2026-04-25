-- ──────────────────────────────────────────────────────────
-- V1: Initial schema — users, roles, user_roles
-- ──────────────────────────────────────────────────────────

CREATE TABLE roles (
    id   SERIAL      PRIMARY KEY,
    name VARCHAR(30) NOT NULL UNIQUE
);

CREATE TABLE users (
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
    version      BIGINT       DEFAULT 0
);

CREATE TABLE user_roles (
    user_id UUID    NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id INTEGER NOT NULL REFERENCES roles(id),
    PRIMARY KEY (user_id, role_id)
);

-- Indexes
CREATE INDEX idx_user_email    ON users(email);
CREATE INDEX idx_user_username ON users(username);

-- Seed roles
INSERT INTO roles (name) VALUES
    ('ROLE_USER'),
    ('ROLE_MODERATOR'),
    ('ROLE_ADMIN');

-- Seed default admin (password: Admin@1234)
INSERT INTO users (id, username, email, password, enabled, first_name, last_name, created_by)
VALUES (
    gen_random_uuid(),
    'admin',
    'admin@ums.local',
    '$2a$12$T1Q1F4PnpFKVv/BoJuVxK.WF8Tc5e8p7CX.5pE3N4RJVZ6nFkHbDa',
    TRUE,
    'System',
    'Admin',
    'system'
);

-- Assign ADMIN role to the seed admin
INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id
FROM   users u, roles r
WHERE  u.username = 'admin'
AND    r.name = 'ROLE_ADMIN';
