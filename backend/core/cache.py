import redis.asyncio as redis
import pickle
import hashlib
from typing import Optional, Any
from backend.core.config import settings

class RedisCache:
    def __init__(self):
        self.client = None
    
    async def connect(self):
        self.client = await redis.from_url(
            settings.REDIS_URL,
            encoding="utf-8",
            decode_responses=False
        )
    
    async def disconnect(self):
        if self.client:
            await self.client.close()
    
    def _get_key(self, prefix: str, data: Any) -> str:
        """Generate cache key from data hash"""
        key_str = f"{prefix}:{hashlib.md5(str(data).encode()).hexdigest()}"
        return key_str
    
    async def get_cultural_context(self, country_code: str, slang: str) -> Optional[dict]:
        key = f"cultural:{country_code}:{slang}"
        data = await self.client.get(key)
        if data:
            return pickle.loads(data)
        return None
    
    async def set_cultural_context(self, country_code: str, slang: str, value: dict, ttl: int = 86400):
        key = f"cultural:{country_code}:{slang}"
        await self.client.setex(key, ttl, pickle.dumps(value))
    
    async def get_translation(self, source_hash: str) -> Optional[str]:
        key = f"translation:{source_hash}"
        return await self.client.get(key)
    
    async def set_translation(self, source_hash: str, translation: str, ttl: int = 3600):
        key = f"translation:{source_hash}"
        await self.client.setex(key, ttl, translation)
    
    async def invalidate_country_cache(self, country_code: str):
        pattern = f"cultural:{country_code}:*"
        keys = await self.client.keys(pattern)
        if keys:
            await self.client.delete(*keys)

cache = RedisCache()
