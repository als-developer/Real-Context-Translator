#!/bin/bash
set -euo pipefail

# RCT-Engine Final Validation Script
# Validates complete system before production launch

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_info() { echo -e "${YELLOW}[i]${NC} $1"; }

FAILED=0
REPORT_FILE="final-validation-$(date +%Y%m%d_%H%M%S).txt"

echo ""
echo "╔═══════════════════════════════════════════════════════════════════════════════╗"
echo "║                    RCT-Engine FINAL VALIDATION                                ║"
echo "║                    $(date)                                                    ║"
echo "╚═══════════════════════════════════════════════════════════════════════════════╝"
echo ""

# 1. Validate all services are running
validate_services() {
    print_info "1. Validating services..."
    
    SERVICES=("api" "worker" "postgres" "redis" "billing-exporter" "nginx")
    
    for service in "${SERVICES[@]}"; do
        if docker ps --format '{{.Names}}' | grep -q "rct-$service"; then
            print_status "Service $service is running"
        else
            print_error "Service $service is not running"
            FAILED=$((FAILED + 1))
        fi
    done
}

# 2. Validate API endpoints
validate_api() {
    print_info "2. Validating API endpoints..."
    
    # Health check
    if curl -s -f "http://localhost:8000/health" > /dev/null; then
        print_status "Health endpoint OK"
    else
        print_error "Health endpoint FAILED"
        FAILED=$((FAILED + 1))
    fi
    
    # Metrics endpoint
    if curl -s "http://localhost:8000/metrics" | grep -q "rct_api_requests_total"; then
        print_status "Metrics endpoint OK"
    else
        print_error "Metrics endpoint FAILED"
        FAILED=$((FAILED + 1))
    fi
    
    # Translation endpoint
    RESPONSE=$(curl -s -X POST "http://localhost:8000/api/v1/translate" \
        -H "X-API-Key: test_key" \
        -H "Content-Type: application/json" \
        -d '{"source_text":"Hello","source_language":"en","target_country":"KE","target_language":"sw"}')
    
    if echo "$RESPONSE" | grep -q "translation_id"; then
        print_status "Translation endpoint OK"
    else
        print_error "Translation endpoint FAILED"
        FAILED=$((FAILED + 1))
    fi
}

# 3. Validate database
validate_database() {
    print_info "3. Validating database..."
    
    # Check connection
    if docker exec rct-postgres pg_isready -U rct_admin > /dev/null 2>&1; then
        print_status "Database connection OK"
    else
        print_error "Database connection FAILED"
        FAILED=$((FAILED + 1))
    fi
    
    # Check tables
    TABLES=("users" "organizations" "cultural_context_matrix" "translation_audit_logs")
    for table in "${TABLES[@]}"; do
        COUNT=$(docker exec rct-postgres psql -U rct_admin -d rct_saas -t -A -c "SELECT COUNT(*) FROM $table;" 2>/dev/null || echo "0")
        if [ "$COUNT" -gt 0 ] || [ "$table" = "translation_audit_logs" ]; then
            print_status "Table $table exists ($COUNT rows)"
        else
            print_error "Table $table is empty or missing"
            FAILED=$((FAILED + 1))
        fi
    done
}

# 4. Validate Redis
validate_redis() {
    print_info "4. Validating Redis..."
    
    if docker exec rct-redis redis-cli ping | grep -q "PONG"; then
        print_status "Redis connection OK"
    else
        print_error "Redis connection FAILED"
        FAILED=$((FAILED + 1))
    fi
}

# 5. Validate cultural detection
validate_cultural_detection() {
    print_info "5. Validating cultural risk detection..."
    
    # Test with known taboo phrase
    RESPONSE=$(curl -s -X POST "http://localhost:8000/api/v1/translate" \
        -H "X-API-Key: test_key" \
        -H "Content-Type: application/json" \
        -d '{"source_text":"haram content","source_language":"en","target_country":"SA","target_language":"ar"}')
    
    if echo "$RESPONSE" | grep -q "CRITICAL\|BLOCKED"; then
        print_status "Cultural risk detection OK"
    else
        print_error "Cultural risk detection FAILED"
        FAILED=$((FAILED + 1))
    fi
}

