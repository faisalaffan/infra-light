# ============================================================
# DevOps — k3s PostgreSQL Database Management
# ============================================================

KUBECTL := kubectl
NAMESPACE := infra
POD := postgres-0
PG_USER := postgres

.PHONY: db-create db-list db-drop db-help zitadel-db-init

# --- PostgreSQL: create database ---------------------------------
# Usage: make db-create DB=icex
db-create:
	@[ -n "$(DB)" ] || { echo "ERROR: set DB=name"; exit 1; }
	@echo "Creating database '$(DB)'..."
	$(KUBECTL) exec -n $(NAMESPACE) $(POD) -- psql -U $(PG_USER) -c "CREATE DATABASE \"$(DB)\" TEMPLATE template0;"
	@echo "✓ Database '$(DB)' created"

# --- PostgreSQL: list databases ----------------------------------
db-list:
	$(KUBECTL) exec -n $(NAMESPACE) $(POD) -- psql -U $(PG_USER) -c "\l"

# --- PostgreSQL: drop database -----------------------------------
# Usage: make db-drop DB=icex
db-drop:
	@[ -n "$(DB)" ] || { echo "ERROR: set DB=name"; exit 1; }
	@echo "WARNING: This will drop database '$(DB)' and all its data."
	@read -p "Type '$(DB)' to confirm: " confirm; \
	[ "$$confirm" = "$(DB)" ] || { echo "Aborted."; exit 1; }
	$(KUBECTL) exec -n $(NAMESPACE) $(POD) -- psql -U $(PG_USER) -c "DROP DATABASE \"$(DB)\" WITH (FORCE);"
	@echo "✓ Database '$(DB)' dropped"

# --- help --------------------------------------------------------
db-help:
	@echo "PostgreSQL DB management (k3s infra/postgres-0)"
	@echo ""
	@echo "  make db-create DB=<name>    Create a new database"
	@echo "  make db-list                List all databases"
	@echo "  make db-drop  DB=<name>     Drop a database (with confirmation)"
	@echo "  make zitadel-db-init        Create zitadel database"

# --- ZITADEL: initialize database --------------------------------
zitadel-db-init:
	@echo "Creating database 'zitadel' in PostgreSQL..."
	@$(KUBECTL) exec -n $(NAMESPACE) $(POD) -- psql -U $(PG_USER) -tc "SELECT 1 FROM pg_database WHERE datname = 'zitadel'" | grep -q 1 || \
		$(KUBECTL) exec -n $(NAMESPACE) $(POD) -- psql -U $(PG_USER) -c "CREATE DATABASE \"zitadel\" TEMPLATE template0;"
	@echo "✓ Database 'zitadel' is ready"

# ============================================================
# Redpanda (Kafka-compatible) Management via rpk
# ============================================================
RP_POD := redpanda-0
RP_CONTAINER := redpanda

.PHONY: rp-info rp-health rp-topics rp-create-topic rp-describe-topic rp-delete-topic rp-help

rp-info:
	$(KUBECTL) exec -n $(NAMESPACE) $(RP_POD) -c $(RP_CONTAINER) -- rpk cluster info

rp-health:
	$(KUBECTL) exec -n $(NAMESPACE) $(RP_POD) -c $(RP_CONTAINER) -- rpk cluster health

rp-topics:
	$(KUBECTL) exec -n $(NAMESPACE) $(RP_POD) -c $(RP_CONTAINER) -- rpk topic list

rp-create-topic:
	@[ -n "$(TOPIC)" ] || { echo "ERROR: set TOPIC=name (e.g. make rp-create-topic TOPIC=events)"; exit 1; }
	$(KUBECTL) exec -n $(NAMESPACE) $(RP_POD) -c $(RP_CONTAINER) -- rpk topic create "$(TOPIC)"

rp-describe-topic:
	@[ -n "$(TOPIC)" ] || { echo "ERROR: set TOPIC=name (e.g. make rp-describe-topic TOPIC=events)"; exit 1; }
	$(KUBECTL) exec -n $(NAMESPACE) $(RP_POD) -c $(RP_CONTAINER) -- rpk topic describe "$(TOPIC)"

