-- ============================================================
-- PostgreSQL 17 — Enable ALL available extensions
-- ============================================================

\set ON_ERROR_STOP off
\echo '=== Installing all PostgreSQL extensions ==='

-- ============================================================
-- Core dependencies (order matters)
-- ============================================================
CREATE EXTENSION IF NOT EXISTS plpgsql;
CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;        -- Required by postgis_tiger_geocoder
CREATE EXTENSION IF NOT EXISTS plpython3u;            -- Required by ltree_plpython3u

-- ============================================================
-- Vector & AI
-- ============================================================
CREATE EXTENSION IF NOT EXISTS vector;              -- pgvector: vector embeddings (0.8.2)

-- ============================================================
-- Geospatial (PostGIS family)
-- ============================================================
CREATE EXTENSION IF NOT EXISTS postgis;              -- Geometry & geography types
CREATE EXTENSION IF NOT EXISTS postgis_raster;       -- Raster data
CREATE EXTENSION IF NOT EXISTS postgis_sfcgal;       -- Advanced 3D/geometric ops
CREATE EXTENSION IF NOT EXISTS postgis_topology;     -- Topology management
CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder; -- TIGER geocoder (US Census)
CREATE EXTENSION IF NOT EXISTS pgrouting;            -- Routing algorithms
CREATE EXTENSION IF NOT EXISTS address_standardizer; -- Address parsing
CREATE EXTENSION IF NOT EXISTS address_standardizer_data_us;

-- ============================================================
-- Time-series
-- ============================================================
CREATE EXTENSION IF NOT EXISTS timescaledb;          -- TimescaleDB hypertables

-- ============================================================
-- Job Scheduling
-- ============================================================
CREATE EXTENSION IF NOT EXISTS pg_cron;              -- Cron scheduler in DB

-- ============================================================
-- Replication & CDC
-- ============================================================
CREATE EXTENSION IF NOT EXISTS pglogical;            -- Logical replication
CREATE EXTENSION IF NOT EXISTS pglogical_ticker;     -- Replication ticker

-- ============================================================
-- Performance & Monitoring
-- ============================================================
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;   -- Query performance stats
CREATE EXTENSION IF NOT EXISTS pg_stat_kcache;       -- Kernel cache stats
CREATE EXTENSION IF NOT EXISTS pg_wait_sampling;     -- Wait event sampling
CREATE EXTENSION IF NOT EXISTS pg_buffercache;       -- Buffer cache inspection
CREATE EXTENSION IF NOT EXISTS pg_prewarm;           -- Prewarm cache
CREATE EXTENSION IF NOT EXISTS pgstattuple;          -- Tuple-level stats
CREATE EXTENSION IF NOT EXISTS pg_visibility;        -- Visibility map info
CREATE EXTENSION IF NOT EXISTS pg_freespacemap;      -- Free space map
CREATE EXTENSION IF NOT EXISTS pg_walinspect;        -- WAL inspection
CREATE EXTENSION IF NOT EXISTS pageinspect;          -- Page-level inspection
CREATE EXTENSION IF NOT EXISTS pg_surgery;           -- Row repair tools
CREATE EXTENSION IF NOT EXISTS toastinfo;            -- TOAST storage details

-- ============================================================
-- Full-Text Search
-- ============================================================
CREATE EXTENSION IF NOT EXISTS pg_trgm;              -- Trigram matching
CREATE EXTENSION IF NOT EXISTS rum;                  -- RUM index (better than GIN)
CREATE EXTENSION IF NOT EXISTS unaccent;             -- Remove accents
CREATE EXTENSION IF NOT EXISTS dict_int;             -- Integer dictionary
CREATE EXTENSION IF NOT EXISTS dict_xsyn;            -- Synonym dictionary

-- ============================================================
-- Index Types
-- ============================================================
CREATE EXTENSION IF NOT EXISTS btree_gin;            -- GIN on B-tree operators
CREATE EXTENSION IF NOT EXISTS btree_gist;           -- GiST on B-tree operators
CREATE EXTENSION IF NOT EXISTS bloom;                -- Bloom filter index
CREATE EXTENSION IF NOT EXISTS hypopg;               -- Hypothetical indexes

