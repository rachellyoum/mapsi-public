"""
config.py

Application configuration management.

- Loads environment variables from .env
- Stores database URL, API keys, service account paths
- Provides centralized access to app settings

All environment-based configuration is defined here.
"""

from pathlib import Path
from pydantic_settings import BaseSettings, SettingsConfigDict

BASE_DIR = Path(__file__).parent.parent.parent

class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=BASE_DIR /".env", env_file_encoding="utf-8")

    ENV: str = "local"

    DATABASE_URL: str
    REDIS_URL: str

    FIREBASE_SERVICE_ACCOUNT_PATH: str | None = None

    AMADEUS_CLIENT_ID: str | None = None
    AMADEUS_CLIENT_SECRET: str | None = None
    GOOGLE_MAPS_API_KEY: str | None = None
    OPENAI_API_KEY: str | None = None


settings = Settings()
