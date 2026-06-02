import httpx
from typing import List, Optional
from dataclasses import dataclass
from backend.core.config import settings

@dataclass
class CulturalAnalysisResult:
    risk_level: str
    detected_slangs: List[str]
    explanation: str
    recommended_fix: Optional[str] = None

class CulturalAIService:
    CULTURAL_SYSTEM_PROMPT = """
    You are an expert in cross-cultural communication and business localization.
    Analyze the given text for:
    1. Slang expressions that may not translate literally
    2. Cultural taboos or offensive content in the target country
    3. Business risks (religious, political, social sensitivities)
    
    Return JSON with: risk_level (LOW/MEDIUM/CRITICAL), detected_slangs (list), explanation, recommended_fix
    """
    
    @classmethod
    async def analyze_cultural_risk(
        cls,
        text: str,
        target_country: str,
        source_language: str
    ) -> CulturalAnalysisResult:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                "https://api.openai.com/v1/chat/completions",
                headers={"Authorization": f"Bearer {settings.OPENAI_API_KEY}"},
                json={
                    "model": settings.OPENAI_MODEL,
                    "messages": [
                        {"role": "system", "content": cls.CULTURAL_SYSTEM_PROMPT},
                        {"role": "user", "content": f"Target country: {target_country}\nSource language: {source_language}\nText: {text}"}
                    ],
                    "response_format": {"type": "json_object"},
                    "temperature": 0.3
                },
                timeout=5.0
            )
            
            if response.status_code == 200:
                result = response.json()
                content = result["choices"][0]["message"]["content"]
                import json
                data = json.loads(content)
                return CulturalAnalysisResult(
                    risk_level=data.get("risk_level", "LOW"),
                    detected_slangs=data.get("detected_slangs", []),
                    explanation=data.get("explanation", ""),
                    recommended_fix=data.get("recommended_fix", None)
                )
            
            # Fallback: return safe if AI fails
            return CulturalAnalysisResult(
                risk_level="LOW",
                detected_slangs=[],
                explanation="AI analysis unavailable, proceeding with caution."
            )
