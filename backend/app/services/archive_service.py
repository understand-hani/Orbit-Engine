from datetime import datetime, timezone
from typing import List, Optional
from uuid import uuid4

from app.db.repositories import ResearchArchiveRepository
from app.schemas.profile import ResearchArchive, ResearchArchiveCreate


class ArchiveService:
    def __init__(self) -> None:
        self.archives = ResearchArchiveRepository()

    def create(self, request: ResearchArchiveCreate) -> ResearchArchive:
        archive = ResearchArchive(
            id=f"archive_{uuid4().hex[:12]}",
            created_at=datetime.now(timezone.utc),
            **request.model_dump(),
        )
        return self.archives.save(archive)

    def get(self, archive_id: str) -> Optional[ResearchArchive]:
        return self.archives.get(archive_id)

    def list(self) -> List[ResearchArchive]:
        return self.archives.list()
