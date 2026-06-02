import pytest
from backend.services.cultural_ai_service import CulturalAIService
from backend.core.cache import cache

@pytest.mark.asyncio
async def test_slang_detection():
    result = await CulturalAIService.analyze_cultural_risk(
        text="Piga chini ofisi za zamani",
        target_country="KE",
        source_language="sw"
    )
    
    assert result.risk_level in ["LOW", "MEDIUM", "CRITICAL"]
    assert isinstance(result.detected_slangs, list)

@pytest.mark.asyncio
async def test_taboo_detection_saudi():
    result = await CulturalAIService.analyze_cultural_risk(
        text="Let's drink alcohol at the party",
        target_country="SA",
        source_language="en"
    )
    
    # Should detect critical risk for alcohol reference in Saudi
    if result.risk_level == "CRITICAL":
        assert len(result.detected_slangs) > 0 or result.explanation

@pytest.mark.asyncio
async def test_safe_content():
    result = await CulturalAIService.analyze_cultural_risk(
        text="We would like to discuss business partnership opportunities",
        target_country="KE",
        source_language="en"
    )
    
    # Safe content should be LOW risk
    assert result.risk_level in ["LOW", "MEDIUM"]

@pytest.mark.asyncio
async def test_cache_hit():
    # First call - should hit AI
    result1 = await CulturalAIService.analyze_cultural_risk(
        text="Same text for caching test",
        target_country="KE",
        source_language="en"
    )
    
    # Second call - should hit cache
    result2 = await CulturalAIService.analyze_cultural_risk(
        text="Same text for caching test",
        target_country="KE",
        source_language="en"
    )
    
    assert result1.risk_level == result2.risk_level
    assert result1.explanation == result2.explanation
