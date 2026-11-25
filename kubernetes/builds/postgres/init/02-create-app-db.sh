#!/bin/bash
# Create app database + user — from container env vars (no hardcoded password)
set -e

APP_USER="${APP_USER:-appuser}"
APP_DB="${APP_DB:-appdb}"

if [ -z "${APP_PASSWORD:-}" ]; then
    if command -v openssl >/dev/null 2>&1; then
        APP_PASSWORD="$(openssl rand -hex 24)"
    else
        APP_PASSWORD="$(head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n')"
    fi
    echo "[!] APP_PASSWORD was not provided — generated random password for '${APP_USER}' (set APP_PASSWORD explicitly to override)."
fi

psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" <<SQL
CREATE DATABASE ${APP_DB}
    WITH OWNER = ${POSTGRES_USER}
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.utf8'
    LC_CTYPE = 'en_US.utf8'
    TEMPLATE = template0
    CONNECTION LIMIT = -1;

\c ${APP_DB}

CREATE USER ${APP_USER} WITH PASSWORD '${APP_PASSWORD}';
GRANT CONNECT ON DATABASE ${APP_DB} TO ${APP_USER};
GRANT ALL ON SCHEMA public TO ${APP_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${APP_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${APP_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO ${APP_USER};

\i /docker-entrypoint-initdb.d/01-extensions.sql

CREATE SCHEMA IF NOT EXISTS analytics;
CREATE SCHEMA IF NOT EXISTS logs;
CREATE SCHEMA IF NOT EXISTS vectors;
CREATE SCHEMA IF NOT EXISTS geo;

GRANT ALL ON SCHEMA analytics, logs, vectors, geo TO ${APP_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA analytics, logs, vectors, geo GRANT ALL ON TABLES TO ${APP_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA analytics, logs, vectors, geo GRANT ALL ON SEQUENCES TO ${APP_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA analytics, logs, vectors, geo GRANT ALL ON FUNCTIONS TO ${APP_USER};
SQL

echo "✓ App DB '${APP_DB}' + user '${APP_USER}' created"
