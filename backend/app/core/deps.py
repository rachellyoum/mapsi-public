"""
deps.py (core)

Reusable FastAPI dependencies.

- Converts verified Firebase user into a database User object
- Ensures user exists in Postgres
- Injected into protected routes

Bridges authentication and database layers.
"""

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.auth import get_current_user
from app.db.deps import get_db
from app.db.models import User

async def get_current_db_user(
    firebase_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> User:
    firebase_uid = firebase_user.get("uid")
    email = firebase_user.get("email")
    name = firebase_user.get("name")

    result = await db.execute(select(User).where(User.firebase_uid == firebase_uid))
    user = result.scalar_one_or_none()

    if user is None:
        user = User(firebase_uid=firebase_uid, email=email, name=name)
        db.add(user)
        await db.commit()
        await db.refresh(user)

    return user
