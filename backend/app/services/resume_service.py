from datetime import datetime, timezone
from typing import List, Optional
from uuid import uuid4

from app.db.repositories import ResumeRepository
from app.schemas.profile import ResumeProfile, ResumeProfileCreate


class ResumeService:
    def __init__(self) -> None:
        self.resumes = ResumeRepository()

    def create(self, request: ResumeProfileCreate) -> ResumeProfile:
        profile = ResumeProfile(
            id=f"resume_{uuid4().hex[:12]}",
            updated_at=datetime.now(timezone.utc),
            **request.model_dump(),
        )
        return self.resumes.save(profile)

    def get(self, profile_id: str) -> Optional[ResumeProfile]:
        return self.resumes.get(profile_id)

    def list(self) -> List[ResumeProfile]:
        return self.resumes.list()

    def latest(self) -> Optional[ResumeProfile]:
        return self.resumes.latest()
