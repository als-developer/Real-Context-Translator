#!/bin/bash
set -euo pipefail

# RCT-Engine Auto-Scale Script
# Dynamic scaling based on load metrics

METRICS_URL="http://localhost:9090/api/v1/query"
NAMESPACE="rct-engine"
DEPLOYMENT="rct-api"

# Thresholds
CPU_HIGH_THRESHOLD=70
CPU_LOW_THRESHOLD=30
MEMORY_HIGH_THRESHOLD=80
REQUEST_HIGH_THRESHOLD=500

# Current replicas
CURRENT_REPLICAS=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}')
MIN_REPLICAS=2
MAX_REPLICAS=20

echo "🔄 RCT-Engine Auto-Scale Check"
echo "=========================================="
echo "Current replicas: $CURRENT_REPLICAS"
echo ""

# Get metrics
get_cpu_usage() {
    curl -s "$METRICS_URL?query=sum(rate(container_cpu_usage_seconds_total{namespace=\"$NAMESPACE\",pod=~\"$DEPLOYMENT.*\"}[5m]))" | jq -r '.data.result[0].value[1] // 0'
}

get_memory_usage() {
    curl -s "$METRICS_URL?query=sum(container_memory_working_set_bytes{namespace=\"$NAMESPACE\",pod=~\"$DEPLOYMENT.*\"})/sum(container_spec_memory_limit_bytes{namespace=\"$NAMESPACE\",pod=~\"$DEPLOYMENT.*\"})*100" | jq -r '.data.result[0].value[1] // 0'
}

get_request_rate() {
    curl -s "$METRICS_URL?query=sum(rate(rct_api_requests_total[1m]))" | jq -r '.data.result[0].value[1] // 0'
}

CPU_USAGE=$(get_cpu_usage | cut -d. -f1)
MEMORY_USAGE=$(get_memory_usage | cut -d. -f1)
REQUEST_RATE=$(get_request_rate | cut -d. -f1)

echo "CPU Usage: ${CPU_USAGE}%"
echo "Memory Usage: ${MEMORY_USAGE}%"
echo "Request Rate: ${REQUEST_RATE} req/s"
echo ""

# Scale up logic
if [ "$CPU_USAGE" -gt "$CPU_HIGH_THRESHOLD" ] || [ "$MEMORY_USAGE" -gt "$MEMORY_HIGH_THRESHOLD" ] || [ "$REQUEST_RATE" -gt "$REQUEST_HIGH_THRESHOLD" ]; then
    NEW_REPLICAS=$((CURRENT_REPLICAS + 1))
    
    if [ "$NEW_REPLICAS" -le "$MAX_REPLICAS" ]; then
        echo "📈 Scaling up to $NEW_REPLICAS replicas..."
        kubectl scale deployment "$DEPLOYMENT" -n "$NAMESPACE" --replicas="$NEW_REPLICAS"
        echo "✅ Scale up completed"
    else
        echo "⚠️ Already at maximum replicas ($MAX_REPLICAS)"
    fi

# Scale down logic
elif [ "$CPU_USAGE" -lt "$CPU_LOW_THRESHOLD" ] && [ "$REQUEST_RATE" -lt 100 ] && [ "$CURRENT_REPLICAS" -gt "$MIN_REPLICAS" ]; then
    NEW_REPLICAS=$((CURRENT_REPLICAS - 1))
    
    echo "📉 Scaling down to $NEW_REPLICAS replicas..."
    kubectl scale deployment "$DEPLOYMENT" -n "$NAMESPACE" --replicas="$NEW_REPLICAS"
    echo "✅ Scale down completed"
else
    echo "✅ No scaling needed"
fi

echo ""
echo "=========================================="
echo "Auto-scale check completed"
