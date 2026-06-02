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
       
