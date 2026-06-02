"""
PayPal Billing Integration for RCT-Engine Ultimate
Usiwahi kuweka API keys moja kwa moja kwenye code!
Tumia environment variables au secrets manager.
"""

import os
import json
import base64
import httpx
from typing import Optional, Dict, Any
from dataclasses import dataclass
from datetime import datetime, timedelta
from loguru import logger

# ============================================
# MAELEZO MUHIMU: Usiweke API keys hapa!
# Tumia environment variables:
# export PAYPAL_CLIENT_ID="your_client_id"
# export PAYPAL_SECRET_KEY="your_secret_key"
# export PAYPAL_MODE="sandbox"  # au "live"
# ============================================

class PayPalConfig:
    """PayPal configuration from environment variables"""
    
    MODE = os.getenv("PAYPAL_MODE", "sandbox")  # sandbox au live
    
    # Sandbox endpoints
    SANDBOX_API_URL = "https://api-m.sandbox.paypal.com"
    SANDBOX_WEBHOOK_URL = "https://api-m.sandbox.paypal.com"
    
    # Live endpoints
    LIVE_API_URL = "https://api-m.paypal.com"
    LIVE_WEBHOOK_URL = "https://api-m.paypal.com"
    
    @property
    def API_URL(self) -> str:
        return self.SANDBOX_API_URL if self.MODE == "sandbox" else self.LIVE_API_URL
    
    @property
    def WEBHOOK_URL(self) -> str:
        return self.SANDBOX_WEBHOOK_URL if self.MODE == "sandbox" else self.LIVE_WEBHOOK_URL
    
    @property
    def CLIENT_ID(self) -> str:
        client_id = os.getenv("PAYPAL_CLIENT_ID")
        if not client_id:
            raise ValueError("PAYPAL_CLIENT_ID environment variable not set")
        return client_id
    
    @property
    def SECRET_KEY(self) -> str:
        secret = os.getenv("PAYPAL_SECRET_KEY")
        if not secret:
            raise ValueError("PAYPAL_SECRET_KEY environment variable not set")
        return secret
    
    @property
    def RETURN_URL(self) -> str:
        return os.getenv("PAYPAL_RETURN_URL", "https://dashboard.rct-engine.com/billing/success")
    
    @property
    def CANCEL_URL(self) -> str:
        return os.getenv("PAYPAL_CANCEL_URL", "https://dashboard.rct-engine.com/billing/cancel")
    
    @property
    def WEBHOOK_ID(self) -> Optional[str]:
        return os.getenv("PAYPAL_WEBHOOK_ID")


paypal_config = PayPalConfig()


