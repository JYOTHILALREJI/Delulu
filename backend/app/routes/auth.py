from datetime import timedelta
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession
import logging

from app.database import get_db
from app.schemas.user import (
    UserSignUp,
    UserLogin,
    GoogleAuthRequest,
    TokenResponse,
    UserResponse,
    UserDetailResponse,
    MessageResponse,
    PasswordChangeRequest,
    PasswordResetRequest,
    PasswordResetConfirm,
    EmailVerificationRequest,
    EmailVerificationConfirm,
    UserUpdate,
)
from app.services.auth_service import AuthService
from app.utils.security import decode_access_token, JWTError
from app.config import settings

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/auth", tags=["Authentication"])
security = HTTPBearer()


async def get_current_user_id(
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> str:
    """
    Dependency to get current user ID from JWT token.
    
    Raises:
        HTTPException: If token is invalid or expired
    """
    try:
        token = credentials.credentials
        payload = decode_access_token(token)
        user_id = payload.get("sub")
        
        if user_id is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid authentication credentials",
                headers={"WWW-Authenticate": "Bearer"},
            )
        
        return user_id
    
    except JWTError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid token: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )


# ==========================================
# Authentication Endpoints
# ==========================================

@router.post(
    "/signup",
    response_model=TokenResponse,
    status_code=status.HTTP_201_CREATED,
    responses={
        400: {"model": MessageResponse},
        409: {"model": MessageResponse},
    },
    summary="Register a new user",
    description="Create a new user account with email and password"
)
async def signup(
    user_data: UserSignUp,
    db: AsyncSession = Depends(get_db),
):
    """Register a new user."""
    try:
        auth_service = AuthService(db)
        user, token = await auth_service.signup(user_data)
        
        return TokenResponse(
            access_token=token,
            token_type="bearer",
            expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
            user=UserResponse(**user.to_dict()),
        )
    
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )
    except Exception as e:
        logger.error(f"Signup error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="An error occurred during registration",
        )


@router.post(
    "/login",
    response_model=TokenResponse,
    responses={
        401: {"model": MessageResponse},
    },
    summary="Login user",
    description="Authenticate user with email and password"
)
async def login(
    login_data: UserLogin,
    db: AsyncSession = Depends(get_db),
):
    """Login user with email and password."""
    try:
        auth_service = AuthService(db)
        user, token = await auth_service.login(login_data)
        
        return TokenResponse(
            access_token=token,
            token_type="bearer",
            expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
            user=UserResponse(**user.to_dict()),
        )
    
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e),
        )
    except Exception as e:
        logger.error(f"Login error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="An error occurred during login",
        )


@router.post(
    "/google",
    response_model=TokenResponse,
    responses={
        401: {"model": MessageResponse},
    },
    summary="Google authentication",
    description="Authenticate or register user with Google via Firebase"
)
async def google_auth(
    auth_data: GoogleAuthRequest,
    db: AsyncSession = Depends(get_db),
):
    """Authenticate with Google via Firebase token."""
    try:
        auth_service = AuthService(db)
        user, token, is_new_user = await auth_service.google_auth(auth_data)
        
        return TokenResponse(
            access_token=token,
            token_type="bearer",
            expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
            user=UserResponse(**user.to_dict()),
        )
    
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e),
        )
    except Exception as e:
        logger.error(f"Google auth error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="An error occurred during Google authentication",
        )


# ==========================================
# User Profile Endpoints
# ==========================================

