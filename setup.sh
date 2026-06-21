#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# DevOps Infrastructure Setup — Full Ansible Bootstrap
# Ubuntu 22.04+ / Debian / macOS
# ============================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[✗]${NC} $*"; exit 1; }

# ------------------------------------------------------------------
# Config — load from DEVOPS/.env
# ------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
    set -a; source "$SCRIPT_DIR/.env"; set +a
    log "Loaded .env — DOMAIN=${DOMAIN:-unset}"
else
    warn "No .env found, using defaults"
fi

SSH_KEY="${SSH_KEY_PATH:-$HOME/.ssh/id_rsa}"
GIT_EMAIL="${GIT_EMAIL:-faisallionel@gmail.com}"
GIT_NAME="${GIT_NAME:-Faisal Affan}"
TOOLBOX_VERSION="${TOOLBOX_VERSION:-1.4.0}"
ANSIBLE_DIR="${SCRIPT_DIR}/ansible"
KUSTOMIZE_DIR="${SCRIPT_DIR}/kubernetes/infra"
HELMCHART_DIR="${SCRIPT_DIR}/kubernetes/helmcharts"

# ------------------------------------------------------------------
# OS Detection
# ------------------------------------------------------------------
detect_os() {
    case "$(uname -s)" in
        Linux)  OS="linux";;
        Darwin) OS="macos";;
        *)      err "Unsupported OS: $(uname -s)";;
    esac

    if [ "$OS" = "linux" ]; then
        if grep -qi "ubuntu" /etc/os-release 2>/dev/null; then
            DISTRO="ubuntu"
        elif grep -qi "debian" /etc/os-release 2>/dev/null; then
            DISTRO="debian"
        else
            warn "Linux detected but not Ubuntu/Debian. Trying anyway..."
            DISTRO="linux"
        fi
    fi
    log "Detected: $OS ($DISTRO)"
}

# ------------------------------------------------------------------
# Base packages (curl, git, gnupg)
# ------------------------------------------------------------------
install_base() {
    if [ "${SUDO_SKIP:-false}" = true ]; then
        warn "Skipping base packages (needs sudo)"
        return
    fi
    log "Installing base packages..."
    if [ "$OS" = "linux" ]; then
        sudo apt-get update -qq
        sudo apt-get install -y -qq curl git build-essential ca-certificates gnupg lsb-release
    elif [ "$OS" = "macos" ]; then
        if ! command -v brew &>/dev/null; then
            log "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        brew install curl git
    fi
    log "Base packages installed"
}

# ------------------------------------------------------------------
# SSH key for GitHub
# ------------------------------------------------------------------
setup_ssh() {
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    local key_existed=false
    if [ -f "$SSH_KEY" ]; then
        log "SSH key exists: $SSH_KEY"
        key_existed=true
    else
        log "Generating SSH key (RSA 4096)..."
        ssh-keygen -t rsa -b 4096 -C "$GIT_EMAIL" -f "$SSH_KEY" -N ""
        log "SSH key generated"
    fi

    if ! grep -q "Host github.com" "$HOME/.ssh/config" 2>/dev/null; then
        cat >> "$HOME/.ssh/config" << 'SSHEOF'

Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_rsa
    IdentitiesOnly yes
SSHEOF
        chmod 600 "$HOME/.ssh/config"
        log "SSH config updated"
    fi

    ssh-add "$SSH_KEY" 2>/dev/null || true

    if [ "$key_existed" = false ]; then
        log "SSH public key (add to GitHub):"
        echo "---"
        cat "${SSH_KEY}.pub"
        echo "---"
    fi
}

# ------------------------------------------------------------------
# uv / uvx (for ansible + MCP servers)
# ------------------------------------------------------------------
install_uv() {
    if command -v uvx &>/dev/null; then
        log "uvx already installed"
    else
        log "Installing uv/uvx..."
        curl -LsSf https://astral.sh/uv/install.sh | sh
        export PATH="$HOME/.local/bin:$PATH"
    fi
    export PATH="$HOME/.local/bin:$PATH"
}

