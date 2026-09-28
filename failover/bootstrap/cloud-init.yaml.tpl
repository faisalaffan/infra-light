#cloud-config
write_files:
  - path: /etc/failover/env
    permissions: '0600'
    owner: root:root
    content: |
      ENVIRONMENT="${environment}"
      K3S_VERSION="${k3s_version}"
      B2_ENDPOINT="${b2_endpoint}"
      B2_BUCKET="${b2_bucket}"
      B2_APPLICATION_KEY_ID="${b2_key_id}"
      B2_APPLICATION_KEY="${b2_application_key}"
      B2_PREFIX="${b2_prefix}"
      GITOPS_REPO_URL="${gitops_repo_url}"
      GITOPS_BRANCH="${gitops_branch}"

  - path: /usr/local/bin/restore.sh
    permissions: '0750'
    owner: root:root
    content: |
${restore_script_content}

  - path: /usr/local/bin/healthcheck.sh
    permissions: '0750'
    owner: root:root
    content: |
${healthcheck_script_content}

package_update: true
packages:
  - curl
  - jq
  - git
  - rsync
  - ca-certificates
  - unzip
  - awscli

runcmd:
  - echo "[FAILOVER] Starting bootstrap sequence at $(date)..."
  - mkdir -p /var/log/failover /var/lib/rancher/k3s/server/db/snapshots
  - /usr/local/bin/restore.sh >> /var/log/failover/restore.log 2>&1
  - /usr/local/bin/healthcheck.sh >> /var/log/failover/healthcheck.log 2>&1 || true
  - echo "[FAILOVER] Bootstrap sequence finished at $(date)"
