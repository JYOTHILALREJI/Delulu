from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel, EmailStr, Field, validator
import re


# ==========================================
# Base Schemas
# ==========================================

class UserBase(BaseModel):
    """Base user schema with common fields."""
    email: EmailStr
    username: Optional[str] = None
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    display_name: Optional[str] = None
    profile_picture: Optional[str] = None
    bio: Optional[str] = None
    phone_number: Optional[str] = None


# ==========================================
# Auth Schemas
# ==========================================

class UserSignUp(BaseModel):
    """Schema for user signup."""
    email: EmailStr
    password: str = Field(
        min_length=8,
        max_length=100,
        description="Password must be at least 8 characters"
    )
    confirm_password: str
    username: Optional[str] = Field(None, min_length=3, max_length=50)
    first_name: Optional[str] = Field(None, max_length=100)
    last_name: Optional[str] = Field(None, max_length=100)
    
    @validator('password')
    def validate_password(cls, v):
        """Validate password strength."""
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        if not re.search(r"[A-Z]", v):
            raise ValueError("Password must contain at least one uppercase letter")
        if not re.search(r"[a-z]", v):
            raise ValueError("Password must contain at least one lowercase letter")
        if not re.search(r"\d", v):
            raise ValueError("Password must contain at least one digit")
        return v
    
    @validator('confirm_password')
    def passwords_match(cls, v, values):
        """Ensure passwords match."""
        if 'password' in values and v != values['password']:
            raise ValueError("Passwords do not match")
        return v
    
    @validator('username')
    def validate_username(cls, v):
        """Validate username format."""
        if v:
            if not re.match(r"^[a-zA-Z0-9_]+$", v):
                raise ValueError("Username can only contain letters, numbers, and underscores")
            if v.startswith("_") or v.endswith("_"):
                raise ValueError("Username cannot start or end with underscore")
        return v


class UserLogin(BaseModel):
    """Schema for user login."""
    email: EmailStr
    password: str


class GoogleAuthRequest(BaseModel):
    """Schema for Google OAuth authentication."""
    id_token: str = Field(..., description="Firebase ID token")
    display_name: Optional[str] = None
    username: Optional[str] = None


class RefreshTokenRequest(BaseModel):
    """Schema for token refresh."""
    refresh_token: str


# ==========================================
# Response Schemas
# ==========================================

class TokenResponse(BaseModel):
    """Schema for authentication token response."""
    access_token: str
    token_type: str = "bearer"
    expires_in: int
    user: "UserResponse"


class UserResponse(BaseModel):
    """Schema for user response."""
    id: str
    email: str
    username: Optional[str]
    first_name: Optional[str]
    last_name: Optional[str]
    display_name: Optional[str]
    profile_picture: Optional[str]
    bio: Optional[str]
    phone_number: Optional[str]
    auth_provider: str
    is_active: bool
    is_verified: bool
    status: str
    last_login_at: Optional[datetime]
    created_at: Optional[datetime]
    
    class Config:
        from_attributes = True


class UserDetailResponse(UserResponse):
    """Detailed user response."""
    full_name: Optional[str]
    
    class Config:
        from_attributes = True


class MessageResponse(BaseModel):
    """Simple message response."""
    message: str
    success: bool = True


class PasswordChangeRequest(BaseModel):
    """Schema for password change."""
    current_password: str
    new_password: str = Field(min_length=8, max_length=100)
    confirm_password: str
    
    @validator('new_password')
    def validate_password(cls, v):
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        if not re.search(r"[A-Z]", v):
            raise ValueError("Password must contain at least one uppercase letter")
        if not re.search(r"[a-z]", v):
            raise ValueError("Password must contain at least one lowercase letter")
        if not re.search(r"\d", v):
            raise ValueError("Password must contain at least one digit")
        return v
    
    @validator('confirm_password')
    def passwords_match(cls, v, values):
        if 'new_password' in values and v != values['new_password']:
            raise ValueError("Passwords do not match")
        return v


class PasswordResetRequest(BaseModel):
    """Schema for password reset request."""
    email: EmailStr


class PasswordResetConfirm(BaseModel):
    """Schema for password reset confirmation."""
    token: str
    new_password: str = Field(min_length=8, max_length=100)
    confirm_password: str
    
    @validator('confirm_password')
    def passwords_match(cls, v, values):
        if 'new_password' in values and v != values['new_password']:
            raise ValueError("Passwords do not match")
        return v


class EmailVerificationRequest(BaseModel):
    """Schema for email verification request."""
    email: EmailStr


class EmailVerificationConfirm(BaseModel):
    """Schema for email verification confirmation."""
    token: str


class UserUpdate(BaseModel):
    """Schema for updating user profile."""
    username: Optional[str] = Field(None, min_length=3, max_length=50)
    first_name: Optional[str] = Field(None, max_length=100)
    last_name: Optional[str] = Field(None, max_length=100)
    display_name: Optional[str] = Field(None, max_length=100)
    bio: Optional[str] = Field(None, max_length=500)
    phone_number: Optional[str] = Field(None, max_length=20)
    profile_picture: Optional[str] = None


# Update forward references
TokenResponse.model_rebuild()