# ------------------------------------------------------------------
# Ansible via uv
# ------------------------------------------------------------------
install_ansible() {
    if command -v ansible-playbook &>/dev/null; then
        log "Ansible already installed: $(ansible --version 2>&1 | head -1)"
    else
        log "Installing Ansible via uv..."
        uv tool install ansible
        export PATH="$HOME/.local/share/uv/tools/ansible/bin:$HOME/.local/bin:$PATH"
        log "Ansible installed: $(ansible --version 2>&1 | head -1)"
    fi
    # Ensure ansible in PATH
    export PATH="$HOME/.local/share/uv/tools/ansible/bin:$HOME/.local/bin:$PATH"
}

# ------------------------------------------------------------------
# Vault — generate from .env if not exists or is encrypted
# ------------------------------------------------------------------
setup_vault() {
    local vault_file="$ANSIBLE_DIR/inventory/group_vars/all/vault.yml"

    if [ ! -f "$vault_file" ]; then
        warn "vault.yml not found, generating from .env..."
    elif head -1 "$vault_file" | grep -q "ANSIBLE_VAULT"; then
        warn "vault.yml is ENCRYPTED — skipping (decrypt + re-run to regenerate)"
        return
    else
        log "vault.yml exists (plaintext)"
        return
    fi

    # Generate vault.yml from .env values
    cat > "$vault_file" << VAULTEOF
# ============================================================
# Vault — generated from DEVOPS/.env by setup.sh
# Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
# ============================================================

vault_tailscale_authkey: "${TAILSCALE_AUTHKEY:-skip-tailscale-local}"
vault_cf_tunnel_token: "${CF_TUNNEL_TOKEN:-}"
vault_k3s_token: "${K3S_TOKEN:-k3s-local-dev-token-2026}"
vault_pg_superuser_password: "${PG_SUPERUSER_PASSWORD:-postgres_super_secret_2026}"
vault_pg_app_password: "${PG_APP_PASSWORD:-appuser_secret_2026}"
vault_mysql_root_password: "${MYSQL_ROOT_PASSWORD:-root_secret_2026}"
vault_mysql_app_password: "${MYSQL_PASSWORD:-appuser_secret_2026}"
vault_grafana_admin_password: "${GRAFANA_ADMIN_PASSWORD:-admin_secret_2026}"
VAULTEOF
    log "vault.yml generated"
}

# ------------------------------------------------------------------
# Bootstrap OS-level: Tailscale + K3s (via Ansible)
# Only runs k3s playbook — infrastructure apps use Kustomize + HelmChart
# ------------------------------------------------------------------
bootstrap_k3s() {
    cd "$ANSIBLE_DIR"

    local tailscale_ip=""
    if command -v tailscale &>/dev/null && tailscale status &>/dev/null 2>&1; then
        tailscale_ip=$(tailscale ip -4 2>/dev/null || echo "")
        if [ -n "$tailscale_ip" ]; then
            log "Tailscale already running — IP: $tailscale_ip"
        fi
    fi

    if [ -z "$tailscale_ip" ]; then
        warn "Tailscale not running. Run: tailscale up"
        warn "Skipping K3s bootstrap..."
        return
    fi

    # Become password untuk ansible (k3s install butuh root)
    local ansible_become=""
    if [ -n "${SUDO_PASS:-}" ]; then
        ansible_become="-e ansible_become_password=$SUDO_PASS"
    fi

    log "Bootstrapping Tailscale + K3s (OS-level)..."
    ansible-playbook playbooks/tailscale.yml -e "tailscale_ipv4=$tailscale_ip" $ansible_become || warn "Tailscale playbook had errors — continuing with K3s"
    ansible-playbook playbooks/k3s.yml -e "tailscale_ipv4=$tailscale_ip" $ansible_become || warn "K3s may already be installed"

    fix_kubeconfig
    fix_k3s_perms
    fix_ufw_ports
    fix_kubectl_wrapper
}

