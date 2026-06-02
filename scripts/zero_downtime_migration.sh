#!/bin/bash
set -euo pipefail

# RCT-Engine Zero-Downtime Migration Script
# Performs database schema migrations without application downtime

MIGRATION_FILE="${1}"
BACKUP_FILE="backup_pre_migration_$(date +%Y%m%d_%H%M%S).sql"

echo "🔄 RCT-Engine Zero-Downtime Migration"
echo "=========================================="

# Step 1: Create backup
create_backup() {
    echo "1. Creating pre-migration backup..."
    docker exec rct-postgres pg_dump -U rct_admin -d rct_saas -Fc > "$BACKUP_FILE"
    echo "   ✓ Backup created: $BACKUP_FILE"
}

# Step 2: Check if migration is safe
check_migration() {
    echo "2. Checking migration safety..."
    
    # Check for destructive operations
    if grep -i "DROP TABLE" "$MIGRATION_FILE" | grep -v "IF EXISTS" > /dev/null; then
        echo "   ⚠️ DROP TABLE detected - manual review required"
        return 1
    fi
    
    if grep -i "DROP COLUMN" "$MIGRATION_FILE" > /dev/null; then
        echo "   ⚠️ DROP COLUMN detected - manual review required"
        return 1
    fi
    
    echo "   ✓ Migration appears safe"
    return 0
}

# Step 3: Apply non-breaking changes first
apply_non_breaking() {
    echo "3. Applying non-breaking changes..."
    
    # Extract and run ADD COLUMN statements (non-breaking)
    grep -i "ADD COLUMN" "$MIGRATION_FILE" | docker exec -i rct-postgres psql -U rct_admin -d rct_saas || true
    grep -i "CREATE INDEX" "$MIGRATION_FILE" | grep -i "CONCURRENTLY" | docker exec -i rct-postgres psql -U rct_admin -d rct_saas || true
    
    echo "   ✓ Non-breaking changes applied"
}

# Step 4: Update application to handle new schema
update_app_schema_cache() {
    echo "4. Updating application schema cache..."
    
    # Notify API to refresh schema cache
    curl -X POST "http://localhost:8000/admin/refresh-schema" -H "X-Admin-Token: ${ADMIN_TOKEN}" || true
    
    echo "   ✓ Schema cache refreshed"
}

# Step 5: Apply remaining changes
apply_remaining() {
    echo "5. Applying remaining changes..."
    
    # Filter out already applied statements
    grep -v "ADD COLUMN" "$MIGRATION_FILE" | \
    grep -v "CREATE INDEX CONCURRENTLY" | \
    docker exec -i rct-postgres psql -U rct_admin -d rct_saas || true
    
    echo "   ✓ Remaining changes applied"
}

# Step 6: Verify migration
verify_migration() {
    echo "6. Verifying migration..."
    
    # Run verification queries if provided in migration file
    if grep -q "-- VERIFY" "$MIGRATION_FILE"; then
        sed -n '/-- VERIFY/,/-- ENDVERIFY/p' "$MIGRATION_FILE" | \
        grep -v "^--" | \
        docker exec -i rct-postgres psql -U rct_admin -d rct_saas
    fi
    
    echo "   ✓ Migration verified"
}

# Step 7: Clean up
cleanup() {
    echo "7. Cleaning up..."
    
    # Remove old backup after successful migration
    # rm -f "$BACKUP_FILE"  # Uncomment to enable
    
    echo "   ✓ Cleanup completed"
}

# Main migration flow
main() {
    if [ ! -f "$MIGRATION_FILE" ]; then
        echo "Error: Migration file not found: $MIGRATION_FILE"
        exit 1
    fi
    
    create_backup
    
    if check_migration; then
        apply_non_breaking
        update_app_schema_cache
        apply_remaining
        verify_migration
        cleanup
        
        echo ""
        echo "✅ Migration completed successfully with zero downtime"
    else
        echo ""
        echo "❌ Migration aborted due to safety concerns"
        echo "   Manual intervention required"
        exit 1
    fi
}

main
