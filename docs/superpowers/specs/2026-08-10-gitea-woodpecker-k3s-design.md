# Gitea + Woodpecker CI on k3s — Design Spec

**Date:** 2026-08-10
**Status:** approved
**Type:** infrastructure

## Summary

Deploy Gitea (self-hosted Git) and Woodpecker CI (Kubernetes-native CI/CD) on the existing k3s cluster. Hybrid use-case: internal DevOps tooling + production code hosting. Follow existing Kustomize manifest patterns under `kubernetes/infra/`.

## Architecture

```
┌──────────────────────────────────────────────────────┐
│  k3s Cluster (namespace: infra)                     │
│                                                      │
│  ┌──────────┐  ┌───────────────┐  ┌──────────────┐ │
│  │  Gitea   │  │   Woodpecker  │  │   Woodpecker │ │
│  │  Server  │◄─┤    Server     │  │    Agent     │ │
│  │  :3000   │  │    :8000      │  │  (K8s pods) │ │
│  └────┬─────┘  └──────┬────────┘  └──────────────┘ │
│       │               │                              │
│  ┌────▼───────────────▼────┐                        │
│  │  postgres-0 (existing)  │                        │
│  │  ├─ gitea DB            │                        │
│  │  └─ woodpecker DB       │                        │
│  └─────────────────────────┘                        │
│                                                      │
│  PVC: gitea-data (git repos, LFS)                   │
│  PVC: woodpecker-data (artifacts, logs)             │
│                                                      │
│  SMTP: Mailpit (existing)                            │
│  Ingress: Cloudflare Tunnel (existing)               │
└──────────────────────────────────────────────────────┘
```

## Directory Structure

```
kubernetes/infra/
├── gitea/
│   ├── kustomization.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── pvc.yaml
│   ├── configmap.yaml          # app.ini
│   └── ingress.yaml            # Cloudflare Tunnel route
├── woodpecker/
│   ├── kustomization.yaml
│   ├── deployment-server.yaml
│   ├── deployment-agent.yaml
│   ├── rbac-agent.yaml         # ClusterRole for agent
│   ├── service-server.yaml
│   ├── service-agent.yaml
│   ├── pvc.yaml
│   ├── configmap-server.yaml
│   └── ingress.yaml            # Cloudflare Tunnel (internal)
└── kustomization.yaml          # UPDATE: add gitea + woodpecker
```

> **Secrets:** Tidak ada file `secrets.yaml` per-komponen. Semua secret mengikuti pola existing: `.env` root → `kubernetes/infra/base/secrets-template.yaml` dengan placeholder `${VAR}`, di-envsubst saat deploy via `setup.sh`.

## Components

### Gitea

| Concern | Implementation |
|---------|---------------|
| Image | `gitea/gitea:1.25` |
| Port | 3000 (HTTP), 2222 (SSH via NodePort optional) |
| DB | External PostgreSQL `gitea` database on existing `postgres-0` |
| Storage | PVC 20Gi for `/data` (git repos, LFS, attachments, index) |
| Config | ConfigMap mounting `app.ini` with DB, SMTP, security, server settings. Secrets from `infra-secrets` via `secretKeyRef` |
| SMTP | Mailpit at `mailpit.infra.svc.cluster.local:1025` |
| Ingress | Cloudflare Tunnel — `git.MYDOMAIN.com` |
| Auth | Built-in Gitea OAuth2, admin user from secret |
| SSH | Clone via HTTP only (SSH git optional, separate NodePort) |

### Woodpecker Server

| Concern | Implementation |
|---------|---------------|
| Image | `woodpeckerci/woodpecker-server:3.4` |
| Port | 8000 (gRPC + HTTP) |
| DB | External PostgreSQL `woodpecker` database on existing `postgres-0` |
| Config | ConfigMap + Secret `infra-secrets` via `secretKeyRef` for DB, agent secret, Gitea OAuth2 |
| OAuth2 | Gitea as OAuth2 provider |
| Ingress | Cloudflare Tunnel — `ci.MYDOMAIN.com` |

### Woodpecker Agent (Kubernetes Backend)

| Concern | Implementation |
|---------|---------------|
| Image | `woodpeckerci/woodpecker-agent:3.4` |
| Backend | Kubernetes native (spawns Pod per pipeline step) |
| RBAC | ClusterRole: create/delete pods, secrets, PVCs, services |
| Registry | Pull from Gitea container registry and Docker Hub |

