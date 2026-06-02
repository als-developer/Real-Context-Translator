# PayPal Integration Guide for RCT-Engine

## ⚠️ IMPORTANT SECURITY NOTICE

**NEVER commit API keys to version control!**

Always use:
- Environment variables (`.env` file, never committed)
- Secrets managers (AWS Secrets Manager, HashiCorp Vault)
- CI/CD secrets (GitHub Secrets, GitLab CI variables)

---

## Setup Instructions

### 1. Create PayPal Developer Account

1. Go to [https://developer.paypal.com](https://developer.paypal.com)
2. Create a developer account
3. Go to "Dashboard" → "My Apps & Credentials"

### 2. Create REST API App

1. Click "Create App"
2. Name: `RCT-Engine Production`
3. Select "Live" or "Sandbox"
4. Copy **Client ID** and **Secret**

### 3. Configure Environment

```bash
# Add to your .env file (NEVER commit this file!)
export PAYPAL_MODE=sandbox
export PAYPAL_CLIENT_ID=your_client_id_here
export PAYPAL_SECRET_KEY=your_secret_key_here
export PAYPAL_RETURN_URL=https://dashboard.rct-engine.com/billing/success
export PAYPAL_CANCEL_URL=https://dashboard.rct-engine.com/billing/cancel
