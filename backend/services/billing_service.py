import stripe
from backend.core.config import settings
import logging
from typing import Optional

stripe.api_key = settings.STRIPE_SECRET_KEY
logger = logging.getLogger(__name__)

class BillingService:
    COST_PER_1000_WORDS = 0.50  # $0.50 per 1000 words
    
    @classmethod
    async def record_usage(cls, api_key: str, word_count: int, organization_id: Optional[str] = None):
        """Record usage for metered billing"""
        try:
            # Get or create customer
            customer_id = await cls._get_customer_by_api_key(api_key)
            
            if customer_id and word_count > 0:
                # Create usage record in Stripe
                stripe.SubscriptionItem.create_usage_record(
                    subscription_item=customer_id,
                    quantity=word_count,
                    timestamp="now",
                    action="increment"
                )
                logger.info(f"Recorded {word_count} words for customer {customer_id}")
        except Exception as e:
            logger.error(f"Billing recording failed: {str(e)}")
            # Don't raise - billing errors shouldn't break translation
    
    @classmethod
    async def _get_customer_by_api_key(cls, api_key: str) -> Optional[str]:
        # In production, lookup in database
        return "si_mock_subscription_item_id"
    
    @classmethod
    def calculate_cost(cls, word_count: int) -> float:
        return (word_count / 1000) * cls.COST_PER_1000_WORDS
