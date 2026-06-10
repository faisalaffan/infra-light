# Changelog

All notable changes to this project.

## [unreleased]

### Added
- PostgreSQL 18.4 base image with 40+ extensions (PostGIS, pgvector, TimescaleDB, pg_cron, ...)
- Multi-platform Docker build (linux/amd64 + arm64) via GitHub Actions
- Docker Hub README auto-sync
- Kustomize-based infrastructure deployment (first-party)
- HelmChart CRD-based deployment for third-party (ingress-nginx, cert-manager)
- GitHub Actions CI for postgres-all image
- UFW auto-configuration for k3s API port
- CoreDNS force_tcp workaround for UDP 53 blocked networks
- Recursive kubectl wrapper detection + auto-fix
- KUBECONFIG persistence in ~/.bashrc

### Changed
- Migrated from Docker Compose to K3s cluster
- Migrated from ansible templates to Kustomize overlays
- Split architecture: Kustomize (first-party) + HelmChart (third-party)

### Removed
- Docker Compose stack (mysql/, postgres/, observability/)
- Old ansible all-services.yaml.j2 monolith template