@router.get(
    "/me",
    response_model=UserDetailResponse,
    responses={
        401: {"model": MessageResponse},
    },
    summary="Get current user",
    description="Get the profile of the currently authenticated user"
)
async def get_current_user(
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Get current user profile."""
    try:
        auth_service = AuthService(db)
        user = await auth_service.get_current_user(user_id)
        
        user_dict = user.to_dict()
        user_dict["full_name"] = user.full_name
        
        return UserDetailResponse(**user_dict)
    
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        )


@router.put(
    "/me",
    response_model=UserResponse,
    responses={
        401: {"model": MessageResponse},
        400: {"model": MessageResponse},
    },
    summary="Update profile",
    description="Update the profile of the currently authenticated user"
)
async def update_profile(
    update_data: UserUpdate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Update current user profile."""
    try:
        auth_service = AuthService(db)
        user = await auth_service.update_profile(user_id, update_data)
        
        return UserResponse(**user.to_dict())
    
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


# ==========================================
# Password Management Endpoints
# ==========================================

@router.post(
    "/change-password",
    response_model=MessageResponse,
    responses={
        401: {"model": MessageResponse},
        400: {"model": MessageResponse},
    },
    summary="Change password",
    description="Change the password of the currently authenticated user"
)
async def change_password(
    password_data: PasswordChangeRequest,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Change user password."""
    try:
        auth_service = AuthService(db)
        await auth_service.change_password(
            user_id,
            password_data.current_password,
            password_data.new_password,
        )
        
        return MessageResponse(message="Password changed successfully")
    
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


@router.post(
    "/forgot-password",
    response_model=MessageResponse,
    responses={
        400: {"model": MessageResponse},
    },
    summary="Request password reset",
    description="Request a password reset email"
)
async def request_password_reset(
    request_data: PasswordResetRequest,
    db: AsyncSession = Depends(get_db),
):
    """Request password reset."""
    try:
        auth_service = AuthService(db)
        await auth_service.request_password_reset(request_data.email)
        
        # Always return success to prevent email enumeration
        return MessageResponse(
            message="If an account with this email exists, a password reset link has been sent"
        )
    
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


@router.post(
    "/reset-password",
    response_model=MessageResponse,
    responses={
        400: {"model": MessageResponse},
    },
    summary="Reset password",
    description="Reset password using the token from email"
)
async def reset_password(
    reset_data: PasswordResetConfirm,
    db: AsyncSession = Depends(get_db),
):
    """Reset password with token."""
    try:
        auth_service = AuthService(db)
        await auth_service.confirm_password_reset(
            reset_data.token,
            reset_data.new_password,
        )
        
        return MessageResponse(message="Password reset successfully")
    
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


# ==========================================
# Email Verification Endpoints
# ==========================================

@router.post(
    "/verify-email/request",
    response_model=MessageResponse,
    responses={
        400: {"model": MessageResponse},
    },
    summary="Request email verification",
    description="Request a new email verification email"
)
async def request_email_verification(
    request_data: EmailVerificationRequest,
    db: AsyncSession = Depends(get_db),
):
    """Request email verification."""
    try:
        auth_service = AuthService(db)
        await auth_service.request_email_verification(request_data.email)
        
        return MessageResponse(message="Verification email sent")
    
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


@router.post(
    "/verify-email/confirm",
    response_model=MessageResponse,
    responses={
        400: {"model": MessageResponse},
    },
    summary="Confirm email verification",
    description="Verify email using the token from email"
)
async def confirm_email_verification(
    verify_data: EmailVerificationConfirm,
    db: AsyncSession = Depends(get_db),
):
    """Confirm email verification."""
    try:
        auth_service = AuthService(db)
        await auth_service.confirm_email_verification(verify_data.token)
        
        return MessageResponse(message="Email verified successfully")
    
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


# ==========================================
# Account Management Endpoints
# ==========================================

@router.delete(
    "/me",
    response_model=MessageResponse,
    responses={
        401: {"model": MessageResponse},
    },
    summary="Delete account",
    description="Delete the currently authenticated user's account"
)
async def delete_account(
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Delete user account."""
    try:
        auth_service = AuthService(db)
        await auth_service.delete_account(user_id)
        
        return MessageResponse(message="Account deleted successfully")
    
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


@router.post(
    "/logout",
    response_model=MessageResponse,
    summary="Logout user",
    description="Logout the currently authenticated user"
)
async def logout(
    user_id: str = Depends(get_current_user_id),
):
    """Logout user (client should discard token)."""
    # In a stateless JWT setup, we just return success
    # For real token invalidation, you'd use a token blacklist in Redis
    return MessageResponse(message="Logged out successfully")