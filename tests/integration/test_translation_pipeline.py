import pytest
from fastapi.testclient import TestClient
from backend.main import app
from backend.core.database import get_db_session, Base
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Test database
TEST_DATABASE_URL = "sqlite:///./test.db"
engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def override_get_db():
    try:
        db = TestingSessionLocal()
        yield db
    finally:
        db.close()

app.dependency_overrides[get_db_session] = override_get_db

client = TestClient(app)

@pytest.fixture(autouse=True)
def setup_database():
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)

def test_full_translation_flow_kenya():
    # 1. Create organization
    org_response = client.post(
        "/api/v1/admin/organizations",
        json={"name": "Test Org", "email": "test@example.com"},
        headers={"X-Admin-Token": "admin_token"}
    )
    assert org_response.status_code in [200, 201]
    
    # 2. Get API key
    api_key_response = client.post(
        "/api/v1/auth/register",
        json={
            "email": "user@test.com",
            "password": "password123",
            "full_name": "Test User",
            "organization_name": "Test Org"
        }
    )
    
    api_key = api_key_response.json().get("api_key")
    assert api_key is not None
    
    # 3. Perform translation
    translation_response = client.post(
        "/api/v1/translate",
        json={
            "source_text": "We need to reject this proposal",
            "source_language": "en",
            "target_country": "KE",
            "target_language": "sw"
        },
        headers={"X-API-Key": api_key}
    )
    
    assert translation_response.status_code == 200
    data = translation_response.json()
    
    # 4. Verify response structure
    assert "translation_id" in data
    assert "cultural_intelligence" in data
    assert "adapted_text" in data or data["cultural_intelligence"]["risk_verdict"] == "BLOCKED"
    
    # 5. Check analytics
    analytics_response = client.get(
        "/api/v1/analytics/dashboard",
        headers={"X-API-Key": api_key}
    )
    
    assert analytics_response.status_code == 200
