.PHONY: up down restart logs status health

up:
	docker compose up -d

down:
	docker compose down

restart:
	docker compose down && docker compose up -d

logs:
	docker compose logs -f

logs-vm:
	docker compose logs -f victoriametrics

logs-loki:
	docker compose logs -f loki

logs-tempo:
	docker compose logs -f tempo

logs-pyroscope:
	docker compose logs -f pyroscope

logs-alloy:
	docker compose logs -f alloy

status:
	docker compose ps

health:
	@echo -n "VictoriaMetrics: "; curl -sf http://localhost:8428/health >/dev/null && echo "✓" || echo "✗"
	@echo -n "Loki:           "; curl -sf http://localhost:3100/ready >/dev/null && echo "✓" || echo "✗"
	@echo -n "Tempo:          "; curl -sf http://localhost:3200/ready >/dev/null && echo "✓" || echo "✗"
	@echo -n "Pyroscope:      "; curl -sf http://localhost:4040/ready >/dev/null && echo "✓" || echo "✗"
	@echo -n "Grafana:        "; curl -sf http://localhost:3000/api/health >/dev/null && echo "✓" || echo "✗"
	@echo -n "Alloy:          "; curl -sf http://localhost:12345/metrics >/dev/null && echo "✓" || echo "✗"

grafana:
	@echo "Grafana: http://localhost:3000 (admin / admin_secret_2026)"

reset:
	docker compose down -v
	sudo rm -rf data/
	docker compose up -d
