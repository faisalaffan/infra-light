# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| Latest (main) | ✅ |
| `postgres-all` latest tag | ✅ |

## Reporting a Vulnerability

**Do not open a public issue.**

Email: faisallionel@gmail.com

Expect response within 48 hours. Critical fixes will be released as patch within 72 hours.

## Supply Chain

- Base image: `postgres:18-bookworm` (Docker Official Image)
- GitHub Actions: `docker/build-push-action@v6`, `docker/setup-buildx-action@v3`
- Extensions: PostgreSQL PGDG official apt repository + TimescaleDB repository
- All builds pinned with SHA digests in CI