class PayPalClient:
    """PayPal API Client for RCT-Engine Billing"""
    
    def __init__(self):
        self.config = paypal_config
        self._access_token = None
        self._token_expires_at = None
    
    async def _get_access_token(self) -> str:
        """Get OAuth2 access token from PayPal"""
        
        # Check if token is still valid
        if self._access_token and self._token_expires_at and datetime.now() < self._token_expires_at:
            return self._access_token
        
        # Get new token
        auth_string = f"{self.config.CLIENT_ID}:{self.config.SECRET_KEY}"
        auth_bytes = auth_string.encode("utf-8")
        auth_base64 = base64.b64encode(auth_bytes).decode("utf-8")
        
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.config.API_URL}/v1/oauth2/token",
                headers={
                    "Authorization": f"Basic {auth_base64}",
                    "Content-Type": "application/x-www-form-urlencoded"
                },
                data={"grant_type": "client_credentials"}
            )
            
            if response.status_code != 200:
                logger.error(f"PayPal token error: {response.text}")
                raise Exception(f"Failed to get PayPal token: {response.status_code}")
            
            data = response.json()
            self._access_token = data["access_token"]
            self._token_expires_at = datetime.now() + timedelta(seconds=data["expires_in"])
            
            return self._access_token
    
    async def _request(self, method: str, path: str, data: Dict = None) -> Dict[str, Any]:
        """Make authenticated request to PayPal API"""
        
        token = await self._get_access_token()
        
        async with httpx.AsyncClient() as client:
            response = await client.request(
                method,
                f"{self.config.API_URL}{path}",
                headers={
                    "Authorization": f"Bearer {token}",
                    "Content-Type": "application/json",
                    "Accept": "application/json"
                },
                json=data
            )
            
            if response.status_code not in [200, 201, 202]:
                logger.error(f"PayPal API error: {response.text}")
                raise Exception(f"PayPal API error: {response.status_code}")
            
            return response.json() if response.text else {}
    
    # ============================================
    # PRODUCT & PLAN MANAGEMENT
    # ============================================
    
    async def create_product(self, name: str, description: str) -> Dict[str, Any]:
        """Create a product in PayPal Catalog"""
        
        data = {
            "name": name,
            "description": description,
            "type": "SERVICE",
            "category": "SOFTWARE",
            "home_url": "https://rct-engine.com"
        }
        
        return await self._request("POST", "/v1/catalogs/products", data)
    
    async def create_plan(self, product_id: str, name: str, price_cents: int, interval: str = "MONTH") -> Dict[str, Any]:
        """Create a subscription plan"""
        
        data = {
            "product_id": product_id,
            "name": name,
            "description": f"{name} - ${price_cents/100}/month",
            "status": "ACTIVE",
            "billing_cycles": [
                {
                    "frequency": {
                        "interval_unit": interval,
                        "interval_count": 1
                    },
                    "tenure_type": "REGULAR",
                    "sequence": 1,
                    "total_cycles": 0,
                    "pricing_scheme": {
                        "fixed_price": {
                            "value": str(price_cents / 100),
                            "currency_code": "USD"
                        }
                    }
                }
            ],
            "payment_preferences": {
                "auto_bill_outstanding": True,
                "setup_fee": {
                    "value": "0",
                    "currency_code": "USD"
                },
                "setup_fee_failure_action": "CONTINUE",
                "payment_failure_threshold": 3
            }
        }
        
        return await self._request("POST", "/v1/billing/plans", data)
    
    # ============================================
    # SUBSCRIPTION MANAGEMENT
    # ============================================
    
    async def create_subscription(self, plan_id: str, subscriber_email: str, subscriber_name: str) -> Dict[str, Any]:
        """Create a subscription for a customer"""
        
        data = {
            "plan_id": plan_id,
            "start_time": (datetime.now() + timedelta(minutes=5)).isoformat() + "Z",
            "subscriber": {
                "name": {
                    "given_name": subscriber_name.split()[0] if " " in subscriber_name else subscriber_name,
                    "surname": subscriber_name.split()[-1] if " " in subscriber_name else ""
                },
                "email_address": subscriber_email
            },
            "application_context": {
                "brand_name": "RCT-Engine",
                "locale": "en-US",
                "shipping_preference": "NO_SHIPPING",
                "user_action": "SUBSCRIBE_NOW",
                "payment_method": {
                    "payer_selected": "PAYPAL",
                    "payee_preferred": "IMMEDIATE_PAYMENT_REQUIRED"
                },
                "return_url": self.config.RETURN_URL,
                "cancel_url": self.config.CANCEL_URL
            }
        }
        
        response = await self._request("POST", "/v1/billing/subscriptions", data)
        
        # Extract approval URL
        approval_url = None
        for link in response.get("links", []):
            if link.get("rel") == "approve":
                approval_url = link.get("href")
                break
        
        return {
            "subscription_id": response["id"],
            "status": response["status"],
            "approval_url": approval_url
        }
    
    async def get_subscription(self, subscription_id: str) -> Dict[str, Any]:
        """Get subscription details"""
        return await self._request("GET", f"/v1/billing/subscriptions/{subscription_id}")
    
    async def cancel_subscription(self, subscription_id: str, reason: str = "Cancelled by user") -> Dict[str, Any]:
        """Cancel a subscription"""
        
        data = {"reason": reason}
        return await self._request("POST", f"/v1/billing/subscriptions/{subscription_id}/cancel", data)
    
    async def suspend_subscription(self, subscription_id: str, reason: str = "Temporarily suspended") -> Dict[str, Any]:
        """Suspend a subscription"""
        
        data = {"reason": reason}
        return await self._request("POST", f"/v1/billing/subscriptions/{subscription_id}/suspend", data)
    
    async def activate_subscription(self, subscription_id: str) -> Dict[str, Any]:
        """Activate a suspended subscription"""
        
        return await self._request("POST", f"/v1/billing/subscriptions/{subscription_id}/activate", {})
    
    # ============================================
    # INVOICE & PAYMENT MANAGEMENT
    # ============================================
    
    async def capture_authorized_payment(self, order_id: str) -> Dict[str, Any]:
        """Capture an authorized payment"""
        return await self._request("POST", f"/v2/checkout/orders/{order_id}/capture")
    
    async def refund_payment(self, capture_id: str, amount_cents: Optional[int] = None) -> Dict[str, Any]:
        """Refund a captured payment"""
        
        data = {}
        if amount_cents:
            data = {
                "amount": {
                    "value": str(amount_cents / 100),
                    "currency_code": "USD"
                }
            }
        
        return await self._request("POST", f"/v2/payments/captures/{capture_id}/refund", data)
    
    # ============================================
    # USAGE-BASED BILLING (Metered)
    # ============================================
    
    async def record_usage(self, subscription_id: str, quantity: int, timestamp: datetime = None) -> Dict[str, Any]:
        """Record usage for metered billing"""
        
        if timestamp is None:
            timestamp = datetime.now()
        
        data = {
            "quantity": str(quantity),
            "timestamp": timestamp.isoformat() + "Z"
        }
        
        return await self._request("POST", f"/v1/billing/subscriptions/{subscription_id}/record-usage", data)
    
    async def get_usage_records(self, subscription_id: str, start_date: datetime, end_date: datetime) -> Dict[str, Any]:
        """Get usage records for a subscription"""
        
        params = {
            "start_time": start_date.isoformat() + "Z",
            "end_time": end_date.isoformat() + "Z"
        }
        
        query_string = "&".join([f"{k}={v}" for k, v in params.items()])
        return await self._request("GET", f"/v1/billing/subscriptions/{subscription_id}/usage-records?{query_string}")


