#!/bin/bash
set -euo pipefail

# RCT-Engine Ultimate Build Script
# This script builds all components: Backend, Frontend, C++ Engine, Go Exporter

echo "🔨 RCT-Engine Ultimate Build System"
echo "===================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[i]${NC} $1"
}

# Build directory
BUILD_DIR="build"
mkdir -p $BUILD_DIR

# 1. Build C++ AVX-512 Engine
print_info "Building C++ AVX-512 Engine..."
cd backend/cpp_engine
g++ -O3 -std=c++23 -march=native -mavx512f -mavx512dq \
    -pthread -flto -fno-exceptions -fno-rtti \
    -o ../../$BUILD_DIR/rct_core rct_core.cpp 2>/dev/null
if [ -f "../../$BUILD_DIR/rct_core" ]; then
    print_status "C++ Engine built successfully"
else
    print_error "C++ Engine build failed (AVX-512 may not be supported)"
    # Build without AVX-512 as fallback
    g++ -O3 -std=c++23 -pthread -o ../../$BUILD_DIR/rct_core rct_core.cpp
    print_info "Fallback build completed (no AVX-512)"
fi
cd ../..

# 2. Build Go Billing Exporter
print_info "Building Go Billing Exporter..."
cd backend/go_exporter
go mod download
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-s -w" \
    -o ../../$BUILD_DIR/rct_exporter .
cd ../..
if [ -f "$BUILD_DIR/rct_exporter" ]; then
    print_status "Go Exporter built successfully"
else
    print_error "Go Exporter build failed"
fi

# 3. Build Python API Docker Image
print_info "Building Python API Docker image..."
docker build -f infrastructure/docker/Dockerfile.api -t rct-api:latest . 2>/dev/null
print_status "API Docker image built"

# 4. Build Worker Docker Image
print_info "Building Worker Docker image..."
docker build -f infrastructure/docker/Dockerfile.worker -t rct-worker:latest . 2>/dev/null
print_status "Worker Docker image built"

# 5. Build Frontend
print_info "Building Frontend application..."
cd frontend/web
npm install --silent 2>/dev/null
npm run build --silent 2>/dev/null
cd ../..
if [ -d "frontend/web/dist" ]; then
    print_status "Frontend built successfully"
else
    print_error "Frontend build failed"
fi

# 6. Run database migrations
print_info "Running database migrations..."
docker-compose -f infrastructure/docker/docker-compose.yml up -d postgres redis
sleep 5
docker exec -i rct-postgres psql -U rct_admin -d rct_saas < database/migrations/001_init.sql 2>/dev/null
docker exec -i rct-postgres psql -U rct_admin -d rct_saas < database/migrations/002_billing.sql 2>/dev/null
docker exec -i rct-postgres psql -U rct_admin -d rct_saas < database/migrations/003_cultural_seed.sql 2>/dev/null
print_status "Database migrations completed"

echo ""
echo "===================================="
echo -e "${GREEN}✅ Build completed successfully!${NC}"
echo ""
echo "Artifacts:"
echo "  - C++ Engine: build/rct_core"
echo "  - Go Exporter: build/rct_exporter"
echo "  - API Docker: rct-api:latest"
echo "  - Worker Docker: rct-worker:latest"
echo "  - Frontend: frontend/web/dist"
echo ""
echo "Run './scripts/deploy_prod.sh' to deploy"
