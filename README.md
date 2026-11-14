# infra-light — K3s DevOps Infrastructure

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Build](https://github.com/faisalaffan/infra-light/actions/workflows/build-postgres.yml/badge.svg)](https://github.com/faisalaffan/infra-light/actions)
[![Docker Hub](https://img.shields.io/badge/Docker%20Hub-faisalaffan%2Fpostgres--all-blue)](https://hub.docker.com/r/faisalaffan/postgres-all)

Zero-Docker infrastructure: **K3s** bootstrap via **Ansible**, cluster services via **Kustomize** + **HelmChart**.

---

## Architecture

```
Host OS (ansible/)                  Cluster (kubernetes/)
├── Tailscale Mesh                  ├── HelmCharts (third-party)
├── K3s Server + Agent              │   ├── ingress-nginx
└── Kernel tuning                   │   ├── cert-manager (Let's Encrypt)
                                    │   └── tailscale-operator
                                    │
                                    └── Infra (first-party)
                                        ├── PostgreSQL 18 (40+ extensions)
                                        ├── MySQL 8.4
                                        ├── Qdrant · Manticore Search · Arize Phoenix
                                        ├── Grafana + datasources
                                        ├── Loki · Tempo · Pyroscope
                                        ├── VictoriaMetrics · Alloy
                                        ├── Cloudflare Tunnel · CloudBeaver
                                        └── Ingress rules
```

## Quick Start

```bash
git clone git@github.com:faisalaffan/infra-light.git
cd infra-light
cp .env.example .env
# edit .env — set DOMAIN, CF_TUNNEL_TOKEN, TAILSCALE_AUTHKEY
./setup.sh
```

## Prerequisites

- Ubuntu 22.04+ / Debian Bookworm
- [Tailscale](https://tailscale.com) mesh network
- Domain routed via Cloudflare Tunnel

## Repository Structure

```
.
├── ansible/                     # Host OS layer (bootstrap k3s + tailscale)
│   ├── playbooks/
│   │   ├── tailscale.yml
│   │   └── k3s.yml
│   ├── roles/
│   │   ├── tailscale/
│   │   ├── k3s_server/
│   │   └── k3s_agent/
│   ├── inventory/
│   └── site.yml                 # Full host bootstrap (all nodes)
│
├── kubernetes/                  # Cluster layer (applied to k3s)
│   ├── helmcharts/              #   Third-party HelmChart CRD
│   │   ├── cert-manager.yaml
│   │   ├── gitlab-runner.yaml
│   │   ├── ingress-nginx.yaml
│   │   └── tailscale-operator.yaml
│   ├── infra/                   #   First-party Kustomize
│   │   ├── base/                #     Namespace, secrets
│   │   ├── postgres/            #     PostgreSQL 18 StatefulSet
│   │   ├── mysql/               #     MySQL 8.4 StatefulSet
│   │   ├── grafana/             #     Grafana dashboards
│   │   ├── loki/                #     Log aggregation
│   │   ├── tempo/               #     Trace storage
│   │   ├── pyroscope/           #     Continuous profiling
│   │   ├── victoriametrics/     #     Metrics backend
│   │   ├── alloy/               #     Grafana Alloy collector
│   │   ├── cloudflared/         #     Cloudflare Tunnel
│   │   ├── cloudbeaver/         #     Web DB manager
│   │   ├── qdrant/              #     Vector Database
│   │   ├── manticore/           #     Full-Text & Vector Search Engine
│   │   ├── memgraph/            #     Graph Database (MAGE) & Memgraph Lab
│   │   ├── phoenix/             #     AI Observability & Tracing
│   │   ├── 9router/             #     Smart AI Gateway & Router
│   │   ├── cap/                 #     Cap Web Screen Recording & Media Server
│   │   └── ingress/             #     Routing rules
│   └── builds/                  #   Custom Docker images
│       └── postgres/            #     postgres-all image
│
├── setup.sh                     # One-command: ansible bootstrap → cluster deploy
├── .env.example
└── .github/workflows/           # CI/CD
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
| CloudBeaver | cloudbeaver.infra | 8978 |
| Redpanda (Kafka) | redpanda.infra | 9093 |
| Redpanda Console | redpanda.faisalaffan.com | 8080 |
| HashiCorp Vault UI | vault.faisalaffan.com | 8200 |
| HashiCorp Vault (Tailscale) | vault-faisalaffan.ts.net | 8200 |
| Qdrant Vector DB | qdrant.infra | 6333 / 6334 |
| Manticore Search | manticore.infra | 9308 (HTTP) / 9306 (MySQL) |
| Memgraph DB | memgraph.infra | 7687 (Bolt) / 7444 (Logs) |
| Memgraph Lab UI | memgraph.faisalaffan.com / memgraph-lab.infra | 3000 |
| Arize Phoenix | phoenix.infra | 6006 |
| 9Router AI Gateway | 9router.infra | 20128 |
| Cap Web | cap.faisalaffan.com / cap-web.infra | 3000 |

## Contributing

See [CONTRIBUTING.md](./.github/CONTRIBUTING.md).

## Security

See [SECURITY.md](./.github/SECURITY.md).

## License

MIT © [Faisal Affan](https://github.com/faisalaffan)
