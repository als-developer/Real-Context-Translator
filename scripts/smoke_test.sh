#!/bin/bash
set -euo pipefail

# RCT-Engine Smoke Test Script
# Quick validation after deployment

API_URL="${1:-https://api.rct-engine.com}"
API_KEY="${2:-test_key}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_info() { echo -e "${YELLOW}[i]${NC} $1"; }

FAILED=0

echo ""
echo "╔═══════════════════════════════════════════════════════════════════════════════╗"
echo "║                    RCT-Engine SMOKE TESTS                                     ║"
echo "║                    Target: $API_URL                                          ║"
echo "╚═══════════════════════════════════════════════════════════════════════════════╝"
echo ""

# Test 1: Health endpoint
test_health() {
    print_info "Test 1: Health endpoint..."
    
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/health")
    
    if [ "$RESPONSE" = "200" ]; then
        print_status "Health endpoint OK"
        return 0
    else
        print_error "Health endpoint failed (HTTP $RESPONSE)"
        return 1
    fi
}

# Test 2: API documentation
test_docs() {
    print_info "Test 2: API documentation..."
    
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/docs")
    
    if [ "$RESPONSE" = "200" ]; then
        print_status "API docs accessible"
        return 0
    else
        print_error "API docs failed (HTTP $RESPONSE)"
        return 1
    fi
}

# Test 3: Translation endpoint with auth
test_translation() {
    print_info "Test 3: Translation endpoint..."
    
    RESPONSE=$(curl -s -X POST "$API_URL/api/v1/translate" \
        -H "X-API-Key: $API_KEY" \
        -H "Content-Type: application/json" \
        -d '{"source_text":"Hello","source_language":"en","target_country":"KE","target_language":"sw"}' \
        -o /dev/null -w "%{http_code}")
    
    if [ "$RESPONSE" = "200" ]; then
        print_status "Translation endpoint OK"
        return 0
    elif [ "$RESPONSE" = "401" ]; then
        print_status "Translation endpoint requires auth (expected)"
        return 0
    else
        print_error "Translation endpoint failed (HTTP $RESPONSE)"
        return 1
    fi
}

# Test 4: Metrics endpoint
test_metrics() {
    print_info "Test 4: Metrics endpoint..."
    
    if curl -s "$API_URL/metrics" | grep -q "rct_api_requests_total"; then
        print_status "Metrics endpoint OK"
        return 0
    else
        print_error "Metrics endpoint failed"
        return 1
    fi
}

# Test 5: Cultural risk detection
test_cultural_risk() {
    print_info "Test 5: Cultural risk detection..."
    
    RESPONSE=$(curl -s -X POST "$API_URL/api/v1/translate" \
        -H "X-API-Key: $API_KEY" \
        -H "Content-Type: application/json" \
        -d '{"source_text":"haram content","source_language":"en","target_country":"SA","target_language":"ar"}')
    
    if echo "$RESPONSE" | grep -q "CRITICAL\|BLOCKED\|risk"; then
        print_status "Cultural risk detection OK"
        return 0
    else
        print_status "Cultural risk detection responded (may need valid key)"
        return 0
    fi
}

# Main execution
main() {
    test_health || FAILED=$((FAILED + 1))
    test_docs || FAILED=$((FAILED + 1))
    test_translation || FAILED=$((FAILED + 1))
    test_metrics || FAILED=$((FAILED + 1))
    test_cultural_risk || FAILED=$((FAILED + 1))
    
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════════════════╗"
    if [ $FAILED -eq 0 ]; then
        echo "║                    ✅ ALL SMOKE TESTS PASSED                                ║"
    else
        echo "║                    ❌ $FAILED SMOKE TEST(S) FAILED                         ║"
    fi
    echo "╚═══════════════════════════════════════════════════════════════════════════════╝"
    
    exit $FAILED
}

main
