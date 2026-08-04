from datetime import date
from typing import Optional

from fastapi import APIRouter, Query

from app.agents.weekly_coordinator import WeeklyCoordinator
from app.schemas.session import BaseSession


router = APIRouter(tags=["today"])
coordinator = WeeklyCoordinator()


@router.get("/today", response_model=BaseSession)
def get_today(target_date: Optional[date] = Query(default=None, alias="date")) -> BaseSession:
    return coordinator.create_session(target_date)

