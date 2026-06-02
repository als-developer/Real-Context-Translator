#!/bin/bash
set -euo pipefail

# RCT-Engine Data Cleanup Script
# Purges old data based on retention policies

RETENTION_DAYS="${1:-90}"
DRY_RUN="${DRY_RUN:-false}"

echo "🧹 RCT-Engine Data Cleanup (Retention: $RETENTION_DAYS days)"
echo "=========================================="
echo "DRY_RUN: $DRY_RUN"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

cleanup_translation_logs() {
    echo "1. Cleaning up translation audit logs..."
    
    if [ "$DRY_RUN" = "true" ]; then
        docker exec rct-postgres psql -U rct_admin -d rct_saas -c "
            SELECT COUNT(*) as would_delete 
            FROM translation_audit_logs 
            WHERE created_at < NOW() - INTERVAL '$RETENTION_DAYS days';
        "
    else
        docker exec rct-postgres psql -U rct_admin -d rct_saas -c "
            DELETE FROM translation_audit_logs 
            WHERE created_at < NOW() - INTERVAL '$RETENTION_DAYS days';
            
            VACUUM ANALYZE translation_audit_logs;
        "
        echo -e "${GREEN}   ✓ Translation logs cleaned${NC}"
    fi
}

cleanup_metering_logs() {
    echo "2. Cleaning up metering logs..."
    
    if [ "$DRY_RUN" = "true" ]; then
        docker exec rct-postgres psql -U rct_admin -d rct_saas -c "
            SELECT COUNT(*) as would_delete 
            FROM metered_usage_logs 
            WHERE recorded_at < NOW() - INTERVAL '$RETENTION_DAYS days';
        "
    else
        docker exec rct-postgres psql -U rct_admin -d rct_saas -c "
            DELETE FROM metered_usage_logs 
            WHERE recorded_at < NOW() - INTERVAL '$RETENTION_DAYS days';
            
            VACUUM ANALYZE metered_usage_logs;
        "
        echo -e "${GREEN}   ✓ Metering logs cleaned${NC}"
    fi
}

cleanup_redis_cache() {
    echo "3. Cleaning up Redis cache..."
    
    if [ "$DRY_RUN" = "true" ]; then
        echo "   Would delete expired cache keys"
    else
        # Delete translation cache older than 7 days
        docker exec rct-redis redis-cli EVAL "
            local keys = redis.call('keys', 'translation:*')
            local deleted = 0
            for i, key in ipairs(keys) do
                local ttl = redis.call('ttl', key)
                if ttl == -1 then
                    redis.call('del', key)
                    deleted = deleted + 1
                end
            end
            return deleted
        " 0
        echo -e "${GREEN}   ✓ Redis cache cleaned${NC}"
    fi
}

cleanup_log_files() {
    echo "4. Cleaning up log files..."
    
    if [ "$DRY_RUN" = "true" ]; then
        find /var/log/rct_engine/ -name "*.log" -mtime +$RETENTION_DAYS -ls 2>/dev/null || echo "   No old logs found"
    else
        find /var/log/rct_engine/ -name "*.log" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
        find /var/log/rct_engine/ -name "*.log.*" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
        echo -e "${GREEN}   ✓ Log files cleaned${NC}"
    fi
}

cleanup_docker_artifacts() {
    echo "5. Cleaning up Docker artifacts..."
    
    if [ "$DRY_RUN" = "true" ]; then
        docker system df
    else
        docker system prune -f --filter "until=24h"
        docker volume prune -f
        echo -e "${GREEN}   ✓ Docker artifacts cleaned${NC}"
    fi
}

main() {
    echo ""
    echo "Starting data cleanup process..."
    echo ""
    
    cleanup_translation_logs
    cleanup_metering_logs
    cleanup_redis_cache
    cleanup_log_files
    cleanup_docker_artifacts
    
    echo ""
    echo "=========================================="
    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${YELLOW}⚠️  DRY RUN completed - no changes made${NC}"
    else
        echo -e "${GREEN}✅ Data cleanup completed successfully${NC}"
    fi
    echo "=========================================="
}

main
