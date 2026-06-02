from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
import time
import logging
from backend.models.audit import AuditLog

logger = logging.getLogger("audit")

class AuditMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        start_time = time.time()
        
        # Get request details
        method = request.method
        path = request.url.path
        client_ip = request.client.host
        user_agent = request.headers.get("User-Agent", "")
        org_id = request.headers.get("X-Organization-ID")
        
        # Skip health checks
        if path == "/health":
            return await call_next(request)
        
        try:
            response = await call_next(request)
            duration_ms = (time.time() - start_time) * 1000
            
            # Log audit entry
            audit_entry = {
                "timestamp": time.time(),
                "method": method,
                "path": path,
                "status_code": response.status_code,
                "client_ip": client_ip,
                "user_agent": user_agent,
                "organization_id": org_id,
                "duration_ms": duration_ms,
                "request_id": getattr(request.state, "request_id", None)
            }
            
            logger.info(audit_entry)
            return response
            
        except Exception as e:
            duration_ms = (time.time() - start_time) * 1000
            logger.error({
                "error": str(e),
                "method": method,
                "path": path,
                "duration_ms": duration_ms,
                "client_ip": client_ip
            })
            raise
