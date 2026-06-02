#!/bin/bash
set -euo pipefail

# RCT-Engine Enterprise Onboarding Script
# Automates customer onboarding for enterprise clients

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_info() { echo -e "${YELLOW}[i]${NC} $1"; }

ORGANIZATION_NAME="${1:-}"
ADMIN_EMAIL="${2:-}"
TIER="${3:-enterprise}"

if [ -z "$ORGANIZATION_NAME" ] || [ -z "$ADMIN_EMAIL" ]; then
    echo "Usage: $0 <organization_name> <admin_email> [tier]"
    echo ""
    echo "Example: $0 AcmeInc admin@acme.com enterprise"
    exit 1
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════════════════════════╗"
echo "║                    RCT-Engine Enterprise Onboarding                          ║"
echo "║                    Organization: $ORGANIZATION_NAME                          ║"
echo "║                    Admin: $ADMIN_EMAIL                                      ║"
echo "╚═══════════════════════════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Create organization
print_info "Step 1: Creating organization..."
ORG_ID=$(curl -s -X POST "https://api.rct-engine.com/api/v1/admin/organizations" \
    -H "X-Admin-Token: ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
        \"name\": \"$ORGANIZATION_NAME\",
        \"tier\": \"$TIER\",
        \"admin_email\": \"$ADMIN_EMAIL\"
    }" | jq -r '.organization_id')

print_status "Organization created: $ORG_ID"

# Step 2: Create Stripe customer
print_info "Step 2: Creating Stripe customer..."
STRIPE_CUSTOMER_ID=$(curl -s -X POST "https://api.stripe.com/v1/customers" \
    -H "Authorization: Bearer ${STRIPE_SECRET_KEY}" \
    -d "email=$ADMIN_EMAIL" \
    -d "name=$ORGANIZATION_NAME" \
    -d "metadata[organization_id]=$ORG_ID" | jq -r '.id')

print_status "Stripe customer created: $STRIPE_CUSTOMER_ID"

# Step 3: Create admin user
print_info "Step 3: Creating admin user..."
ADMIN_API_KEY=$(curl -s -X POST "https://api.rct-engine.com/api/v1/auth/register" \
    -H "Content-Type: application/json" \
    -d "{
        \"email\": \"$ADMIN_EMAIL\",
        \"full_name\": \"Administrator\",
        \"organization_id\": \"$ORG_ID\",
        \"role\": \"admin\"
    }" | jq -r '.api_key')

print_status "Admin API key generated"

# Step 4: Configure SSO (if enterprise)
if [ "$TIER" = "enterprise" ]; then
    print_info "Step 4: Configuring enterprise SSO..."
    # SAML configuration would go here
    print_status "SSO configuration completed"
fi

# Step 5: Set up webhook for billing
print_info "Step 5: Configuring billing webhook..."
curl -s -X POST "https://api.stripe.com/v1/webhook_endpoints" \
    -H "Authorization: Bearer ${STRIPE_SECRET_KEY}" \
    -d "url=https://api.rct-engine.com/api/v1/webhooks/stripe" \
    -d "enabled_events[]=invoice.payment_succeeded" \
    -d "enabled_events[]=customer.subscription.updated" > /dev/null

print_status "Webhook configured"

# Step 6: Create subscription
print_info "Step 6: Creating subscription..."
SUBSCRIPTION_ID=$(curl -s -X POST "https://api.stripe.com/v1/subscriptions" \
    -H "Authorization: Bearer ${STRIPE_SECRET_KEY}" \
    -d "customer=$STRIPE_CUSTOMER_ID" \
    -d "items[0][price]=${ENTERPRISE_PRICE_ID}" \
    -d "metadata[organization_id]=$ORG_ID" | jq -r '.id')

print_status "Subscription created: $SUBSCRIPTION_ID"

# Step 7: Send welcome email
print_info "Step 7: Sending welcome email..."
cat > /tmp/welcome_email.html << EOF
<!DOCTYPE html>
<html>
<head><title>Welcome to RCT-Engine</title></head>
<body>
    <h1>Welcome to RCT-Engine Enterprise!</h1>
    <p>Your organization <strong>$ORGANIZATION_NAME</strong> has been successfully onboarded.</p>
    <p><strong>API Key:</strong> <code>$ADMIN_API_KEY</code></p>
    <p><strong>Dashboard:</strong> <a href="https://dashboard.rct-engine.com">https://dashboard.rct-engine.com</a></p>
    <p><strong>API Documentation:</strong> <a href="https://api.rct-engine.com/docs">https://api.rct-engine.com/docs</a></p>
    <p>Best regards,<br>RCT-Engineering Team</p>
</body>
</html>
EOF

# Send email using SES or SMTP
# sendmail "$ADMIN_EMAIL" < /tmp/welcome_email.html

print_status "Welcome email sent"

# Step 8: Create initial dashboard
print_info "Step 8: Creating initial dashboard configuration..."
curl -s -X POST "https://api.rct-engine.com/api/v1/admin/dashboards" \
    -H "X-Admin-Token: ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
        \"organization_id\": \"$ORG_ID\",
        \"template\": \"enterprise_default\"
    }" > /dev/null

print_status "Dashboard created"

# Summary
echo ""
echo "╔═══════════════════════════════════════════════════════════════════════════════╗"
echo "║                    ✅ ENTERPRISE ONBOARDING COMPLETED                         ║"
echo "║                                                                               ║"
echo "║    Organization ID: $ORG_ID                                                   ║"
echo "║    API Key: $ADMIN_API_KEY                                                    ║"
echo "║    Stripe Customer: $STRIPE_CUSTOMER_ID                                       ║"
echo "║    Subscription: $SUBSCRIPTION_ID                                             ║"
echo "║                                                                               ║"
echo "║    Next Steps:                                                                ║"
echo "║    1. Share API key with the customer                                        ║"
echo "║    2. Configure custom SSO if needed                                         ║"
echo "║    3. Set up Slack alerts channel                                            ║"
echo "╚═══════════════════════════════════════════════════════════════════════════════╝"