rp-delete-topic:
	@[ -n "$(TOPIC)" ] || { echo "ERROR: set TOPIC=name (e.g. make rp-delete-topic TOPIC=events)"; exit 1; }
	$(KUBECTL) exec -n $(NAMESPACE) $(RP_POD) -c $(RP_CONTAINER) -- rpk topic delete "$(TOPIC)"

rp-help:
	@echo "Redpanda Streaming Management (k3s infra/redpanda-0)"
	@echo ""
	@echo "  make rp-info                       Show cluster info & brokers"
	@echo "  make rp-health                     Show cluster health"
	@echo "  make rp-topics                     List all topics"
	@echo "  make rp-create-topic TOPIC=<name>  Create a new topic"
	@echo "  make rp-describe-topic TOPIC=<name> Describe topic details"
	@echo "  make rp-delete-topic TOPIC=<name>  Delete a topic"

# ============================================================
# HashiCorp Vault Management
# ============================================================
VAULT_POD := vault-0

.PHONY: vault-status vault-init vault-unseal vault-login vault-pull-envs vault-help

vault-status:
	@$(KUBECTL) exec -n $(NAMESPACE) $(VAULT_POD) -c vault -- vault status || true

vault-init:
	$(KUBECTL) exec -n $(NAMESPACE) $(VAULT_POD) -c vault -- vault operator init

vault-unseal:
	@[ -n "$(KEY)" ] || { echo "ERROR: set KEY=unseal_key (e.g. make vault-unseal KEY=xxxx)"; exit 1; }
	$(KUBECTL) exec -n $(NAMESPACE) $(VAULT_POD) -c vault -- vault operator unseal "$(KEY)"

vault-pull-envs:
	@python3 scripts/pull-vault-envs.py

vault-help:
	@echo "HashiCorp Vault Management (k3s infra/vault-0)"
	@echo ""
	@echo "  make vault-status                  Check Vault status (initialized/sealed)"
	@echo "  make vault-init                    Initialize Vault (generates unseal keys + root token)"
	@echo "  make vault-unseal KEY=<key>        Unseal Vault using unseal key"
	@echo "  make vault-pull-envs               Pull all secrets from Vault and export to .env files"

# ============================================================
# Cold-Standby Disaster Recovery (Failover to Tencent Cloud / Vultr / AWS)
# ============================================================
PROVIDER ?= tencent
ENV ?= prod

.PHONY: failover-status failover-switch-tencent failover-switch-homelab failover-switch \
        failover-start-tencent failover-stop-tencent \
        failback-sync failback-quick drill-stop-homelab drill-start-homelab \
        failover-plan failover-apply failover-destroy failover-output failover-help

# --- ⚡ DNS Master Pointer Switcher (Zero-Cost & Instant) ---
failover-status:
	@bash ./failover/failover.sh status

failover-switch-tencent:
	@bash ./failover/failover.sh switch tencent

failover-switch-homelab:
	@bash ./failover/failover.sh switch homelab

failover-switch:
	@bash ./failover/failover.sh switch $(TARGET)

# --- ☁️ Tencent Standby CVM Lifecycle ($0 Idle Compute) ---
failover-start-tencent:
	@python3 ./failover/scripts/tencent_cvm.py start

failover-stop-tencent:
	@python3 ./failover/scripts/tencent_cvm.py stop

# --- 📱 DR Mobile Dashboard (Cloudflare Worker) ---
failover-worker-deploy:
	@bash ./failover/failover.sh worker-deploy

# --- 🔄 Failback & Drill Simulation Helpers ---
failback-sync:
	@bash ./scripts/failback-homelab.sh

failback-quick:
	@bash ./scripts/failback-homelab.sh --quick

