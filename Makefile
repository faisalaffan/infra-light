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
	$(KUBECTL) exec -n $(NAMESPACE) $(POD) -- psql -U $(PG_USER) -c "CREATE DATABASE \"$(DB)\";"
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
	$(KUBECTL) exec -n $(NAMESPACE) $(POD) -- psql -U $(PG_USER) -c "DROP DATABASE \"$(DB)\";"
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

.PHONY: vault-status vault-init vault-unseal vault-login vault-help

vault-status:
	@$(KUBECTL) exec -n $(NAMESPACE) $(VAULT_POD) -c vault -- vault status || true

vault-init:
	$(KUBECTL) exec -n $(NAMESPACE) $(VAULT_POD) -c vault -- vault operator init

vault-unseal:
	@[ -n "$(KEY)" ] || { echo "ERROR: set KEY=unseal_key (e.g. make vault-unseal KEY=xxxx)"; exit 1; }
	$(KUBECTL) exec -n $(NAMESPACE) $(VAULT_POD) -c vault -- vault operator unseal "$(KEY)"

vault-help:
	@echo "HashiCorp Vault Management (k3s infra/vault-0)"
	@echo ""
	@echo "  make vault-status                  Check Vault status (initialized/sealed)"
	@echo "  make vault-init                    Initialize Vault (generates unseal keys + root token)"
	@echo "  make vault-unseal KEY=<key>        Unseal Vault using unseal key"

