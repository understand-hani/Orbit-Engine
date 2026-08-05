import sqlite3
from contextlib import contextmanager
from pathlib import Path
from typing import Iterator

from app.config import get_settings
from app.config import BACKEND_DIR


def database_path() -> Path:
    configured = Path(get_settings().database_path)
    if configured.is_absolute():
        return configured
    return (BACKEND_DIR / configured).resolve()


@contextmanager
def connect() -> Iterator[sqlite3.Connection]:
    path = database_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(path))
    conn.row_factory = sqlite3.Row
    try:
        yield conn
        conn.commit()
    finally:
        conn.close()
