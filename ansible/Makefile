.PHONY: ping site tailscale k3s ingress cloudflared encrypt-ts encrypt-cf encrypt-k3s vault-edit lint clean

# Test connection
ping:
	ansible all -i inventory/hosts.yml -m ping

# ── Full Bootstrap ────────────────────────────────────────────
site:
	ansible-playbook site.yml -i inventory/hosts.yml --ask-vault-pass

# ── Individual Steps ──────────────────────────────────────────
tailscale:
	ansible-playbook playbooks/tailscale.yml -i inventory/hosts.yml --ask-vault-pass

k3s:
	ansible-playbook playbooks/k3s.yml -i inventory/hosts.yml --ask-vault-pass

ingress:
	ansible-playbook playbooks/ingress.yml -i inventory/hosts.yml

cloudflared:
	ansible-playbook playbooks/cloudflared.yml -i inventory/hosts.yml --ask-vault-pass

# ── Vault Encryption ──────────────────────────────────────────
encrypt-ts:
	@read -p "Tailscale authkey: " key; \
	ansible-vault encrypt_string "$$key" --name 'vault_tailscale_authkey'

encrypt-cf:
	@read -p "CF tunnel token: " token; \
	ansible-vault encrypt_string "$$token" --name 'vault_cf_tunnel_token'

encrypt-k3s:
	@read -p "K3s token: " token; \
	ansible-vault encrypt_string "$$token" --name 'vault_k3s_token'
	@echo ""
	@echo "Jalankan:  ansible-vault edit inventory/group_vars/all/vault.yml"
	@echo "Lalu paste encrypted string sebagai vault_k3s_token"

# ── Maintenance ───────────────────────────────────────────────
vault-edit:
	ansible-vault edit inventory/group_vars/all/vault.yml

vault-encrypt-file:
	ansible-vault encrypt inventory/group_vars/all/vault.yml

lint:
	ansible-lint site.yml playbooks/*.yml 2>/dev/null || echo "ansible-lint not installed, run: pip install ansible-lint"

clean:
	rm -rf /tmp/ansible_cache *.retry
