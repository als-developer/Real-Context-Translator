#!/bin/bash
set -euo pipefail

# RCT-Engine Disaster Recovery Script
# Full system recovery from backup in case of catastrophic failure

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_info() { echo -e "${YELLOW}[i]${NC} $1"; }

BACKUP_SOURCE="${1:-}"
RECOVERY_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="/var/log/rct-dr-recovery-${RECOVERY_TIMESTAMP}.log"

exec > >(tee -a "$LOG_FILE") 2>&1

echo ""
echo "╔═══════════════════════════════════════════════════════════════════════════════╗"
echo "║                    RCT-ENGINE DISASTER RECOVERY                               ║"
echo "║                           ${RECOVERY_TIMESTAMP}                               ║"
echo "╚═══════════════════════════════════════════════════════════════════════════════╝"
echo ""

# Pre-recovery checks
pre_recovery_checks() {
    print_info "Running pre-recovery checks..."
    
    # Check if Docker is running
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running"
        exit 1
    fi
    
    # Check available disk space
    AVAILABLE_SPACE=$(df /var | awk 'NR==2 {print $4}')
    if [ "$AVAILABLE_SPACE" -lt 50000000 ]; then
        print_error "Insufficient disk space (<50GB available)"
        exit 1
    fi
    
    print_status "Pre-recovery checks passed"
}

# Stop all services
stop_services() {
    print_info "Stopping all RCT-Engine services..."
    
    docker-compose -f infrastructure/docker/docker-compose.yml down 2>/dev/null || true
    kubectl scale deployment --all --replicas=0 -n rct-engine 2>/dev/null || true
    
    print_status "All services stopped"
}

# Restore database
restore_database() {
    print_info "Restoring PostgreSQL database..."
    
    # Find latest backup if not specified
    if [ -z "$BACKUP_SOURCE" ]; then
        BACKUP_SOURCE=$(find /var/backups/rct-engine -name "backup-*.tar.gz" -type f | sort | tail -n 1)
    fi
    
    if [ -z "$BACKUP_SOURCE" ] || [ ! -f "$BACKUP_SOURCE" ]; then
        print_error "No backup found at: $BACKUP_SOURCE"
        exit 1
    fi
    
    print_info "Using backup: $BACKUP_SOURCE"
    
    # Extract backup
    TEMP_DIR=$(mktemp -d)
    tar -xzf "$BACKUP_SOURCE" -C "$TEMP_DIR"
    
    # Start PostgreSQL temporarily
    docker run -d --name rct-postgres-dr \
        -e POSTGRES_USER=rct_admin \
        -e POSTGRES_PASSWORD=temp_pass \
        -e POSTGRES_DB=rct_saas \
        -v rct_dr_data:/var/lib/postgresql/data \
        postgres:15-alpine
    
    sleep 10
    
    # Restore database
    docker cp "$TEMP_DIR/postgres.pgdump" rct-postgres-dr:/tmp/restore.pgdump
    docker exec rct-postgres-dr pg_restore -U rct_admin -d rct_saas --clean --if-exists /tmp/restore.pgdump
    
    # Stop temporary PostgreSQL
    docker stop rct-postgres-dr
    docker rm rct-postgres-dr
    
    # Move data to permanent location
    docker volume create rct_postgres_data
    docker run --rm -v rct_dr_data:/from -v rct_postgres_data:/to alpine cp -av /from/. /to/
    
    print_status "Database restored successfully"
}

# Restore Redis
restore_redis() {
    print_info "Restoring Redis data..."
    
    TEMP_DIR=$(mktemp -d)
    tar -xzf "$BACKUP_SOURCE" -C "$TEMP_DIR"
    
    docker run -d --name rct-redis-dr redis:7-alpine
    docker cp "$TEMP_DIR/redis.rdb" rct-redis-dr:/data/dump.rdb
    docker stop rct-redis-dr
    docker rm rct-redis-dr
    
    # Move to persistent volume
    docker volume create rct_redis_data
    docker run --rm -v rct_redis_dr:/data -v rct_redis_data:/to alpine cp -av /data/. /to/
    
    print_status "Redis restored successfully"
}

# Restore configuration
restore_configuration() {
    print_info "Restoring configuration files..."
    
    TEMP_DIR=$(mktemp -d)
    tar -xzf "$BACKUP_SOURCE" -C "$TEMP_DIR"
    
    # Restore Terraform configs
    if [ -d "$TEMP_DIR/terraform" ]; then
        cp -r "$TEMP_DIR/terraform"/* infrastructure/terraform/ 2>/dev/null || true
    fi
    
    # Restore Kubernetes configs
    if [ -d "$TEMP_DIR/kubernetes" ]; then
        cp -r "$TEMP_DIR/kubernetes"/* infrastructure/kubernetes/ 2>/dev/null || true
    fi
    
    # Restore Prometheus configs
    if [ -d "$TEMP_DIR/prometheus" ]; then
        cp -r "$TEMP_DIR/prometheus"/* monitoring/prometheus/ 2>/dev/null || true
    fi
    
    print_status "Configuration restored"
}

# Start services
start_services() {
    print_info "Starting RCT-Engine services..."
    
    docker-compose -f infrastructure/docker/docker-compose.yml up -d
    
    # Wait for services to be healthy
    sleep 30
    
    print_status "Services started"
}

# Verify recovery
verify_recovery() {
    print_info "Verifying recovery..."
    
    # Check API health
    if curl -s -f "http://localhost:8000/health" > /dev/null; then
        print_status "API is healthy"
    else
        print_error "API health check failed"
        exit 1
    fi
    
    # Check database
    if docker exec rct-postgres pg_isready -U rct_admin > /dev/null 2>&1; then
        print_status "Database is ready"
    else
        print_error "Database is not ready"
        exit 1
    fi
    
    # Check Redis
    if docker exec rct-redis redis-cli ping | grep -q "PONG"; then
        print_status "Redis is ready"
    else
        print_error "Redis is not ready"
        exit 1
    fi
    
    print_status "Recovery verification passed"
}

# Cleanup
cleanup() {
    print_info "Cleaning up temporary files..."
    
    docker volume rm rct_dr_data 2>/dev/null || true
    docker volume rm rct_redis_dr 2>/dev/null || true
    
    print_status "Cleanup completed"
}

# Main recovery flow
main() {
    pre_recovery_checks
    stop_services
    restore_database
    restore_redis
    restore_configuration
    start_services
    verify_recovery
    cleanup
    
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                    ✅ DISASTER RECOVERY COMPLETED                             ║"
    echo "║                                                                               ║"
    echo "║    Recovery Log: $LOG_FILE                                                    ║"
    echo "║    Backup Used: $BACKUP_SOURCE                                                ║"
    echo "║    Time Completed: $(date)                                                    ║"
    echo "╚═══════════════════════════════════════════════════════════════════════════════╝"
}

main
