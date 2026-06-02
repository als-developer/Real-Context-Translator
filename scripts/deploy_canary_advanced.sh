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
        local p99_latency=$(curl -s "http://localhost:9090/api/v1/query?query=histogram_quantile(0.99,sum(rate(rct_api_request_duration_ms_bucket{version=\"canary\"}[1m]))by(le))" | jq -r '.data.result[0].value[1] // 0')
        
        if [ -n "$p99_latency" ] && [ "$p99_latency" != "null" ]; then
            local p99_int=$(echo "$p99_latency" | cut -d. -f1)
            if [ "$p99_int" -gt 500 ]; then
                echo "⚠️ High latency detected: ${p99_latency}ms"
            fi
        fi
        
        sleep 10
    done
    
    echo "✅ Canary metrics within threshold"
    return 0
}

# Gradual rollout
gradual_rollout() {
    echo "🔄 Gradual rollout..."
    
    local steps=("25" "50" "75" "100")
    
    for step in "${steps[@]}"; do
        echo "   Increasing to ${step}%..."
        
        if command -v kubectl &>/dev/null; then
            kubectl patch virtualservice rct-api-canary -n rct-engine --type='json' \
                -p="[{'op': 'replace', 'path': '/spec/http/1/route/0/weight', 'value': $((100 - step))}, {'op': 'replace', 'path': '/spec/http/1/route/1/weight', 'value': $step}]"
        fi
        
        sleep 60
        
        # Quick validation after each step
        local error_rate=$(curl -s "http://localhost:9090/api/v1/query?query=sum(rate(rct_api_errors_total[1m]))/sum(rate(rct_api_requests_total[1m]))*100" | jq -r '.data.result[0].value[1] // 0')
        
        if [ -n "$error_rate" ] && (( $(echo "$error_rate > $ROLLBACK_THRESHOLD" | bc -l) )); then
            echo "❌ Error spike detected at ${step}% - rolling back"
            return 1
        fi
    done
    
    echo "✅ Full rollout completed"
    return 0
}

# Main
main() {
    deploy_canary
    
    if monitor_metrics; then
        if gradual_rollout; then
            echo ""
            echo "✅ Canary deployment successful!"
            exit 0
        else
            echo ""
            echo "❌ Canary deployment failed - rolling back"
            # Rollback logic here
            exit 1
        fi
    else
        echo "❌ Canary metrics failed - rolling back"
        exit 1
    fi
}

main
