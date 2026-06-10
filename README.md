# infra-light — K3s DevOps Infrastructure

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Build](https://github.com/faisalaffan/infra-light/actions/workflows/build-postgres.yml/badge.svg)](https://github.com/faisalaffan/infra-light/actions)
[![Docker Hub](https://img.shields.io/badge/Docker%20Hub-faisalaffan%2Fpostgres--all-blue)](https://hub.docker.com/r/faisalaffan/postgres-all)

Zero-Docker infrastructure: **K3s** with **Kustomize** (first-party) + **HelmChart** (third-party).

---

## Architecture

```
First-party → Kustomize                 Third-party → HelmChart CRD
├── PostgreSQL 18 (40+ extensions)      ├── ingress-nginx
├── MySQL 8.4                           └── cert-manager (Let's Encrypt)
├── Grafana + datasources
├── Loki · Tempo · Pyroscope
├── VictoriaMetrics · Alloy
└── Cloudflare Tunnel
```

## Quick Start

```bash
git clone git@github.com:faisalaffan/infra-light.git
cd infra-light
cp .env.example .env
./setup.sh
```

## Prerequisites

- Ubuntu 22.04+ / Debian Bookworm
- [Tailscale](https://tailscale.com) mesh network
- Domain routed via Cloudflare Tunnel

## Repository Structure

```
.
├── kustomize/infra/          # First-party (Kustomize)
│   ├── base/                 #   Namespace, secrets
│   ├── postgres/             #   PostgreSQL 18 StatefulSet
│   ├── mysql/                #   MySQL 8.4 StatefulSet
│   ├── grafana/              #   Grafana dashboards
│   ├── loki/                 #   Log aggregation
│   ├── tempo/                #   Trace storage
│   ├── pyroscope/            #   Continuous profiling
│   ├── victoriametrics/      #   Metrics backend
│   ├── alloy/                #   Grafana Alloy collector
│   └── ingress/              #   Routing rules
│
├── helmcharts/               # Third-party (HelmChart CRD)
│   ├── ingress-nginx.yaml
│   └── cert-manager.yaml
│
├── docker-postgres/          # Custom PG18 image
│   ├── Dockerfile
│   ├── init/
│   └── config/
│
├── ansible/                  # OS bootstrap
│   └── playbooks/
│       ├── tailscale.yml
│       └── k3s.yml
│
├── setup.sh                  # One-command deploy
├── .env.example
└── .github/workflows/        # CI/CD
```

## postgres-all Image

Pre-built PostgreSQL 18.4 with everything included:

| Category | Extensions |
|----------|-----------|
| Geospatial | PostGIS 3, pgRouting |
| AI / ML | pgvector, PL/Python3U (numpy, pandas, scikit-learn, langchain, openai) |
| Time-Series | TimescaleDB 2 |
| Scheduling | pg_cron |
| Maintenance | pg_repack |
| Security | pgAudit |
| Performance | HypoPG, RUM |
| Replication | pglogical, wal2json, pg-failover-slots |
| FDW | mysql-fdw |
| Contrib | ~50 extensions (btree_gin, hstore, uuid-ossp, pg_stat_statements, ...) |

```bash
docker run -d --name postgres \
  -e POSTGRES_PASSWORD=secret \
  -p 5432:5432 \
  faisalaffan/postgres-all:latest
```

## Services

| Service | Host | Port |
|---------|------|------|
| PostgreSQL 18.4 | postgres.infra | 5432 |
| MySQL 8.4 | mysql.infra | 3306 |
| Grafana | grafana.infra | 3000 |
| VictoriaMetrics | victoriametrics.infra | 8428 |
| Loki | loki.infra | 3100 |
| Tempo | tempo.infra | 3200 |
| Pyroscope | pyroscope.infra | 4040 |

## Contributing

See [CONTRIBUTING.md](./.github/CONTRIBUTING.md).

## Security

See [SECURITY.md](./.github/SECURITY.md).

## License

MIT © [Faisal Affan](https://github.com/faisalaffan)
