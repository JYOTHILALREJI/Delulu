from datetime import datetime
from typing import Optional, Tuple
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
import logging

from app.models.user import User, AuthProvider, UserStatus
from app.schemas.user import (
    UserSignUp,
    UserLogin,
    GoogleAuthRequest,
    UserResponse,
    TokenResponse,
    UserUpdate,
)
from app.utils.security import (
    verify_password,
    get_password_hash,
    create_access_token,
    generate_verification_token,
    verify_verification_token,
    generate_password_reset_token,
    verify_password_reset_token,
)
from app.utils.firebase import verify_firebase_token, get_firebase_user
from app.config import settings

logger = logging.getLogger(__name__)


class AuthService:
    """Service class for authentication operations."""
    
    def __init__(self, db: AsyncSession):
        self.db = db
    
    async def signup(self, user_data: UserSignUp) -> Tuple[User, str]:
        """
        Register a new user with email and password.
        
        Returns:
            Tuple[User, str]: Created user and access token
        """
        # Check if email already exists
        existing_user = await self._get_user_by_email(user_data.email)
        if existing_user:
            raise ValueError("Email already registered")
        
        # Check if username exists (if provided)
        if user_data.username:
            existing_username = await self._get_user_by_username(user_data.username)
            if existing_username:
                raise ValueError("Username already taken")
        
        # Create user
        user = User(
            email=user_data.email,
            password_hash=get_password_hash(user_data.password),
            username=user_data.username,
            first_name=user_data.first_name,
            last_name=user_data.last_name,
            display_name=user_data.display_name or (
                f"{user_data.first_name} {user_data.last_name}".strip() 
                if user_data.first_name or user_data.last_name 
                else None
            ),
            auth_provider=AuthProvider.EMAIL,
            is_verified=False,  # Email verification required
            status=UserStatus.ACTIVE,
        )
        
        self.db.add(user)
        await self.db.flush()
        await self.db.refresh(user)
        
        # Generate access token
        access_token = create_access_token({"sub": str(user.id), "email": user.email})
        
        logger.info(f"New user registered: {user.email}")
        
        return user, access_token
    
    async def login(self, login_data: UserLogin) -> Tuple[User, str]:
        """
        Authenticate user with email and password.
        
        Returns:
            Tuple[User, str]: User and access token
        """
        # Get user by email
        user = await self._get_user_by_email(login_data.email)
        if not user:
            raise ValueError("Invalid email or password")
        
        # Check if user is active
        if not user.is_active or user.status != UserStatus.ACTIVE:
            raise ValueError("Account is not active")
        
        # Verify password (only for email auth users)
        if user.auth_provider == AuthProvider.EMAIL:
            if not user.password_hash:
                raise ValueError("Please login with your social account")
            if not verify_password(login_data.password, user.password_hash):
                raise ValueError("Invalid email or password")
        else:
            raise ValueError(f"Please login with {user.auth_provider.value}")
        
        # Update last login
        user.last_login_at = datetime.utcnow()
        await self.db.flush()
        
        # Generate access token
        access_token = create_access_token({"sub": str(user.id), "email": user.email})
        
        logger.info(f"User logged in: {user.email}")
        
        return user, access_token
    
    async def google_auth(self, auth_data: GoogleAuthRequest) -> Tuple[User, str, bool]:
        """
        Authenticate or register user with Google (via Firebase).
        
        Returns:
            Tuple[User, str, bool]: User, access token, and is_new_user flag
        """
        # Verify Firebase token
        firebase_data = verify_firebase_token(auth_data.id_token)
        firebase_uid = firebase_data.get("uid")
        firebase_email = firebase_data.get("email")
        
        if not firebase_email:
            raise ValueError("Email not available from Google account")
        
        # Get detailed Firebase user info
        firebase_user = get_firebase_user(firebase_uid)
        
        # Check if user exists
        user = await self._get_user_by_firebase_uid(firebase_uid)
        
        is_new_user = False
        
        if user:
            # Existing user - update last login
            user.last_login_at = datetime.utcnow()
            
            # Update profile picture if changed
            if firebase_user.get("photo_url") and firebase_user["photo_url"] != user.profile_picture:
                user.profile_picture = firebase_user["photo_url"]
            
            await self.db.flush()
        else:
            # Check if email exists with different provider
            existing_email_user = await self._get_user_by_email(firebase_email)
            if existing_email_user:
                # Link accounts
                existing_email_user.firebase_uid = firebase_uid
                existing_email_user.auth_provider = AuthProvider.GOOGLE
                existing_email_user.is_verified = True
                existing_email_user.last_login_at = datetime.utcnow()
                
                if firebase_user.get("photo_url"):
                    existing_email_user.profile_picture = firebase_user["photo_url"]
                
                user = existing_email_user
            else:
                # Create new user
                is_new_user = True
                
                # Generate username if not provided
                username = auth_data.username
                if not username:
                    base_username = firebase_email.split("@")[0].replace(".", "_").lower()
                    username = await self._generate_unique_username(base_username)
                
                # Get display name
                display_name = (
                    auth_data.display_name or 
                    firebase_user.get("display_name") or 
                    username
                )
                
                user = User(
                    email=firebase_email,
                    firebase_uid=firebase_uid,
                    username=username,
                    display_name=display_name,
                    profile_picture=firebase_user.get("photo_url"),
                    auth_provider=AuthProvider.GOOGLE,
                    is_verified=True,  # Google users are pre-verified
                    is_active=True,
                    status=UserStatus.ACTIVE,
                    provider_data={
                        "google": {
                            "uid": firebase_uid,
                            "email": firebase_email,
                            "display_name": firebase_user.get("display_name"),
                            "photo_url": firebase_user.get("photo_url"),
                            "provider_id": "google.com",
                        }
                    },
                    email_verified_at=datetime.utcnow(),
                    last_login_at=datetime.utcnow(),
                )
                
                self.db.add(user)
            
            await self.db.flush()
            await self.db.refresh(user)
        
        # Generate access token
        access_token = create_access_token({"sub": str(user.id), "email": user.email})
        
        logger.info(f"Google auth: {user.email} (new: {is_new_user})")
        
        return user, access_token, is_new_user
    
    async def get_current_user(self, user_id: str) -> User:
        """Get user by ID."""
        user = await self._get_user_by_id(user_id)
        if not user:
            raise ValueError("User not found")
        if not user.is_active or user.status == UserStatus.DELETED:
            raise ValueError("User account is not active")
        return user
    
    async def update_profile(self, user_id: str, update_data: UserUpdate) -> User:
        """Update user profile."""
        user = await self.get_current_user(user_id)
        
        # Check username uniqueness if changing
        if update_data.username and update_data.username != user.username:
            existing = await self._get_user_by_username(update_data.username)
            if existing:
                raise ValueError("Username already taken")
        
        # Update fields
        update_dict = update_data.model_dump(exclude_unset=True)
        for field, value in update_dict.items():
            setattr(user, field, value)
        
        user.updated_at = datetime.utcnow()
        await self.db.flush()
        await self.db.refresh(user)
        
        logger.info(f"Profile updated: {user.email}")
        
        return user
    
    async def change_password(self, user_id: str, current_password: str, new_password: str) -> None:
        """Change user password."""
        user = await self.get_current_user(user_id)
        
        if not user.password_hash:
            raise ValueError("Cannot change password for social login users")
        
        if not verify_password(current_password, user.password_hash):
            raise ValueError("Current password is incorrect")
        
        user.password_hash = get_password_hash(new_password)
        user.password_changed_at = datetime.utcnow()
        user.updated_at = datetime.utcnow()
        
        await self.db.flush()
        
        logger.info(f"Password changed: {user.email}")
    
    async def request_password_reset(self, email: str) -> str:
        """Request password reset and return token."""
        user = await self._get_user_by_email(email)
        if not user:
            # Don't reveal if email exists
            return ""
        
        if user.auth_provider != AuthProvider.EMAIL:
            raise ValueError("Please reset password through your social provider")
        
        token = generate_password_reset_token(email)
        logger.info(f"Password reset requested: {email}")
        
        # TODO: Send email with reset link
        
        return token
    
    async def confirm_password_reset(self, token: str, new_password: str) -> None:
        """Confirm password reset with token."""
        email = verify_password_reset_token(token)
        
        user = await self._get_user_by_email(email)
        if not user:
            raise ValueError("Invalid reset token")
        
        user.password_hash = get_password_hash(new_password)
        user.password_changed_at = datetime.utcnow()
        user.updated_at = datetime.utcnow()
        
        await self.db.flush()
        
        logger.info(f"Password reset completed: {email}")
    
    async def request_email_verification(self, email: str) -> str:
        """Request email verification."""
        user = await self._get_user_by_email(email)
        if not user:
            raise ValueError("User not found")
        
        if user.is_verified:
            raise ValueError("Email is already verified")
        
        token = generate_verification_token(email)
        
        # TODO: Send verification email
        
        return token
    
    async def confirm_email_verification(self, token: str) -> None:
        """Confirm email verification."""
        email = verify_verification_token(token)
        
        user = await self._get_user_by_email(email)
        if not user:
            raise ValueError("Invalid verification token")
        
        user.is_verified = True
        user.email_verified_at = datetime.utcnow()
        user.updated_at = datetime.utcnow()
        
        await self.db.flush()
        
        logger.info(f"Email verified: {email}")
    
    async def delete_account(self, user_id: str) -> None:
        """Soft delete user account."""
        user = await self.get_current_user(user_id)
        
        user.status = UserStatus.DELETED
        user.is_active = False
        user.deleted_at = datetime.utcnow()
        user.updated_at = datetime.utcnow()
        
        await self.db.flush()
        
        logger.info(f"Account deleted: {user.email}")
    
    # ==========================================
    # Private Helper Methods
    # ==========================================
    
    async def _get_user_by_id(self, user_id: str) -> Optional[User]:
        """Get user by UUID."""
        result = await self.db.execute(select(User).where(User.id == user_id))
        return result.scalar_one_or_none()
    
    async def _get_user_by_email(self, email: str) -> Optional[User]:
        """Get user by email."""
        result = await self.db.execute(
            select(User).where(User.email == email, User.status != UserStatus.DELETED)
        )
        return result.scalar_one_or_none()
    
    async def _get_user_by_username(self, username: str) -> Optional[User]:
        """Get user by username."""
        result = await self.db.execute(
            select(User).where(User.username == username, User.status != UserStatus.DELETED)
        )
        return result.scalar_one_or_none()
    
    async def _get_user_by_firebase_uid(self, firebase_uid: str) -> Optional[User]:
        """Get user by Firebase UID."""
        result = await self.db.execute(
            select(User).where(User.firebase_uid == firebase_uid)
        )
        return result.scalar_one_or_none()
    
    async def _generate_unique_username(self, base_username: str) -> str:
        """Generate a unique username."""
        username = base_username
        counter = 1
        
        while await self._get_user_by_username(username):
            username = f"{base_username}_{counter}"
            counter += 1
        
        return username