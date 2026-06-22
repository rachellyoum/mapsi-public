from __future__ import annotations

import json
from typing import Any

import redis.asyncio as redis

from app.core.config import settings

redis_client: redis.Redis | None = None


def get_redis() -> redis.Redis:
    global redis_client
    if redis_client is None:
        if not settings.REDIS_URL:
            raise RuntimeError("REDIS_URL not set")
        redis_client = redis.from_url(settings.REDIS_URL, decode_responses=True)
    return redis_client


async def cache_get_json(key: str) -> Any | None:
    r = get_redis()
    val = await r.get(key)
    if val is None:
        return None
    return json.loads(val)


async def cache_set_json(key: str, value: Any, ttl_seconds: int = 900) -> None:
    r = get_redis()
    await r.set(key, json.dumps(value), ex=ttl_seconds)
