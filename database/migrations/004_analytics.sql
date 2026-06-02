-- Analytics and Reporting Tables

CREATE TABLE daily_usage_stats (
    stat_date DATE PRIMARY KEY,
    total_translations BIGINT DEFAULT 0,
    total_words_processed BIGINT DEFAULT 0,
    total_revenue_cents BIGINT DEFAULT 0,
    critical_blocks_count INTEGER DEFAULT 0,
    avg_latency_ms FLOAT DEFAULT 0,
    unique_organizations INTEGER DEFAULT 0
);

CREATE TABLE country_risk_metrics (
    id SERIAL PRIMARY KEY,
    country_code VARCHAR(5) NOT NULL,
    week_start DATE NOT NULL,
    total_translations INTEGER DEFAULT 0,
    risk_incidents INTEGER DEFAULT 0,
    risk_rate FLOAT DEFAULT 0,
    top_slangs JSONB,
    UNIQUE(country_code, week_start)
);

-- Function to update daily stats
CREATE OR REPLACE FUNCTION update_daily_stats()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO daily_usage_stats (stat_date, total_translations, total_words_processed, critical_blocks_count)
    VALUES (CURRENT_DATE, 1, NEW.word_count, CASE WHEN NEW.risk_level = 'CRITICAL' THEN 1 ELSE 0 END)
    ON CONFLICT (stat_date) DO UPDATE SET
        total_translations = daily_usage_stats.total_translations + 1,
        total_words_processed = daily_usage_stats.total_words_processed + EXCLUDED.total_words_processed,
        critical_blocks_count = daily_usage_stats.critical_blocks_count + EXCLUDED.critical_blocks_count;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_stats_on_translation
AFTER INSERT ON translation_audit_logs
FOR EACH ROW
EXECUTE FUNCTION update_daily_stats();
