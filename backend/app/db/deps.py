"""
deps.py (db)

Database session dependency.

- Provides one database session per request
- Ensures sessions are automatically closed
- Used in API endpoints via FastAPI dependency injection

Prevents connection leaks and ensures safe DB usage.
"""


from collections.abc import AsyncGenerator
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.database import AsyncSessionLocal

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with AsyncSessionLocal() as session:
        yield session