drill-stop-homelab:
	@echo "🧪 [DRILL] Memutus Cloudflare Tunnel & menghentikan K3s di Homelab..."
	@$(KUBECTL) scale deployment cloudflared -n $(NAMESPACE) --replicas=0 2>/dev/null || true
	sudo systemctl stop k3s
	sudo pkill -f "cloudflared tunnel" 2>/dev/null || true
	@echo "✓ Akses Homelab sekarang benar-benar terputus (Simulasi Mati Lampu/Internet Putus)."
	@echo "👉 Silakan cek grafana.faisalaffan.com (pasti down), lalu buka https://dr.faisalaffan.com untuk pindah ke Cloud!"

drill-start-homelab:
	@echo "🧪 [DRILL] Menyalakan kembali K3s & Cloudflare Tunnel di Homelab..."
	sudo systemctl start k3s
	@until $(KUBECTL) get nodes 2>/dev/null | grep -q "Ready"; do sleep 2; done
	@$(KUBECTL) scale deployment cloudflared -n $(NAMESPACE) --replicas=1
	@echo "✓ K3s & Tunnel Homelab kembali menyala normal."

# --- 🚀 Infrastructure Provisioning (Terraform) ---
failover-plan:
	@bash ./failover/failover.sh plan $(ENV) $(PROVIDER)

failover-apply:
	@bash ./failover/failover.sh apply $(ENV) $(PROVIDER)

failover-destroy:
	@bash ./failover/failover.sh destroy $(ENV) $(PROVIDER)

failover-output:
	@bash ./failover/failover.sh output $(ENV) $(PROVIDER)

failover-help:
	@echo "Disaster Recovery Failover Management"
	@echo ""
	@echo "  # ⚡ DNS Master Pointer Switcher (Zero-Cost & Instant):"
	@echo "  make failover-status            Check live origin routing & Tencent CVM status"
	@echo "  make failover-switch-tencent    Switch ALL 29 subdomains to Tencent Standby"
	@echo "  make failover-switch-homelab    Switch ALL 29 subdomains back to Homelab Primary"
	@echo "  make failover-switch TARGET=... Switch to custom target (homelab or tencent)"
	@echo ""
	@echo "  # ☁️ Tencent Standby CVM Lifecycle (\$$0 Idle Compute):"
	@echo "  make failover-start-tencent     Start Tencent CVM instance (boot time ~30s)"
	@echo "  make failover-stop-tencent      Stop Tencent CVM instance (STOP_CHARGING - \$$0 compute)"
	@echo "  make failover-worker-deploy     Deploy/Redeploy DR Mobile Dashboard to Cloudflare Workers"
	@echo ""
	@echo "  # 🚀 Infrastructure Provisioning via Terraform:"
	@echo "  make failover-plan [ENV=drill|prod] [PROVIDER=vultr|aws|tencent]"
	@echo "  make failover-apply [ENV=drill|prod] [PROVIDER=vultr|aws|tencent]"
	@echo "  make failover-destroy [ENV=drill|prod] [PROVIDER=vultr|aws|tencent]"
	@echo "  make failover-output [ENV=drill|prod] [PROVIDER=vultr|aws|tencent]"
	@echo ""
	@echo "  # 🖥️  Baremetal Server via Ansible:"
	@echo "  make baremetal-restore [TARGET=k3s_server]"

# --- Baremetal Restoration via Ansible ---------------------------
TARGET ?= k3s_server
.PHONY: baremetal-restore

baremetal-restore:
	@echo "Restoring Baremetal K3s on target '$(TARGET)' from B2 snapshots..."
	cd ansible && ansible-playbook playbooks/failover-restore.yml -i inventory/hosts.yml -e "target_hosts=$(TARGET)"

# ============================================================
# Qdrant Vector Database Management
# ============================================================
QDRANT_POD := qdrant-0

.PHONY: qdrant-health qdrant-collections qdrant-help

qdrant-health:
	@IP=$$($(KUBECTL) get svc qdrant -n $(NAMESPACE) -o jsonpath='{.spec.clusterIP}'); \
	curl -s "http://$$IP:6333/healthz" || true
	@echo ""

