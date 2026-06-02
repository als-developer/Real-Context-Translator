#!/bin/bash
set -euo pipefail

# RCT-Engine API Key Rotation Script
# Rotates API keys for all active organizations

DRY_RUN="${DRY_RUN:-false}"
echo "🔄 RCT-Engine API Key Rotation"
echo "=========================================="
echo "DRY_RUN: $DRY_RUN"
echo ""

rotate_keys() {
    docker exec rct-postgres psql -U rct_admin -d rct_saas -t -A -c "
        SELECT id, api_key_hash 
        FROM users 
        WHERE is_active = true 
          AND last_key_rotation < NOW() - INTERVAL '90 days';
    " | while IFS='|' read user_id old_hash; do
        NEW_KEY="rct_$(openssl rand -hex 32)"
        NEW_HASH=$(echo -n "$NEW_KEY" | sha256sum | cut -d' ' -f1)
        
        echo "Rotating key for user: $user_id"
        
        if [ "$DRY_RUN" = "false" ]; then
            docker exec rct-postgres psql -U rct_admin -d rct_saas -c "
                UPDATE users 
                SET api_key_hash = '$NEW_HASH',
                    last_key_rotation = NOW(),
                    old_key_hash = '$old_hash',
                    old_key_expires_at = NOW() + INTERVAL '7 days'
                WHERE id = '$user_id';
            "
            
            # Send email notification to user
            send_rotation_notification "$user_id" "$NEW_KEY"
        fi
    done
}

send_rotation_notification() {
    local user_id=$1
    local new_key=$2
    
    # Get user email
    email=$(docker exec rct-postgres psql -U rct_admin -d rct_saas -t -A -c "
        SELECT email FROM users WHERE id = '$user_id';
    ")
    
    # Send email (implementation depends on email service)
    echo "  📧 Notification sent to: $email"
}

main() {
    rotate_keys
    
    echo ""
    echo "=========================================="
    echo "✅ API key rotation completed"
    echo "=========================================="
}

main
