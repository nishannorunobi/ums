# UMS Database Setup Guide

> **For new developers** — follow this guide top to bottom on a fresh machine.  
> All database scripts run **inside the PostgreSQL Docker container**.

---

## Prerequisites

Make sure these are installed on your machine before starting:

| Tool       | Check                  | Install |
|------------|------------------------|---------|
| Docker     | `docker --version`     | https://docs.docker.com/get-docker |
| Git        | `git --version`        | https://git-scm.com |

---

## Step 1 — Get the project

```bash
git clone git@github.com:nishannorunobi/ums.git
cd ums
```

---

## Step 2 — Start the PostgreSQL container

The dev container is based on `postgres:16`.  
Start it from the workspace root using the dockerspace scripts:

```bash
bash dockerspace/start_project_container.sh
```

This builds the image, starts the container, and drops you into a shell inside it.  
Keep this terminal open — you will run all database scripts from here.

---

## Step 3 — Locate the database scripts

Inside the container the workspace is mounted at `/myworkspace`.  
The database scripts are at:

```
/myworkspace/projectspace/ums/umsdb/
```

```bash
cd /myworkspace/projectspace/ums/umsdb
```

---

## Step 4 — Configure credentials

Open `.env` and verify the values match your environment:

```bash
vi .env
```

| Variable          | Default      | Description                        |
|-------------------|--------------|------------------------------------|
| `PG_HOST`         | `localhost`  | PostgreSQL host (inside container) |
| `PG_PORT`         | `5432`       | PostgreSQL port                    |
| `PG_SUPERUSER`    | `postgres`   | Superuser for setup scripts        |
| `UMS_DB`          | `umsdb`      | Application database name          |
| `UMS_USER`        | `ums_user`   | Application database user          |
| `UMS_PASSWORD`    | `ums_pass`   | Application database password      |
| `TABLE_ROLES`     | `roles`      | Roles table name                   |
| `TABLE_USERS`     | `users`      | Users table name                   |
| `TABLE_USER_ROLES`| `user_roles` | User–role junction table name      |
| `TABLE_AUDIT_LOGS`| `audit_logs` | Audit log table name               |

> Do **not** commit `.env` with real production credentials — keep it local only.

---

## Step 5 — Run the full setup (recommended)

This single command runs all steps in the correct order:

```bash
bash scripts/prepare_db.sh
```

It will:
1. Check PostgreSQL is running
2. Create the `ums_user` database user
3. Create the `umsdb` database
4. Create all four tables in order
5. Apply grants so `ums_user` can access all tables
6. Seed default roles and users
7. Install **pgweb** (browser-based DB UI)

---

## Step 5 (alternative) — Run each script manually

Use this if you want to set up tables one at a time or debug a specific step.

### 5a. Create the database user

```bash
psql -U postgres \
     -v UMS_USER=ums_user \
     -v UMS_PASSWORD=ums_pass \
     -f init/01_create_user.sql
```

### 5b. Create the database

```bash
psql -U postgres \
     -v UMS_DB=umsdb \
     -v UMS_USER=ums_user \
     -f init/02_create_database.sql
```

### 5c. Create tables — run in order

```bash
# 1. roles (no dependencies)
psql -U postgres -d umsdb \
     -v TABLE_NAME=roles \
     -f tables/01_roles.sql

# 2. users (no dependencies)
psql -U postgres -d umsdb \
     -v TABLE_NAME=users \
     -f tables/02_users.sql

# 3. user_roles — depends on roles and users (must run after 01 and 02)
psql -U postgres -d umsdb \
     -v TABLE_NAME=user_roles \
     -v TABLE_USERS=users \
     -v TABLE_ROLES=roles \
     -f tables/03_user_roles.sql

# 4. audit_logs (no dependencies)
psql -U postgres -d umsdb \
     -v TABLE_NAME=audit_logs \
     -f tables/04_audit_logs.sql
```

### 5d. Seed default data

```bash
psql -U postgres -d umsdb -f init/04_seed_data.sql
```

Default accounts created (password for all: `Admin@1234`):

| Username    | Role            |
|-------------|-----------------|
| `admin`     | `ROLE_ADMIN`    |
| `moderator` | `ROLE_MODERATOR`|
| `john_doe`  | `ROLE_USER`     |

---

## Step 6 — Verify the setup

Open a psql shell and check the tables exist:

```bash
bash scripts/connect.sh
```

```sql
\dt              -- list all tables
SELECT * FROM roles;
SELECT username, email, enabled FROM users;
\q               -- quit
```

---

## Step 7 — Browse tables in the browser

Launch the pgweb UI (installs automatically on first run):

```bash
bash scripts/db_ui.sh
```

Open in your host browser: **http://localhost:8085**

To stop pgweb:

```bash
bash scripts/db_ui.sh stop
```

---

## Step 8 — Connect the Spring Boot app

Update `ums/umsdb/.env` or the Spring Boot `application.yml` with:

```yaml
spring:
  datasource:
    url:      jdbc:postgresql://localhost:5432/umsdb
    username: ums_user
    password: ums_pass
```

Then start the app:

```bash
cd /myworkspace/projectspace/ums
bash start.sh
```

---

## Useful commands

| Task                         | Command                              |
|------------------------------|--------------------------------------|
| Open psql as app user        | `bash scripts/connect.sh`            |
| Open psql as superuser       | `bash scripts/connect.sh --admin`    |
| Launch browser DB UI         | `bash scripts/db_ui.sh`              |
| Stop browser DB UI           | `bash scripts/db_ui.sh stop`         |
| Full rebuild (wipe all data) | `bash scripts/reset_db.sh`           |
| Full rebuild (no prompt)     | `bash scripts/reset_db.sh --yes`     |

---

## Troubleshooting

**`pg_isready` fails — PostgreSQL not ready**  
The container is still starting. Wait a few seconds and retry `prepare_db.sh`.

**`psql: error: connection refused`**  
PostgreSQL may not be running. Inside the container:
```bash
pg_ctlcluster $(pg_lsclusters -h | awk 'NR==1{print $1,$2}') start
```

**`role "ums_user" already exists`**  
Safe to ignore — `01_create_user.sql` is idempotent and just updates the password.

**`database "umsdb" already exists`**  
Safe to ignore — `prepare_db.sh` skips creation and continues.

**`pgweb` download fails (no internet in container)**  
Install curl first: `apt-get update && apt-get install -y curl`  
Then retry: `bash scripts/db_ui.sh`

---

## File reference

```
umsdb/
├── .env                        ← credentials and table names (edit this first)
├── dbguide.md                  ← this file
├── init/
│   ├── 01_create_user.sql      ← creates ums_user
│   ├── 02_create_database.sql  ← creates umsdb
│   └── 04_seed_data.sql        ← roles + default users
├── tables/
│   ├── 01_roles.sql            ← roles table
│   ├── 02_users.sql            ← users table
│   ├── 03_user_roles.sql       ← junction table (needs 01 + 02 first)
│   └── 04_audit_logs.sql       ← audit log table
└── scripts/
    ├── prepare_db.sh           ← runs all steps in order
    ├── connect.sh              ← opens psql shell
    ├── db_ui.sh                ← launches pgweb browser UI
    └── reset_db.sh             ← wipe and full rebuild (dev only)
```
