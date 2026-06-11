-- ============================================================
-- Create Application Database & User
-- ============================================================

-- Create app database
CREATE DATABASE appdb
    WITH OWNER = postgres
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.utf8'
    LC_CTYPE = 'en_US.utf8'
    TEMPLATE = template0
    CONNECTION LIMIT = -1;

\c appdb

-- Create app user
CREATE USER appuser WITH PASSWORD 'appuser_secret_2026';
GRANT CONNECT ON DATABASE appdb TO appuser;

-- Grant schema permissions
GRANT ALL ON SCHEMA public TO appuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO appuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO appuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO appuser;

-- Enable all extensions in appdb too
\i /docker-entrypoint-initdb.d/01-extensions.sql

-- Create useful schemas
CREATE SCHEMA IF NOT EXISTS analytics;
CREATE SCHEMA IF NOT EXISTS logs;
CREATE SCHEMA IF NOT EXISTS vectors;
CREATE SCHEMA IF NOT EXISTS geo;

GRANT ALL ON SCHEMA analytics, logs, vectors, geo TO appuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA analytics, logs, vectors, geo
    GRANT ALL ON TABLES TO appuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA analytics, logs, vectors, geo
    GRANT ALL ON SEQUENCES TO appuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA analytics, logs, vectors, geo
    GRANT ALL ON FUNCTIONS TO appuser;

\echo '============================================'
\echo ' App DB & User created successfully!'
\echo '============================================'
