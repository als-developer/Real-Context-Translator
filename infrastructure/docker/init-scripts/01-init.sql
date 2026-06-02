-- Initialize RCT-Engine Database
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Cultural Context Matrix
CREATE TABLE IF NOT EXISTS cultural_context_matrix (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    country_code VARCHAR(5) NOT NULL,
    language_code VARCHAR(5) NOT NULL,
    slang_term TEXT NOT NULL,
    literal_meaning TEXT NOT NULL,
    true_cultural_context TEXT NOT NULL,
    business_risk_level VARCHAR(20) DEFAULT 'LOW',
    category VARCHAR(50),
    verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Translation Audit Logs
CREATE TABLE IF NOT EXISTS translation_audit_logs (
    audit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID,
    source_text TEXT NOT NULL,
    target_country VARCHAR(5),
    risk_level VARCHAR(20),
    detected_slangs TEXT[],
    processing_time_ms INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert seed data
INSERT INTO cultural_context_matrix (country_code, language_code, slang_term, literal_meaning, true_cultural_context, business_risk_level, verified)
VALUES 
('KE', 'sw', 'piga chini', 'hit to the ground', 'To reject or discard a proposal', 'MEDIUM', TRUE),
('SA', 'ar', 'حرام', 'haram', 'Religiously forbidden - critical taboo', 'CRITICAL', TRUE),
('CN', 'zh', '牛逼', 'cow vagina', 'Vulgar slang meaning awesome', 'MEDIUM', TRUE);

CREATE INDEX idx_cultural_country ON cultural_context_matrix(country_code);
CREATE INDEX idx_audit_created ON translation_audit_logs(created_at DESC);
