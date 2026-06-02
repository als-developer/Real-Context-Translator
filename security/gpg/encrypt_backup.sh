#!/bin/bash
set -euo pipefail

# RCT-Engine GPG Backup Encryption Script
# Encrypts database backups before offsite storage

BACKUP_DIR="/var/backups/rct_db"
ENCRYPTED_DIR="/var/backups/rct_db/encrypted"
GPG_RECIPIENT="security@rct-engine.com"
GPG_PUBLIC_KEY="/etc/gpg/rct-public-key.asc"

# Create encrypted directory if not exists
mkdir -p "$ENCRYPTED_DIR"

# Find latest backup file
LATEST_BACKUP=$(find "$BACKUP_DIR" -name "*.sql.gz" -type f | sort | tail -n 1)

if [ -z "$LATEST_BACKUP" ]; then
    echo "[ERROR] No backup file found to encrypt"
    exit 1
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ENCRYPTED_FILE="$ENCRYPTED_DIR/rct_backup_${TIMESTAMP}.sql.gz.gpg"

echo "[$(date)] Encrypting backup: $LATEST_BACKUP"

# Import GPG public key if not already imported
if ! gpg --list-keys "$GPG_RECIPIENT" &>/dev/null; then
    gpg --import "$GPG_PUBLIC_KEY"
fi

# Encrypt the backup
gpg --encrypt --recipient "$GPG_RECIPIENT" \
    --trust-model always \
    --output "$ENCRYPTED_FILE" \
    "$LATEST_BACKUP"

# Verify encryption
if gpg --list-packets "$ENCRYPTED_FILE" &>/dev/null; then
    echo "[SUCCESS] Backup encrypted: $ENCRYPTED_FILE"
    
    # Remove original unencrypted backup
    rm -f "$LATEST_BACKUP"
    
    # Upload to S3 (if configured)
    if command -v aws &>/dev/null && [ -n "${AWS_S3_BUCKET:-}" ]; then
        aws s3 cp "$ENCRYPTED_FILE" "s3://${AWS_S3_BUCKET}/backups/"
        echo "[SUCCESS] Uploaded to S3"
    fi
else
    echo "[ERROR] Encryption verification failed"
    exit 1
fi

# Cleanup old encrypted backups (keep 30 days)
find "$ENCRYPTED_DIR" -name "*.gpg" -mtime +30 -delete

echo "[$(date)] Backup encryption completed"
