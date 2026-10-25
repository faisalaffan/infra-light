# ============================================================
# DevOps — k3s PostgreSQL Database Management
# ============================================================

KUBECTL := kubectl
NAMESPACE := infra
POD := postgres-0
PG_USER := postgres

.PHONY: db-create db-list db-drop db-help

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
# Langfuse & ClickHouse Management
# ============================================================
.PHONY: langfuse-status langfuse-health langfuse-backup langfuse-flush-traces langfuse-logs langfuse-help

langfuse-status:
	@echo "--- Langfuse Pods ---"
	@$(KUBECTL) get pods -n $(NAMESPACE) -l 'app in (langfuse-web, langfuse-worker, clickhouse)'
	@echo ""
	@echo "--- Langfuse CronJobs ---"
	@$(KUBECTL) get cronjobs -n $(NAMESPACE) | grep -E "langfuse" || true

langfuse-health:
	@echo "Checking Langfuse Web health..."
	@IP=$$($(KUBECTL) get svc langfuse-web -n $(NAMESPACE) -o jsonpath='{.spec.clusterIP}'); \
	curl -s "http://$$IP:3000/api/public/health" || true; echo ""
	@echo "Checking ClickHouse ping..."
	@CH_IP=$$($(KUBECTL) get svc clickhouse -n $(NAMESPACE) -o jsonpath='{.spec.clusterIP}'); \
	curl -s "http://$$CH_IP:8123/ping" || true; echo ""

langfuse-backup:
	@echo "Triggering manual Langfuse backup job..."
	$(KUBECTL) create job --from=cronjob/langfuse-backup langfuse-backup-manual-$$(date +%s) -n $(NAMESPACE)

langfuse-flush-traces:
	@echo "Triggering manual Langfuse 7-day trace retention flush job..."
	$(KUBECTL) create job --from=cronjob/langfuse-trace-flush langfuse-trace-flush-manual-$$(date +%s) -n $(NAMESPACE)

langfuse-logs:
	@echo "--- Langfuse Web Logs ---"
	@$(KUBECTL) logs -n $(NAMESPACE) -l app=langfuse-web --tail=50 || true
	@echo ""
	@echo "--- Langfuse Worker Logs ---"
	@$(KUBECTL) logs -n $(NAMESPACE) -l app=langfuse-worker --tail=50 || true

langfuse-help:
	@echo "Langfuse LLM Observability Management (k3s infra)"
	@echo ""
	@echo "  make langfuse-status        Show status of Langfuse pods & cronjobs"
	@echo "  make langfuse-health        Check health endpoints of Web and ClickHouse"
	@echo "  make langfuse-backup        Trigger manual daily backup job"
	@echo "  make langfuse-flush-traces  Trigger manual 7-day trace retention flush"
	@echo "  make langfuse-logs          Show recent logs from Web and Worker"

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

