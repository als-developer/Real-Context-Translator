#!/bin/bash
set -euo pipefail

# RCT-Engine Complete Restore Script

BACKUP_FILE="${1:-}"
ENCRYPT_KEY="${ENCRYPT_KEY:-}"

if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: $0 <backup-file.tar.gz[.enc]>"
    echo ""
    echo "Available backups:"
    ls -la /var/backups/rct-engine/backup-*.tar.gz* 2>/dev/null || echo "No backups found"
    exit 1
fi

RESTORE_DIR="/tmp/rct-restore-$(date +%s)"
mkdir -p "$RESTORE_DIR"

echo "🔄 Starting RCT-Engine restore from $BACKUP_FILE"
echo "=========================================="

# 1. Decrypt if needed
if [[ "$BACKUP_FILE" == *.enc ]]; then
    echo "1. Decrypting backup..."
    if [ -z "$ENCRYPT_KEY" ]; then
        read -s -p "Enter encryption key: " ENCRYPT_KEY
        echo
    fi
    openssl enc -d -aes-256-cbc -in "$BACKUP_FILE" -out "$RESTORE_DIR/backup.tar.gz" -k "$ENCRYPT_KEY"
    BACKUP_FILE="$RESTORE_DIR/backup.tar.gz"
    echo "   ✓ Backup decrypted"
fi

# 2. Extract archive
echo "2. Extracting backup archive..."
tar -xzf "$BACKUP_FILE" -C "$RESTORE_DIR"
EXTRACTED_DIR=$(find "$RESTORE_DIR" -name "backup-*" -type d | head -1)
echo "   ✓ Extracted to: $EXTRACTED_DIR"

# 3. Stop services
echo "3. Stopping services..."
docker-compose -f infrastructure/docker/docker-compose.yml stop
echo "   ✓ Services stopped"

# 4. Restore PostgreSQL
echo "4. Restoring PostgreSQL database..."
docker start rct-postgres
sleep 5
docker cp "$EXTRACTED_DIR/postgres.pgdump" rct-postgres:/tmp/restore.pgdump
docker exec rct-postgres pg_restore -U rct_admin -d rct_saas --clean --if-exists /tmp/restore.pgdump
echo "   ✓ PostgreSQL restored"

# 5. Restore Redis
echo "5. Restoring Redis data..."
docker cp "$EXTRACTED_DIR/redis.rdb" rct-postgres:/tmp/dump.rdb
docker exec rct-redis redis-cli SHUTDOWN NOSAVE || true
docker start rct-redis
echo "   ✓ Redis restored"

# 6. Restore configuration (dry run)
echo "6. Checking configuration diffs..."
if [ -d "$EXTRACTED_DIR/terraform" ]; then
    echo "   📁 Terraform configuration available at: $EXTRACTED_DIR/terraform"
fi
if [ -d "$EXTRACTED_DIR/kubernetes" ]; then
    echo "   📁 Kubernetes manifests available at: $EXTRACTED_DIR/kubernetes"
fi
echo "   ✓ Configuration files available for manual review"

# 7. Start services
echo "7. Starting services..."
docker-compose -f infrastructure/docker/docker-compose.yml up -d
sleep 10

# 8. Verify restore
echo "8. Verifying restore..."
if docker exec rct-postgres psql -U rct_admin -d rct_saas -c "SELECT COUNT(*) FROM cultural_context_matrix;" > /dev/null 2>&1; then
    echo "   ✓ Database verification passed"
else
    echo "   ❌ Database verification failed"
    exit 1
fi

if docker exec rct-redis redis-cli PING | grep -q "PONG"; then
    echo "   ✓ Redis verification passed"
else
    echo "   ❌ Redis verification failed"
    exit 1
fi

# 9. Cleanup
echo "9. Cleaning up..."
rm -rf "$RESTORE_DIR"
echo "   ✓ Cleanup completed"

echo ""
echo "=========================================="
echo "✅ Restore completed successfully!"
echo "=========================================="
