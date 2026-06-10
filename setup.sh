#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# DevOps Infrastructure Setup — Ubuntu 22.04+ / macOS
# One script: Docker, PostgreSQL, MySQL, MCP toolbox, SSH
# ============================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[✗]${NC} $*"; exit 1; }

# ------------------------------------------------------------------
# Config — load from DEVOPS/.env if exists, else use defaults
# ------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
    set -a; source "$SCRIPT_DIR/.env"; set +a
fi

GITHUB_REPO="${GIT_REPO:-git@github.com:faisalaffan/infra-light.git}"
REPO_DIR="${INFRA_DIR:-$HOME/infra-light}"
SSH_KEY="${SSH_KEY_PATH:-$HOME/.ssh/id_rsa}"
GIT_EMAIL="${GIT_EMAIL:-faisallionel@gmail.com}"
GIT_NAME="${GIT_NAME:-Faisal Affan}"
TOOLBOX_VERSION="${TOOLBOX_VERSION:-1.4.0}"

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
# Docker + Compose
# ------------------------------------------------------------------
install_docker() {
    if command -v docker &>/dev/null; then
        log "Docker already installed: $(docker --version)"
    else
        log "Installing Docker..."
        if [ "$OS" = "linux" ]; then
            curl -fsSL https://get.docker.com | sh
            sudo usermod -aG docker "$USER"
            sudo systemctl enable docker
            sudo systemctl start docker
        elif [ "$OS" = "macos" ]; then
            if command -v brew &>/dev/null; then
                brew install --cask docker
            else
                warn "Install Docker Desktop manually: https://docs.docker.com/desktop/setup/mac/"
            fi
        fi
        log "Docker installed"
    fi

    if docker compose version &>/dev/null; then
        log "Docker Compose available"
    else
        warn "Docker Compose not found — install Docker Desktop or docker-compose-plugin"
    fi
}

# ------------------------------------------------------------------
# Base packages
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

    if [ -f "$SSH_KEY" ]; then
        log "SSH key exists: $SSH_KEY"
    else
        log "Generating SSH key (RSA 4096)..."
        ssh-keygen -t rsa -b 4096 -C "$GIT_EMAIL" -f "$SSH_KEY" -N ""
        log "SSH key generated"
    fi

    # SSH config for GitHub
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

    # Start ssh-agent, add key
    if [ "$OS" = "macos" ]; then
        ssh-add --apple-use-keychain "$SSH_KEY" 2>/dev/null || ssh-add "$SSH_KEY" 2>/dev/null || true
    else
        ssh-add "$SSH_KEY" 2>/dev/null || true
    fi

    log "SSH public key:"
    echo "---"
    cat "${SSH_KEY}.pub"
    echo "---"
    warn "Add this key to: https://github.com/settings/keys"
}

# ------------------------------------------------------------------
# Clone infra-light repo
# ------------------------------------------------------------------
clone_repo() {
    if [ -d "$REPO_DIR" ]; then
        log "Repo exists, pulling latest..."
        cd "$REPO_DIR"
        git pull origin dev
    else
        log "Cloning $GITHUB_REPO..."
        GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new" git clone "$GITHUB_REPO" "$REPO_DIR"
        cd "$REPO_DIR"
        git checkout dev
    fi
    log "Repo ready: $REPO_DIR"
}

# ------------------------------------------------------------------
# uv / uvx (for MCP servers: serena, MiniMax)
# ------------------------------------------------------------------
install_uv() {
    if command -v uvx &>/dev/null; then
        log "uvx already installed: $(uvx --version 2>&1 || true)"
    else
        log "Installing uv/uvx..."
        curl -LsSf https://astral.sh/uv/install.sh | sh
        export PATH="$HOME/.local/bin:$PATH"
        log "uvx installed: $(uvx --version 2>&1 || true)"
    fi
    # Ensure in PATH for current session
    export PATH="$HOME/.local/bin:$PATH"
}

