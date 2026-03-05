#!/usr/bin/env bash
# Deploy n8n to production VPS
# Usage: ./deploy.sh <SERVER_IP> [SSH_USER]
#
# Prerequisites:
#   - SSH key access to the server
#   - Server has been set up with setup-server.sh
#   - .env file exists in this directory

set -euo pipefail

SERVER_IP="${1:?Usage: ./deploy.sh <SERVER_IP> [SSH_USER]}"
SSH_USER="${2:-root}"
DEPLOY_DIR="/opt/n8n"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Validate .env exists
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo "ERROR: .env file not found. Copy .env.example to .env and fill in values."
    exit 1
fi

echo "=== Deploying n8n to $SSH_USER@$SERVER_IP ==="

# ── Upload files ─────────────────────────────────────────────
echo "[1/4] Uploading deploy files..."
scp -r \
    "$SCRIPT_DIR/docker-compose.prod.yml" \
    "$SCRIPT_DIR/Caddyfile" \
    "$SCRIPT_DIR/.env" \
    "$SSH_USER@$SERVER_IP:$DEPLOY_DIR/"

# ── Generate encryption key if placeholder ───────────────────
echo "[2/4] Checking encryption key..."
ssh "$SSH_USER@$SERVER_IP" bash -c "'
cd $DEPLOY_DIR
if grep -q CHANGE_ME_GENERATE_WITH_OPENSSL .env; then
    KEY=\$(openssl rand -hex 32)
    sed -i \"s/CHANGE_ME_GENERATE_WITH_OPENSSL/\$KEY/\" .env
    echo \"Generated new encryption key\"
fi
if grep -q CHANGE_ME_STRONG_PASSWORD .env; then
    PASS=\$(openssl rand -base64 24 | tr -d /+=)
    sed -i \"s/CHANGE_ME_STRONG_PASSWORD/\$PASS/\" .env
    echo \"Generated new database password: \$PASS\"
    echo \"SAVE THIS PASSWORD!\"
fi
'"

# ── Pull and start ───────────────────────────────────────────
echo "[3/4] Pulling images and starting services..."
ssh "$SSH_USER@$SERVER_IP" bash -c "'
cd $DEPLOY_DIR
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
'"

# ── Verify ───────────────────────────────────────────────────
echo "[4/4] Verifying deployment..."
sleep 10
ssh "$SSH_USER@$SERVER_IP" bash -c "'
cd $DEPLOY_DIR
docker compose -f docker-compose.prod.yml ps
echo \"\"
echo \"Checking n8n health...\"
for i in 1 2 3 4 5; do
    if curl -sf http://localhost:5678/healthz > /dev/null 2>&1; then
        echo \"n8n is healthy!\"
        break
    fi
    echo \"Waiting for n8n to start... (\$i/5)\"
    sleep 5
done
'"

echo ""
echo "=== Deployment complete! ==="
echo ""
echo "Next steps:"
echo "  1. Point DNS: n8n.colorverse.dev -> $SERVER_IP (A record in Cloudflare)"
echo "  2. Wait for DNS propagation (~1-5 min with Cloudflare)"
echo "  3. Caddy will auto-provision HTTPS via Let's Encrypt"
echo "  4. Access: https://n8n.colorverse.dev"
echo "  5. Create owner account on first visit"
echo ""
echo "Useful commands (on server):"
echo "  cd $DEPLOY_DIR"
echo "  docker compose -f docker-compose.prod.yml logs -f n8n"
echo "  docker compose -f docker-compose.prod.yml restart n8n"
echo "  docker compose -f docker-compose.prod.yml down"
echo ""
