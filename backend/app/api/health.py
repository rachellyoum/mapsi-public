"""
health.py

Health check endpoint.

- Provides simple route to confirm server is running
- Used for testing and deployment monitoring
"""


from fastapi import APIRouter
from app.core.cache import get_redis

router = APIRouter(tags=["health"])

@router.get("/health")
def health():
    return {"ok": True}

@router.get("/health/redis")
async def redis_health():
    r = get_redis()
    pong = await r.ping()
    return {"ok": bool(pong)}