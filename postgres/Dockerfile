FROM postgres:17-bookworm

LABEL maintainer="it-helpdesk"
LABEL description="PostgreSQL 17 with all extensions: PostGIS, pgvector, pg_cron, TimescaleDB, pg_repack, RUM, HypoPG, pgAudit, procedural languages, FDWs, and all contrib modules"

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies for building extensions
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Build tools
    build-essential ca-certificates curl gnupg lsb-release wget \
    # For procedural languages
    python3 python3-pip python3-dev python3-venv \
    perl libperl-dev \
    tcl tcl-dev \
    lua5.3 liblua5.3-dev \
    # For PostGIS raster
    libxml2-dev libgeos-dev libproj-dev libgdal-dev libjson-c-dev \
    libprotobuf-c-dev protobuf-c-compiler \
    # For various extensions
    libssl-dev zlib1g-dev libreadline-dev libpq-dev \
    libcurl4-openssl-dev libpcre3-dev \
    # Utilities
    git postgresql-server-dev-17 \
    && rm -rf /var/lib/apt/lists/*

# Add PostgreSQL APT repository for extension packages
RUN curl -sS https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor > /usr/share/keyrings/pgdg.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/pgdg.gpg] http://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" > /etc/apt/sources.list.d/pgdg.list

# Add TimescaleDB repository (use trusted due to PackageCloud GPG issues)
RUN echo "deb [trusted=yes] https://packagecloud.io/timescale/timescaledb/debian/ bookworm main" > /etc/apt/sources.list.d/timescaledb.list

# Update and install ALL PostgreSQL 17 extensions from apt
RUN apt-get update && apt-get install -y --no-install-recommends \
    # ============================================================
    # PostGIS — Geospatial
    # ============================================================
    postgresql-17-postgis-3 postgresql-17-postgis-3-scripts \
    postgresql-17-pgrouting postgresql-17-pgrouting-scripts \
    # ============================================================
    # pgvector — Vector embeddings / AI
    # ============================================================
    postgresql-17-pgvector \
    \
    # ============================================================
    # TimescaleDB — Time-series data
    # ============================================================
    timescaledb-2-postgresql-17 \
    \
    # ============================================================
    # pg_cron — Job scheduling (cron)
    # ============================================================
    postgresql-17-cron \
    \
    # ============================================================
    # pg_repack — Table reorganization without locks
    # ============================================================
    postgresql-17-repack \
    \
    # ============================================================
    # pgAudit — Detailed audit logging
    # ============================================================
    postgresql-17-pgaudit \
    \
    # ============================================================
    # HypoPG — Hypothetical indexes
    # ============================================================
    postgresql-17-hypopg \
    \
    # ============================================================
    # RUM — Enhanced full-text search index
    # ============================================================
    postgresql-17-rum \
    \
    # ============================================================
    # pglogical — Logical replication
    # ============================================================
    postgresql-17-pglogical postgresql-17-pglogical-ticker \
    \
    # ============================================================
    # PL/Lua — Lua procedural language
    # ============================================================
    postgresql-17-pllua \
    \
    # ============================================================
    # Prefix — Prefix matching via GiST
    # ============================================================
    postgresql-17-prefix \
    \
    # ============================================================
    # IP4r — IP address range type
    # ============================================================
    postgresql-17-ip4r \
    \
    # ============================================================
    # JSQuery — JSON query language
    # ============================================================
    postgresql-17-jsquery \
    \
    # ============================================================
    # Unit — Unit of measure types
    # ============================================================
    postgresql-17-unit \
    \
    # ============================================================
    # TDigest — Statistical aggregates
    # ============================================================
    postgresql-17-tdigest \
    \
    # ============================================================
    # pgMP — Multiple precision arithmetic
    # ============================================================
    postgresql-17-pgmp \
    \
    # ============================================================
    # Foreign Data Wrappers
    # ============================================================
    postgresql-17-mysql-fdw \
    postgresql-17-ogr-fdw \
    postgresql-17-tds-fdw \
    \
    # ============================================================
    # Replication & WAL
    # ============================================================
    postgresql-17-wal2json \
    postgresql-17-repmgr \
    postgresql-17-pg-failover-slots \
    postgresql-17-pgq3 \
    \
    # ============================================================
    # Profiling & Monitoring
    # ============================================================
    postgresql-17-plprofiler \
    postgresql-17-pg-stat-kcache \
    postgresql-17-pg-wait-sampling \
    postgresql-17-toastinfo \
    \
    # ============================================================
    # Contrib extensions (huge bundle)
    # ============================================================
    postgresql-contrib-17 \
    \
    # ============================================================
    # Additional utilities
    # ============================================================
    postgresql-17-pg-checksums \
    postgresql-17-pgagent \
    postgresql-17-pgmemcache \
    postgresql-17-plpgsql-check \
    postgresql-17-plsh \
    && rm -rf /var/lib/apt/lists/*

# ============================================================
# Install pgvector from source for latest version (optional, apt version is fine)
# ============================================================

# ============================================================
# Install PL/Python3U support & common Python packages
# ============================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-plpython3-17 \
    && python3 -m pip install --break-system-packages \
    numpy pandas scipy scikit-learn \
    requests httpx \
    langchain langchain-community \
    openai \
    && rm -rf /var/lib/apt/lists/*

# ============================================================
# Copy init scripts
# ============================================================
COPY init/ /docker-entrypoint-initdb.d/
COPY config/ /etc/postgresql-config/

# ============================================================
# Set permissions
# ============================================================
RUN chmod -R 755 /docker-entrypoint-initdb.d/ \
    && chown -R postgres:postgres /docker-entrypoint-initdb.d/

# ============================================================
# Custom postgresql.conf will be loaded via docker-compose volume mount
# ============================================================

ENV DEBIAN_FRONTEND=dialog

EXPOSE 5432

CMD ["postgres"]