qdrant-collections:
	@IP=$$($(KUBECTL) get svc qdrant -n $(NAMESPACE) -o jsonpath='{.spec.clusterIP}'); \
	KEY=$$(grep -E "^QDRANT_API_KEY=" .env 2>/dev/null | cut -d'=' -f2-); \
	curl -s -H "api-key: $$KEY" "http://$$IP:6333/collections" || true
	@echo ""

qdrant-help:
	@echo "Qdrant Vector Database Management (k3s infra/qdrant-0)"
	@echo ""
	@echo "  make qdrant-health         Check Qdrant health status"
	@echo "  make qdrant-collections    List all collections in Qdrant"

# ============================================================
# Arize Phoenix (LLM Observability, Evals & Tracing) Management
# ============================================================
.PHONY: phoenix-status phoenix-health phoenix-logs phoenix-help

phoenix-status:
	@echo "--- Phoenix Pods & Services ---"
	@$(KUBECTL) get pods,svc,pvc -n $(NAMESPACE) -l app=phoenix

phoenix-health:
	@echo "Checking Arize Phoenix health..."
	@IP=$$($(KUBECTL) get svc phoenix -n $(NAMESPACE) -o jsonpath='{.spec.clusterIP}'); \
	echo -n "Healthz: "; curl -s -o /dev/null -w "%{http_code}\n" "http://$$IP:6006/healthz" || true; \
	echo -n "Readyz: "; curl -s -o /dev/null -w "%{http_code}\n" "http://$$IP:6006/readyz" || true

phoenix-logs:
	@echo "--- Arize Phoenix Logs ---"
	@$(KUBECTL) logs -n $(NAMESPACE) -l app=phoenix --tail=50 -f

phoenix-help:
	@echo "Arize Phoenix LLM Observability Management (k3s infra)"
	@echo ""
	@echo "  make phoenix-status        Show status of Phoenix pods, service & PVC"
	@echo "  make phoenix-health        Check health & ready endpoints of Phoenix"
	@echo "  make phoenix-logs          Follow live logs from Arize Phoenix"

# ============================================================
# 9Router (AI Gateway, RTK Compressor & Auto-Fallback) Management
# ============================================================
.PHONY: 9router-status 9router-health 9router-logs 9router-help

9router-status:
	@echo "--- 9Router Pods & Services ---"
	@$(KUBECTL) get pods,svc,pvc -n $(NAMESPACE) -l app=ninerouter

9router-health:
	@echo "Checking 9Router health..."
	@IP=$$($(KUBECTL) get svc ninerouter -n $(NAMESPACE) -o jsonpath='{.spec.clusterIP}'); \
	echo -n "Health: "; curl -s -o /dev/null -w "%{http_code}\n" "http://$$IP:20128/api/health" || true

9router-logs:
	@echo "--- 9Router Logs ---"
	@$(KUBECTL) logs -n $(NAMESPACE) -l app=ninerouter --tail=50 -f

9router-help:
	@echo "9Router AI Proxy & Gateway Management (k3s infra)"
	@echo ""
	@echo "  make 9router-status        Show status of 9Router pods, service & PVC"
	@echo "  make 9router-health        Check health endpoint of 9Router"
	@echo "  make 9router-logs          Follow live logs from 9Router"

# ============================================================
# Manticore Search (Full-Text & Vector Search) Management
# ============================================================
MANTICORE_POD := manticore-0

.PHONY: manticore-status manticore-health manticore-sql manticore-tables manticore-metrics manticore-logs manticore-help

manticore-status:
	@echo "--- Manticore Pods & Services ---"
	@$(KUBECTL) get pods,svc,pvc -n $(NAMESPACE) -l app=manticore

manticore-health:
	@echo "Checking Manticore Search health..."
	@IP=$$($(KUBECTL) get svc manticore -n $(NAMESPACE) -o jsonpath='{.spec.clusterIP}'); \
	curl -s "http://$$IP:9308/" || true
	@echo ""

manticore-metrics:
	@IP=$$($(KUBECTL) get svc manticore -n $(NAMESPACE) -o jsonpath='{.spec.clusterIP}'); \
	curl -s "http://$$IP:9308/metrics" | head -n 25 || true

