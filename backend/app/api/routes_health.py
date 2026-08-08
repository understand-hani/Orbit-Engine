from typing import Dict

from fastapi import APIRouter

from app.config import get_settings


router = APIRouter(tags=["health"])


@router.get("/health")
def health() -> Dict[str, str]:
    settings = get_settings()
    return {
        "status": "ok",
        "app": settings.app_name,
        "env": settings.app_env,
        "llm_provider": settings.llm_provider,
        "openrouter_configured": str(bool(settings.openrouter_api_key)).lower(),
        "openrouter_model": settings.openrouter_model,
    }