# ------------------------------------------------------------------
# Google MCP Toolbox (for mysql MCP)
# ------------------------------------------------------------------
install_toolbox() {
    if command -v toolbox &>/dev/null; then
        log "toolbox already installed: $(toolbox --version 2>&1 || true)"
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
        log "toolbox installed: $(toolbox --version 2>&1 || true)"
    fi
    export PATH="$HOME/.local/bin:$PATH"
}

# ------------------------------------------------------------------
# Setup Claude Code MCP servers
# ------------------------------------------------------------------
setup_mcp() {
    log "Setting up Claude Code MCP servers..."

    # Ensure claude CLI available
    if ! command -v claude &>/dev/null; then
        warn "claude CLI not found. Run: npm install -g @anthropic-ai/claude-code"
        warn "Or install via: curl -fsSL https://claude.ai/code/install.sh | sh"
        return
    fi

    # MySQL MCP with env vars
    if claude mcp get mysql &>/dev/null 2>&1; then
        claude mcp remove mysql -s user 2>/dev/null || true
    fi

    claude mcp add mysql -s user \
        -e MYSQL_HOST="${MYSQL_HOST:-127.0.0.1}" \
        -e MYSQL_PORT="${MYSQL_PORT:-3306}" \
        -e MYSQL_USER="${MYSQL_USER:-appuser}" \
        -e MYSQL_PASSWORD="${MYSQL_PASSWORD:-appuser_secret_2026}" \
        -e MYSQL_DATABASE="${MYSQL_DATABASE:-appdb}" \
        -- "$HOME/.local/bin/toolbox" --prebuilt=mysql --stdio

    log "MCP servers configured"
}

# ------------------------------------------------------------------
# Start infrastructure
# ------------------------------------------------------------------
start_services() {
    log "Starting PostgreSQL..."
    cd "$REPO_DIR/postgres"
    docker compose up -d

    log "Starting MySQL..."
    cd "$REPO_DIR/mysql"
    docker compose up -d

    log "Waiting for services to be healthy..."
    local retries=0
    while [ $retries -lt 60 ]; do
        local pg_ok mysql_ok
        pg_ok=$(docker ps --filter name=postgres-all --filter health=healthy -q 2>/dev/null || true)
        mysql_ok=$(docker ps --filter name=mysql-all --filter health=healthy -q 2>/dev/null || true)
        if [ -n "$pg_ok" ] && [ -n "$mysql_ok" ]; then
            log "All services healthy"
            break
        fi
        sleep 3
        retries=$((retries + 1))
        [ $((retries % 5)) -eq 0 ] && warn "Waiting... ($retries/60)"
    done
}

# ------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------
print_summary() {
    echo ""
    echo "============================================"
    echo "  DevOps Setup Complete"
    echo "============================================"
    echo ""
    echo "  PostgreSQL:  localhost:5432"
    echo "    superuser:  postgres / postgres_super_secret_2026"
    echo "    app user:   appuser / appuser_secret_2026"
    echo "    database:   postgres, appdb"
    echo ""
    echo "  MySQL:       localhost:3306"
    echo "    root:       root / root_secret_2026"
    echo "    app user:   appuser / appuser_secret_2026"
    echo "    database:   appdb"
    echo ""
    echo "  Repo:        $REPO_DIR"
    echo "  GitHub:      $GITHUB_REPO"
    echo ""
    echo "  Quick commands:"
    echo "    cd $REPO_DIR/postgres && make psql"
    echo "    cd $REPO_DIR/mysql && make mysql"
    echo "    claude mcp list"
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
    echo "  Ubuntu 22.04+ / macOS"
    echo "============================================"
    echo ""

    detect_os
    install_base
    install_docker
    install_uv
    install_toolbox
    setup_ssh
    clone_repo
    start_services
    setup_mcp
    print_summary
}

main "$@"
