# RCT-Engine User Guide

## Getting Started

### Creating an Account

1. Visit [https://dashboard.rct-engine.com](https://dashboard.rct-engine.com)
2. Click "Contact Sales" for enterprise access
3. Receive your API key via email
4. Log in to the dashboard

### Your First Translation

#### Using the Web Dashboard

1. Navigate to the **Translator** tab
2. Enter your text in the source box
3. Select source language (e.g., English)
4. Select target country (e.g., Kenya)
5. Select target language (e.g., Swahili)
6. Click **Translate with Cultural Context**

#### Using the API

```bash
curl -X POST https://api.rct-engine.com/api/v1/translate \
  -H "X-API-Key: your_api_key" \
  -H "Content-Type: application/json" \
  -d '{
    "source_text": "Hello, how are you?",
    "source_language": "en",
    "target_country": "KE",
    "target_language": "sw"
  }'
