-- RCT-Engine SLA Tracking and Reporting
-- Monthly SLA compliance calculation

-- Create SLA tracking table
CREATE TABLE IF NOT EXISTS sla_metrics (
    id SERIAL PRIMARY KEY,
    date DATE NOT NULL,
    total_requests BIGINT DEFAULT 0,
    successful_requests BIGINT DEFAULT 0,
    failed_requests BIGINT DEFAULT 0,
    avg_latency_ms DECIMAL(10,2),
    p99_latency_ms DECIMAL(10,2),
    availability_pct DECIMAL(5,2),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(date)
);

-- Function to update SLA metrics daily
CREATE OR REPLACE FUNCTION update_sla_metrics()
RETURNS void AS $$
DECLARE
    target_date DATE := CURRENT_DATE - INTERVAL '1 day';
    req_count BIGINT;
    success_count BIGINT;
    avg_lat DECIMAL(10,2);
    p99_lat DECIMAL(10,2);
BEGIN
    -- Get counts
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE status_code = 200),
        AVG(processing_time_ms),
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY processing_time_ms)
    INTO req_count, success_count, avg_lat, p99_lat
    FROM api_request_logs
    WHERE DATE(created_at) = target_date;
    
    -- Insert or update
    INSERT INTO sla_metrics (date, total_requests, successful_requests, failed_requests, avg_latency_ms, p99_latency_ms, availability_pct)
    VALUES (
        target_date,
        req_count,
        success_count,
        req_count - success_count,
        avg_lat,
        p99_lat,
        CASE WHEN req_count > 0 THEN (success_count::DECIMAL / req_count) * 100 ELSE 100 END
    )
    ON CONFLICT (date) DO UPDATE SET
        total_requests = EXCLUDED.total_requests,
        successful_requests = EXCLUDED.successful_requests,
        failed_requests = EXCLUDED.failed_requests,
        avg_latency_ms = EXCLUDED.avg_latency_ms,
        p99_latency_ms = EXCLUDED.p99_latency_ms,
        availability_pct = EXCLUDED.availability_pct;
END;
$$ LANGUAGE plpgsql;

-- SLA Report for current month
CREATE OR REPLACE VIEW sla_monthly_report AS
SELECT 
    DATE_TRUNC('month', date) as month,
    SUM(total_requests) as total_requests,
    SUM(successful_requests) as successful_requests,
    ROUND((SUM(successful_requests)::DECIMAL / NULLIF(SUM(total_requests), 0)) * 100, 2) as availability,
    ROUND(AVG(avg_latency_ms), 2) as avg_latency,
    MAX(p99_latency_ms) as max_p99_latency,
    CASE 
        WHEN (SUM(successful_requests)::DECIMAL / NULLIF(SUM(total_requests), 0)) >= 0.999 THEN 'SLA MET'
        WHEN (SUM(successful_requests)::DECIMAL / NULLIF(SUM(total_requests), 0)) >= 0.99 THEN 'SLA WARNING'
        ELSE 'SLA BREACH'
    END as sla_status
FROM sla_metrics
WHERE date >= DATE_TRUNC('month', CURRENT_DATE)
GROUP BY DATE_TRUNC('month', date);

-- Trigger to run daily
CREATE OR REPLACE FUNCTION trigger_sla_update()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM update_sla_metrics();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Schedule: Run via cron or pg_cron
-- SELECT cron.schedule('update-sla', '0 1 * * *', 'SELECT update_sla_metrics();');
