#cloud-config
%{ if ssh_public_key != "" ~}
users:
  - default
  - name: root
    ssh_authorized_keys:
      - "${ssh_public_key}"
ssh_authorized_keys:
  - "${ssh_public_key}"
%{ endif ~}

write_files:
  - path: /var/log/failover/restore.log
    permissions: '0644'
    owner: root:root
    content: |
      [FAILOVER] Initializing VPS environment, package installation in progress...
  - path: /etc/failover/env
    permissions: '0600'
    owner: root:root
    content: |
      ENVIRONMENT="${environment}"
      K3S_VERSION="${k3s_version}"
      K3S_TOKEN="${k3s_token}"
      B2_ENDPOINT="${b2_endpoint}"
      B2_BUCKET="${b2_bucket}"
      B2_APPLICATION_KEY_ID="${b2_key_id}"
      B2_APPLICATION_KEY="${b2_application_key}"
      B2_PREFIX="${b2_prefix}"
      RESTIC_PASSWORD="${restic_password}"
      GITOPS_REPO_URL="${gitops_repo_url}"
      GITOPS_BRANCH="${gitops_branch}"
      CLOUDFLARE_STANDBY_TUNNEL_TOKEN="${cloudflare_standby_tunnel_token}"

%{ if vault_token_b64gz != "" ~}
  - path: /etc/failover/SEALED_TOKEN_VAULT.md
    permissions: '0600'
    owner: root:root
    encoding: gz+b64
    content: ${vault_token_b64gz}
%{ endif ~}

  - path: /usr/local/bin/restore.sh
    permissions: '0750'
    owner: root:root
    encoding: gz+b64
    content: ${restore_script_b64gz}

  - path: /usr/local/bin/healthcheck.sh
    permissions: '0750'
    owner: root:root
    encoding: gz+b64
    content: ${healthcheck_script_b64gz}

  - path: /usr/local/bin/failover-startup-daemon.sh
    permissions: '0750'
    owner: root:root
    encoding: gz+b64
    content: ${startup_daemon_script_b64gz}

  - path: /etc/systemd/system/failover-startup.service
    permissions: '0644'
    owner: root:root
    content: |
      [Unit]
      Description=Failover Startup Daemon & Traffic Gatekeeper
      After=network.target k3s.service
      Wants=k3s.service

      [Service]
      Type=oneshot
      ExecStart=/usr/local/bin/failover-startup-daemon.sh
      RemainAfterExit=yes
      StandardOutput=journal+console
      StandardError=journal+console

      [Install]
      WantedBy=multi-user.target

package_update: true
packages:
  - curl
  - jq
  - git
  - rsync
  - ca-certificates
  - unzip
  - awscli
  - bzip2
  - restic

runcmd:
  - echo "[FAILOVER] Starting bootstrap sequence at $(date)..."
  - mkdir -p /var/log/failover /var/lib/rancher/k3s/server/db/snapshots
  - systemctl daemon-reload
  - systemctl enable failover-startup.service
  - /usr/local/bin/restore.sh >> /var/log/failover/restore.log 2>&1
  - /usr/local/bin/healthcheck.sh >> /var/log/failover/healthcheck.log 2>&1 || true
  - echo "[FAILOVER] Bootstrap sequence finished at $(date)"
