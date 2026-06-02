#!/bin/bash
set -euo pipefail

# Advanced Canary Deployment with Automated Analysis

CANARY_PERCENT="${1:-10}"
ANALYSIS_DURATION="${2:-300}"
ROLLBACK_THRESHOLD="${3:-5}"

echo "🚀 RCT-Engine Advanced Canary Deployment"
echo "=========================================="
echo "Canary Traffic: ${CANARY_PERCENT}%"
echo "Analysis Duration: ${ANALYSIS_DURATION}s"
echo "Error Threshold: ${ROLLBACK_THRESHOLD}%"
echo ""

# Deploy canary
deploy_canary() {
    echo "📦 Deploying canary version..."
    
    if command -v kubectl &>/dev/null; then
        cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: rct-api-canary
  namespace: rct-engine
spec:
  hosts:
  - rct-api
  http:
  - match:
    - headers:
        x-canary:
          exact: "true"
    route:
    - destination:
        host: rct-api-canary
        weight: 100
  - route:
    - destination:
        host: rct-api
        weight: $((100 - CANARY_PERCENT))
    - destination:
        host: rct-api-canary
        weight: $CANARY_PERCENT
EOF
    fi
    
    echo "✅ Canary deployed"
}

# Monitor metrics
monitor_metrics() {
    echo "📊 Monitoring metrics for ${ANALYSIS_DURATION}s..."
    
    local start_time=$(date +%s)
    local error_count=0
    local total_requests=0
    
    while [ $(($(date +%s) - start_time)) -lt $ANALYSIS_DURATION ]; do
        # Fetch error rate from Prometheus
        local error_rate=$(curl -s "http://localhost:9090/api/v1/query?query=sum(rate(rct_api_errors_total{version=\"canary\"}[1m]))/sum(rate(rct_api_requests_total{version=\"canary\"}[1m]))*100" | jq -r '.data.result[0].value[1] // 0')
        
        if [ -n "$error_rate" ] && [ "$error_rate" != "null" ]; then
            local error_rate_int=$(echo "$error_rate" | cut -d. -f1)
            echo "   Current error rate: ${error_rate}%"
            
            if [ "$error_rate_int" -gt "$ROLLBACK_THRESHOLD" ]; then
                echo "❌ Error rate ${error_rate}% exceeds threshold ${ROLLBACK_THRESHOLD}%"
                return 1
            fi
        fi
        
        # Check latency
        local p99_latency=$(curl -s "http://localhost:9090/api/v1
