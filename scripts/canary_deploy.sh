#!/bin/bash
set -euo pipefail

# RCT-Engine Canary Deployment Script
# Gradually rolls out new version with automated rollback on failure

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_info() { echo -e "${YELLOW}[i]${NC} $1"; }

NEW_VERSION="${1:-latest}"
CANARY_PERCENT="${2:-10}"
MONITOR_TIME="${3:-300}"  # 5 minutes default
ROLLBACK_THRESHOLD="${4:-5}"  # 5% error rate triggers rollback

echo ""
echo "╔═══════════════════════════════════════════════════════════════════════════════╗"
echo "║                    RCT-ENGINE CANARY DEPLOYMENT                               ║"
echo "║                    Version: $NEW_VERSION                                      ║"
echo "║                    Canary: ${CANARY_PERCENT}%                                 ║"
echo "╚═══════════════════════════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Build new version
build_new_version() {
    print_info "Building version $NEW_VERSION..."
    
    docker build -f infrastructure/docker/Dockerfile.api -t "rct-api:${NEW_VERSION}" .
    docker build -f infrastructure/docker/Dockerfile.worker -t "rct-worker:${NEW_VERSION}" .
    
    print_status "Version $NEW_VERSION built"
}

# Step 2: Deploy canary
deploy_canary() {
    print_info "Deploying canary ($CANARY_PERCENT% traffic)..."
    
    if command -v kubectl &>/dev/null; then
        # Kubernetes canary with Istio
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
        subset: v2
      weight: 100
  - route:
    - destination:
        host: rct-api
        subset: v1
      weight: $((100 - CANARY_PERCENT))
    - destination:
        host: rct-api-canary
        subset: v2
      weight: $CANARY_PERCENT
EOF
    else
        # Docker Compose canary
        docker-compose -f infrastructure/docker/docker-compose.yml scale api=$((3 - CANARY_PERCENT/10))
        docker-compose -f infrastructure/docker/docker-compose.yml up -d --scale api-canary=$CANARY_PERCENT
    fi
    
    print_status "Canary deployed"
}

# Step 3: Monitor canary
monitor_canary() {
    print_info "Monitoring canary for ${MONITOR_TIME}s..."
    
    START_TIME=$(date +%s)
    ERROR_COUNT=0
    TOTAL_REQUESTS=0
    
    while [ $(($(date +%s) - START_TIME)) -lt $MONITOR_TIME ]; do
        # Fetch metrics from Prometheus
        ERROR_RATE=$(curl -s "http://localhost:9090/api/v1/query?query=sum(rate(rct_api_errors_total[1m]))" | jq -r '.data.result[0].value[1] // 0')
        REQUEST_RATE=$(curl -s "http://localhost:9090/api/v1/query?query=sum(rate(rct_api_requests_total[1m]))" | jq -r '.data.result[0].value[1] // 1')
        
        if [ -n "$ERROR_RATE" ] && [ -n "$REQUEST_RATE" ]; then
            ERROR_PERCENT=$(echo "scale=2; $ERROR_RATE / $REQUEST_RATE * 100" | bc)
            
            echo -ne "\r   Error rate: ${ERROR_PERCENT}%    "
            
            if (( $(echo "$ERROR_PERCENT > $ROLLBACK_THRESHOLD" | bc -l) )); then
                print_error "\nError rate exceeded threshold!"
                return 1
            fi
        fi
        
        sleep 10
    done
    
    echo ""
    print_status "Canary monitoring passed"
    return 0
}

# Step 4: Rollout full
rollout_full() {
    print_info "Rolling out full deployment..."
    
    if command -v kubectl &>/dev/null; then
        kubectl set image deployment/rct-api rct-api="rct-api:${NEW_VERSION}" -n rct-engine
        kubectl rollout status deployment/rct-api -n rct-engine
    else
        docker-compose -f infrastructure/docker/docker-compose.yml up -d --no-deps --build api
    fi
    
    print_status "Full rollout completed"
}

# Step 5: Rollback on failure
rollback() {
    print_info "Rolling back canary deployment..."
    
    if command -v kubectl &>/dev/null; then
        kubectl delete virtualservice rct-api-canary -n rct-engine 2>/dev/null || true
    else
        docker-compose -f infrastructure/docker/docker-compose.yml down api-canary
    fi
    
    print_status "Rollback completed"
}

# Main canary flow
main() {
    build_new_version
    
    if deploy_canary; then
        if monitor_canary; then
            rollout_full
        else
            rollback
            exit 1
        fi
    else
        print_error "Canary deployment failed"
        exit 1
    fi
    
    echo ""
    print_status "✅ Canary deployment successful!"
}

main
