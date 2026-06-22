"""
auth.py

Authentication layer for protected endpoints.

- Extracts Bearer token from Authorization header
- Verifies Firebase ID token
- Returns decoded Firebase user information

Used to secure API routes.
"""

from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from firebase_admin import auth as fb_auth

security = HTTPBearer(auto_error=False)

def get_current_user(creds: HTTPAuthorizationCredentials | None = Depends(security)):
    if creds is None or creds.scheme.lower() != "bearer":
        raise HTTPException(status_code=401, detail="Missing Authorization Bearer token")

    try:
        decoded = fb_auth.verify_id_token(creds.credentials)
        return decoded  # contains uid, email (if available), etc.
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
