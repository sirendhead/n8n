#!/usr/bin/env bash
# n8n Production Server Setup Script
# Run on a fresh Ubuntu 22.04/24.04 VPS
# Usage: ssh root@SERVER_IP 'bash -s' < setup-server.sh

set -euo pipefail

echo "=== n8n Production Server Setup ==="

# ── System updates ───────────────────────────────────────────
echo "[1/6] Updating system..."
apt-get update -qq && apt-get upgrade -y -qq
apt-get install -y -qq curl wget git ufw

# ── Firewall ─────────────────────────────────────────────────
echo "[2/6] Configuring firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP (Caddy redirect)
ufw allow 443/tcp   # HTTPS
ufw allow 443/udp   # HTTP/3 (QUIC)
ufw --force enable

# ── Docker ───────────────────────────────────────────────────
echo "[3/6] Installing Docker..."
if ! command -v docker &>/dev/null; then
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
fi

# Docker Compose plugin (v2)
if ! docker compose version &>/dev/null; then
    apt-get install -y -qq docker-compose-plugin
fi

echo "Docker version: $(docker --version)"
echo "Compose version: $(docker compose version)"

# ── Create n8n user ──────────────────────────────────────────
echo "[4/6] Creating n8n service user..."
if ! id -u n8n &>/dev/null; then
    useradd -m -s /bin/bash -G docker n8n
fi

# ── Deploy directory ─────────────────────────────────────────
echo "[5/6] Setting up deploy directory..."
DEPLOY_DIR="/opt/n8n"
mkdir -p "$DEPLOY_DIR"
chown n8n:n8n "$DEPLOY_DIR"

# ── Swap (for small VPS) ────────────────────────────────────
echo "[6/6] Configuring swap..."
if [ ! -f /swapfile ]; then
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

echo ""
echo "=== Server setup complete! ==="
echo "Next steps:"
echo "  1. Copy deploy files to /opt/n8n/"
echo "  2. Create .env from .env.example"
echo "  3. docker compose -f docker-compose.prod.yml up -d"
echo ""
