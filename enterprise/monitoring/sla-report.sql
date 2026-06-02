-- RCT-Engine SLA Report Generation Query
-- Monthly SLA compliance report

WITH monthly_stats AS (
    SELECT 
        DATE_TRUNC('month', created_at) as month,
        COUNT(*) as total_requests,
        COUNT(*) FILTER (WHERE status_code = 200) as successful_requests,
        AVG(processing_time_ms) as avg_latency,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY processing_time_ms) as p99_latency
    FROM api_request_logs
    WHERE created_at >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month')
      AND created_at < DATE_TRUNC('month', CURRENT_DATE)
    GROUP BY DATE_TRUNC('month', created_at)
),
sla_calc AS (
    SELECT 
        month,
        total_requests,
        successful_requests,
        ROUND((successful_requests::DECIMAL / total_requests) * 100, 2) as availability,
        p99_latency,
        CASE 
            WHEN (successful_requests::DECIMAL / total_requests) >= 0.999 THEN 'SLA MET'
            WHEN (successful_requests::DECIMAL / total_requests) >= 0.99 THEN 'SLA WARNING'
            ELSE 'SLA BREACH'
        END as sla_status,
        CASE 
            WHEN p99_latency <= 200 THEN 'PASS'
            ELSE 'FAIL'
        END as latency_status
    FROM monthly_stats
)
SELECT 
    month,
    total_requests,
    availability || '%' as availability_percent,
    p99_latency || 'ms' as p99_latency,
    sla_status,
    latency_status,
    CASE 
        WHEN sla_status = 'SLA BREACH' THEN 'CRITICAL'
        WHEN sla_status = 'SLA WARNING' THEN 'WARNING'
        ELSE 'OK'
    END as alert_level
FROM sla_calc;
