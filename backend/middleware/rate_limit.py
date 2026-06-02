from fastapi import Request, HTTPException
from starlette.middleware.base import BaseHTTPMiddleware
from backend.core.rate_limiter import rate_limiter
import time

class RateLimitMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        # Get client identifier (API key or IP)
        api_key = request.headers.get("X-API-Key")
        client_ip = request.client.host
        key = api_key or client_ip
        
        # Check rate limit
        allowed, remaining = rate_limiter.is_allowed(key)
        
        if not allowed:
            raise HTTPException(
                status_code=429,
                detail={
                    "error": "Rate limit exceeded",
                    "retry_after_ms": remaining,
                    "limit": 50
                }
            )
        
        response = await call_next(request)
        response.headers["X-RateLimit-Remaining"] = str(remaining)
        return response
