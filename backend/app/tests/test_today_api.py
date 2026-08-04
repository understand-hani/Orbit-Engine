from datetime import date

from app.api.routes_sessions import preview_session
from app.api.routes_today import get_today


def test_today_accepts_date_query():
    session = get_today(date(2026, 7, 13))
    assert session.weekday == "monday"
    assert session.task_type == "tech_radar"
    assert session.payload.radar_type == "product_strategy_radar"


def test_sessions_preview_accepts_date_query():
    session = preview_session(date(2026, 7, 14))
    assert session.weekday == "tuesday"
    assert session.task_type == "tech_radar"
    assert session.payload.radar_type == "technical_method_radar"
