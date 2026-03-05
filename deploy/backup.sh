#!/usr/bin/env bash
# Backup n8n database and data
# Usage: ./backup.sh [SERVER_IP] [SSH_USER]
# Run locally to pull backup from server, or on server directly

set -euo pipefail

DEPLOY_DIR="/opt/n8n"
BACKUP_DIR="/opt/n8n/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Load env
if [ -f "$DEPLOY_DIR/.env" ]; then
    source "$DEPLOY_DIR/.env"
fi

DB_USER="${POSTGRES_USER:-n8n}"
DB_NAME="${POSTGRES_DB:-n8n}"

echo "=== n8n Backup — $TIMESTAMP ==="

mkdir -p "$BACKUP_DIR"

# ── Database dump ────────────────────────────────────────────
echo "[1/2] Backing up PostgreSQL..."
docker compose -f "$DEPLOY_DIR/docker-compose.prod.yml" exec -T postgres \
    pg_dump -U "$DB_USER" -d "$DB_NAME" --clean --if-exists \
    | gzip > "$BACKUP_DIR/n8n_db_$TIMESTAMP.sql.gz"

echo "  Database: $BACKUP_DIR/n8n_db_$TIMESTAMP.sql.gz"

# ── n8n data volume ─────────────────────────────────────────
echo "[2/2] Backing up n8n data volume..."
docker run --rm \
    -v n8n_data:/data:ro \
    -v "$BACKUP_DIR":/backup \
    alpine tar czf "/backup/n8n_data_$TIMESTAMP.tar.gz" -C /data .

echo "  Data: $BACKUP_DIR/n8n_data_$TIMESTAMP.tar.gz"

# ── Cleanup old backups (keep last 7) ───────────────────────
echo "Cleaning up old backups (keeping last 7)..."
ls -t "$BACKUP_DIR"/n8n_db_*.sql.gz 2>/dev/null | tail -n +8 | xargs -r rm
ls -t "$BACKUP_DIR"/n8n_data_*.tar.gz 2>/dev/null | tail -n +8 | xargs -r rm

echo ""
echo "=== Backup complete ==="
ls -lh "$BACKUP_DIR"/n8n_*"$TIMESTAMP"*
