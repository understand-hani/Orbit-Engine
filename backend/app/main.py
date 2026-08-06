from fastapi import FastAPI

from app.api.routes_archive import router as archive_router
from app.api.routes_chat import router as chat_router
from app.api.routes_checkins import router as checkins_router
from app.api.routes_health import router as health_router
from app.api.routes_jd_intelligence import router as jd_intelligence_router
from app.api.routes_materials import router as materials_router
from app.api.routes_resume import router as resume_router
from app.api.routes_sessions import router as sessions_router
from app.api.routes_sources import router as sources_router
from app.api.routes_today import router as today_router
from app.api.routes_user_context import router as user_context_router
from app.config import get_settings
from app.db.migrations import init_db


settings = get_settings()

app = FastAPI(title=settings.app_name)
app.include_router(health_router, prefix="/api")
app.include_router(today_router, prefix="/api")
app.include_router(sessions_router, prefix="/api")
app.include_router(checkins_router, prefix="/api")
app.include_router(chat_router, prefix="/api")
app.include_router(materials_router, prefix="/api")
app.include_router(resume_router, prefix="/api")
app.include_router(archive_router, prefix="/api")
app.include_router(sources_router, prefix="/api")
app.include_router(jd_intelligence_router, prefix="/api")
app.include_router(user_context_router, prefix="/api")


@app.on_event("startup")
def on_startup() -> None:
    init_db()
