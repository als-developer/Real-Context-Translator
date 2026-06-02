from celery import shared_task
import asyncio
from typing import List, Dict
import uuid

from backend.services.translation_service import TranslationService
from backend.services.cultural_ai_service import CulturalAIService

@shared_task(name="batch_translate", bind=True, max_retries=3)
def batch_translate(self, texts: List[Dict], organization_id: str, webhook_url: str = None):
    """Process batch translation requests"""
    results = []
    failed = []
    
    for idx, item in enumerate(texts):
        try:
            # Run async translation in sync context
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            
            result = loop.run_until_complete(
                TranslationService.translate_with_context(
                    text=item["source_text"],
                    source_lang=item["source_language"],
                    target_lang=item["target_language"],
                    target_country=item["target_country"],
                    industry=item.get("industry", "marketing")
                )
            )
            loop.close()
            
            results.append({
                "index": idx,
                "success": True,
                "translation": result.text,
                "risk_level": result.risk_level
            })
            
        except Exception as e:
            failed.append({"index": idx, "error": str(e)})
            results.append({"index": idx, "success": False, "error": str(e)})
    
    # Send webhook notification if provided
    if webhook_url:
        import httpx
        httpx.post(webhook_url, json={
            "batch_id": str(uuid.uuid4()),
            "completed_at": str(uuid.uuid4()),
            "total": len(texts),
            "successful": len([r for r in results if r.get("success")]),
            "failed": len(failed),
            "results": results
        })
    
    return {
        "batch_id": str(uuid.uuid4()),
        "total": len(texts),
        "successful": len([r for r in results if r.get("success")]),
        "failed": len(failed),
        "results": results
    }
