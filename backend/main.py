from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from prometheus_fastapi_instrumentator import Instrumentator
import time
import uuid

from backend.api.v1.endpoints import translate, auth, billing, analytics, admin, webhooks
from backend.core.config import settings
from backend.core.logging import setup_logging
from backend.middleware.rate_limit import RateLimitMiddleware
from backend.middleware.audit import AuditMiddleware

# Initialize app
app = FastAPI(
    title="RCT-Engine Ultimate",
    description="Real Context Translator - Cross-Border Cultural Intelligence Platform",
    version="3.0.0",
    docs_url="/api/docs",
    redoc_url="/api/redoc"
)

# Setup logging
setup_logging()

# Add middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_middleware(TrustedHostMiddleware, allowed_hosts=settings.ALLOWED_HOSTS)
app.add_middleware(RateLimitMiddleware)
app.add_middleware(AuditMiddleware)

# Request ID middleware
@app.middleware("http")
async def add_request_id(request: Request, call_next):
    request_id = str(uuid.uuid4())
    request.state.request_id = request_id
    response = await call_next(request)
    response.headers["X-Request-ID"] = request_id
    return response

# Metrics
Instrumentator().instrument(app).expose(app, endpoint="/metrics")

# Health check
@app.get("/health")
async def health_check():
    return {"status": "healthy", "version": "3.0.0", "environment": settings.ENVIRONMENT}

# Include routers
app.include_router(auth.router, prefix="/api/v1")
app.include_router(translate.router, prefix="/api/v1")
app.include_router(billing.router, prefix="/api/v1")
app.include_router(analytics.router, prefix="/api/v1")
app.include_router(admin.router, prefix="/api/v1")
app.include_router(webhooks.router, prefix="/api/v1")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
