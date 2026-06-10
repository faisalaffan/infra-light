.PHONY: ping bootstrap tailscale docker infra vault-encrypt vault-edit lint

# Test connection ke semua node
ping:
	ansible all -i inventory/hosts.yml -m ping

# Full bootstrap dari 0
bootstrap:
	ansible-playbook -i inventory/hosts.yml playbooks/bootstrap.yml --ask-vault-pass

# Hanya Tailscale
tailscale:
	ansible-playbook -i inventory/hosts.yml playbooks/tailscale.yml --ask-vault-pass

# Hanya Docker
docker:
	ansible-playbook -i inventory/hosts.yml playbooks/docker.yml

# Hanya deploy infra services
infra:
	ansible-playbook -i inventory/hosts.yml playbooks/infra.yml --ask-vault-pass

# Encrypt string untuk vault
vault-encrypt:
	@read -p "Authkey: " key; \
	ansible-vault encrypt_string "$$key" --name 'vault_tailscale_authkey'

# Edit vault file
vault-edit:
	ansible-vault edit inventory/group_vars/all/vault.yml

# Lint playbooks
lint:
	ansible-lint playbooks/*.yml 2>/dev/null || echo "ansible-lint not installed"
