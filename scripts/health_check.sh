#!/bin/bash
set -euo pipefail

# RCT-Engine Health Check Script
# Used by Kubernetes and monitoring systems

API_URL="${API_URL:-http://localhost:8000}"
METRICS_URL="${METRICS_URL:-http://localhost:9102}"
TIMEOUT=10

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

check_endpoint() {
    local url=$1
    local name=$2
    local expected_code=${3:-200}
    
    response=$(curl -s -o /dev/null -w "%{http_code}" --max-time $TIMEOUT "$url" 2>/dev/null || echo "000")
    
    if [ "$response" = "$expected_code" ]; then
        echo -e "${GREEN}[✓]${NC} $name is healthy (HTTP $response)"
        return 0
    else
        echo -e "${RED}[✗]${NC} $name failed (HTTP $response)"
        return 1
    fi
}

check_database() {
    if docker exec rct-postgres pg_isready -U rct_admin &>/dev/null; then
        echo -e "${GREEN}[✓]${NC} Database is ready"
        return 0
    else
        echo -e "${RED}[✗]${NC} Database is not ready"
        return 1
    fi
}

check_redis() {
    if docker exec rct-redis redis-cli ping | grep -q "PONG"; then
        echo -e "${GREEN}[✓]${NC} Redis is ready"
        return 0
    else
        echo -e "${RED}[✗]${NC} Redis is not ready"
        return 1
    fi
}

check_cpp_engine() {
    if pgrep -f "rct_core" > /dev/null; then
        echo -e "${GREEN}[✓]${NC} C++ Engine is running"
        return 0
    else
        echo -e "${RED}[✗]${NC} C++ Engine is not running"
        return 1
    fi
}

check_disk_space() {
    usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$usage" -lt 85 ]; then
        echo -e "${GREEN}[✓]${NC} Disk space OK (${usage}% used)"
        return 0
    else
        echo -e "${RED}[✗]${NC} Disk space critical (${usage}% used)"
        return 1
    fi
}

check_memory() {
    available=$(free -m | awk 'NR==2 {print $7}')
    if [ "$available" -gt 500 ]; then
        echo -e "${GREEN}[✓]${NC} Memory OK (${available}MB available)"
        return 0
    else
        echo -e "${RED}[✗]${NC} Memory low (${available}MB available)"
        return 1
    fi
}

main() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "              RCT-Engine Health Check"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    
    failed=0
    
    check_endpoint "$API_URL/health" "API Service" || ((failed++))
    check_endpoint "$METRICS_URL/metrics" "Billing Exporter" || ((failed++))
    check_database || ((failed++))
    check_redis || ((failed++))
    check_cpp_engine || ((failed++))
    check_disk_space || ((failed++))
    check_memory || ((failed++))
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    
    if [ $failed -eq 0 ]; then
        echo -e "${GREEN}✅ ALL SYSTEMS HEALTHY${NC}"
        exit 0
    else
        echo -e "${RED}❌ $failed SYSTEM(S) DEGRADED${NC}"
        exit 1
    fi
}

main