# ============================================
# WEBHOOK HANDLERS
# ============================================

class PayPalWebhookHandler:
    """Handle incoming PayPal webhook events"""
    
    def __init__(self, paypal_client: PayPalClient):
        self.paypal_client = paypal_client
    
    async def verify_webhook_signature(self, headers: Dict, body: str) -> bool:
        """Verify that webhook came from PayPal"""
        
        # In production, verify the signature using PayPal's verification endpoint
        # For now, return True (implement properly in production)
        
        auth_algo = headers.get("paypal-auth-algo")
        cert_url = headers.get("paypal-cert-url")
        transmission_id = headers.get("paypal-transmission-id")
        transmission_sig = headers.get("paypal-transmission-sig")
        transmission_time = headers.get("paypal-transmission-time")
        
        # Verify using PayPal API
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.paypal_client.config.API_URL}/v1/notifications/verify-webhook-signature",
                headers={"Authorization": f"Bearer {await self.paypal_client._get_access_token()}"},
                json={
                    "auth_algo": auth_algo,
                    "cert_url": cert_url,
                    "transmission_id": transmission_id,
                    "transmission_sig": transmission_sig,
                    "transmission_time": transmission_time,
                    "webhook_id": self.paypal_client.config.WEBHOOK_ID,
                    "webhook_event": json.loads(body) if isinstance(body, str) else body
                }
            )
            
            if response.status_code == 200:
                data = response.json()
                return data.get("verification_status") == "SUCCESS"
            
            return False
    
    async def handle_event(self, event: Dict[str, Any]) -> Dict[str, Any]:
        """Route webhook event to appropriate handler"""
        
        event_type = event.get("event_type")
        
        handlers = {
            "PAYMENT.SALE.COMPLETED": self.handle_payment_completed,
            "BILLING.SUBSCRIPTION.CREATED": self.handle_subscription_created,
            "BILLING.SUBSCRIPTION.ACTIVATED": self.handle_subscription_activated,
            "BILLING.SUBSCRIPTION.CANCELLED": self.handle_subscription_cancelled,
            "BILLING.SUBSCRIPTION.SUSPENDED": self.handle_subscription_suspended,
            "BILLING.SUBSCRIPTION.EXPIRED": self.handle_subscription_expired,
            "BILLING.SUBSCRIPTION.UPDATED": self.handle_subscription_updated,
            "PAYMENT.CAPTURE.COMPLETED": self.handle_payment_captured,
            "PAYMENT.CAPTURE.REFUNDED": self.handle_payment_refunded,
        }
        
        handler = handlers.get(event_type)
        if handler:
            return await handler(event)
        else:
            logger.info(f"Unhandled PayPal webhook event: {event_type}")
            return {"status": "ignored", "event_type": event_type}
    
    async def handle_payment_completed(self, event: Dict[str, Any]) -> Dict[str, Any]:
        """Handle successful payment"""
        resource = event.get("resource", {})
        logger.info(f"Payment completed: {resource.get('id')}")
        
        # Update organization billing status
        # Add to database, send confirmation email, etc.
        
        return {"status": "processed", "event": "payment_completed"}
    
    async def handle_subscription_created(self, event: Dict[str, Any]) -> Dict[str, Any]:
        """Handle new subscription creation"""
        resource = event.get("resource", {})
        logger.info(f"Subscription created: {resource.get('id')}")
        
        # Create organization subscription record
        # Update database with PayPal subscription ID
        
        return {"status": "processed", "event": "subscription_created"}
    
    async def handle_subscription_activated(self, event: Dict[str, Any]) -> Dict[str, Any]:
        """Handle subscription activation"""
        resource = event.get("resource", {})
        logger.info(f"Subscription activated: {resource.get('id')}")
        
        # Activate organization's subscription
        # Update billing status
        
        return {"status": "processed", "event": "subscription_activated"}
    
    async def handle_subscription_cancelled(self, event: Dict[str, Any]) -> Dict[str, Any]:
        """Handle subscription cancellation"""
        resource = event.get("resource", {})
        logger.info(f"Subscription cancelled: {resource.get('id')}")
        
        # Downgrade organization to free tier
        # Send cancellation confirmation
        
        return {"status": "processed", "event": "subscription_cancelled"}
    
    async def handle_subscription_suspended(self, event: Dict[str, Any]) -> Dict[str, Any]:
        """Handle subscription suspension"""
        resource = event.get("resource", {})
        logger.info(f"Subscription suspended: {resource.get('id')}")
        
        # Suspend organization's access
        # Send notification
        
        return {"status": "processed", "event": "subscription_suspended"}
    
    async def handle_subscription_expired(self, event: Dict[str, Any]) -> Dict[str, Any]:
        """Handle subscription expiry"""
        resource = event.get("resource", {})
        logger.info(f"Subscription expired: {resource.get('id')}")
        
        # Downgrade to free tier
        # Send expiry notification
        
        return {"status": "processed", "event": "subscription_expired"}
    
    async def handle_subscription_updated(self, event: Dict[str, Any]) -> Dict[str, Any]:
        """Handle subscription updates (plan change, etc.)"""
        resource = event.get("resource", {})
        logger.info(f"Subscription updated: {resource.get('id')}")
        
        # Update plan information in database
        
        return {"status": "processed", "event": "subscription_updated"}
    
    async def handle_payment_captured(self, event: Dict[str, Any]) -> Dict[str, Any]:
        """Handle captured payment"""
        resource = event.get("resource", {})
        logger.info(f"Payment captured: {resource.get('id')}")
        
        # Record payment in billing system
        # Update invoice status
        
        return {"status": "processed", "event": "payment_captured"}
    
    async def handle_payment_refunded(self, event: Dict[str, Any]) -> Dict[str, Any]:
        """Handle refunded payment"""
        resource = event.get("resource", {})
        logger.info(f"Payment refunded: {resource.get('id')}")
        
        # Record refund in billing system
        # Adjust usage quotas if needed
        
        return {"status": "processed", "event": "payment_refunded"}


