#!/bin/bash
# RCT-Engine Self-Healing Monitor Daemon

SERVICES=("api" "worker" "postgres" "redis" "billing-exporter")
CHECK_INTERVAL=10
MAX_RETRIES=3
ALERT_WEBHOOK="${SLACK_ALERT_WEBHOOK:-}"

send_alert() {
    local service=$1
    local status=$2
    local message=$3
    
    echo "[$(date)] ALERT: $service - $status - $message"
    
    if [ -n "$ALERT_WEBHOOK" ]; then
        curl -s -X POST "$ALERT_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{\"text\":\"🚨 RCT-Engine Alert\nService: $service\nStatus: $status\nMessage: $message\"}" \
            > /dev/null 2>&1 || true
    fi
}

check_service() {
    local service=$1
    local retries=0
    
    while [ $retries -lt $MAX_RETRIES ]; do
        case $service in
            api)
                if curl -s -f "http://localhost:8000/health" > /dev/null 2>&1; then
                    return 0
                fi
                ;;
            worker)
                if docker exec rct-worker celery -A workers.celery_app status > /dev/null 2>&1; then
                    return 0
                fi
                ;;
            postgres)
                if docker exec rct-postgres pg_isready -U rct_admin > /dev/null 2>&1; then
                    return 0
                fi
                ;;
            redis)
                if docker exec rct-redis redis-cli PING | grep -q "PONG"; then
                    return 0
                fi
                ;;
            billing-exporter)
                if curl -s -f "http://localhost:9102/health" > /dev/null 2>&1; then
                    return 0
                fi
                ;;
        esac
        
        retries=$((retries + 1))
        sleep 2
    done
    
    return 1
}

restart_service() {
    local service=$1
    
    echo "[$(date)] Restarting $service..."
    
    case $service in
        api|worker|postgres|redis|billing-exporter)
            docker-compose -f infrastructure/docker/docker-compose.yml restart "$service"
            sleep 5
            ;;
    esac
}

main() {
    echo "[$(date)] RCT-Engine Monitor started"
    
    while true; do
        for service in "${SERVICES[@]}"; do
            if ! check_service "$service"; then
                send_alert "$service" "DEGRADED" "Service health check failed"
                restart_service "$service"
                
                # Verify restart
                if check_service "$service"; then
                    send_alert "$service" "RECOVERED" "Service successfully restarted"
                else
                    send_alert "$service" "CRITICAL" "Service restart failed - manual intervention required"
                fi
            fi
        done
        
        sleep $CHECK_INTERVAL
    done
}

# Handle signals
trap 'echo "[$(date)] Monitor stopped"; exit 0' SIGTERM SIGINT

main
