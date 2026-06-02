import pytest
from fastapi.testclient import TestClient
from unittest.mock import patch, AsyncMock
from backend.main import app
from backend.services.cultural_ai_service import CulturalAnalysisResult

client = TestClient(app)

def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"

def test_translate_endpoint_no_api_key():
    response = client.post("/api/v1/translate", json={
        "source_text": "Hello world",
        "source_language": "en",
        "target_country": "KE",
        "target_language": "sw"
    })
    assert response.status_code == 401

def test_translate_endpoint_with_api_key():
    response = client.post(
        "/api/v1/translate",
        json={
            "source_text": "Hello world",
            "source_language": "en",
            "target_country": "KE",
            "target_language": "sw"
        },
        headers={"X-API-Key": "test_key"}
    )
    assert response.status_code in [200, 429]  # Rate limit may apply

@patch('backend.services.cultural_ai_service.CulturalAIService.analyze_cultural_risk')
def test_critical_risk_blocking(mock_analyze):
    mock_analyze.return_value = CulturalAnalysisResult(
        risk_level="CRITICAL",
        detected_slangs=["haram"],
        explanation="Religious taboo detected",
        recommended_fix="Remove reference"
    )
    
    response = client.post(
        "/api/v1/translate",
        json={
            "source_text": "Test with haram content",
            "source_language": "en",
            "target_country": "SA",
            "target_language": "ar"
        },
        headers={"X-API-Key": "test_key"}
    )
    
    assert response.status_code == 200
    data = response.json()
    assert data["cultural_intelligence"]["risk_verdict"] == "BLOCKED"

def test_rate_limiting():
    # Make multiple requests to trigger rate limit
    for i in range(60):
        response = client.post(
            "/api/v1/translate",
            json={
                "source_text": f"Test message {i}",
                "source_language": "en",
                "target_country": "KE",
                "target_language": "sw"
            },
            headers={"X-API-Key": "test_key"}
        )
        if response.status_code == 429:
            assert response.json()["detail"]["error"] == "Rate limit exceeded"
            break

def test_batch_translate():
    response = client.post(
        "/api/v1/batch/translate",
        json={
            "texts": [
                {
                    "source_text": "First text",
                    "source_language": "en",
                    "target_country": "KE",
                    "target_language": "sw"
                },
                {
                    "source_text": "Second text",
                    "source_language": "en",
                    "target_country": "SA",
                    "target_language": "ar"
                }
            ],
            "webhook_url": "https://webhook.site/test"
        },
        headers={"X-API-Key": "test_key"}
    )
    
    assert response.status_code == 200
    data = response.json()
    assert "batch_id" in data
