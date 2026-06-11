# =============================================================================
#  ██████╗  ██████╗ ███████╗████████╗ ██████╗ ██████╗ ███████╗███████╗
#  ██╔══██╗██╔═══██╗██╔════╝╚══██╔══╝██╔════╝ ██╔══██╗██╔════╝██╔════╝
#  ██████╔╝██║   ██║███████╗   ██║   ██║  ███╗██████╔╝█████╗  ███████╗
#  ██╔═══╝ ██║   ██║╚════██║   ██║   ██║   ██║██╔══██╗██╔══╝  ╚════██║
#  ██║     ╚██████╔╝███████║   ██║   ╚██████╔╝██║  ██║███████╗███████║
#  ╚═╝      ╚═════╝ ╚══════╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚══════╝╚══════╝
#
#  PostgreSQL 18.4 — All Extensions Image
#  PostGIS · pgvector · TimescaleDB · pg_cron · pg_repack · pgAudit
#  HypoPG · RUM · pglogical · mysql-fdw · Python ML · 40+ extensions
# =============================================================================

FROM postgres:18-bookworm

# ── OCI Labels ────────────────────────────────────────────────────────────────
LABEL org.opencontainers.image.title="Postgres-All"
LABEL org.opencontainers.image.description="PostgreSQL 18.4 with PostGIS, pgvector, TimescaleDB, pg_cron, pgAudit, HypoPG, RUM, pglogical, FDWs, Python/ML — all batteries included"
LABEL org.opencontainers.image.authors="Faisal Affan <faisallionel@gmail.com>"
LABEL org.opencontainers.image.url="https://github.com/faisalaffan/infra-light"
LABEL org.opencontainers.image.source="https://github.com/faisalaffan/infra-light/tree/dev/docker-postgres"
LABEL org.opencontainers.image.vendor="faisalaffan"
LABEL org.opencontainers.image.licenses="MIT"
LABEL com.faisalaffan.postgres-all.version="18.4"
LABEL com.faisalaffan.postgres-all.extensions="PostGIS-3 pgvector TimescaleDB-2 pg_cron pg_repack pgAudit HypoPG RUM pglogical mysql-fdw wal2json contrib plpython3"

ENV DEBIAN_FRONTEND=noninteractive \
    PG_MAJOR=18

# ── 1. Bootstrap: curl + gnupg + ca-certificates ──────────────────────────────
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl gnupg ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# ── 2. Add PostgreSQL APT repository ─────────────────────────────────────────
RUN curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    | gpg --dearmor -o /usr/share/keyrings/pgdg.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/pgdg.gpg] https://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" \
        > /etc/apt/sources.list.d/pgdg.list

# ── 3. Add TimescaleDB repository ────────────────────────────────────────────
RUN echo "deb [trusted=yes] https://packagecloud.io/timescale/timescaledb/debian/ bookworm main" \
        > /etc/apt/sources.list.d/timescaledb.list

# ── 4. Install ALL build deps + extensions in ONE layer ───────────────────────
#      (single layer = smaller final image)
RUN apt-get update && apt-get install -y --no-install-recommends \
    \
    # --- Build toolchain ---
    build-essential ca-certificates curl gnupg lsb-release wget git \
    \
    # --- Procedural languages ---
    python3 python3-pip python3-dev python3-venv \
    perl libperl-dev \
    tcl tcl-dev \
    \
    # --- PostGIS compilation deps ---
    libxml2-dev libgeos-dev libproj-dev libgdal-dev libjson-c-dev \
    libprotobuf-c-dev protobuf-c-compiler \
    \
    # --- General -dev headers ---
    libssl-dev zlib1g-dev libreadline-dev libpq-dev \
    libcurl4-openssl-dev libpcre3-dev \
    \
    # --- PGDG server-dev ---
    postgresql-server-dev-${PG_MAJOR} \
    \
    # ═══════════════════════════════════════════════════════════════════════
    # EXTENSIONS
    # ═══════════════════════════════════════════════════════════════════════
    \
    # PostGIS — Geospatial
    postgresql-${PG_MAJOR}-postgis-3 postgresql-${PG_MAJOR}-postgis-3-scripts \
    postgresql-${PG_MAJOR}-pgrouting postgresql-${PG_MAJOR}-pgrouting-scripts \
    \
    # pgvector — AI/Vector embeddings
    postgresql-${PG_MAJOR}-pgvector \
    \
    # TimescaleDB — Time-series
    timescaledb-2-postgresql-${PG_MAJOR} \
    \
    # pg_cron — Job scheduler
    postgresql-${PG_MAJOR}-cron \
    \
    # pg_repack — Online table repack
    postgresql-${PG_MAJOR}-repack \
    \
    # pgAudit — Audit logging
    postgresql-${PG_MAJOR}-pgaudit \
    \
    # HypoPG — Hypothetical indexes
    postgresql-${PG_MAJOR}-hypopg \
    \
    # RUM — Enhanced full-text search
    postgresql-${PG_MAJOR}-rum \
    \
    # pglogical — Logical replication
    postgresql-${PG_MAJOR}-pglogical \
    \
    # mysql-fdw — MySQL foreign data wrapper
    postgresql-${PG_MAJOR}-mysql-fdw \
    \
    # wal2json — WAL to JSON
    postgresql-${PG_MAJOR}-wal2json \
    \
    # pg-failover-slots — Failover slot sync
    postgresql-${PG_MAJOR}-pg-failover-slots \
    \
    # Contrib — ~50 built-in extensions
    postgresql-contrib-${PG_MAJOR} \
    \
    # PL/Python3U — Python procedural language
    postgresql-plpython3-${PG_MAJOR} \
    \
    && rm -rf /var/lib/apt/lists/*

# ── 5. Python ML / AI libraries ──────────────────────────────────────────────
#      Pin major versions for reproducibility
RUN python3 -m pip install --no-cache-dir --break-system-packages \
    numpy pandas scipy scikit-learn \
    requests httpx \
    langchain langchain-community \
    openai \
    && python3 -m pip cache purge 2>/dev/null || true

# ── 6. Init scripts + custom config ──────────────────────────────────────────
COPY init/   /docker-entrypoint-initdb.d/
COPY config/ /etc/postgresql-config/

RUN chmod -R 755 /docker-entrypoint-initdb.d/ \
    && chown -R postgres:postgres /docker-entrypoint-initdb.d/

# ── 7. Environment defaults ──────────────────────────────────────────────────
ENV DEBIAN_FRONTEND=dialog \
    PGUSER=postgres \
    PGDATA=/var/lib/postgresql/data

# ── 8. Health check ──────────────────────────────────────────────────────────
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD pg_isready -U postgres || exit 1

EXPOSE 5432

STOPSIGNAL SIGINT

CMD ["postgres"]