# ============================================
# API ENDPOINTS FOR FASTAPI
# ============================================

from fastapi import APIRouter, HTTPException, Request, Header
from pydantic import BaseModel

router = APIRouter(prefix="/billing/paypal", tags=["PayPal Billing"])

class SubscriptionRequest(BaseModel):
    plan_id: str
    return_url: Optional[str] = None

class UsageRecordRequest(BaseModel):
    subscription_id: str
    word_count: int


@router.post("/create-subscription")
async def create_subscription_endpoint(
    request: SubscriptionRequest,
    x_api_key: str = Header(...)
):
    """Create a PayPal subscription for the organization"""
    
    # Validate API key and get organization
    # Get organization email and name from database
    
    paypal_client = PayPalClient()
    
    try:
        result = await paypal_client.create_subscription(
            plan_id=request.plan_id,
            subscriber_email="customer@example.com",  # Get from DB
            subscriber_name="Customer Name"  # Get from DB
        )
        
        return {
            "success": True,
            "subscription_id": result["subscription_id"],
            "approval_url": result["approval_url"]
        }
    
    except Exception as e:
        logger.error(f"Failed to create subscription: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/webhook")
async def paypal_webhook(
    request: Request,
    x_paypal_transmission_id: Optional[str] = Header(None),
    x_paypal_transmission_sig: Optional[str] = Header(None)
):
    """Handle PayPal webhook notifications"""
    
    body = await request.body()
    
    paypal_client = PayPalClient()
    webhook_handler = PayPalWebhookHandler(paypal_client)
    
    # Verify webhook signature (in production)
    # verified = await webhook_handler.verify_webhook_signature(dict(request.headers), body.decode())
    
    # For now, process without verification (add in production!)
    event = await request.json()
    
    result = await webhook_handler.handle_event(event)
    
    return {"status": "received", "result": result}


@router.post("/record-usage")
async def record_usage_endpoint(
    request: UsageRecordRequest,
    x_api_key: str = Header(...)
):
    """Record usage for metered billing"""
    
    paypal_client = PayPalClient()
    
    try:
        result = await paypal_client.record_usage(
            subscription_id=request.subscription_id,
            quantity=request.word_count
        )
        
        return {"success": True, "result": result}
    
    except Exception as e:
        logger.error(f"Failed to record usage: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/subscription/{subscription_id}")
async def get_subscription_endpoint(
    subscription_id: str,
    x_api_key: str = Header(...)
):
    """Get subscription details"""
    
    paypal_client = PayPalClient()
    
    try:
        result = await paypal_client.get_subscription(subscription_id)
        return {"success": True, "subscription": result}
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/subscription/{subscription_id}/cancel")
async def cancel_subscription_endpoint(
    subscription_id: str,
    x_api_key: str = Header(...),
    reason: str = "Cancelled by user"
):
    """Cancel a subscription"""
    
    paypal_client = PayPalClient()
    
    try:
        result = await paypal_client.cancel_subscription(subscription_id, reason)
        return {"success": True, "result": result}
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
