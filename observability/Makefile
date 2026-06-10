# Observability Makefile — variables from ../.env
include ../.env
export

.PHONY: up down restart logs status health grafana

up:
	docker compose up -d

down:
	docker compose down

restart:
	docker compose down && docker compose up -d

logs:
	docker compose logs -f

status:
	docker compose ps

health:
	@echo -n "VictoriaMetrics: "; curl -sf http://localhost:${VM_PORT}/health >/dev/null && echo "✓" || echo "✗"
	@echo -n "Loki:           "; curl -sf http://localhost:${LOKI_PORT}/ready >/dev/null && echo "✓" || echo "✗"
	@echo -n "Tempo:          "; curl -sf http://localhost:${TEMPO_PORT}/ready >/dev/null && echo "✓" || echo "✗"
	@echo -n "Pyroscope:      "; curl -sf http://localhost:${PYROSCOPE_PORT}/ready >/dev/null && echo "✓" || echo "✗"
	@echo -n "Grafana:        "; curl -sf http://localhost:${GRAFANA_PORT}/api/health >/dev/null && echo "✓" || echo "✗"
	@echo -n "Alloy:          "; curl -sf http://localhost:${ALLOY_PORT}/metrics >/dev/null && echo "✓" || echo "✗"

grafana:
	@echo "Grafana: http://localhost:${GRAFANA_PORT} (${GRAFANA_ADMIN_USER} / ${GRAFANA_ADMIN_PASSWORD})"

reset:
	docker compose down -v
	rm -rf data/
	docker compose up -d
