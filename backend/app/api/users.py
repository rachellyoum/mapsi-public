from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_db_user
from app.db.deps import get_db
from app.db.models import User

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/search")
async def search_users(
    q: str = Query(..., min_length=2),
    current_user: User = Depends(get_current_db_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(User)
        .where(User.email.is_not(None))
        .where(User.email.ilike(f"%{q}%"))
        .limit(10)
    )
    users = result.scalars().all()

    return [
        {
            "id": u.id,
            "name": u.name,
            "email": u.email,
        }
        for u in users
        if u.id != current_user.id
    ]