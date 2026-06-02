-- RCT-Engine Ultimate Initial Schema
-- Version: 3.0.0

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Organizations table
CREATE TABLE organizations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    stripe_customer_id VARCHAR(100) UNIQUE,
    subscription_tier VARCHAR(50) DEFAULT 'FREE',
    monthly_word_limit BIGINT DEFAULT 1000000,
    words_used_current_month BIGINT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Users table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    email VARCHAR(255) UNIQUE NOT NULL,
    hashed_password TEXT NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    role VARCHAR(50) DEFAULT 'viewer',
    api_key_hash TEXT UNIQUE,
    is_active BOOLEAN DEFAULT TRUE,
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Cultural Context Matrix (Core Intelligence)
CREATE TABLE cultural_context_matrix (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    country_code VARCHAR(5) NOT NULL,
    language_code VARCHAR(5) NOT NULL,
    slang_term TEXT NOT NULL,
    literal_meaning TEXT NOT NULL,
    true_cultural_context TEXT NOT NULL,
    business_risk_level VARCHAR(20) DEFAULT 'LOW',
    category VARCHAR(50),
    created_by UUID REFERENCES users(id),
    verified BOOLEAN DEFAULT FALSE,
    usage_count BIGINT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Translation Audit Logs
CREATE TABLE translation_audit_logs (
    audit_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID REFERENCES organizations(id),
    user_id UUID REFERENCES users(id),
    source_text TEXT NOT NULL,
    source_language VARCHAR(5),
    target_country VARCHAR(5),
    target_language VARCHAR(5),
    translated_text TEXT,
    cultural_verdict VARCHAR(50),
    risk_level VARCHAR(20),
    detected_slangs TEXT[],
    processing_time_ms INTEGER,
    word_count INTEGER,
    cost_in_cents INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes
CREATE INDEX idx_cultural_country ON cultural_context_matrix(country_code);
CREATE INDEX idx_cultural_slang ON cultural_context_matrix USING GIN(to_tsvector('english', slang_term));
CREATE INDEX idx_audit_org_date ON translation_audit_logs(organization_id, created_at DESC);
CREATE INDEX idx_audit_risk ON translation_audit_logs(risk_level) WHERE risk_level = 'CRITICAL';

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_organizations_updated_at BEFORE UPDATE ON organizations FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_cultural_matrix_updated_at BEFORE UPDATE ON cultural_context_matrix FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
