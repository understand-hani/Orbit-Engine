from functools import lru_cache
from pathlib import Path
from typing import Optional

from pydantic_settings import BaseSettings, SettingsConfigDict


BACKEND_DIR = Path(__file__).resolve().parents[1]


class Settings(BaseSettings):
    app_name: str = "Personal Infra Agent"
    app_env: str = "development"
    timezone: str = "Asia/Shanghai"
    host: str = "127.0.0.1"
    port: int = 8000
    database_path: str = "../data/infra_agent.db"
    llm_provider: str = "mock"
    openrouter_api_key: Optional[str] = None
    openrouter_model: str = "openai/gpt-4o-mini"
    openrouter_base_url: str = "https://openrouter.ai/api/v1"
    openrouter_timeout_sec: float = 20.0
    openrouter_site_url: Optional[str] = None
    bocha_api_key: Optional[str] = None
    github_token: Optional[str] = None
    source_timeout_sec: float = 10.0

    model_config = SettingsConfigDict(env_file=BACKEND_DIR / ".env", extra="ignore")


@lru_cache
def get_settings() -> Settings:
    return Settings()
