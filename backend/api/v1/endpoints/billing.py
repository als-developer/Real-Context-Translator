from fastapi import APIRouter, Depends, HTTPException, Header
from typing import Optional
import stripe
from pydantic import BaseModel

from backend.core.config import settings
from backend.services.billing_service import BillingService

router = APIRouter(prefix="/billing", tags=["Billing"])
stripe.api_key = settings.STRIPE_SECRET_KEY

class UsageRequest(BaseModel):
    organization_id: str
    word_count: int

@router.get("/plan")
async def get_current_plan(organization_id: str = Header(...)):
    """Get current subscription plan details"""
    return {
        "plan": "Pro",
        "monthly_limit": 500000,
        "words_used": 123456,
        "remaining": 376544,
        "renewal_date": "2026-06-30"
    }

@router.get("/usage")
async def get_usage_stats(
    organization_id: str = Header(...),
    days: int = 30
):
    """Get usage statistics for billing"""
    return {
        "total_words": 123456,
        "total_cost_cents": 6172,
        "daily_breakdown": [
            {"date": "2026-05-30", "words": 4567},
            {"date": "2026-05-29", "words": 3890}
        ]
    }

@router.post("/webhook/stripe")
async def stripe_webhook(payload: dict):
    """Handle Stripe webhook events"""
    event_type = payload.get("type")
    
    if event_type == "invoice.payment_succeeded":
        # Update organization subscription status
        pass
    elif event_type == "customer.subscription.deleted":
        # Downgrade to free tier
        pass
    
    return {"status": "received"}
