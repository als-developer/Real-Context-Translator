from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, EmailStr
from datetime import timedelta
import secrets

from backend.core.security import create_access_token, verify_password, get_password_hash
from backend.core.config import settings
from backend.models.user import User, UserRole

router = APIRouter(prefix="/auth", tags=["Authentication"])
security = HTTPBearer()

class LoginRequest(BaseModel):
    email: EmailStr
    password: str

class RegisterRequest(BaseModel):
    email: EmailStr
    password: str
    full_name: str
    organization_name: str

class APIKeyResponse(BaseModel):
    api_key: str
    message: str

@router.post("/login")
async def login(request: LoginRequest):
    # In production, fetch from database
    # This is a mock implementation
    if request.email == "admin@example.com" and request.password == "password":
        access_token = create_access_token(
            data={"sub": request.email, "role": "admin"},
            expires_delta=timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
        )
        return {"access_token": access_token, "token_type": "bearer"}
    
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid credentials"
    )

@router.post("/register", response_model=APIKeyResponse)
async def register(request: RegisterRequest):
    # Generate API key
    api_key = f"rct_{secrets.token_urlsafe(32)}"
    
    # In production, save to database
    return {
        "api_key": api_key,
        "message": "Organization and user created successfully"
    }

@router.post("/rotate-key")
async def rotate_api_key(credentials: HTTPAuthorizationCredentials = Depends(security)):
    new_api_key = f"rct_{secrets.token_urlsafe(32)}"
    return {"api_key": new_api_key}
