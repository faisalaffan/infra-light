.PHONY: up down restart logs shell mysql status

up:
	docker compose up -d

down:
	docker compose down

restart:
	docker compose down && docker compose up -d

logs:
	docker compose logs -f

shell:
	docker compose exec mysql bash

mysql:
	docker compose exec mysql mysql -u root -p

mysql-app:
	docker compose exec mysql mysql -u appuser -pappuser_secret_2026 appdb

status:
	docker compose ps

health:
	@docker compose exec mysql mysqladmin ping -h localhost -u root -proot_secret_2026 && echo "✓ MySQL healthy" || echo "✗ MySQL down"

reset:
	docker compose down -v
	sudo rm -rf data/ logs/
	docker compose up -d

backup:
	@mkdir -p backups
	docker compose exec -T mysql mysqldump -u root -proot_secret_2026 --all-databases --single-transaction --routines --triggers | gzip > backups/backup-$$(date +%Y%m%d-%H%M%S).sql.gz

restore:
	@gunzip -c $$(ls -t backups/*.sql.gz | head -1) | docker compose exec -T mysql mysql -u root -proot_secret_2026