-- ============================================================
-- Data Types & Utilities
-- ============================================================
CREATE EXTENSION IF NOT EXISTS hstore;               -- Key-value store
CREATE EXTENSION IF NOT EXISTS citext;               -- Case-insensitive text
CREATE EXTENSION IF NOT EXISTS ltree;                -- Tree structures
CREATE EXTENSION IF NOT EXISTS ltree_plpython3u;     -- ltree + Python
CREATE EXTENSION IF NOT EXISTS isn;                  -- ISBN/ISSN/UPC/EAN types
CREATE EXTENSION IF NOT EXISTS unit;                 -- Units of measure
CREATE EXTENSION IF NOT EXISTS ip4r;                 -- IP address ranges
CREATE EXTENSION IF NOT EXISTS prefix;               -- Prefix matching
CREATE EXTENSION IF NOT EXISTS seg;                  -- Line segments / intervals
CREATE EXTENSION IF NOT EXISTS cube;                 -- Multi-dimensional cubes
CREATE EXTENSION IF NOT EXISTS earthdistance;        -- Earth distance calculations
CREATE EXTENSION IF NOT EXISTS tdigest;              -- Statistical aggregates
CREATE EXTENSION IF NOT EXISTS pgmp;                 -- Arbitrary precision math

-- ============================================================
-- JSON & Semi-structured
-- ============================================================
CREATE EXTENSION IF NOT EXISTS jsquery;              -- JSON query language

-- ============================================================
-- Cryptography & Security
-- ============================================================
CREATE EXTENSION IF NOT EXISTS pgcrypto;             -- Cryptographic functions
CREATE EXTENSION IF NOT EXISTS pgaudit;              -- Audit logging

-- ============================================================
-- UUID & Identity
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";          -- UUID generation

-- ============================================================
-- Procedural Languages
-- ============================================================
CREATE EXTENSION IF NOT EXISTS pllua;                -- Lua
CREATE EXTENSION IF NOT EXISTS plsh;                 -- Shell scripting
CREATE EXTENSION IF NOT EXISTS plpgsql_check;        -- PL/pgSQL linter
CREATE EXTENSION IF NOT EXISTS plprofiler;           -- PL/pgSQL profiler

-- ============================================================
-- Foreign Data Wrappers
-- ============================================================
CREATE EXTENSION IF NOT EXISTS postgres_fdw;         -- PostgreSQL-to-PostgreSQL
CREATE EXTENSION IF NOT EXISTS mysql_fdw;            -- MySQL FDW
CREATE EXTENSION IF NOT EXISTS ogr_fdw;              -- OGR (GIS file formats)
CREATE EXTENSION IF NOT EXISTS tds_fdw;              -- SQL Server / Sybase FDW

-- ============================================================
-- Cross-DB
-- ============================================================
CREATE EXTENSION IF NOT EXISTS dblink;               -- Cross-database queries

-- ============================================================
-- Table Management
-- ============================================================
CREATE EXTENSION IF NOT EXISTS pg_repack;            -- Online table repack

-- ============================================================
-- Analytics & Math
-- ============================================================
CREATE EXTENSION IF NOT EXISTS tablefunc;            -- Crosstab
CREATE EXTENSION IF NOT EXISTS intagg;               -- Integer aggregator
CREATE EXTENSION IF NOT EXISTS intarray;             -- Integer arrays

-- ============================================================
-- Misc Contrib
-- ============================================================
CREATE EXTENSION IF NOT EXISTS lo;                   -- Large object management
CREATE EXTENSION IF NOT EXISTS xml2;                 -- XML/XPath
CREATE EXTENSION IF NOT EXISTS sslinfo;              -- SSL certificate info
CREATE EXTENSION IF NOT EXISTS pgrowlocks;           -- Row locking info
CREATE EXTENSION IF NOT EXISTS refint;               -- Referential integrity
CREATE EXTENSION IF NOT EXISTS tsm_system_rows;      -- Tablesample: rows
CREATE EXTENSION IF NOT EXISTS tsm_system_time;      -- Tablesample: time limit
CREATE EXTENSION IF NOT EXISTS moddatetime;          -- Auto last-modified timestamp

-- ============================================================
-- Report
-- ============================================================
\echo '============================================'
\echo ' Verifying installed extensions:'
\echo '============================================'
SELECT
    name,
    default_version,
    installed_version,
    substring(comment, 1, 80) AS description
FROM pg_available_extensions
WHERE installed_version IS NOT NULL
ORDER BY name;
