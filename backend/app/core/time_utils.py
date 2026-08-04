from datetime import date, timedelta

from app.core.constants import WEEKDAY_NAMES


def weekday_name(target_date: date) -> str:
    return WEEKDAY_NAMES[target_date.weekday()]


def week_bounds(target_date: date) -> tuple:
    week_start = target_date - timedelta(days=target_date.weekday())
    week_end = week_start + timedelta(days=6)
    return week_start, week_end

