# ============================================================
# PostgreSQL All-Extensions Makefile
# ============================================================

.PHONY: build up down restart logs shell psql status clean

# Build the custom image
build:
	docker build --network host -t postgres-all:latest .

# Build without cache
build-no-cache:
	docker build --network host --no-cache -t postgres-all:latest .

# Start in background
up:
	docker compose up -d

# Start and follow logs
up-debug:
	docker compose up

# Stop
down:
	docker compose down

# Restart
restart:
	docker compose down && docker compose up -d

# Follow logs
logs:
	docker compose logs -f

# Shell into container
shell:
	docker compose exec postgres bash

# psql as superuser
psql:
	docker compose exec postgres psql -U postgres

# psql into appdb
psql-app:
	docker compose exec postgres psql -U appuser -d appdb

# List all enabled extensions
extensions:
	docker compose exec postgres psql -U postgres -c "SELECT name, default_version, installed_version, comment FROM pg_available_extensions WHERE installed_version IS NOT NULL ORDER BY name;"

# Show container status
status:
	docker compose ps

# Full reset (WARNING: deletes all data)
reset:
	docker compose down -v
	rm -rf data/ logs/
	docker compose build --no-cache
	docker compose up -d

# Backup
backup:
	@mkdir -p backups
	docker compose exec -T postgres pg_dumpall -U postgres --clean --if-exists | gzip > backups/backup-$$(date +%Y%m%d-%H%M%S).sql.gz

# Restore latest backup
restore:
	@gunzip -c $$(ls -t backups/*.sql.gz | head -1) | docker compose exec -T postgres psql -U postgres

# Health check
health:
	@docker compose exec postgres pg_isready -U postgres && echo "✓ PostgreSQL healthy" || echo "✗ PostgreSQL down"
