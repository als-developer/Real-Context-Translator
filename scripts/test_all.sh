#!/bin/bash
set -euo pipefail

# RCT-Engine Ultimate Test Runner
# Runs all test suites and generates reports

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_info() { echo -e "${YELLOW}[i]${NC} $1"; }

REPORT_DIR="test-reports"
mkdir -p "$REPORT_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        RCT-Engine Ultimate Test Suite                       ║"
echo "║                    Version 3.0.0                            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# 1. Unit Tests
print_info "Running Unit Tests..."
pytest tests/unit -v \
    --cov=backend \
    --cov-report=html:$REPORT_DIR/coverage \
    --cov-report=xml:$REPORT_DIR/coverage.xml \
    --junitxml=$REPORT_DIR/junit-unit.xml
print_status "Unit tests completed"

# 2. Integration Tests
print_info "Running Integration Tests..."
docker-compose -f infrastructure/docker/docker-compose.yml up -d postgres redis
sleep 5
pytest tests/integration -v --junitxml=$REPORT_DIR/junit-integration.xml
docker-compose -f infrastructure/docker/docker-compose.yml down
print_status "Integration tests completed"

# 3. C++ Tests
print_info "Running C++ Tests..."
cd backend/cpp_engine
make test > ../../$REPORT_DIR/cpp-tests.log 2>&1
cd ../..
print_status "C++ tests completed"

# 4. Security Scan
print_info "Running Security Scan..."
bandit -r backend/ -f json -o $REPORT_DIR/bandit-report.json
safety check -r backend/requirements.txt --json > $REPORT_DIR/safety-report.json
print_status "Security scan completed"

# 5. Performance Tests (optional)
if [ "${RUN_PERF_TESTS:-false}" = "true" ]; then
    print_info "Running Performance Tests..."
    ./tests/performance/run_perf_test.sh http://localhost:8000 50 10 5m
    print_status "Performance tests completed"
fi

# 6. E2E Tests
print_info "Running E2E Tests..."
cd frontend/web
npm run test:e2e
cd ../..
print_status "E2E tests completed"

# 7. Generate Summary Report
print_info "Generating summary report..."
cat > "$REPORT_DIR/summary-$TIMESTAMP.md" << EOF
# RCT-Engine Test Summary
**Date:** $(date)
**Commit:** $(git rev-parse HEAD)
**Branch:** $(git branch --show-current)

## Test Results

| Test Suite | Status |
|------------|--------|
| Unit Tests | ✅ Passed |
| Integration Tests | ✅ Passed |
| C++ Tests | ✅ Passed |
| Security Scan | ✅ Passed |
| E2E Tests | ✅ Passed |

## Coverage Report

$(pytest --cov=backend --cov-report=term 2>/dev/null | grep -A 10 "TOTAL" || echo "Coverage data available in $REPORT_DIR/coverage/")

## Artifacts

- Coverage Report: \`$REPORT_DIR/coverage/\`
- JUnit Reports: \`$REPORT_DIR/junit-*.xml\`
- Security Reports: \`$REPORT_DIR/*-report.json\`
EOF

print_status "Summary report generated: $REPORT_DIR/summary-$TIMESTAMP.md"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    ✅ All Tests Passed!                      ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Reports saved to: $REPORT_DIR/"
