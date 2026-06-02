#!/bin/bash
# Performance test runner for RCT-Engine

set -e

echo "🚀 RCT-Engine Performance Test Suite"
echo "===================================="

# Check if locust is installed
if ! command -v locust &>/dev/null; then
    echo "Installing locust..."
    pip install locust
fi

# Default values
HOST="${1:-http://localhost:8000}"
USERS="${2:-100}"
SPAWN_RATE="${3:-10}"
RUN_TIME="${4:-5m}"

echo ""
echo "Test Configuration:"
echo "  Target URL: $HOST"
echo "  Concurrent Users: $USERS"
echo "  Spawn Rate: $SPAWN_RATE users/sec"
echo "  Run Duration: $RUN_TIME"
echo ""

# Run the test
locust -f locustfile.py \
    --host="$HOST" \
    --users="$USERS" \
    --spawn-rate="$SPAWN_RATE" \
    --run-time="$RUN_TIME" \
    --headless \
    --only-summary \
    --csv=perf_results_$(date +%Y%m%d_%H%M%S)

echo ""
echo "Performance test completed!"
echo "Results saved to perf_results_*.csv"
