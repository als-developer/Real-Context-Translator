#!/bin/bash
set -euo pipefail

# RCT-Engine Performance Benchmark Script

OUTPUT_DIR="./benchmark-results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_FILE="$OUTPUT_DIR/benchmark_$TIMESTAMP.json"

mkdir -p "$OUTPUT_DIR"

echo "📊 RCT-Engine Performance Benchmark"
echo "=========================================="

# Configuration
URL="${1:-http://localhost:8000}"
API_KEY="${2:-test_key}"
REQUESTS="${3:-1000}"
CONCURRENCY="${4:-10}"

# Install dependencies if needed
if ! command -v hey &>/dev/null; then
    echo "Installing hey benchmark tool..."
    go install github.com/rakyll/hey@latest
fi

# Benchmark translation endpoint
run_benchmark() {
    local endpoint=$1
    local name=$2
    
    echo ""
    echo "Running benchmark: $name"
    echo "----------------------------------------"
    
    hey -n "$REQUESTS" -c "$CONCURRENCY" \
        -H "X-API-Key: $API_KEY" \
        -H "Content-Type: application/json" \
        -d '{"source_text":"Hello world test message","source_language":"en","target_country":"KE","target_language":"sw"}' \
        "$URL/api/v1/translate" \
        > "$OUTPUT_DIR/${name}_$TIMESTAMP.txt"
    
    # Extract key metrics
    TOTAL_TIME=$(grep "Total:" "$OUTPUT_DIR/${name}_$TIMESTAMP.txt" | awk '{print $2}')
    REQUESTS_PER_SEC=$(grep "Requests/sec:" "$OUTPUT_DIR/${name}_$TIMESTAMP.txt" | awk '{print $2}')
    LATENCY_AVG=$(grep "Average:" "$OUTPUT_DIR/${name}_$TIMESTAMP.txt" | awk '{print $2}')
    LATENCY_P99=$(grep "99%" "$OUTPUT_DIR/${name}_$TIMESTAMP.txt" | awk '{print $2}')
    
    echo "  Total time: $TOTAL_TIME"
    echo "  Requests/sec: $REQUESTS_PER_SEC"
    echo "  Avg latency: $LATENCY_AVG"
    echo "  P99 latency: $LATENCY_P99"
}

# Run benchmarks
run_benchmark "translate" "translation"

# Generate JSON report
cat > "$OUTPUT_FILE" << EOF
{
  "timestamp": "$TIMESTAMP",
  "config": {
    "url": "$URL",
    "requests": $REQUESTS,
    "concurrency": $CONCURRENCY
  },
  "results": {
    "translation": {
      "total_time": "$TOTAL_TIME",
      "requests_per_sec": $REQUESTS_PER_SEC,
      "avg_latency": "$LATENCY_AVG",
      "p99_latency": "$LATENCY_P99"
    }
  }
}
EOF

echo ""
echo "=========================================="
echo "✅ Benchmark completed"
echo "Results saved to: $OUTPUT_DIR"
echo "=========================================="
