#!/bin/bash
set -euo pipefail

# RCT-Engine Distributed Load Testing Script
# Runs load tests from multiple cloud regions

REGIONS=("us-east-1" "eu-west-1" "ap-southeast-1" "sa-east-1")
DURATION="${1:-10m}"
USERS="${2:-100}"
TARGET_URL="${3:-https://api.rct-engine.com}"

echo "🌍 RCT-Engine Distributed Load Test"
echo "=========================================="
echo "Regions: ${REGIONS[*]}"
echo "Duration: $DURATION"
echo "Users per region: $USERS"
echo "Target: $TARGET_URL"
echo ""

# Deploy load generator to each region
for region in "${REGIONS[@]}"; do
    echo "Deploying load generator to $region..."
    
    aws ecs run-task \
        --cluster rct-load-test \
        --task-definition locust-worker \
        --count 1 \
        --launch-type FARGATE \
        --network-configuration "awsvpcConfiguration={subnets=[subnet-xxx],securityGroups=[sg-xxx],assignPublicIp=ENABLED}" \
        --overrides "{
            \"containerOverrides\": [{
                \"name\": \"locust\",
                \"environment\": [
                    {\"name\": \"TARGET_URL\", \"value\": \"$TARGET_URL\"},
                    {\"name\": \"REGION\", \"value\": \"$region\"},
                    {\"name\": \"USERS\", \"value\": \"$USERS\"},
                    {\"name\": \"DURATION\", \"value\": \"$DURATION\"}
                ]
            }]
        }" \
        --region "$region" > /dev/null
    
    echo "  ✓ Deployed to $region"
done

echo ""
echo "Load test running for $DURATION..."
sleep $(( $(echo $DURATION | sed 's/m/*60/' | bc) ))

# Collect results
echo ""
echo "Collecting results..."
for region in "${REGIONS[@]}"; do
    echo "Results from $region:"
    aws logs get-query-results --query-id $(aws logs start-query --log-group-name /ecs/locust --start-time $(date -d '1 hour ago' +%s) --end-time $(date +%s) --query-string "fields @timestamp, @message | sort @timestamp desc | limit 50" --region $region --output text) --region $region | grep -E "(Requests/sec|Avg|P99)" || true
done

echo ""
echo "✅ Distributed load test completed"