# ------------------------------------------------------------------
# Deploy third-party via HelmChart CRD
# Ingress-nginx + cert-manager — di-manage k3s helm-controller
# ------------------------------------------------------------------
deploy_helmcharts() {
    log "Deploying third-party services (HelmChart)..."

    # Ensure required namespaces exist (Tailscale Operator needs it)
    kubectl create namespace tailscale 2>/dev/null || true
    kubectl create namespace cert-manager 2>/dev/null || true
    kubectl create namespace ingress-nginx 2>/dev/null || true

    for chart in "$HELMCHART_DIR"/*.yaml; do
        [ -f "$chart" ] || continue
        log "Applying: $(basename "$chart")"
        envsubst < "$chart" | kubectl apply -f -
    done
    log "HelmCharts applied — k3s helm-controller will install"
}

# ------------------------------------------------------------------
# Deploy first-party via Kustomize
# PostgreSQL, MySQL, VictoriaMetrics, Loki, Tempo, Pyroscope, Grafana, Alloy, Ingress
# Menggunakan envsubst untuk resolve ${VAR:-default} dari .env
# ------------------------------------------------------------------
# Postgres image: faisalaffan/postgres-all (Auto-built via GitHub Actions)
# CI trigger: push ke kubernetes/builds/postgres/ → .github/workflows/build-postgres.yml
# Local fallback: docker build --network host -t postgres-all:latest kubernetes/builds/postgres/
# ------------------------------------------------------------------
build_postgres_image() {
    local image="docker.io/faisalaffan/postgres-all:latest"
    local dockerfile_dir="$SCRIPT_DIR/kubernetes/builds/postgres"

    # Cek di k3s containerd dulu
    if sudo k3s crictl images 2>/dev/null | grep -q "postgres-all"; then
        log "postgres-all image already in k3s containerd"
        return
    fi

    # Pre-pull dari Docker Hub (CI-built)
    if sudo k3s ctr images pull "$image" 2>/dev/null; then
        log "postgres-all pulled from Docker Hub ✓"
        return
    fi

    # Fallback: build lokal kalo ga ada Docker Hub access
    warn "Cannot pull from Docker Hub — building locally..."
    [ -f "$dockerfile_dir/Dockerfile" ] || { warn "Dockerfile not found: $dockerfile_dir"; return; }

    if command -v docker &>/dev/null && sudo systemctl is-active --quiet docker 2>/dev/null; then
        log "Building postgres-all (~10-15 min)..."
        sudo docker build --network host -t postgres-all:latest "$dockerfile_dir" || { warn "Build failed"; return; }
        sudo docker save postgres-all:latest | sudo k3s ctr images import -
        log "postgres-all built & imported to k3s"
    else
        warn "Docker not running — install Docker or configure Docker Hub access"
    fi
}

# ------------------------------------------------------------------
# Deploy first-party via Kustomize
# PostgreSQL, MySQL, VictoriaMetrics, Loki, Tempo, Pyroscope, Grafana, Alloy, Ingress
# Idempotent — aman dijalankan berkali-kali
# ------------------------------------------------------------------
deploy_kustomize() {
    log "Deploying first-party services (Kustomize)..."
    cd "$KUSTOMIZE_DIR"

    # Load .env untuk envsubst
    set -a; source "$SCRIPT_DIR/.env" 2>/dev/null; set +a

    # Create namespace
    kubectl create namespace infra 2>/dev/null || true

    # --- Pre-flight checks ---
    log "Pre-flight: checking cluster health..."
    if ! kubectl cluster-info &>/dev/null; then
        err "Cannot reach Kubernetes cluster. Is K3s running?"
    fi
    kubectl wait --for=condition=ready pod -l k8s-app=kube-dns -n kube-system --timeout=120s 2>/dev/null || true

    # --- infra-secrets (hanya create, jangan overwrite) ---
    if kubectl get secret infra-secrets -n infra &>/dev/null; then
        log "infra-secrets already exists — skipping (delete manually to regenerate)"
    else
        log "Creating infra-secrets from .env..."
        envsubst < "$SCRIPT_DIR/kubernetes/infra/base/secrets-template.yaml" | kubectl apply -f -
        log "infra-secrets created ✓"
    fi

    # --- tunnel-token secret (hanya create, jangan overwrite) ---
    if [ -z "${CF_TUNNEL_TOKEN:-}" ]; then
        warn "CF_TUNNEL_TOKEN is empty in .env — cloudflared tunnel will fail"
        warn "Set CF_TUNNEL_TOKEN in $SCRIPT_DIR/.env and re-run"
    elif kubectl get secret tunnel-token -n infra &>/dev/null; then
        # Verifikasi token valid (bukan placeholder envsubst)
        local token_val
        token_val=$(kubectl get secret tunnel-token -n infra -o jsonpath='{.data.token}' 2>/dev/null | base64 -d 2>/dev/null || echo "")
        if [ -n "$token_val" ] && [ "$token_val" != '${CF_TUNNEL_TOKEN}' ]; then
            log "tunnel-token already exists with valid token — skipping"
        else
            warn "tunnel-token exists but contains placeholder — regenerating from .env..."
            kubectl create secret generic tunnel-token -n infra \
                --from-literal=token="${CF_TUNNEL_TOKEN}" \
                --dry-run=client -o yaml | kubectl apply -f -
        fi
    else
        log "Creating tunnel-token from .env..."
        kubectl create secret generic tunnel-token -n infra \
            --from-literal=token="${CF_TUNNEL_TOKEN}" \
            --dry-run=client -o yaml | kubectl apply -f -
    fi

    # Default derivatif
    export GRAFANA_DOMAIN="${GRAFANA_DOMAIN:-grafana.${DOMAIN:-faisalaffan.com}}"
    export CLOUDBEAVER_HOSTNAME="${CLOUDBEAVER_HOSTNAME:-db.${DOMAIN:-faisalaffan.com}}"
    export MINIO_CONSOLE_HOSTNAME="${MINIO_CONSOLE_HOSTNAME:-minio.${DOMAIN:-faisalaffan.com}}"
    export S3_HOSTNAME="${S3_HOSTNAME:-s3.${DOMAIN:-faisalaffan.com}}"
    export EXCALIDRAW_HOSTNAME="${EXCALIDRAW_HOSTNAME:-excalidraw.${DOMAIN:-faisalaffan.com}}"

    # Build kustomize + substitute env vars + apply
    # Filter: skip PVC errors (cannot patch storage), surface real errors
    log "Applying infra kustomization..."
    local apply_output apply_rc
    apply_output=$(kubectl kustomize . | envsubst | kubectl apply -f - 2>&1)
    apply_rc=$?

    # Filter known-harmless errors (PVC storage resize, unchanged resources)
    local real_errors
    real_errors=$(echo "$apply_output" | grep -v "unchanged\|configured\|created" | grep -iE "error|Error|failed|invalid" || true)

    if [ -n "$real_errors" ]; then
        # Check apakah cuma PVC errors yg harmless
        local non_pvc_errors
        non_pvc_errors=$(echo "$real_errors" | grep -v "PersistentVolumeClaim.*field can not be less than status" || true)
        if [ -n "$non_pvc_errors" ]; then
            warn "Kustomize apply had errors:"
            echo "$non_pvc_errors" | while IFS= read -r line; do warn "  $line"; done
        else
            log "Kustomize applied (PVC size warnings ignored — harmless)"
        fi
    else
        log "Kustomize applied clean ✓"
    fi

    log "Infrastructure deployed ✓"
}

# ------------------------------------------------------------------
# Fix CoreDNS — force TCP untuk upstream DNS (UDP 53 sering diblok)
# Issue: Pod network tidak bisa resolve domain eksternal via UDP 53
# Root cause: UDP port 53 outbound dari pod network diblok firewall/network
# Fix: CoreDNS forward ke 8.8.8.8/8.8.4.4 pakai TCP (force_tcp)
# ------------------------------------------------------------------
fix_coredns_force_tcp() {
    log "Fixing CoreDNS — force TCP for upstream DNS..."

    # Tunggu CoreDNS ready
    kubectl wait --for=condition=ready pod -l k8s-app=kube-dns -n kube-system --timeout=120s 2>/dev/null || true

    # Cek apakah force_tcp sudah ada di config
    if kubectl get configmap -n kube-system coredns -o jsonpath='{.data.Corefile}' 2>/dev/null | grep -q "force_tcp"; then
        log "CoreDNS force_tcp already configured"
        return
    fi

    # Terapkan force_tcp — ganti forward . /etc/resolv.conf menjadi forward . 8.8.8.8 8.8.4.4 { force_tcp }
    kubectl patch configmap -n kube-system coredns --type merge -p '{
        "data": {
            "Corefile": ".:53 {\n    errors\n    health\n    ready\n    kubernetes cluster.local in-addr.arpa ip6.arpa {\n      pods insecure\n      fallthrough in-addr.arpa ip6.arpa\n    }\n    hosts /etc/coredns/NodeHosts {\n      ttl 60\n      reload 15s\n      fallthrough\n    }\n    prometheus :9153\n    cache 30\n    loop\n    reload\n    loadbalance\n    import /etc/coredns/custom/*.override\n    forward . 8.8.8.8 8.8.4.4 {\n        force_tcp\n    }\n}\nimport /etc/coredns/custom/*.server\n"
        }
    }' 2>/dev/null || warn "Failed to patch CoreDNS ConfigMap"

    kubectl rollout restart deploy -n kube-system coredns 2>/dev/null || true
    kubectl wait --for=condition=ready pod -l k8s-app=kube-dns -n kube-system --timeout=60s 2>/dev/null || true

    log "CoreDNS force_tcp applied ✓"
}

# ------------------------------------------------------------------
# Full deploy: HelmCharts (third-party) → Kustomize (first-party)
# Idempotent — bisa dijalankan berkali-kali
# ------------------------------------------------------------------
deploy_all() {
    log "=== Deploying all infrastructure ==="

    # 0. Fix CoreDNS — force TCP DNS (sebelum HelmCharts yg butuh DNS)
    fix_coredns_force_tcp

    # 1. Third-party: ingress-nginx, cert-manager
    deploy_helmcharts

    # 2. Build custom images (postgres-all dll)
    build_postgres_image

    # 3. Wait for ingress-nginx (blocking — needed by Ingress resources)
    log "Waiting for ingress-nginx (max 120s)..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=ingress-nginx \
        -n ingress-nginx --timeout=120s 2>/dev/null || warn "ingress-nginx not ready yet"

    # 4. First-party: all infra services via Kustomize
    deploy_kustomize

    log "=== Deploy complete ==="
    kubectl get pods,svc -n infra -o wide 2>/dev/null || true
}

# ------------------------------------------------------------------
# Fix k3s directory permissions — pastikan user bisa baca /etc/rancher/k3s
# ------------------------------------------------------------------
fix_k3s_perms() {
    if [ "${SUDO_SKIP:-false}" = true ]; then
        return
    fi
    if [ -d /etc/rancher/k3s ] && [ ! -r /etc/rancher/k3s/k3s.yaml ]; then
        log "Fixing /etc/rancher/k3s permissions..."
        sudo chmod 755 /etc/rancher/k3s
    fi
}

# ------------------------------------------------------------------
# Fix UFW — open k3s API port (Tailscale operator handles db access)
# ------------------------------------------------------------------
fix_ufw_ports() {
    if [ "${SUDO_SKIP:-false}" = true ]; then
        return
    fi
    if command -v ufw &>/dev/null && sudo ufw status 2>/dev/null | grep -q "Status: active"; then
        if ! sudo ufw status 2>/dev/null | grep -q "6443/tcp"; then
            log "Opening UFW port 6443 for k3s API..."
            sudo ufw allow 6443/tcp
        fi
    fi
}

# ------------------------------------------------------------------
# Fix kubectl wrapper — deteksi & perbaiki recursive wrapper di ~/.local/bin/kubectl
# ------------------------------------------------------------------
fix_kubectl_wrapper() {
    local wrapper="$HOME/.local/bin/kubectl"
    local real_kubectl="/usr/local/bin/kubectl"

    # Kalau ~/.local/bin/kubectl adalah shell script (bukan binary/symlink)
    if [ -f "$wrapper" ] && [ ! -L "$wrapper" ] && file "$wrapper" 2>/dev/null | grep -qi "shell script"; then
        # Cek apakah dia recursive (panggil "kubectl" tanpa full path)
        if grep -q 'exec kubectl' "$wrapper" 2>/dev/null; then
            warn "Recursive kubectl wrapper detected! Fixing..."
            sed -i "s|exec kubectl|exec $real_kubectl|" "$wrapper"
            log "kubectl wrapper fixed → $real_kubectl"
        fi
    fi

    # Kalau tidak ada wrapper tapi juga tidak ada kubectl di PATH, buat symlink
    if [ ! -f "$wrapper" ] && [ -x "$real_kubectl" ] && ! command -v kubectl &>/dev/null; then
        log "Creating kubectl symlink in ~/.local/bin..."
        mkdir -p "$HOME/.local/bin"
        ln -sf "$real_kubectl" "$wrapper"
    fi
}

# ------------------------------------------------------------------
# Fix kubeconfig — chown ke user, setup KUBECONFIG permanent
# ------------------------------------------------------------------
fix_kubeconfig() {
    local kubeconfig="$HOME/.kube/k3s-config"
    local default_kubeconfig="$HOME/.kube/config"

    if [ -f "$kubeconfig" ] && [ "$(stat -c '%U' "$kubeconfig" 2>/dev/null || echo '')" = "root" ]; then
        log "Fixing kubeconfig ownership..."
        sudo chown "$USER:$(id -gn)" "$kubeconfig"
        chmod 600 "$kubeconfig"
    fi

    # Copy ke default kubeconfig location biar kubectl auto-detect
    if [ -f "$kubeconfig" ] && [ ! -f "$default_kubeconfig" ]; then
        mkdir -p "$HOME/.kube"
        cp "$kubeconfig" "$default_kubeconfig"
        chmod 600 "$default_kubeconfig"
        log "Kubeconfig ready: $default_kubeconfig"
    fi

    # Set KUBECONFIG permanent di .bashrc
    local final_kubeconfig="${default_kubeconfig:-$kubeconfig}"
    if [ -f "$final_kubeconfig" ] && ! grep -q "KUBECONFIG" "$HOME/.bashrc" 2>/dev/null; then
        echo "export KUBECONFIG=$final_kubeconfig" >> "$HOME/.bashrc"
        log "KUBECONFIG added to ~/.bashrc"
    fi

    export KUBECONFIG="${KUBECONFIG:-$final_kubeconfig}"
}

# ------------------------------------------------------------------
# Google MCP Toolbox (for mysql MCP)
# ------------------------------------------------------------------
install_toolbox() {
    if command -v toolbox &>/dev/null; then
        log "toolbox already installed"
    else
        log "Installing Google MCP Toolbox v${TOOLBOX_VERSION}..."
        local url
        if [ "$OS" = "linux" ]; then
            url="https://storage.googleapis.com/mcp-toolbox-for-databases/v${TOOLBOX_VERSION}/linux/amd64/toolbox"
        else
            url="https://storage.googleapis.com/mcp-toolbox-for-databases/v${TOOLBOX_VERSION}/darwin/arm64/toolbox"
        fi
        curl -L -o "$HOME/.local/bin/toolbox" "$url"
        chmod +x "$HOME/.local/bin/toolbox"
    fi
    export PATH="$HOME/.local/bin:$PATH"
}

# ------------------------------------------------------------------
# Setup Claude Code MCP servers
# ------------------------------------------------------------------
setup_mcp() {
    log "Setting up Claude Code MCP servers..."

    if ! command -v claude &>/dev/null; then
        warn "claude CLI not found. Run: npm install -g @anthropic-ai/claude-code"
        return
    fi

    # MySQL MCP — skip if already configured
    if claude mcp get mysql &>/dev/null 2>&1; then
        log "MySQL MCP already configured, skipping"
        return
    fi

    claude mcp add mysql -s user \
        -e MYSQL_HOST="${MYSQL_HOST:-127.0.0.1}" \
        -e MYSQL_PORT="${MYSQL_PORT:-3306}" \
        -e MYSQL_USER="${MYSQL_USER:-appuser}" \
        -e MYSQL_PASSWORD="${MYSQL_PASSWORD:-appuser_secret_2026}" \
        -e MYSQL_DATABASE="${MYSQL_DATABASE:-appdb}" \
        -- "$HOME/.local/bin/toolbox" --prebuilt=mysql --stdio 2>/dev/null || warn "MySQL MCP setup skipped"

    log "MCP servers configured"
}

# ------------------------------------------------------------------
# Verify TLS — check cert-manager issues certificates after deploy
# ------------------------------------------------------------------
verify_tls() {
    log "Verifying TLS certificates..."
    kubectl get clusterissuer 2>/dev/null | grep -q "True" || {
        warn "No ready ClusterIssuer found — TLS will not work"
        return
    }

    # Check all ingresses with cert-manager annotation
    local tls_ingresses
    tls_ingresses=$(kubectl get ingress -A -o json 2>/dev/null | jq -r '
      .items[] | select(.metadata.annotations["cert-manager.io/cluster-issuer"] != null) |
      "\(.metadata.namespace)/\(.metadata.name)"
    ' 2>/dev/null || true)

    if [ -z "$tls_ingresses" ]; then
        warn "No ingresses with cert-manager annotation found"
        return
    fi

    local timeout=180
    local start_time=$(date +%s)

    for ingress_ref in $tls_ingresses; do
        local ns="${ingress_ref%%/*}"
        local name="${ingress_ref##*/}"

        # Extract TLS secret name from ingress
        local secret_name
        secret_name=$(kubectl get ingress "$name" -n "$ns" -o jsonpath='{.spec.tls[*].secretName}' 2>/dev/null || true)

        if [ -z "$secret_name" ]; then
            warn "Ingress $ns/$name has no tls.secretName — skipping"
            continue
        fi

        log "Waiting for TLS cert: $ns/$secret_name (timeout ${timeout}s)..."

        while true; do
            local elapsed=$(($(date +%s) - start_time))
            if [ $elapsed -ge $timeout ]; then
                warn "Timeout waiting for TLS cert $ns/$secret_name after ${timeout}s"
                break
            fi

            local cert_ready
            cert_ready=$(kubectl get cert "$secret_name" -n "$ns" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")

            if [ "$cert_ready" = "True" ]; then
                log "TLS cert $ns/$secret_name ✓ Ready"
                break
            fi

            # Show challenge state if stuck
            local challenge_state
            challenge_state=$(kubectl get challenge -n "$ns" -o jsonpath='{range .items[*]}{.status.reason}{"\n"}{end}' 2>/dev/null | head -1 || echo "waiting...")
            log "  $ns/$secret_name: $cert_ready ($challenge_state)"

            sleep 10
        done
    done

    log "TLS verification complete"
}

