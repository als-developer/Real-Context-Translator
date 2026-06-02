#!/bin/bash
set -euo pipefail

# RCT-Engine Ultimate Production Deployment Script

echo "🚀 RCT-Engine Ultimate Production Deployment"
echo "============================================"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Load environment variables
if [ -f .env.production ]; then
    export $(cat .env.production | grep -v '^#' | xargs)
    print_info "Loaded .env.production"
else
    print_error ".env.production not found"
    exit 1
fi

print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }
print_info() { echo -e "${YELLOW}[i]${NC} $1"; }

# Pre-deployment checks
print_info "Running pre-deployment checks..."

# Check required tools
command -v docker >/dev/null 2>&1 || print_error "Docker not installed"
command -v docker-compose >/dev/null 2>&1 || print_error "Docker Compose not installed"
command -v kubectl >/dev/null 2>&1 || print_info "kubectl not found - skipping K8s deployment"

# Check environment
if [ "$ENVIRONMENT" != "production" ]; then
    print_info "ENVIRONMENT is set to $ENVIRONMENT (not production)"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Deploy with Docker Compose
print_info "Starting Docker Compose deployment..."
cd infrastructure/docker

# Pull latest images
docker-compose pull 2>/dev/null || true

# Start services
docker-compose up -d --build

# Wait for services to be healthy
print_info "Waiting for services to be healthy..."
sleep 10

# Check service health
for service in api worker postgres redis; do
    status=$(docker inspect --format='{{.State.Health.Status}}' "rct-$service" 2>/dev/null || echo "none")
    if [ "$status" = "healthy" ]; then
        print_status "$service is healthy"
    else
        print_error "$service is not healthy (status: $status)"
    fi
done

cd ../..

# Apply database migrations
print_info "Running database migrations..."
docker exec rct-postgres psql -U rct_admin -d rct_saas -f /docker-entrypoint-initdb.d/01-init.sql

# Configure Grafana dashboards
if command -v curl >/dev/null 2>&1; then
    print_info "Configuring Grafana dashboards..."
    curl -s -X POST -H "Content-Type: application/json" \
        -d @monitoring/grafana/datasources.yml \
        http://admin:admin@localhost:3000/api/datasources 2>/dev/null || true
fi

# Verify deployment
print_info "Verifying deployment..."

# Check API health
API_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/health)
if [ "$API_HEALTH" = "200" ]; then
    print_status "API is healthy"
else
    print_error "API health check failed (HTTP $API_HEALTH)"
fi

# Check metrics endpoint
METRICS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9102/metrics)
if [ "$METRICS" = "200" ]; then
    print_status "Billing exporter is healthy"
else
    print_info "Billing exporter not responding (HTTP $METRICS)"
fi

echo ""
echo "============================================"
print_status "Deployment completed successfully!"
echo ""
echo "Service endpoints:"
echo "  - API: https://api.rct-engine.com"
echo "  - Dashboard: https://dashboard.rct-engine.com"
echo "  - Grafana: https://monitoring.rct-engine.com (admin/admin)"
echo "  - Prometheus: https://prometheus.rct-engine.com"
echo ""
echo "Monitoring:"
echo "  - Check logs: docker-compose -f infrastructure/docker/docker-compose.yml logs -f"
echo "  - Check metrics: curl http://localhost:9102/metrics"
echo ""
