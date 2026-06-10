FROM postgres:18-bookworm

LABEL maintainer="it-helpdesk"
LABEL description="PostgreSQL 18.4 all extensions: PostGIS, pgvector, pg_cron, TimescaleDB, pg_repack, RUM, HypoPG, pgAudit, PLs, FDWs, contrib"

ENV DEBIAN_FRONTEND=noninteractive

# 1. Install curl + gnupg first (base image minimal — ga ada curl)
RUN apt-get update && apt-get install -y --no-install-recommends curl gnupg ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 2. Add PostgreSQL APT repo
RUN curl -sS https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor > /usr/share/keyrings/pgdg.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/pgdg.gpg] http://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" > /etc/apt/sources.list.d/pgdg.list

# 3. Add TimescaleDB repo
RUN echo "deb [trusted=yes] https://packagecloud.io/timescale/timescaledb/debian/ bookworm main" > /etc/apt/sources.list.d/timescaledb.list

# 4. All system deps + ALL extensions in one layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    # --- Build tools ---
    build-essential ca-certificates curl gnupg lsb-release wget git \
    # --- Procedural languages ---
    python3 python3-pip python3-dev python3-venv \
    perl libperl-dev \
    tcl tcl-dev \
    lua5.3 liblua5.3-dev \
    # --- PostGIS deps ---
    libxml2-dev libgeos-dev libproj-dev libgdal-dev libjson-c-dev \
    libprotobuf-c-dev protobuf-c-compiler \
    # --- General -dev ---
    libssl-dev zlib1g-dev libreadline-dev libpq-dev \
    libcurl4-openssl-dev libpcre3-dev \
    # --- PGDG dev ---
    postgresql-server-dev-18 \
    # ============================================================
    # EXTENSIONS — all from PGDG + TimescaleDB repos
    # ============================================================
    # PostGIS
    postgresql-18-postgis-3 postgresql-18-postgis-3-scripts \
    postgresql-18-pgrouting postgresql-18-pgrouting-scripts \
    # pgvector
    postgresql-18-pgvector \
    # TimescaleDB
    timescaledb-2-postgresql-18 \
    # pg_cron
    postgresql-18-cron \
    # pg_repack
    postgresql-18-repack \
    # pgAudit
    postgresql-18-pgaudit \
    # HypoPG
    postgresql-18-hypopg \
    # RUM
    postgresql-18-rum \
    # pglogical
    postgresql-18-pglogical postgresql-18-pglogical-ticker \
    # PL/Lua
    postgresql-18-pllua \
    # Prefix
    postgresql-18-prefix \
    # IP4r
    postgresql-18-ip4r \
    # JSQuery
    postgresql-18-jsquery \
    # Unit
    postgresql-18-unit \
    # TDigest
    postgresql-18-tdigest \
    # pgMP
    postgresql-18-pgmp \
    # FDWs
    postgresql-18-mysql-fdw \
    postgresql-18-ogr-fdw \
    postgresql-18-tds-fdw \
    # Replication
    postgresql-18-wal2json \
    postgresql-18-repmgr \
    postgresql-18-pg-failover-slots \
    postgresql-18-pgq3 \
    # Monitoring
    postgresql-18-plprofiler \
    postgresql-18-pg-stat-kcache \
    postgresql-18-pg-wait-sampling \
    postgresql-18-toastinfo \
    # Contrib
    postgresql-contrib-18 \
    # Misc
    postgresql-18-pg-checksums \
    postgresql-18-pgagent \
    postgresql-18-pgmemcache \
    postgresql-18-plpgsql-check \
    postgresql-18-plsh \
    # PL/Python3U
    postgresql-plpython3-18 \
    && rm -rf /var/lib/apt/lists/*

# 5. Python ML libs
RUN python3 -m pip install --break-system-packages \
    numpy pandas scipy scikit-learn \
    requests httpx \
    langchain langchain-community \
    openai

# 6. Copy init + config
COPY init/ /docker-entrypoint-initdb.d/
COPY config/ /etc/postgresql-config/

RUN chmod -R 755 /docker-entrypoint-initdb.d/ \
    && chown -R postgres:postgres /docker-entrypoint-initdb.d/

ENV DEBIAN_FRONTEND=dialog

EXPOSE 5432

CMD ["postgres"]
