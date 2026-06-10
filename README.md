# DevOps Infrastructure

One-command setup for PostgreSQL 17 + MySQL 8.4 + MCP servers.

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/faisalaffan/infra-light/dev/setup.sh | bash
```

Or manual:

```bash
git clone git@github.com:faisalaffan/infra-light.git ~/infra-light
cd ~/infra-light
chmod +x setup.sh
./setup.sh
```

## What it does

| Step | Detail |
|------|--------|
| OS detect | Ubuntu 22.04+ / Debian / macOS |
| Docker | Install via get.docker.com or Homebrew |
| Base pkgs | curl, git, build-essential |
| SSH key | RSA 4096 for GitHub auth |
| uv/uvx | Python toolchain (MCP servers) |
| toolbox | Google MCP Toolbox (mysql MCP) |
| Clone repo | `faisalaffan/infra-light` → `~/infra-light` |
| Start services | PostgreSQL (:5432) + MySQL (:3306) |
| MCP config | Register mysql MCP with Claude Code |

## Services

| Service | Port | Root/Admin | App User | Database |
|---------|------|-----------|----------|----------|
| PostgreSQL 17 | 5432 | `postgres` / `postgres_super_secret_2026` | `appuser` / `appuser_secret_2026` | `postgres`, `appdb` |
| MySQL 8.4 | 3306 | `root` / `root_secret_2026` | `appuser` / `appuser_secret_2026` | `appdb` |

## PostgreSQL Extensions (74 total)

PostGIS 3.6.3, pgvector 0.8.2, TimescaleDB 2.27.2, pg_cron, pglogical, pgaudit, pg_repack, RUM, HypoPG, plpython3u (numpy, pandas, scikit-learn, langchain, openai), postgres_fdw, mysql_fdw, ogr_fdw, tds_fdw, +55 more.

## Directory Structure

```
DEVOPS/
├── setup.sh              # One-script bootstrap (Ubuntu + macOS)
├── README.md
├── postgres/
│   ├── Dockerfile        # Custom PG17 + all extensions
│   ├── docker-compose.yml
│   ├── Makefile
│   ├── .env.example
│   ├── config/custom.conf
│   └── init/*.sql
└── mysql/
    ├── docker-compose.yml
    ├── Makefile
    ├── .env.example
    └── init/*.sql
```
