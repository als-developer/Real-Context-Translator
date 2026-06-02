#!/bin/bash
set -euo

# RCT-Engine GPG Backup Decryption Script
# For disaster recovery and audit access

ENCRYPTED_DIR="/var/backups/rct_db/encrypted"
DECRYPTED_DIR="/var/backups/rct_db/decrypted"
GPG_PRIVATE_KEY="/etc/gpg/rct-private-key.asc"
GPG_PASSPHRASE_FILE="/etc/gpg/passphrase"

mkdir -p "$DECRYPTED_DIR"

# Find latest encrypted backup
LATEST_ENCRYPTED=$(find "$ENCRYPTED_DIR" -name "*.gpg" -type f | sort | tail -n 1)

if [ -z "$LATEST_ENCRYPTED" ]; then
    echo "[ERROR] No encrypted backup found"
    exit 1
fi

# Import private key if not already imported
if ! gpg --list-secret-keys "security@rct-engine.com" &>/dev/null; then
    gpg --batch --import "$GPG_PRIVATE_KEY"
fi

# Decrypt the backup
DECRYPTED_FILE="$DECRYPTED_DIR/$(basename "$LATEST_ENCRYPTED" .gpg)"

echo "[$(date)] Decrypting: $LATEST_ENCRYPTED"

gpg --batch --yes --passphrase-file "$GPG_PASSPHRASE_FILE" \
    --output "$DECRYPTED_FILE" \
    --decrypt "$LATEST_ENCRYPTED"

if [ -f "$DECRYPTED_FILE" ]; then
    echo "[SUCCESS] Decrypted to: $DECRYPTED_FILE"
    
    # Verify gzip integrity
    if gunzip -t "$DECRYPTED_FILE" 2>/dev/null; then
        echo "[SUCCESS] Backup integrity verified"
    else
        echo "[ERROR] Backup corrupted"
        exit 1
    fi
else
    echo "[ERROR] Decryption failed"
    exit 1
fi

echo "[$(date)] Decryption completed"
