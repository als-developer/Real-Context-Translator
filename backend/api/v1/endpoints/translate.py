from fastapi import APIRouter, HTTPException, BackgroundTasks, Header
from typing import Optional
import uuid
import time

from backend.schemas.request import TranslateRequest
from backend.services.translation_service import TranslationService
from backend.services.cultural_ai_service import CulturalAIService
from backend.services.billing_service import BillingService
from backend.core.rate_limiter import rate_limiter

router = APIRouter(prefix="/translate", tags=["Translation"])

@router.post("/")
async def translate_text(
    request: TranslateRequest,
    background_tasks: BackgroundTasks,
    x_api_key: Optional[str] = Header(None),
    x_organization: Optional[str] = Header(None)
):
    # Rate limiting check
    if not rate_limiter.is_allowed(x_api_key or "anonymous"):
        raise HTTPException(status_code=429, detail="Rate limit exceeded")
    
    # Validate API key and get organization
    if not x_api_key:
        raise HTTPException(status_code=401, detail="API key required")
    
    start_time = time.perf_counter()
    
    # Step 1: Detect cultural risks
    cultural_check = await CulturalAIService.analyze_cultural_risk(
        text=request.source_text,
        target_country=request.target_country,
        source_language=request.source_language
    )
    
    if cultural_check.risk_level == "CRITICAL":
        return {
            "translation_id": f"rct_{uuid.uuid4().hex[:12]}",
            "adapted_text": None,
            "cultural_intelligence": {
                "risk_verdict": "BLOCKED",
                "reason": cultural_check.explanation,
                "recommended_action": "REWRITE_CAMPAIGN"
            },
            "telemetry": {"latency_ms": int((time.perf_counter() - start_time) * 1000)}
        }
    
    # Step 2: Perform context-aware translation
    translation = await TranslationService.translate_with_context(
        text=request.source_text,
        source_lang=request.source_language,
        target_lang=request.target_language,
        target_country=request.target_country,
        industry=request.industry_vertical,
        cultural_context=cultural_check
    )
    
    # Step 3: Track billing asynchronously
    background_tasks.add_task(
        BillingService.record_usage,
        api_key=x_api_key,
        word_count=len(request.source_text.split()),
        organization_id=x_organization
    )
    
    return {
        "translation_id": f"rct_{uuid.uuid4().hex[:12]}",
        "adapted_text": translation.text,
        "cultural_intelligence": {
            "slang_detected": cultural_check.detected_slangs,
            "risk_matrix_rating": cultural_check.risk_level,
            "cultural_explanation": cultural_check.explanation
        },
        "telemetry": {"latency_ms": int((time.perf_counter() - start_time) * 1000)}
    }
