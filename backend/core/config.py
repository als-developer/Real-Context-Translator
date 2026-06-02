from pydantic_settings import BaseSettings
from typing import Optional

class Settings(BaseSettings):
    # Application
    APP_NAME: str = "RCT-Engine Ultimate"
    ENVIRONMENT: str = "production"
    DEBUG: bool = False
    
    # Database
    DATABASE_URL: str = "postgresql://rct_admin:vault_pass_2026@localhost:5432/rct_saas"
    
    # Redis
    REDIS_URL: str = "redis://localhost:6379/0"
    
    # API Security
    SECRET_KEY: str = "your-super-secret-key-change-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440
    
    # Stripe Billing
    STRIPE_SECRET_KEY: str = "sk_live_your_key"
    STRIPE_WEBHOOK_SECRET: str = "whsec_your_webhook_secret"
    
    # AI Providers
    OPENAI_API_KEY: str = ""
    CLAUDE_API_KEY: str = ""
    OPENAI_MODEL: str = "gpt-4-turbo-preview"
    
    # Slack Alerts
    SLACK_WEBHOOK_URL: Optional[str] = None
    
    # Rate Limiting
    RATE_LIMIT_PER_SECOND: int = 50
    RATE_LIMIT_BURST: int = 15
    
    # Monitoring
    PROMETHEUS_PORT: int = 9090
    
    class Config:
        env_file = ".env"

settings = Settings()
