"""
firebase.py

Initializes Firebase Admin SDK.

- Loads Firebase service account credentials
- Connects backend to Firebase project
- Enables verification of Firebase ID tokens

Runs once during application startup.
"""


import firebase_admin
from firebase_admin import credentials
from app.core.config import settings


def init_firebase():
    if firebase_admin._apps:
        return

    if not settings.FIREBASE_SERVICE_ACCOUNT_PATH:
        raise RuntimeError("FIREBASE_SERVICE_ACCOUNT_PATH is not set in .env")

    cred = credentials.Certificate(settings.FIREBASE_SERVICE_ACCOUNT_PATH)
    firebase_admin.initialize_app(cred)
