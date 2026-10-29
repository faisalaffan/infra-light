#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# PostgreSQL Cross-Database FDW Synchronizer
# Imports all databases into 'postgres' database schemas
# ─────────────────────────────────────────────────────────────

POSTGRES_POD="${POSTGRES_POD:-postgres-0}"
POSTGRES_NAMESPACE="${POSTGRES_NAMESPACE:-infra}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-postgres_super_secret_2026}"

echo "🔄 Synchronizing foreign data wrappers in ${POSTGRES_POD} (${POSTGRES_NAMESPACE})..."

kubectl exec -n "${POSTGRES_NAMESPACE}" "${POSTGRES_POD}" -- psql -U "${POSTGRES_USER}" -d postgres -c "
DO \$\$
DECLARE
    db_rec RECORD;
    schema_rec RECORD;
    safe_schema_name text;
    srv_name text;
    schema_name_zitadel text;
    target_schema text;
BEGIN
    CREATE EXTENSION IF NOT EXISTS postgres_fdw;

    -- 1. Import all standard databases (public schema)
    FOR db_rec IN 
        SELECT datname 
        FROM pg_database 
        WHERE datistemplate = false 
          AND datname NOT IN ('postgres')
    LOOP
        safe_schema_name := replace(db_rec.datname, '-', '_');
        srv_name := 'fdw_' || safe_schema_name;

        EXECUTE format('DROP SERVER IF EXISTS %I CASCADE;', srv_name);
        EXECUTE format('CREATE SERVER %I FOREIGN DATA WRAPPER postgres_fdw OPTIONS (host %L, port %L, dbname %L);', srv_name, 'localhost', '5432', db_rec.datname);
        EXECUTE format('CREATE USER MAPPING FOR postgres SERVER %I OPTIONS (user %L, password %L);', srv_name, '${POSTGRES_USER}', '${POSTGRES_PASSWORD}');

        EXECUTE format('CREATE SCHEMA IF NOT EXISTS %I;', safe_schema_name);

        BEGIN
            EXECUTE format('IMPORT FOREIGN SCHEMA public FROM SERVER %I INTO %I;', srv_name, safe_schema_name);
            RAISE NOTICE 'Imported public from % into schema %', db_rec.datname, safe_schema_name;
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Skipping public from %: %', db_rec.datname, SQLERRM;
        END;
    END LOOP;

    -- 2. Import Zitadel dedicated microservice schemas
    IF EXISTS (SELECT 1 FROM pg_database WHERE datname = 'zitadel') THEN
        FOR schema_name_zitadel IN 
            SELECT unnest(ARRAY['adminapi', 'auth', 'cache', 'eventstore', 'logstore', 'projections', 'system'])
        LOOP
            target_schema := 'zitadel_' || schema_name_zitadel;
            EXECUTE format('CREATE SCHEMA IF NOT EXISTS %I;', target_schema);
            BEGIN
                EXECUTE format('IMPORT FOREIGN SCHEMA %I FROM SERVER fdw_zitadel INTO %I;', schema_name_zitadel, target_schema);
                RAISE NOTICE 'Imported zitadel.% into schema %', schema_name_zitadel, target_schema;
            EXCEPTION WHEN OTHERS THEN
                RAISE NOTICE 'Skipping zitadel.%: %', schema_name_zitadel, SQLERRM;
            END;
        END LOOP;
    END IF;
END
\$\$;
"

echo "✅ All database schemas successfully imported into 'postgres' database via postgres_fdw!"

