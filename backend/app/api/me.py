"""
me.py

Authenticated user endpoint.

- Returns information about the currently logged-in user
- Verifies Firebase token
- Ensures user exists in database

Used to confirm authentication is working.
"""

from fastapi import APIRouter, Depends
from sqlalchemy import select
from app.core.auth import get_current_user
from app.db.database import AsyncSessionLocal
from app.db.models import User

router = APIRouter(tags=["auth"])

@router.get("/me")
async def me(user=Depends(get_current_user)):
    firebase_uid = user.get("uid")
    email = user.get("email")

    async with AsyncSessionLocal() as session:
        result = await session.execute(
            select(User).where(User.firebase_uid == firebase_uid)
        )
        db_user = result.scalar_one_or_none()

        if not db_user:
            db_user = User(firebase_uid=firebase_uid, email=email)
            session.add(db_user)
            await session.commit()
            await session.refresh(db_user)

    return {
        "id": db_user.id,
        "firebase_uid": db_user.firebase_uid,
        "email": db_user.email,
    }
