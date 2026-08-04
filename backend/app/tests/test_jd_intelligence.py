import os
import tempfile
from pathlib import Path

from app.config import get_settings
from app.db.migrations import init_db
from app.schemas.jd_intelligence import (
    CandidateActionDecision,
    CandidateActionStatus,
    InterestLevel,
    JDImageImportRequest,
    JDEntryCreate,
    JDPreferenceMarkCreate,
)
from app.services.jd_intelligence_service import JDIntelligenceService


def test_jd_intelligence_mvp_flow():
    original_path = os.environ.get("DATABASE_PATH")
    db_path = Path(tempfile.mkdtemp()) / "infra_jd_intelligence_test.db"
    os.environ["DATABASE_PATH"] = str(db_path)
    get_settings.cache_clear()
    try:
        init_db()
        service = JDIntelligenceService()
        entry = service.create_entry(
            JDEntryCreate(
                company="Example Robotics",
                team_or_department="World Model Team",
                role_title="Research Engineer - 4D Reconstruction / World Model",
                city="Shanghai",
                source_name="manual",
                jd_text="负责自动驾驶世界模型、4DGS、SLAM 几何一致性和 PyTorch 训练工程。",
                must_have_skills=["4DGS", "SLAM", "PyTorch"],
                bonus_skills=["world model", "driving video generation"],
                salary_range="35-60K",
            )
        )
        assert service.get_entry(entry.id) is not None
        assert len(service.list_entries()) == 1

        preference = service.save_preference(
            entry.id,
            JDPreferenceMarkCreate(
                interest_level=InterestLevel.favorite,
                why_liked="方向贴合 4D 重建和世界模型。",
                why_hesitated="还缺 WM pipeline 证据。",
            ),
        )
        assert preference is not None
        assert service.get_entry(entry.id).status.value == "favorite"

        skill_snapshot = service.latest_skill_snapshot()
        task_snapshot = service.latest_task_snapshot()
        assert skill_snapshot.skills
        assert task_snapshot.tasks

        result = service.analyze_entry(entry.id)
        assert result is not None
        assert result.analysis.jd_entry_id == entry.id
        assert result.candidate_actions
        assert service.get_entry(entry.id).status.value == "analyzed"

        action = result.candidate_actions[0]
        accepted = service.decide_action(
            action.id,
            CandidateActionStatus.accepted,
            CandidateActionDecision(reason="这个建议可以进入候选任务池。"),
        )
        assert accepted is not None
        assert accepted.status == CandidateActionStatus.accepted
        assert service.list_actions(CandidateActionStatus.accepted)

        imported = service.import_image(
            JDImageImportRequest(
                image_base64="ZmFrZV9pbWFnZQ==",
                filename="jd.png",
                source_name="mock_image",
            )
        )
        assert imported.ocr_text
        assert imported.draft_entry.role_title
        assert imported.draft_entry.must_have_skills
    finally:
        if original_path is None:
            os.environ.pop("DATABASE_PATH", None)
        else:
            os.environ["DATABASE_PATH"] = original_path
        get_settings.cache_clear()
