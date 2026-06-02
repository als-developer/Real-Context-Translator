#!/bin/bash
set -euo pipefail

# RCT-Engine Deployment Validation Script
# Validates all components after deployment

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_info() { echo -e "${YELLOW}[i]${NC} $1"; }

FAILED=0

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           RCT-Engine Deployment Validation                  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# 1. Validate API service
print_info "Validating API service..."
if curl -s -f "http://localhost:8000/health" > /dev/null; then
    print_status "API service is healthy"
else
    print_error "API service is not responding"
    FAILED=$((FAILED + 1))
fi

# 2. Validate database connectivity
print_info "Validating database connectivity..."
if docker exec rct-postgres pg_isready -U rct_admin > /dev/null 2>&1; then
    print_status "Database is ready"
else
    print_error "Database is not ready"
    FAILED=$((FAILED + 1))
fi

# 3. Validate Redis connectivity
print_info "Validating Redis connectivity..."
if docker exec rct-redis redis-cli ping | grep -q "PONG"; then
    print_status "Redis is ready"
else
    print_error "Redis is not ready"
    FAILED=$((FAILED + 1))
fi

# 4. Validate cultural matrix data
print_info "Validating cultural matrix data..."
COUNT=$(docker exec rct-postgres psql -U rct_admin -d rct_saas -t -A -c "SELECT COUNT(*) FROM cultural_context_matrix;")
if [ "$COUNT" -gt 0 ]; then
    print_status "Cultural matrix has $COUNT entries"
else
    print_error "Cultural matrix is empty"
    FAILED=$((FAILED + 1))
fi

# 5. Validate billing exporter
print_info "Validating billing exporter..."
if curl -s -f "http://localhost:9102/metrics" | grep -q "rct_"; then
    print_status "Billing exporter is healthy"
else
    print_error "Billing exporter is not responding"
    FAILED=$((FAILED + 1))
fi

# 6. Validate C++ engine
print_info "Validating C++ engine..."
if pgrep -f "rct_core" > /dev/null; then
    print_status "C++ engine is running"
else
    print_info "C++ engine not running (AVX-512 may not be supported)"
fi

# 7. Test translation endpoint
print_info "Testing translation endpoint..."
RESPONSE=$(curl -s -X POST "http://localhost:8000/api/v1/translate" \
    -H "X-API-Key: test_key" \
    -H "Content-Type: application/json" \
    -d '{"source_text":"Hello","source_language":"en","target_country":"KE","target_language":"sw"}' 2>/dev/null)

if echo "$RESPONSE" | grep -q "translation_id"; then
    print_status "Translation endpoint is working"
else
    print_error "Translation endpoint failed"
    FAILED=$((FAILED + 1))
fi

# 8. Validate metrics endpoint
print_info "Validating Prometheus metrics..."
if curl -s "http://localhost:8000/metrics" | grep -q "rct_api_requests_total"; then
    print_status "Prometheus metrics are exposed"
else
    print_error "Prometheus metrics not found"
    FAILED=$((FAILED + 1))
fi

# 9. Validate backup directory
print_info "Validating backup configuration..."
if [ -d "/var/backups/rct_db" ]; then
    print_status "Backup directory exists"
else
    print_info "Backup directory not found (may not be configured)"
fi

# 10. Validate log rotation
print_info "Validating log configuration..."
if [ -f "/etc/logrotate.d/rct-engine" ]; then
    print_status "Logrotate configuration exists"
else
    print_info "Logrotate not configured"
fi

echo ""
echo "=========================================="
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ ALL VALIDATIONS PASSED${NC}"
    exit 0
else
    echo -e "${RED}❌ $FAILED VALIDATION(S) FAILED${NC}"
    exit 1
fi
echo "=========================================="
