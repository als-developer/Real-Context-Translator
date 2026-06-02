import pytest
from unittest.mock import patch, MagicMock
from backend.services.billing_service import BillingService
from backend.models.organization import Organization
from backend.core.database import get_db_session

@pytest.mark.asyncio
async def test_usage_recording():
    with patch('stripe.SubscriptionItem.create_usage_record') as mock_stripe:
        mock_stripe.return_value = MagicMock(id="usage_123")
        
        await BillingService.record_usage(
            api_key="test_key",
            word_count=1000,
            organization_id="org_123"
        )
        
        mock_stripe.assert_called_once()

def test_cost_calculation():
    cost = BillingService.calculate_cost(5000)
    assert cost == 2.50  # $0.50 per 1000 words
    
    cost = BillingService.calculate_cost(100)
    assert cost == 0.05

@pytest.mark.asyncio
async def test_quota_check():
    # Test quota check logic
    org = Organization(
        id="test_org",
        monthly_word_limit=100000,
        words_used_current_month=50000
    )
    
    assert org.check_quota(40000) == True   # Within limit
    assert org.check_quota(60000) == False  # Would exceed limit

def test_invoice_generation():
    # Test invoice generation logic
    from backend.services.billing_service import generate_invoice
    
    invoice = generate_invoice(
        organization_id="org_123",
        word_count=50000,
        amount_cents=2500
    )
    
    assert invoice["amount_cents"] == 2500
    assert invoice["word_count"] == 50000
    assert "invoice_id" in invoice