## Database Setup

Databases created manually once on existing `postgres-0`:
```sql
CREATE DATABASE gitea;
CREATE DATABASE woodpecker;
```

Both apps run auto-migration on startup.

## Secrets (Centralized via `.env`)

Ikuti pola existing: semua secret di `DEVOPS/.env`, direferensikan di `kubernetes/infra/base/secrets-template.yaml` dengan placeholder `${VAR}`, di-envsubst saat `setup.sh` deploy.

### `.env` additions

```bash
# ── Gitea ─────────────────────────────────────────────────────
GITEA_VERSION=1.25
GITEA_HTTP_PORT=3000
GITEA_SSH_PORT=2222
GITEA_DOMAIN=git.faisalaffan.com
GITEA_DB_HOST=postgres.infra.svc.cluster.local
GITEA_DB_PORT=5432
GITEA_DB_NAME=gitea
GITEA_DB_USER=postgres
GITEA_DB_PASSWORD=postgres_super_secret_2026
GITEA_ADMIN_USER=admin
GITEA_ADMIN_PASSWORD=gitea_admin_secret_2026
GITEA_ADMIN_EMAIL=faisallionel@gmail.com
GITEA_SMTP_HOST=mailpit.infra.svc.cluster.local
GITEA_SMTP_PORT=1025
GITEA_SMTP_FROM=gitea@faisalaffan.com
GITEA_DATA_SIZE=20Gi

# ── Woodpecker CI ─────────────────────────────────────────────
WOODPECKER_VERSION=3.4
WOODPECKER_SERVER_HOST=ci.faisalaffan.com
WOODPECKER_SERVER_PORT=8000
WOODPECKER_DB_HOST=postgres.infra.svc.cluster.local
WOODPECKER_DB_PORT=5432
WOODPECKER_DB_NAME=woodpecker
WOODPECKER_DB_USER=postgres
WOODPECKER_DB_PASSWORD=postgres_super_secret_2026
WOODPECKER_AGENT_SECRET=wp_agent_secret_replace_me_2026
WOODPECKER_GITEA_CLIENT=  # filled after Gitea OAuth2 setup
WOODPECKER_GITEA_SECRET=  # filled after Gitea OAuth2 setup
WOODPECKER_ADMIN_USER=admin
WOODPECKER_DATA_SIZE=10Gi
```

### `secrets-template.yaml` additions

```yaml
GITEA_DB_PASSWORD: "${GITEA_DB_PASSWORD}"
GITEA_ADMIN_PASSWORD: "${GITEA_ADMIN_PASSWORD}"
WOODPECKER_DB_PASSWORD: "${WOODPECKER_DB_PASSWORD}"
WOODPECKER_AGENT_SECRET: "${WOODPECKER_AGENT_SECRET}"
WOODPECKER_GITEA_CLIENT: "${WOODPECKER_GITEA_CLIENT}"
WOODPECKER_GITEA_SECRET: "${WOODPECKER_GITEA_SECRET}"
```

Manifest (deployment, configmap) reference secret via `secretKeyRef` dari Secret `infra-secrets`.

## Integration Points

1. **Cloudflare Tunnel** — update existing `cloudflared/all.yaml` to add `git.` and `ci.` hostnames
2. **Postgres** — use existing `postgres.infra.svc.cluster.local:5432`
3. **Mailpit** — use existing `mailpit.infra.svc.cluster.local:1025`
4. **Ingress** — may use existing ingress or Cloudflare Tunnel route

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| PVC hostPath on single node | Acceptable for now; migrate to Longhorn/NFS later |
| Gitea OAuth2 + Woodpecker circular boot | Start Gitea first, configure OAuth2, then Woodpecker |
| Agent pods resource consumption | Set resource limits in pipeline YAML or agent config |
| Woodpecker version drift from Gitea | Pin both versions, update together |

## Post-Deployment Steps

1. Create databases on postgres-0
2. Apply Gitea manifests → verify web UI accessible
3. Create admin user via Gitea web UI (or env vars)
4. Register Woodpecker OAuth2 application in Gitea
5. Apply Woodpecker manifests → verify login via Gitea
6. Enable repos in Woodpecker, test pipeline
