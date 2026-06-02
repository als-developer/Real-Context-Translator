-- Seed cultural context data for high-risk countries

INSERT INTO cultural_context_matrix (country_code, language_code, slang_term, literal_meaning, true_cultural_context, business_risk_level, category, verified) VALUES
-- Kenya / Swahili
('KE', 'sw', 'piga chini', 'hit to the ground', 'To reject, discard, or eliminate a business proposal', 'MEDIUM', 'BUSINESS_SLANG', TRUE),
('KE', 'sw', 'kula pesa', 'eat money', 'Corruption or misappropriation of funds', 'CRITICAL', 'CORRUPTION', TRUE),
('KE', 'sw', 'mwizi', 'thief', 'Accusation of theft - very serious in business context', 'CRITICAL', 'ACCUSATION', TRUE),

-- Tanzania / Swahili
('TZ', 'sw', 'piga chenga', 'hit a step', 'To show off or be arrogant', 'MEDIUM', 'SOCIAL', TRUE),
('TZ', 'sw', 'kata mikate', 'cut bread', 'To earn money or make profit', 'LOW', 'BUSINESS', TRUE),

-- Saudi Arabia / Arabic
('SA', 'ar', 'خمر', 'khamr', 'Reference to alcohol - strictly forbidden in public communications', 'CRITICAL', 'RELIGIOUS_TABOO', TRUE),
('SA', 'ar', 'حرام', 'haram', 'Religiously forbidden - extremely serious', 'CRITICAL', 'RELIGIOUS', TRUE),

-- China / Mandarin
('CN', 'zh', '牛逼', 'cow vagina', 'Actually means "awesome" but can be vulgar in formal business', 'MEDIUM', 'SLANG', TRUE),
('CN', 'zh', '六四', 'June Fourth', 'Political taboo - absolute block', 'CRITICAL', 'POLITICAL', TRUE),

-- Nigeria / English Pidgin
('NG', 'en-pcm', 'dash', 'give', 'Bribe or illegal payment context', 'CRITICAL', 'CORRUPTION', TRUE),
('NG', 'en-pcm', 'sabi', 'know', 'To be knowledgeable - neutral in business', 'LOW', 'NEUTRAL', TRUE);

-- Create materialized view for fast lookup
CREATE MATERIALIZED VIEW cultural_lookup_view AS
SELECT 
    country_code,
    slang_term,
    true_cultural_context,
    business_risk_level,
    category
FROM cultural_context_matrix
WHERE verified = TRUE;

REFRESH MATERIALIZED VIEW cultural_lookup_view;
