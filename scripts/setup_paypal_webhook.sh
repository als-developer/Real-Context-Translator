#!/bin/bash
# Script ya kuweka PayPal Webhook moja kwa moja

set -euo pipefail

echo "🔧 Setting up PayPal Webhook for RCT-Engine"
echo "============================================"

# Load environment variables
source .env

if [ -z "${PAYPAL_CLIENT_ID:-}" ] || [ -z "${PAYPAL_SECRET_KEY:-}" ]; then
    echo "❌ PayPal credentials not set in .env"
    exit 1
fi

# Get access token
echo "Getting access token..."
AUTH_STRING=$(echo -n "${PAYPAL_CLIENT_ID}:${PAYPAL_SECRET_KEY}" | base64)

ACCESS_TOKEN=$(curl -s -X POST "https://api-m.sandbox.paypal.com/v1/oauth2/token" \
    -H "Authorization: Basic ${AUTH_STRING}" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=client_credentials" | jq -r '.access_token')

if [ "$ACCESS_TOKEN" = "null" ] || [ -z "$ACCESS_TOKEN" ]; then
    echo "❌ Failed to get access token"
    exit 1
fi

# Create webhook
echo "Creating webhook..."
WEBHOOK_URL="https://api.rct-engine.com/api/v1/billing/paypal/webhook"

WEBHOOK_RESPONSE=$(curl -s -X POST "https://api-m.sandbox.paypal.com/v1/notifications/webhooks" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
        \"url\": \"${WEBHOOK_URL}\",
        \"event_types\": [
            {\"name\": \"PAYMENT.SALE.COMPLETED\"},
            {\"name\": \"BILLING.SUBSCRIPTION.CREATED\"},
            {\"name\": \"BILLING.SUBSCRIPTION.ACTIVATED\"},
            {\"name\": \"BILLING.SUBSCRIPTION.CANCELLED\"},
            {\"name\": \"BILLING.SUBSCRIPTION.SUSPENDED\"},
            {\"name\": \"BILLING.SUBSCRIPTION.EXPIRED\"},
            {\"name\": \"BILLING.SUBSCRIPTION.UPDATED\"},
            {\"name\": \"PAYMENT.CAPTURE.COMPLETED\"},
            {\"name\": \"PAYMENT.CAPTURE.REFUNDED\"}
        ]
    }")

WEBHOOK_ID=$(echo "$WEBHOOK_RESPONSE" | jq -r '.id')

if [ "$WEBHOOK_ID" != "null" ] && [ -n "$WEBHOOK_ID" ]; then
    echo "✅ Webhook created successfully!"
    echo "   Webhook ID: $WEBHOOK_ID"
    echo ""
    echo "Add this to your .env file:"
    echo "PAYPAL_WEBHOOK_ID=$WEBHOOK_ID"
else
    echo "❌ Failed to create webhook"
    echo "$WEBHOOK_RESPONSE"
    exit 1
fi

# Test webhook (simulate)
echo ""
echo "Testing webhook..."

TEST_RESPONSE=$(curl -s -X POST "https://api-m.sandbox.paypal.com/v1/notifications/simulate-event" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
        \"webhook_id\": \"${WEBHOOK_ID}\",
        \"event_type\": \"PAYMENT.SALE.COMPLETED\"
    }")

if echo "$TEST_RESPONSE" | grep -q "SUCCESS"; then
    echo "✅ Webhook test successful!"
else
    echo "⚠️ Webhook test may have issues"
fi

echo ""
echo "============================================"
echo "✅ PayPal webhook setup complete!"
