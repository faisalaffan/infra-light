# Contributing

## Getting Started

```bash
git clone git@github.com:faisalaffan/infra-light.git
cd infra-light
cp .env.example .env
```

## Development Flow

1. Create branch from `dev`
2. Make changes
3. Run `./setup.sh` to verify
4. Open PR to `dev`

## Docker Image

```bash
cd kubernetes/builds/postgres
docker build --network host -t postgres-all:latest .
docker run -e POSTGRES_PASSWORD=test -p 5433:5432 postgres-all:latest
```

## Kustomize

```bash
kubectl kustomize kubernetes/infra | envsubst | kubectl diff -f -
```

## Commit Convention

- `feat:` new feature
- `fix:` bug fix
- `refactor:` code restructure
- `chore:` config, CI, docs
- `docs:` documentation only
