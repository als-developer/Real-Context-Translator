#!/bin/bash
set -euo pipefail

# RCT-Engine Stripe Subscription Sync Script

echo "🔄 Syncing Stripe Subscriptions"
echo "=========================================="

STRIPE_SECRET_KEY="${STRIPE_SECRET_KEY:-}"
if [ -z "$STRIPE_SECRET_KEY" ]; then
    echo "Error: STRIPE_SECRET_KEY not set"
    exit 1
fi

# Fetch all active subscriptions from Stripe
fetch_subscriptions() {
    echo "1. Fetching subscriptions from Stripe..."
    
    curl -s -X GET "https://api.stripe.com/v1/subscriptions?status=active&limit=100" \
        -H "Authorization: Bearer $STRIPE_SECRET_KEY" \
        > /tmp/stripe_subs.json
    
    echo "   ✓ Subscriptions fetched"
}

# Sync to local database
sync_to_database() {
    echo "2. Syncing to local database..."
    
    jq -c '.data[]' /tmp/stripe_subs.json | while read sub; do
        CUSTOMER_ID=$(echo "$sub" | jq -r '.customer')
        STATUS=$(echo "$sub" | jq -r '.status')
        CURRENT_PERIOD_END=$(echo "$sub" | jq -r '.current_period_end')
        
        docker exec rct-postgres psql -U rct_admin -d rct_saas -c "
            UPDATE organizations 
            SET subscription_status = '$STATUS',
                subscription_end_date = to_timestamp($CURRENT_PERIOD_END),
                updated_at = NOW()
            WHERE stripe_customer_id = '$CUSTOMER_ID';
        " 2>/dev/null || true
    done
    
    echo "   ✓ Subscriptions synced"
}

# Update usage-based billing data
sync_usage() {
    echo "3. Syncing usage data to Stripe..."
    
    # Get usage from local database
    docker exec rct-postgres psql -U rct_admin -d rct_saas -t -A -F',' -c "
        SELECT organization_id, SUM(word_count) as total_words
        FROM metered_usage_logs
        WHERE stripe_synced = false
        GROUP BY organization_id;
    " | while IFS=',' read org_id word_count; do
        if [ -n "$org_id" ] && [ "$word_count" -gt 0 ]; then
            # Get subscription item ID
            SUB_ITEM_ID=$(docker exec rct-postgres psql -U rct_admin -d rct_saas -t -A -c "
                SELECT stripe_subscription_item_id 
                FROM organizations 
                WHERE id = '$org_id';
            ")
            
            if [ -n "$SUB_ITEM_ID" ]; then
                curl -s -X POST "https://api.stripe.com/v1/subscription_items/$SUB_ITEM_ID/usage_records" \
                    -H "Authorization: Bearer $STRIPE_SECRET_KEY" \
                    -d "quantity=$word_count" \
                    -d "timestamp=now" \
                    -d "action=increment" > /dev/null
                
                # Mark as synced
                docker exec rct-postgres psql -U rct_admin -d rct_saas -c "
                    UPDATE metered_usage_logs 
                    SET stripe_synced = true, stripe_synced_at = NOW()
                    WHERE organization_id = '$org_id' AND stripe_synced = false;
                "
            fi
        fi
    done
    
    echo "   ✓ Usage data synced"
}

main() {
    fetch_subscriptions
    sync_to_database
    sync_usage
    
    echo ""
    echo "=========================================="
    echo "✅ Subscription sync completed"
    echo "=========================================="
}

main