# ------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------
print_summary() {
    echo ""
    echo "============================================"
    echo "  DevOps Setup Complete (Ansible)"
    echo ""
    echo "============================================"
    echo "  DevOps Setup Complete"
    echo "  First-party: Kustomize  |  Third-party: HelmChart"
    echo "============================================"
    echo ""
    echo "  Domain:      ${DOMAIN:-faisalaffan.com}"
    echo "  Kustomize:   $KUSTOMIZE_DIR"
    echo "  HelmCharts:  $HELMCHART_DIR"
    echo ""
    echo "  Services (on K3s):"
    echo "    PostgreSQL 17:  postgres.infra:5432"
    echo "    MySQL 8.4:      mysql.infra:3306"
    echo "    VictoriaMetrics: victoriametrics.infra:8428"
    echo "    Loki:            loki.infra:3100"
    echo "    Tempo:           tempo.infra:3200"
    echo "    Pyroscope:       pyroscope.infra:4040"
    echo "    Grafana:         grafana.infra:3000"
    echo ""
    echo "  Kubeconfig:   ~/.kube/k3s-config"
    echo ""
    echo "  Quick commands:"
    echo "    export KUBECONFIG=~/.kube/k3s-config"
    echo "    kubectl get pods -n infra"
    echo "    kubectl kustomize $KUSTOMIZE_DIR"
    echo ""
    echo "============================================"
}

