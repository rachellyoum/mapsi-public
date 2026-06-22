"""
database.py

Database connection setup.

- Creates async SQLAlchemy engine
- Defines session factory (AsyncSessionLocal)
- Connects backend to PostgreSQL

Provides database session creation for the app.
"""


from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker
from app.core.config import settings

engine = create_async_engine(settings.DATABASE_URL.split('?')[0], echo=True, connect_args={"ssl": True},  pool_pre_ping=True)
AsyncSessionLocal = async_sessionmaker(engine, expire_on_commit=False)
