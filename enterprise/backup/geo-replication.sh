#!/bin/bash
set -euo pipefail

# RCT-Engine Geo-Replication Backup Script
# Replicates backups to multiple geographic regions

REGIONS=("us-east-1" "eu-west-1" "ap-southeast-1" "sa-east-1")
SOURCE_BUCKET="rct-engine-backups-prod"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "🌍 RCT-Engine Geo-Replication"
echo "=========================================="

# Find latest backup
LATEST_BACKUP=$(aws s3 ls "s3://$SOURCE_BUCKET/backups/" --recursive | sort | tail -n 1 | awk '{print $4}')

if [ -z "$LATEST_BACKUP" ]; then
    echo "❌ No backup found to replicate"
    exit 1
fi

echo "Latest backup: $LATEST_BACKUP"

# Replicate to each region
for region in "${REGIONS[@]}"; do
    DEST_BUCKET="rct-engine-backups-${region}"
    
    echo ""
    echo "Replicating to $region..."
    
    # Create bucket if not exists
    aws s3 mb "s3://$DEST_BUCKET" --region "$region" 2>/dev/null || true
    
    # Enable versioning
    aws s3api put-bucket-versioning \
        --bucket "$DEST_BUCKET" \
        --versioning-configuration Status=Enabled \
        --region "$region" 2>/dev/null || true
    
    # Enable encryption
    aws s3api put-bucket-encryption \
        --bucket "$DEST_BUCKET" \
        --server-side-encryption-configuration '{
            "Rules": [
                {
                    "ApplyServerSideEncryptionByDefault": {
                        "SSEAlgorithm": "AES256"
                    }
                }
            ]
        }' \
        --region "$region" 2>/dev/null || true
    
    # Copy backup
    aws s3 cp "s3://$SOURCE_BUCKET/$LATEST_BACKUP" \
        "s3://$DEST_BUCKET/$LATEST_BACKUP" \
        --region "$region" \
        --storage-class STANDARD_IA
    
    echo "  ✓ Replicated to $region ($DEST_BUCKET)"
done

echo ""
echo "=========================================="
echo "✅ Geo-replication completed"
echo "Backup replicated to ${#REGIONS[@]} regions"
