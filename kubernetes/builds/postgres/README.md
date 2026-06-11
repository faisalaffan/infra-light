# 🐘 Postgres-All — PostgreSQL 18.4 Complete

[![Build & Push](https://github.com/faisalaffan/infra-light/actions/workflows/build-postgres.yml/badge.svg)](https://github.com/faisalaffan/infra-light/actions/workflows/build-postgres.yml)

**Everything PostgreSQL — no missing extensions.**

## Included Extensions

| Category | Extensions |
|----------|-----------|
| Geospatial | PostGIS 3, pgRouting |
| AI / ML | pgvector, PL/Python3U (numpy, pandas, scikit-learn, langchain, openai) |
| Time-Series | TimescaleDB 2 |
| Maintenance | pg_cron, pg_repack |
| Security | pgAudit |
| Performance | HypoPG, RUM |
| Replication | pglogical, wal2json, pg-failover-slots |
| FDW | mysql-fdw |
| Built-ins | ~50 contrib extensions (btree_gin, hstore, pg_stat_statements, uuid-ossp, ...) |

## Usage

```bash
docker run -d --name postgres \
  -e POSTGRES_PASSWORD=secret \
  -p 5432:5432 \
  faisalaffan/postgres-all:latest
```

### Enable extensions

```sql
CREATE EXTENSION postgis;
CREATE EXTENSION vector;
CREATE EXTENSION timescaledb;
CREATE EXTENSION pg_cron;
CREATE EXTENSION pg_stat_statements;
-- ... and many more
```

## Tags

- `latest` — PostgreSQL 18.4 + all extensions
- `sha-xxxxx` — Pinned to git commit SHA

## Build locally

```bash
git clone https://github.com/faisalaffan/infra-light
cd infra-light/docker-postgres
docker build --network host -t postgres-all:latest .
```

## License

MIT — Faisal Affan (@faisalaffan)
