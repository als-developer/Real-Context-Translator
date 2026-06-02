#!/bin/bash
set -euo pipefail

# RCT-Engine Chaos Monkey - Random failure injection

WORKING_HOURS_START=9
WORKING_HOURS_END=17
CHAOS_PROBABILITY=0.05  # 5% chance per hour

echo "🐒 RCT-Engine Chaos Monkey Activated"
echo "=========================================="

# Check if within working hours
current_hour=$(date +%H)
if [ "$current_hour" -lt "$WORKING_HOURS_START" ] || [ "$current_hour" -gt "$WORKING_HOURS_END" ]; then
    echo "Outside working hours - Chaos Monkey sleeping"
    exit 0
fi

# Random chance to cause chaos
if (( $(echo "$RANDOM <= 32767 * $CHAOS_PROBABILITY" | bc -l) )); then
    chaos_type=$((RANDOM % 5))
    
    case $chaos_type in
        0)
            echo "💥 Chaos: Killing API container..."
            docker kill rct-api 2>/dev/null || true
            ;;
        1)
            echo "💥 Chaos: Killing Worker container..."
            docker kill rct-worker 2>/dev/null || true
            ;;
        2)
            echo "💥 Chaos: Network latency injection..."
            docker exec rct-api tc qdisc add dev eth0 root netem delay 1000ms 2>/dev/null || true
            sleep 30
            docker exec rct-api tc qdisc del dev eth0 root 2>/dev/null || true
            ;;
        3)
            echo "💥 Chaos: Database connection limit..."
            docker exec rct-postgres psql -U rct_admin -c "ALTER SYSTEM SET max_connections = '10';" 2>/dev/null || true
            docker exec rct-postgres pg_ctl reload 2>/dev/null || true
            sleep 30
            docker exec rct-postgres psql -U rct_admin -c "ALTER SYSTEM SET max_connections = '500';" 2>/dev/null || true
            docker exec rct-postgres pg_ctl reload 2>/dev/null || true
            ;;
        4)
            echo "💥 Chaos: Redis flush..."
            docker exec rct-redis redis-cli FLUSHALL 2>/dev/null || true
            ;;
    esac
    
    echo "Chaos injected! Monitoring auto-remediation..."
    sleep 10
    
    # Check if services recovered
    if curl -s -f "http://localhost:8000/health" > /dev/null; then
        echo "✅ System recovered automatically"
    else
        echo "⚠️ System still degraded - manual intervention may be needed"
    fi
else
    echo "No chaos today - system stable"
fi
