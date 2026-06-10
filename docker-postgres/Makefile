# Postgres Makefile — variables from ../.env
include ../.env
export

.PHONY: build up down restart logs shell psql status health

build:
	docker build --network host -t ${PG_IMAGE} .

build-no-cache:
	docker build --network host --no-cache -t ${PG_IMAGE} .

up:
	docker compose up -d

down:
	docker compose down

restart:
	docker compose down && docker compose up -d

logs:
	docker compose logs -f

shell:
	docker compose exec postgres bash

psql:
	docker compose exec postgres psql -U ${PG_SUPERUSER}

psql-app:
	docker compose exec postgres psql -U ${PG_APP_USER} -d ${PG_APP_DB}

extensions:
	docker compose exec postgres psql -U ${PG_SUPERUSER} -c "SELECT name, default_version, installed_version, comment FROM pg_available_extensions WHERE installed_version IS NOT NULL ORDER BY name;"

status:
	docker compose ps

reset:
	docker compose down -v
	rm -rf data/ logs/
	docker compose up -d

backup:
	@mkdir -p backups
	docker compose exec -T postgres pg_dumpall -U ${PG_SUPERUSER} --clean --if-exists | gzip > backups/backup-$$(date +%Y%m%d-%H%M%S).sql.gz

restore:
	@gunzip -c $$(ls -t backups/*.sql.gz | head -1) | docker compose exec -T postgres psql -U ${PG_SUPERUSER}

health:
	@docker compose exec postgres pg_isready -U ${PG_SUPERUSER} && echo "✓ PostgreSQL healthy" || echo "✗ PostgreSQL down"