manticore-sql:
	@[ -n "$(QUERY)" ] || { echo "ERROR: set QUERY=\"SQL\" (e.g. make manticore-sql QUERY='SHOW STATUS;')"; exit 1; }
	$(KUBECTL) exec -n $(NAMESPACE) $(MANTICORE_POD) -- mysql -h 127.0.0.1 -P 9306 -e "$(QUERY)"

manticore-tables:
	$(KUBECTL) exec -n $(NAMESPACE) $(MANTICORE_POD) -- mysql -h 127.0.0.1 -P 9306 -e "SHOW TABLES;"

manticore-logs:
	@echo "--- Manticore Search Logs ---"
	@$(KUBECTL) logs -n $(NAMESPACE) -l app=manticore --tail=50 -f

manticore-help:
	@echo "Manticore Search Engine Management (k3s infra/manticore-0)"
	@echo ""
	@echo "  make manticore-status        Show status of Manticore pods, service & PVC"
	@echo "  make manticore-health        Check cluster info via HTTP API"
	@echo "  make manticore-metrics       View Prometheus metrics from Manticore Buddy"
	@echo "  make manticore-tables        List all tables in Manticore"
	@echo "  make manticore-sql QUERY=... Execute SphinxQL / SQL query"
	@echo "  make manticore-logs          Follow live logs from Manticore"

# ============================================================
# Cap Web (Screen Recording & Video Sharing) Management
# ============================================================
.PHONY: cap-status cap-health cap-logs cap-media-logs cap-mysql-logs cap-db-shell cap-init-bucket cap-help

cap-status:
	@echo "--- Cap Pods, Services & PVC ---"
	@$(KUBECTL) get pods,svc,pvc -n $(NAMESPACE) -l 'app in (cap-web,cap-media-server,cap-mysql)'

cap-health:
	@echo "Checking Cap Web & Media Server health..."
	@WEB_IP=$$($(KUBECTL) get svc cap-web -n $(NAMESPACE) -o jsonpath='{.spec.clusterIP}'); \
	echo -n "cap-web (/): "; curl -s -o /dev/null -w "%{http_code}\n" "http://$$WEB_IP:3000/" || true; \
	MEDIA_IP=$$($(KUBECTL) get svc cap-media-server -n $(NAMESPACE) -o jsonpath='{.spec.clusterIP}'); \
	echo -n "cap-media-server (/health): "; curl -s -o /dev/null -w "%{http_code}\n" "http://$$MEDIA_IP:3456/health" || true

cap-logs:
	@echo "--- Cap Web Logs (including login OTP codes if Resend is unset) ---"
	@$(KUBECTL) logs -n $(NAMESPACE) -l app=cap-web --tail=50 -f

cap-media-logs:
	@echo "--- Cap Media Server Logs ---"
	@$(KUBECTL) logs -n $(NAMESPACE) -l app=cap-media-server --tail=50 -f

cap-mysql-logs:
	@echo "--- Cap MySQL Logs ---"
	@$(KUBECTL) logs -n $(NAMESPACE) -l app=cap-mysql --tail=50 -f

cap-db-shell:
	@PASS=$$(grep -E "^CAP_MYSQL_PASSWORD=" .env 2>/dev/null | cut -d'=' -f2-); \
	$(KUBECTL) exec -it -n $(NAMESPACE) cap-mysql-0 -- mysql -u cap -p"$$PASS" cap

cap-init-bucket:
	@BUCKET=$$(grep -E "^CAP_AWS_BUCKET=" .env 2>/dev/null | cut -d'=' -f2-); \
	BUCKET=$${BUCKET:-cap}; \
	$(KUBECTL) exec -n $(NAMESPACE) deploy/minio -- sh -c "mc alias set local http://127.0.0.1:9000 \"\$$MINIO_ROOT_USER\" \"\$$MINIO_ROOT_PASSWORD\" && mc mb local/$$BUCKET --ignore-existing"

