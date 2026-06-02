-- Billing and Subscription Tables

CREATE TABLE subscription_plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    stripe_price_id VARCHAR(100),
    monthly_price_cents INTEGER NOT NULL,
    word_limit_per_month BIGINT NOT NULL,
    features JSONB,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE invoices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID REFERENCES organizations(id),
    stripe_invoice_id VARCHAR(100),
    amount_cents INTEGER NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    status VARCHAR(50) DEFAULT 'pending',
    pdf_url TEXT,
    period_start DATE,
    period_end DATE,
    paid_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE metered_usage_logs (
    id BIGSERIAL PRIMARY KEY,
    organization_id UUID REFERENCES organizations(id),
    api_key_hash TEXT,
    word_count INTEGER NOT NULL,
    cost_cents INTEGER NOT NULL,
    endpoint VARCHAR(255),
    recorded_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert default subscription plans
INSERT INTO subscription_plans (name, monthly_price_cents, word_limit_per_month, features) VALUES
('Free', 0, 10000, '{"features": ["Basic Translation", "Community Support"]}'),
('Pro', 4900, 500000, '{"features": ["Cultural Context", "Slang Detection", "Email Support", "Analytics Dashboard"]}'),
('Enterprise', 19900, 5000000, '{"features": ["All Pro Features", "Custom AI Training", "SLA Guarantee", "Dedicated Support", "SSO Integration"]}');

-- Create function to check quota
CREATE OR REPLACE FUNCTION check_org_quota(org_id UUID, requested_words INTEGER)
RETURNS BOOLEAN AS $$
DECLARE
    current_usage BIGINT;
    monthly_limit BIGINT;
BEGIN
    SELECT words_used_current_month, monthly_word_limit INTO current_usage, monthly_limit
    FROM organizations WHERE id = org_id;
    
    RETURN (current_usage + requested_words) <= monthly_limit;
END;
$$ LANGUAGE plpgsql;