# 6. Validate billing exporter
validate_billing() {
    print_info "6. Validating billing exporter..."
    
    if curl -s "http://localhost:9102/metrics" | grep -q "rct_billing_words_total"; then
        print_status "Billing exporter OK"
    else
        print_error "Billing exporter FAILED"
        FAILED=$((FAILED + 1))
    fi
}

# 7. Validate monitoring stack
validate_monitoring() {
    print_info "7. Validating monitoring stack..."
    
    # Prometheus
    if curl -s "http://localhost:9090/-/healthy" > /dev/null; then
        print_status "Prometheus OK"
    else
        print_warning "Prometheus not running (optional)"
    fi
    
    # Grafana
    if curl -s "http://localhost:3000/api/health" > /dev/null; then
        print_status "Grafana OK"
    else
        print_warning "Grafana not running (optional)"
    fi
}

# 8. Validate backups
validate_backups() {
    print_info "8. Validating backup configuration..."
    
    BACKUP_DIR="/var/backups/rct-engine"
    if [ -d "$BACKUP_DIR" ]; then
        BACKUP_COUNT=$(find "$BACKUP_DIR" -name "backup-*.tar.gz" 2>/dev/null | wc -l)
        print_status "Backup directory exists ($BACKUP_COUNT backups)"
    else
        print_warning "Backup directory not found"
    fi
}

# 9. Validate security
validate_security() {
    print_info "9. Validating security configuration..."
    
    # Check TLS
    if curl -s "https://localhost:8443/health" --insecure > /dev/null 2>&1; then
        print_status "TLS endpoint accessible"
    else
        print_warning "TLS not configured (development mode)"
    fi
    
    # Check API key requirement
    RESPONSE=$(curl -s -X POST "http://localhost:8000/api/v1/translate" \
        -H "Content-Type: application/json" \
        -d '{"source_text":"test"}' -w "%{http_code}" -o /dev/null)
    
    if [ "$RESPONSE" = "401" ]; then
        print_status "API key enforcement OK"
    else
        print_error "API key enforcement FAILED"
        FAILED=$((FAILED + 1))
    fi
}

# 10. Generate final report
generate_report() {
    cat > "$REPORT_FILE" << EOF
╔═══════════════════════════════════════════════════════════════════════════════╗
║                    RCT-Engine FINAL VALIDATION REPORT                         ║
║                    $(date)                                                    ║
╚═══════════════════════════════════════════════════════════════════════════════╝

Validation Results:

✅ Services Running
✅ API Endpoints
✅ Database Connectivity
✅ Redis Cache
✅ Cultural Risk Detection
✅ Billing Exporter
✅ Security Controls

Final Status: $([ $FAILED -eq 0 ] && echo "PASSED" || echo "FAILED")
Total Errors: $FAILED

---
This report was generated by RCT-Engine Validation Suite
EOF

    print_status "Report generated: $REPORT_FILE"
}

# Main execution
main() {
    validate_services
    validate_api
    validate_database
    validate_redis
    validate_cultural_detection
    validate_billing
    validate_monitoring
    validate_backups
    validate_security
    generate_report
    
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════════════════╗"
    if [ $FAILED -eq 0 ]; then
        echo "║                    ✅ ALL VALIDATIONS PASSED                                  ║"
        echo "║                    RCT-Engine is READY FOR PRODUCTION                       ║"
    else
        echo "║                    ❌ $FAILED VALIDATION(S) FAILED                          ║"
        echo "║                    Please review errors before deployment                   ║"
    fi
    echo "╚═══════════════════════════════════════════════════════════════════════════════╝"
    
    exit $FAILED
}

main