cap-help:
	@echo "Cap Web Screen Recording Management (k3s infra)"
	@echo ""
	@echo "  make cap-status        Show status of Cap pods, services & PVC"
	@echo "  make cap-health        Check HTTP health of cap-web & cap-media-server"
	@echo "  make cap-logs          Follow cap-web logs (shows login codes if no Resend)"
	@echo "  make cap-media-logs    Follow cap-media-server logs"
	@echo "  make cap-mysql-logs    Follow cap-mysql logs"
	@echo "  make cap-db-shell      Open MySQL shell in cap-mysql-0"
	@echo "  make cap-init-bucket   Ensure Cap S3 bucket exists in MinIO"

# ============================================================
# Memgraph (Graph Database + MAGE + Lab UI) Management
# ============================================================
MEMGRAPH_POD := memgraph-0

.PHONY: memgraph-status memgraph-health memgraph-cypher memgraph-init-user memgraph-logs memgraph-lab-logs memgraph-help

memgraph-status:
	@echo "--- Memgraph Pods, Services & PVC ---"
	@$(KUBECTL) get pods,svc,pvc -n $(NAMESPACE) -l 'app in (memgraph,memgraph-lab)'

memgraph-health:
	@echo "Checking Memgraph DB & Memgraph Lab health..."
	@U=$$(grep -E "^MEMGRAPH_USER=" .env 2>/dev/null | cut -d'=' -f2-); \
	P=$$(grep -E "^MEMGRAPH_PASSWORD=" .env 2>/dev/null | cut -d'=' -f2-); \
	if [ -n "$$U" ] && [ -n "$$P" ]; then \
		$(KUBECTL) exec -n $(NAMESPACE) $(MEMGRAPH_POD) -- sh -c "echo 'RETURN 1 AS ok;' | mgconsole --username=$$U --password=$$P" || true; \
	else \
		$(KUBECTL) exec -n $(NAMESPACE) $(MEMGRAPH_POD) -- sh -c "echo 'RETURN 1 AS ok;' | mgconsole" || true; \
	fi
	@LAB_IP=$$($(KUBECTL) get svc memgraph-lab -n $(NAMESPACE) -o jsonpath='{.spec.clusterIP}'); \
	echo -n "memgraph-lab (/): "; curl -s -o /dev/null -w "%{http_code}\n" "http://$$LAB_IP:3000/" || true

memgraph-cypher:
	@[ -n "$(QUERY)" ] || { echo "ERROR: set QUERY=\"CYPHER\" (e.g. make memgraph-cypher QUERY='SHOW STORAGE INFO;')"; exit 1; }
	@U=$$(grep -E "^MEMGRAPH_USER=" .env 2>/dev/null | cut -d'=' -f2-); \
	P=$$(grep -E "^MEMGRAPH_PASSWORD=" .env 2>/dev/null | cut -d'=' -f2-); \
	if [ -n "$$U" ] && [ -n "$$P" ]; then \
		$(KUBECTL) exec -n $(NAMESPACE) $(MEMGRAPH_POD) -- sh -c "echo \"$(QUERY)\" | mgconsole --username=$$U --password=$$P"; \
	else \
		$(KUBECTL) exec -n $(NAMESPACE) $(MEMGRAPH_POD) -- sh -c "echo \"$(QUERY)\" | mgconsole"; \
	fi

memgraph-init-user:
	@U=$$(grep -E "^MEMGRAPH_USER=" .env 2>/dev/null | cut -d'=' -f2-); \
	P=$$(grep -E "^MEMGRAPH_PASSWORD=" .env 2>/dev/null | cut -d'=' -f2-); \
	[ -n "$$U" ] && [ -n "$$P" ] || { echo "ERROR: set MEMGRAPH_USER and MEMGRAPH_PASSWORD in .env"; exit 1; } ; \
	echo "Creating Memgraph native user '$$U'..."; \
	$(KUBECTL) exec -n $(NAMESPACE) $(MEMGRAPH_POD) -- sh -c "echo \"CREATE USER IF NOT EXISTS $$U IDENTIFIED BY '$$P';\" | mgconsole"

