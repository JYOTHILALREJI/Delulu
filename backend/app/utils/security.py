from datetime import datetime, timedelta
from typing import Optional
from jose import JWTError, jwt
from passlib.context import CryptContext
from app.config import settings

# Password hashing context
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a plain password against a hashed password."""
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    """Hash a password."""
    return pwd_context.hash(password)


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """
    Create a JWT access token.
    
    Args:
        data: Payload data to encode
        expires_delta: Custom expiration time
        
    Returns:
        str: Encoded JWT token
    """
    to_encode = data.copy()
    
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    
    to_encode.update({
        "exp": expire,
        "iat": datetime.utcnow()
    })
    
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return encoded_jwt


def decode_access_token(token: str) -> dict:
    """
    Decode a JWT access token.
    
    Args:
        token: JWT token to decode
        
    Returns:
        dict: Decoded payload
        
    Raises:
        JWTError: If token is invalid
    """
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        return payload
    except JWTError as e:
        raise JWTError(f"Could not validate credentials: {str(e)}")


def generate_verification_token(email: str) -> str:
    """Generate email verification token."""
    expire = datetime.utcnow() + timedelta(hours=24)
    return jwt.encode(
        {"email": email, "exp": expire, "type": "verification"},
        settings.SECRET_KEY,
        algorithm=settings.ALGORITHM
    )


def verify_verification_token(token: str) -> str:
    """Verify email verification token and return email."""
    payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
    if payload.get("type") != "verification":
        raise JWTError("Invalid token type")
    return payload.get("email")


def generate_password_reset_token(email: str) -> str:
    """Generate password reset token."""
    expire = datetime.utcnow() + timedelta(hours=1)
    return jwt.encode(
        {"email": email, "exp": expire, "type": "password_reset"},
        settings.SECRET_KEY,
        algorithm=settings.ALGORITHM
    )


def verify_password_reset_token(token: str) -> str:
    """Verify password reset token and return email."""
    payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
    if payload.get("type") != "password_reset":
        raise JWTError("Invalid token type")
    return payload.get("email")