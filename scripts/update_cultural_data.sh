#!/bin/bash
set -euo pipefail

# RCT-Engine Cultural Data Update Script
# Updates cultural context matrix from CSV file

CSV_FILE="${1:-./data/cultural_updates.csv}"

if [ ! -f "$CSV_FILE" ]; then
    echo "Error: CSV file not found: $CSV_FILE"
    echo ""
    echo "Expected format:"
    echo "country_code,language_code,slang_term,literal_meaning,true_cultural_context,risk_level"
    echo ""
    echo "Example:"
    echo "KE,sw,new_slang,literal,context,MEDIUM"
    exit 1
fi

echo "📚 Updating Cultural Data"
echo "=========================================="

# Backup current data
echo "1. Backing up current cultural matrix..."
docker exec rct-postgres psql -U rct_admin -d rct_saas -c "
    CREATE TABLE IF NOT EXISTS cultural_context_matrix_backup AS 
    SELECT * FROM cultural_context_matrix;
"
echo "   ✓ Backup created"

# Process CSV and upsert
echo "2. Processing updates from CSV..."
while IFS=',' read -r country lang slang literal context risk; do
    # Skip header
    if [ "$country" = "country_code" ]; then continue; fi
    
    docker exec rct-postgres psql -U rct_admin -d rct_saas -c "
        INSERT INTO cultural_context_matrix 
        (country_code, language_code, slang_term, literal_meaning, true_cultural_context, business_risk_level, verified, updated_at)
        VALUES ('$country', '$lang', '$slang', '$literal', '$context', '$risk', true, NOW())
        ON CONFLICT (country_code, slang_term) 
        DO UPDATE SET 
            literal_meaning = EXCLUDED.literal_meaning,
            true_cultural_context = EXCLUDED.true_cultural_context,
            business_risk_level = EXCLUDED.business_risk_level,
            updated_at = NOW();
    "
    echo "   ✓ Updated: $country - $slang"
done < "$CSV_FILE"

# Refresh materialized view
echo "3. Refreshing materialized view..."
docker exec rct-postgres psql -U rct_admin -d rct_saas -c "REFRESH MATERIALIZED VIEW cultural_lookup_view;"
echo "   ✓ View refreshed"

# Invalidate cache
echo "4. Invalidating Redis cache..."
docker exec rct-redis redis-cli DEL "cultural:*"
echo "   ✓ Cache invalidated"

echo ""
echo "=========================================="
echo "✅ Cultural data updated successfully"
echo "=========================================="
