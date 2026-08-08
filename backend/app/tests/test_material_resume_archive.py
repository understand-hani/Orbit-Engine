import os
import tempfile
from datetime import date
from pathlib import Path

from app.config import get_settings
from app.db.migrations import init_db
from app.schemas.profile import ResearchArchiveCreate, ResumeProfileCreate
from app.schemas.research_feeder import ConfirmedResearchMaterial
from app.services.archive_service import ArchiveService
from app.services.feed_service import FeedService
from app.services.material_service import MaterialService
from app.services.resume_service import ResumeService


def test_material_resume_archive_services():
    original_path = os.environ.get("DATABASE_PATH")
    db_path = Path(tempfile.mkdtemp()) / "infra_material_test.db"
    os.environ["DATABASE_PATH"] = str(db_path)
    get_settings.cache_clear()
    try:
        init_db()
        feed = FeedService()
        materials = MaterialService()
        resume = ResumeService()
        archive = ArchiveService()

        radar = feed.generate_and_save_mock_session(date(2026, 7, 13))
        radar_items = materials.list_radar_items(radar.id)
        assert radar_items is not None

        research = feed.generate_and_save_mock_session(date(2026, 7, 16))
        papers = materials.list_papers(research.id)
        assert papers is not None
        assert len(papers) == 2
        updated_research = feed.save_selected_materials(
            research.id,
            [
                ConfirmedResearchMaterial(
                    id=papers[0].id,
                    paper_id=papers[0].id,
                    title=papers[0].title,
                    summary=papers[0].summary,
                    url=papers[0].url,
                    source_type="public_source",
                )
            ],
        )
        assert updated_research is not None
        assert updated_research.payload.selected_materials[0].paper_id == papers[0].id

        profile = resume.create(
            ResumeProfileCreate(
                basic_profile={"name": "User"},
                skills=[{"name": "GNSS/IMU Fusion"}],
            )
        )
        assert resume.latest() is not None
        assert resume.get(profile.id) is not None

        saved_archive = archive.create(
            ResearchArchiveCreate(
                paper_id="mock_paper_primary",
                note_id="mock_notes_001",
                tags=["World Model"],
                usable_for=["research_note", "resume"],
            )
        )
        assert archive.get(saved_archive.id) is not None
        assert len(archive.list()) == 1
    finally:
        if original_path is None:
            os.environ.pop("DATABASE_PATH", None)
        else:
            os.environ["DATABASE_PATH"] = original_path
        get_settings.cache_clear()
