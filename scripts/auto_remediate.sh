#!/bin/bash
set -euo pipefail

# RCT-Engine Auto-Remediation Script
# Automatically fixes common production issues

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_info() { echo -e "${YELLOW}[i]${NC} $1"; }

REMEDIATION_LOG="/var/log/rct-auto-remediate.log"

# Issue 1: High CPU usage
fix_high_cpu() {
    print_info "Checking CPU usage..."
    
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    
    if (( $(echo "$CPU_USAGE > 80" | bc -l) )); then
        print_info "High CPU detected: ${CPU_USAGE}%"
        
        # Restart offending service
        docker restart rct-worker
        print_status "Restarted worker service"
        
        echo "$(date): High CPU (${CPU_USAGE}%) - restarted worker" >> "$REMEDIATION_LOG"
    fi
}

# Issue 2: Memory leak
fix_memory_leak() {
    print_info "Checking memory usage..."
    
    MEM_USAGE=$(free | awk 'NR==2{printf "%.0f", $3/$2*100}')
    
    if [ "$MEM_USAGE" -gt 85 ]; then
        print_info "High memory usage: ${MEM_USAGE}%"
        
        # Clear Redis cache
        docker exec rct-redis redis-cli FLUSHDB
        print_status "Cleared Redis cache"
        
        # Restart API
        docker restart rct-api
        print_status "Restarted API service"
        
        echo "$(date): High memory (${MEM_USAGE}%) - cleared cache and restarted API" >> "$REMEDIATION_LOG"
    fi
}

# Issue 3: Database connection pool exhausted
fix_db_connections() {
    print_info "Checking database connections..."
    
    CONN_COUNT=$(docker exec rct-postgres psql -U rct_admin -t -A -c "SELECT count(*) FROM pg_stat_activity;")
    
    if [ "$CONN_COUNT" -gt 450 ]; then
        print_info "High connection count: ${CONN_COUNT}"
        
        # Kill idle connections
        docker exec rct-postgres psql -U rct_admin -c "
            SELECT pg_terminate_backend(pid)
            FROM pg_stat_activity
            WHERE state = 'idle'
              AND pid <> pg_backend_pid();
        "
        print_status "Killed idle database connections"
        
        echo "$(date): High connections (${CONN_COUNT}) - killed idle connections" >> "$REMEDIATION_LOG"
    fi
}

# Issue 4: Disk space low
fix_disk_space() {
    print_info "Checking disk space..."
    
    DISK_USAGE=$(df / | awk 'NR==2{print $5}' | sed 's/%//')
    
    if [ "$DISK_USAGE" -gt 85 ]; then
        print_info "Low disk space: ${DISK_USAGE}% used"
        
        # Clean up old logs
        find /var/log/rct_engine/ -name "*.log" -mtime +7 -delete
        docker system prune -f
        
        print_status "Cleaned up old logs and Docker artifacts"
        
        echo "$(date): Low disk space (${DISK_USAGE}%) - cleaned logs" >> "$REMEDIATION_LOG"
    fi
}

# Issue 5: Unhealthy API
fix_unhealthy_api() {
    print_info "Checking API health..."
    
    if ! curl -s -f "http://localhost:8000/health" > /dev/null; then
        print_info "API is unhealthy"
        
        # Restart API
        docker restart rct-api
        sleep 10
        
        if curl -s -f "http://localhost:8000/health" > /dev/null; then
            print_status "API recovered after restart"
        else
            print_error "API still unhealthy - manual intervention required"
        fi
        
        echo "$(date): Unhealthy API - restarted service" >> "$REMEDIATION_LOG"
    fi
}

# Issue 6: Redis connection issues
fix_redis() {
    print_info "Checking Redis connectivity..."
    
    if ! docker exec rct-redis redis-cli ping | grep -q "PONG"; then
        print_info "Redis is not responding"
        
        docker restart rct-redis
        sleep 5
        
        print_status "Redis restarted"
        
        echo "$(date): Redis unresponsive - restarted" >> "$REMEDIATION_LOG"
    fi
}

# Main remediation loop
main() {
    echo "🔄 RCT-Engine Auto-Remediation Run - $(date)" >> "$REMEDIATION_LOG"
    
    fix_high_cpu
    fix_memory_leak
    fix_db_connections
    fix_disk_space
    fix_unhealthy_api
    fix_redis
    
    print_status "Auto-remediation cycle completed"
}

# Run as daemon if --daemon flag
if [ "${1:-}" = "--daemon" ]; then
    while true; do
        main
        sleep 300  # Run every 5 minutes
    done
else
    main
fi
