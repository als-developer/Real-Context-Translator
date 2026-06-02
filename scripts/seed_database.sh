#!/bin/bash
set -euo pipefail

# RCT-Engine Database Seeding Script
# Seeds initial data for development/testing

echo "🌱 Seeding RCT-Engine Database"
echo "=========================================="

# Seed countries
seed_countries() {
    echo "1. Seeding countries..."
    docker exec -i rct-postgres psql -U rct_admin -d rct_saas << EOF
INSERT INTO countries (code, name, language_code, risk_level) VALUES
('KE', 'Kenya', 'sw', 'MEDIUM'),
('TZ', 'Tanzania', 'sw', 'MEDIUM'),
('UG', 'Uganda', 'sw', 'MEDIUM'),
('SA', 'Saudi Arabia', 'ar', 'CRITICAL'),
('AE', 'UAE', 'ar', 'HIGH'),
('CN', 'China', 'zh', 'HIGH'),
('NG', 'Nigeria', 'en-pcm', 'MEDIUM'),
('US', 'United States', 'en', 'LOW'),
('GB', 'United Kingdom', 'en', 'LOW'),
('FR', 'France', 'fr', 'LOW'),
('DE', 'Germany', 'de', 'LOW'),
('JP', 'Japan', 'ja', 'MEDIUM')
ON CONFLICT (code) DO NOTHING;
EOF
    echo "   ✓ Countries seeded"
}

# Seed cultural slang
seed_slang() {
    echo "2. Seeding cultural slang..."
    docker exec -i rct-postgres psql -U rct_admin -d rct_saas << EOF
INSERT INTO cultural_context_matrix (country_code, language_code, slang_term, literal_meaning, true_cultural_context, business_risk_level, verified) VALUES
('KE', 'sw', 'piga chini', 'hit to the ground', 'To reject or discard a business proposal', 'MEDIUM', true),
('KE', 'sw', 'kula pesa', 'eat money', 'Corruption or misappropriation', 'CRITICAL', true),
('KE', 'sw', 'mwizi', 'thief', 'Serious accusation in business', 'CRITICAL', true),
('TZ', 'sw', 'piga chenga', 'hit a step', 'To show off or be arrogant', 'MEDIUM', true),
('TZ', 'sw', 'kata mikate', 'cut bread', 'To earn profit', 'LOW', true),
('SA', 'ar', 'حرام', 'haram', 'Religiously forbidden', 'CRITICAL', true),
('SA', 'ar', 'خمر', 'khamr', 'Alcohol reference', 'CRITICAL', true),
('CN', 'zh', '牛逼', 'cow vagina', 'Vulgar for awesome', 'MEDIUM', true),
('CN', 'zh', '六四', 'June Fourth', 'Political taboo', 'CRITICAL', true),
('NG', 'en-pcm', 'dash', 'give', 'Bribe reference', 'CRITICAL', true),
('NG', 'en-pcm', 'sabi', 'know', 'To be knowledgeable', 'LOW', true)
ON CONFLICT (country_code, slang_term) DO NOTHING;
EOF
    echo "   ✓ Slang seeded"
}

# Seed test users
seed_users() {
    echo "3. Seeding test users..."
    docker exec -i rct-postgres psql -U rct_admin -d rct_saas << EOF
INSERT INTO organizations (id, name, stripe_customer_id, subscription_tier, monthly_word_limit) VALUES
('11111111-1111-1111-1111-111111111111', 'Demo Corp', 'cus_demo', 'PRO', 500000),
('22222222-2222-2222-2222-222222222222', 'Test Inc', 'cus_test', 'FREE', 10000);

INSERT INTO users (id, organization_id, email, hashed_password, full_name, role, api_key_hash) VALUES
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'admin@demo.com', 'hashed_password', 'Admin User', 'admin', 'demo_key_hash'),
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '11111111-1111-1111-1111-111111111111', 'user@demo.com', 'hashed_password', 'Regular User', 'viewer', 'user_key_hash')
ON CONFLICT (email) DO NOTHING;
EOF
    echo "   ✓ Users seeded"
}

# Refresh materialized view
refresh_view() {
    echo "4. Refreshing materialized view..."
    docker exec rct-postgres psql -U rct_admin -d rct_saas -c "REFRESH MATERIALIZED VIEW cultural_lookup_view;"
    echo "   ✓ View refreshed"
}

main() {
    seed_countries
    seed_slang
    seed_users
    refresh_view
    
    echo ""
    echo "=========================================="
    echo "✅ Database seeding completed"
    echo "=========================================="
}

main
