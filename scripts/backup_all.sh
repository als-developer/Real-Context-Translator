#!/bin/bash
set -euo pipefail

# RCT-Engine Complete Backup Script
# Backs up database, Redis, and configuration files

BACKUP_DIR="/var/backups/rct-engine"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="$BACKUP_DIR/backup-$TIMESTAMP"
ENCRYPT_KEY="${ENCRYPT_KEY:-}"

mkdir -p "$BACKUP_PATH"

echo "📦 Starting RCT-Engine backup at $(date)"
echo "=========================================="

# 1. PostgreSQL backup
echo "1. Backing up PostgreSQL database..."
docker exec rct-postgres pg_dump -U rct_admin -d rct_saas \
    --format=custom \
    --compress=9 \
    --file="/tmp/rct_dump.pgdump"
docker cp rct-postgres:/tmp/rct_dump.pgdump "$BACKUP_PATH/postgres.pgdump"
echo "   ✓ PostgreSQL backup completed"

# 2. Redis backup
echo "2. Backing up Redis data..."
docker exec rct-redis redis-cli SAVE
docker cp rct-redis:/data/dump.rdb "$BACKUP_PATH/redis.rdb"
echo "   ✓ Redis backup completed"

# 3. Configuration files
echo "3. Backing up configuration..."
cp -r infrastructure/terraform "$BACKUP_PATH/terraform/"
cp -r infrastructure/kubernetes "$BACKUP_PATH/kubernetes/"
cp -r monitoring/prometheus "$BACKUP_PATH/prometheus/"
cp -r security/gpg/*.asc "$BACKUP_PATH/gpg/" 2>/dev/null || true
echo "   ✓ Configuration backup completed"

# 4. Application logs (last 7 days)
echo "4. Backing up recent logs..."
docker logs rct-api --since 7d > "$BACKUP_PATH/api.log" 2>&1
docker logs rct-worker --since 7d > "$BACKUP_PATH/worker.log" 2>&1
echo "   ✓ Log backup completed"

# 5. Create manifest
echo "5. Creating backup manifest..."
cat > "$BACKUP_PATH/MANIFEST.txt" << EOF
Backup Date: $(date)
RCT-Engine Version: $(git describe --tags 2>/dev/null || echo "unknown")
PostgreSQL Version: $(docker exec rct-postgres psql -U rct_admin -c "SELECT version();" | head -1)
Redis Version: $(docker exec rct-redis redis-cli INFO server | grep redis_version)
Components:
- PostgreSQL dump: postgres.pgdump
- Redis dump: redis.rdb
- Terraform config: terraform/
- Kubernetes config: kubernetes/
- Prometheus config: prometheus/
- GPG keys: gpg/
- Logs: api.log, worker.log
EOF
echo "   ✓ Manifest created"

# 6. Archive and compress
echo "6. Creating archive..."
tar -czf "$BACKUP_PATH.tar.gz" -C "$BACKUP_DIR" "backup-$TIMESTAMP"
rm -rf "$BACKUP_PATH"
echo "   ✓ Archive created: $BACKUP_PATH.tar.gz"

# 7. Encrypt if key provided
if [ -n "$ENCRYPT_KEY" ]; then
    echo "7. Encrypting backup..."
    openssl enc -aes-256-cbc -salt -in "$BACKUP_PATH.tar.gz" \
        -out "$BACKUP_PATH.tar.gz.enc" -k "$ENCRYPT_KEY"
    rm -f "$BACKUP_PATH.tar.gz"
    echo "   ✓ Backup encrypted"
fi

# 8. Upload to S3 (if configured)
if [ -n "${AWS_S3_BUCKET:-}" ]; then
