FROM postgres:17-bookworm

LABEL maintainer="it-helpdesk"
LABEL description="PostgreSQL 17 all extensions: PostGIS, pgvector, pg_cron, TimescaleDB, pg_repack, RUM, HypoPG, pgAudit, PLs, FDWs, contrib"

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
    postgresql-server-dev-17 \
    # ============================================================
    # EXTENSIONS — all from PGDG + TimescaleDB repos
    # ============================================================
    # PostGIS
    postgresql-17-postgis-3 postgresql-17-postgis-3-scripts \
    postgresql-17-pgrouting postgresql-17-pgrouting-scripts \
    # pgvector
    postgresql-17-pgvector \
    # TimescaleDB
    timescaledb-2-postgresql-17 \
    # pg_cron
    postgresql-17-cron \
    # pg_repack
    postgresql-17-repack \
    # pgAudit
    postgresql-17-pgaudit \
    # HypoPG
    postgresql-17-hypopg \
    # RUM
    postgresql-17-rum \
    # pglogical
    postgresql-17-pglogical postgresql-17-pglogical-ticker \
    # PL/Lua
    postgresql-17-pllua \
    # Prefix
    postgresql-17-prefix \
    # IP4r
    postgresql-17-ip4r \
    # JSQuery
    postgresql-17-jsquery \
    # Unit
    postgresql-17-unit \
    # TDigest
    postgresql-17-tdigest \
    # pgMP
    postgresql-17-pgmp \
    # FDWs
    postgresql-17-mysql-fdw \
    postgresql-17-ogr-fdw \
    postgresql-17-tds-fdw \
    # Replication
    postgresql-17-wal2json \
    postgresql-17-repmgr \
    postgresql-17-pg-failover-slots \
    postgresql-17-pgq3 \
    # Monitoring
    postgresql-17-plprofiler \
    postgresql-17-pg-stat-kcache \
    postgresql-17-pg-wait-sampling \
    postgresql-17-toastinfo \
    # Contrib
    postgresql-contrib-17 \
    # Misc
    postgresql-17-pg-checksums \
    postgresql-17-pgagent \
    postgresql-17-pgmemcache \
    postgresql-17-plpgsql-check \
    postgresql-17-plsh \
    # PL/Python3U
    postgresql-plpython3-17 \
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