memgraph-logs:
	@echo "--- Memgraph DB Logs ---"
	@$(KUBECTL) logs -n $(NAMESPACE) -l app=memgraph --tail=50 -f

memgraph-lab-logs:
	@echo "--- Memgraph Lab Logs ---"
	@$(KUBECTL) logs -n $(NAMESPACE) -l app=memgraph-lab --tail=50 -f

memgraph-help:
	@echo "Memgraph Graph Database Management (k3s infra/memgraph-0)"
	@echo ""
	@echo "  make memgraph-status        Show status of Memgraph pods, services & PVC"
	@echo "  make memgraph-health        Check Memgraph DB (mgconsole) & Lab UI health"
	@echo "  make memgraph-cypher QUERY=... Run Cypher query via mgconsole"
	@echo "  make memgraph-init-user     Create native Memgraph user from .env"
	@echo "  make memgraph-logs          Follow live logs from Memgraph DB"
	@echo "  make memgraph-lab-logs      Follow live logs from Memgraph Lab UI"

# ============================================================
# Backblaze B2 & Restic Disaster Recovery Management
# ============================================================
.PHONY: b2-backup b2-snapshots b2-check b2-unlock b2-cron-trigger b2-help

b2-backup:
	@if [ "$$(id -u)" -ne 0 ]; then \
		echo "Notice: Non-root user ($$USER) detected."; \
		echo "Routing backup through Kubernetes runner (has full root access to PV volumes)..."; \
		$(MAKE) b2-cron-trigger; \
	else \
		echo "Running Disaster Recovery Backup to Backblaze B2 (Host Root Mode)..."; \
		./scripts/backup-restic-b2.sh; \
	fi

b2-snapshots:
	@echo "Listing Restic snapshots from Backblaze B2..."
	./scripts/backup-restic-b2.sh --snapshots

b2-check:
	@echo "Checking Restic repository integrity on Backblaze B2..."
	./scripts/restore-restic-b2.sh --check

b2-unlock:
	@echo "Clearing stale locks on Backblaze B2..."
	./scripts/restore-restic-b2.sh --unlock

b2-cron-trigger:
	@JOB="k3s-b2-backup-manual-$$(date +%s)"; \
	echo "Triggering Kubernetes Job/$$JOB..."; \
	$(KUBECTL) create job --from=cronjob/k3s-b2-backup $$JOB -n $(NAMESPACE); \
	echo "Waiting for pod to start..."; \
	sleep 4; \
	$(KUBECTL) logs -n $(NAMESPACE) -l app=k3s-b2-backup -f --tail=30 || true

b2-help:
	@echo "Backblaze B2 & Restic Disaster Recovery (k3s infra)"
	@echo ""
	@echo "  make b2-backup          Run full local backup to Backblaze B2"
	@echo "  make b2-snapshots       List all snapshot points in B2 repository"
	@echo "  make b2-check           Verify repository cryptographic integrity"
	@echo "  make b2-cron-trigger    Trigger Kubernetes CronJob k3s-b2-backup"

# ============================================================
# Security & Secret Management
# ============================================================
.PHONY: secrets-init secrets-audit secrets-rotate secrets-help

secrets-init:
	@bash ./scripts/generate-secrets.sh

secrets-rotate:
	@bash ./scripts/rotate-all-secrets.sh

secrets-audit:
	@if git grep -n -E "(secret_2026|minioadmin|k3s-local-dev-token-2026|ADMIN_PIN[[:space:]]*=[[:space:]]*\"2026\")"; then \
		echo "ERROR: Banned hardcoded credential patterns detected!"; \
		exit 1; \
	fi
	@echo "✓ Secret audit passed (0 banned patterns)"

secrets-help:
	@echo "Security & Secret Management"
	@echo ""
	@echo "  make secrets-init       Generate strong random secrets into .env"
	@echo "  make secrets-audit      Scan repo for hardcoded/banned secret patterns"
	@echo "  make secrets-rotate     Rotate all live K3s & DB credentials in-place"