# ------------------------------------------------------------------
# Main
# ------------------------------------------------------------------
main() {
    echo ""
    echo "============================================"
    echo "  DevOps Infrastructure Setup"
    echo "  First-party: Kustomize  |  Third-party: HelmChart"
    echo "  Ubuntu 22.04+ / macOS"
    echo "============================================"
    echo ""

    # Cache sudo password once (needed for ansible become + apt installs)
    # Non-interactive mode: skip sudo, run only kubectl-based fixes
    if [ ! -t 0 ]; then
        warn "Non-interactive mode — skipping sudo-requiring steps (ansible, apt)"
        SUDO_SKIP=true
    fi

    if [ "${SUDO_SKIP:-false}" = false ] && ! sudo -n true 2>/dev/null; then
        read -sp "[sudo] password for $USER: " SUDO_PASS
        echo
        if echo "$SUDO_PASS" | sudo -S true 2>/dev/null; then
            export SUDO_PASS
            log "Sudo access confirmed"
        else
            warn "Wrong sudo password — some steps may fail"
            SUDO_SKIP=true
        fi
    fi

    detect_os
    install_base
    fix_k3s_perms
    fix_ufw_ports
    install_uv
    fix_kubectl_wrapper
    install_ansible
    setup_ssh
    setup_vault
    install_toolbox

    if [ "${SUDO_SKIP:-false}" = true ]; then
        warn "Skipping bootstrap_k3s (needs sudo)"
    else
        bootstrap_k3s "$@"
    fi

    deploy_all
    setup_mcp
    verify_tls
    print_summary
}

main "$@"
