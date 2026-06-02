from pydantic import BaseModel, Field, field_validator
from typing import List, Optional, Literal

class TranslateRequest(BaseModel):
    source_text: str = Field(..., min_length=1, max_length=50000, description="Text to translate")
    source_language: str = Field(..., min_length=2, max_length=5, description="ISO code e.g., 'sw', 'en', 'zh'")
    target_country: str = Field(..., min_length=2, max_length=5, description="ISO country code e.g., 'KE', 'SA', 'CN'")
    target_language: str = Field(..., min_length=2, max_length=5)
    industry_vertical: Optional[Literal["marketing", "legal", "medical", "technical", "diplomatic"]] = "marketing"
    preserve_tone: Optional[bool] = True
    detect_slang: Optional[bool] = True
    
    @field_validator('source_text')
    def validate_text(cls, v):
        if len(v.strip()) == 0:
            raise ValueError('Text cannot be empty')
        return v

class BatchTranslateRequest(BaseModel):
    texts: List[TranslateRequest] = Field(..., max_items=100)
    webhook_url: Optional[str] = None

class CulturalIngestionRequest(BaseModel):
    country_code: str
    language_code: str
    slang_term: str
    literal_meaning: str
    true_cultural_context: str
    business_risk_level: Literal["LOW", "MEDIUM", "CRITICAL"]
