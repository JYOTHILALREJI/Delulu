import firebase_admin
from firebase_admin import credentials, auth
from app.config import settings
import json
import logging

logger = logging.getLogger(__name__)

# Global Firebase app instance
_firebase_app = None


def initialize_firebase():
    """Initialize Firebase Admin SDK."""
    global _firebase_app
    
    try:
        if _firebase_app is None:
            # Check if already initialized
            if not firebase_admin._apps:
                # Build credentials from environment variables
                cred_dict = {
                    "type": settings.FIREBASE_TYPE,
                    "project_id": settings.FIREBASE_PROJECT_ID,
                    "private_key_id": settings.FIREBASE_PRIVATE_KEY_ID,
                    "private_key": settings.FIREBASE_PRIVATE_KEY.replace("\\n", "\n"),
                    "client_email": settings.FIREBASE_CLIENT_EMAIL,
                    "client_id": settings.FIREBASE_CLIENT_ID,
                    "auth_uri": settings.FIREBASE_AUTH_URI,
                    "token_uri": settings.FIREBASE_TOKEN_URI,
                    "auth_provider_x509_cert_url": settings.FIREBASE_AUTH_PROVIDER_X509_CERT_URL,
                    "client_x509_cert_url": settings.FIREBASE_CLIENT_X509_CERT_URL,
                }
                
                cred = credentials.Certificate(cred_dict)
                _firebase_app = firebase_admin.initialize_app(cred)
                logger.info("Firebase initialized successfully")
            else:
                _firebase_app = list(firebase_admin._apps.values())[0]
                logger.info("Firebase already initialized")
        
        return _firebase_app
    
    except Exception as e:
        logger.error(f"Failed to initialize Firebase: {str(e)}")
        raise


def verify_firebase_token(id_token: str) -> dict:
    """
    Verify Firebase ID token and return user info.
    
    Args:
        id_token: Firebase ID token from client
        
    Returns:
        dict: User info from Firebase
        
    Raises:
        ValueError: If token is invalid
    """
    try:
        initialize_firebase()
        decoded_token = auth.verify_id_token(id_token, check_revoked=True)
        return decoded_token
    except auth.RevokedIdTokenError:
        raise ValueError("Token has been revoked")
    except auth.InvalidIdTokenError:
        raise ValueError("Invalid token")
    except auth.ExpiredIdTokenError:
        raise ValueError("Token has expired")
    except Exception as e:
        logger.error(f"Firebase token verification failed: {str(e)}")
        raise ValueError(f"Token verification failed: {str(e)}")


def get_firebase_user(uid: str) -> dict:
    """
    Get Firebase user details by UID.
    
    Args:
        uid: Firebase user UID
        
    Returns:
        dict: User details
    """
    try:
        initialize_firebase()
        user = auth.get_user(uid)
        return {
            "uid": user.uid,
            "email": user.email,
            "display_name": user.display_name,
            "photo_url": user.photo_url,
            "phone_number": user.phone_number,
            "email_verified": user.email_verified,
            "disabled": user.disabled,
            "provider_data": [
                {
                    "provider_id": p.provider_id,
                    "email": p.email,
                    "display_name": p.display_name,
                    "photo_url": p.photo_url,
                }
                for p in user.provider_data
            ]
        }
    except auth.UserNotFoundError:
        raise ValueError("User not found in Firebase")
    except Exception as e:
        logger.error(f"Failed to get Firebase user: {str(e)}")
        raise ValueError(f"Failed to get user: {str(e)}")