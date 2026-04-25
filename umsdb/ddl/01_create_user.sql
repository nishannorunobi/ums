-- 01_create_user.sql — Create the application DB user (idempotent)

DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'UMS_USER') THEN
        EXECUTE format('CREATE USER %I WITH PASSWORD %L', :'UMS_USER', :'UMS_PASSWORD');
        RAISE NOTICE 'User "%" created.', :'UMS_USER';
    ELSE
        -- Update password in case it changed
        EXECUTE format('ALTER USER %I WITH PASSWORD %L', :'UMS_USER', :'UMS_PASSWORD');
        RAISE NOTICE 'User "%" already exists — password updated.', :'UMS_USER';
    END IF;
END
$$;
