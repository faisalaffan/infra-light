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
KUSTOMIZE_DIR="${SCRIPT_DIR}/kustomize"
HELMCHART_DIR="${SCRIPT_DIR}/helmcharts"

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
# Clone infra-light repo
# ------------------------------------------------------------------
clone_repo() {
    if [ -d "$REPO_DIR" ]; then
        log "Repo exists, pulling latest..."
        cd "$REPO_DIR"
        git pull origin "${GIT_BRANCH:-dev}" 2>/dev/null || log "Pull skipped (dirty tree?)"
    else
        log "Cloning $GITHUB_REPO..."
        GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new" git clone "$GITHUB_REPO" "$REPO_DIR"
        cd "$REPO_DIR"
        git checkout "${GIT_BRANCH:-dev}"
    fi
    log "Repo ready: $REPO_DIR"
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
        warn "vault.yml is ENCRYPTED. Overwriting with plaintext from .env..."
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
    ansible-playbook playbooks/tailscale.yml -e "tailscale_ipv4=$tailscale_ip" $ansible_become || true
    ansible-playbook playbooks/k3s.yml -e "tailscale_ipv4=$tailscale_ip" $ansible_become || warn "K3s may already be installed"

    fix_kubeconfig
    fix_k3s_perms
    fix_ufw_k3s
    fix_kubectl_wrapper
}

# ------------------------------------------------------------------
# Deploy third-party via HelmChart CRD
# Ingress-nginx + cert-manager — di-manage k3s helm-controller
# ------------------------------------------------------------------
deploy_helmcharts() {
    log "Deploying third-party services (HelmChart)..."
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
# CI trigger: push ke docker-postgres/ → .github/workflows/build-postgres.yml
# Local fallback: docker build --network host -t postgres-all:latest docker-postgres/
# ------------------------------------------------------------------
build_postgres_image() {
    local image="docker.io/faisalaffan/postgres-all:latest"
    local dockerfile_dir="$SCRIPT_DIR/docker-postgres"

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
# ------------------------------------------------------------------
deploy_kustomize() {
    log "Deploying first-party services (Kustomize)..."
    cd "$KUSTOMIZE_DIR/infra"

    # Load .env untuk envsubst
    set -a; source "$SCRIPT_DIR/.env" 2>/dev/null; set +a

    # Create namespace
    kubectl create namespace infra 2>/dev/null || true

    # Create infra-secrets dari .env
    log "Creating infra-secrets..."
    envsubst < "$SCRIPT_DIR/kustomize/infra/base/secrets-template.yaml" | kubectl apply -f - 2>/dev/null || true

    # Default derivatif
    export GRAFANA_DOMAIN="${GRAFANA_DOMAIN:-grafana.${DOMAIN:-faisalaffan.com}}"

    # Wait for CoreDNS
    log "Waiting for CoreDNS..."
    kubectl wait --for=condition=ready pod -l k8s-app=kube-dns -n kube-system --timeout=120s 2>/dev/null || true

    # Build kustomize + substitute env vars + apply
    log "Applying infra kustomization..."
    kubectl kustomize . | envsubst | kubectl apply -f - || warn "Kustomize apply had errors"

    log "Infrastructure deployed ✓"
}

# ------------------------------------------------------------------
# Full deploy: HelmCharts (third-party) → Kustomize (first-party)
# Idempotent — bisa dijalankan berkali-kali
# ------------------------------------------------------------------
deploy_all() {
    log "=== Deploying all infrastructure ==="

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
    if [ -d /etc/rancher/k3s ] && [ ! -r /etc/rancher/k3s/k3s.yaml ]; then
        log "Fixing /etc/rancher/k3s permissions..."
        sudo chmod 755 /etc/rancher/k3s
    fi
}

# ------------------------------------------------------------------
# Fix UFW — allow k3s API port 6443 so pods can reach API server
# Tanpa ini CoreDNS kubernetes plugin ga bisa sync → DNS loop mati
# ------------------------------------------------------------------
fix_ufw_k3s() {
    if command -v ufw &>/dev/null && sudo ufw status 2>/dev/null | grep -q "Status: active"; then
        if ! sudo ufw status 2>/dev/null | grep -q "6443"; then
            log "Opening UFW port 6443 for k3s API server..."
            sudo ufw allow 6443/tcp
            log "UFW: 6443/tcp opened"
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

    # MySQL MCP
    if claude mcp get mysql &>/dev/null 2>&1; then
        claude mcp remove mysql -s user 2>/dev/null || true
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
    echo "  Kustomize:   $KUSTOMIZE_DIR/infra"
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
    echo "    kubectl kustomize $KUSTOMIZE_DIR/infra"
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
    if ! sudo -n true 2>/dev/null; then
        read -sp "[sudo] password for $USER: " SUDO_PASS
        echo
        # Validate immediately
        if echo "$SUDO_PASS" | sudo -S true 2>/dev/null; then
            export SUDO_PASS
            log "Sudo access confirmed"
        else
            warn "Wrong sudo password — some steps may fail"
        fi
    fi

    detect_os
    install_base
    fix_k3s_perms
    fix_ufw_k3s
    install_uv
    fix_kubectl_wrapper
    install_ansible
    setup_ssh
    setup_vault
    install_toolbox
    bootstrap_k3s "$@"
    deploy_all
    setup_mcp
    print_summary
}

main "$@"
