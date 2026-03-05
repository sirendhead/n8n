#!/usr/bin/env bash
# Provision a Hetzner Cloud VPS for n8n
# Prerequisites: hcloud CLI installed and configured
# Usage: ./provision-hetzner.sh

set -euo pipefail

SERVER_NAME="n8n-prod"
SERVER_TYPE="cx22"          # 2 vCPU, 4GB RAM, 40GB SSD — $4.50/mo
IMAGE="ubuntu-24.04"
LOCATION="sin"              # Singapore (closest to Vietnam)
SSH_KEY_NAME="default"      # Name of your SSH key in Hetzner

echo "=== Provisioning Hetzner VPS for n8n ==="
echo "  Server: $SERVER_NAME"
echo "  Type: $SERVER_TYPE (2vCPU/4GB/40GB)"
echo "  Image: $IMAGE"
echo "  Location: $LOCATION (Singapore)"
echo ""

# Check hcloud CLI
if ! command -v hcloud &>/dev/null; then
    echo "hcloud CLI not found. Install it:"
    echo "  Windows: scoop install hcloud"
    echo "  macOS:   brew install hcloud"
    echo "  Linux:   snap install hcloud"
    echo ""
    echo "Then configure: hcloud context create n8n"
    echo "  (paste your API token from console.hetzner.cloud)"
    exit 1
fi

# Check active context
if ! hcloud context active &>/dev/null; then
    echo "No active hcloud context. Run:"
    echo "  hcloud context create n8n"
    exit 1
fi

# List SSH keys
echo "Available SSH keys:"
hcloud ssh-key list
echo ""

# Check if SSH key exists
if ! hcloud ssh-key describe "$SSH_KEY_NAME" &>/dev/null; then
    echo "SSH key '$SSH_KEY_NAME' not found in Hetzner."
    echo "Upload your key first:"
    echo "  hcloud ssh-key create --name default --public-key-from-file ~/.ssh/id_ed25519.pub"
    exit 1
fi

# Check if server already exists
if hcloud server describe "$SERVER_NAME" &>/dev/null; then
    echo "Server '$SERVER_NAME' already exists!"
    IP=$(hcloud server ip "$SERVER_NAME")
    echo "  IP: $IP"
    exit 0
fi

# Create server
echo "Creating server..."
hcloud server create \
    --name "$SERVER_NAME" \
    --type "$SERVER_TYPE" \
    --image "$IMAGE" \
    --location "$LOCATION" \
    --ssh-key "$SSH_KEY_NAME"

# Get IP
IP=$(hcloud server ip "$SERVER_NAME")

echo ""
echo "=== VPS Created! ==="
echo "  Name: $SERVER_NAME"
echo "  IP: $IP"
echo "  SSH: ssh root@$IP"
echo ""
echo "Next steps:"
echo "  1. Add DNS record in Cloudflare:"
echo "     n8n.colorverse.dev -> $IP (A record, DNS only / no proxy)"
echo ""
echo "  2. Setup server:"
echo "     ssh root@$IP 'bash -s' < setup-server.sh"
echo ""
echo "  3. Deploy n8n:"
echo "     cp .env.example .env  # then edit .env"
echo "     ./deploy.sh $IP"
echo ""
