from typing import List, Optional

from fastapi import APIRouter, HTTPException, Query, Response

from app.schemas.jd_intelligence import (
    CandidateAction,
    CandidateActionDecision,
    CandidateActionStatus,
    JDEntry,
    JDEntryCreate,
    JDEntryUpdate,
    JDImageImportRequest,
    JDImageImportResult,
    JDDiscussionRequest,
    JDDiscussionResponse,
    JDFitAnalysis,
    JDFitAnalysisResult,
    JDPreferenceMark,
    JDPreferenceMarkCreate,
    SkillStackSnapshot,
    SkillStackSnapshotCreate,
    TaskStateSnapshot,
    TaskStateSnapshotCreate,
)
from app.services.jd_intelligence_service import JDIntelligenceService


router = APIRouter(tags=["jd-intelligence"])
service = JDIntelligenceService()


@router.get("/jd/entries", response_model=List[JDEntry])
def list_jd_entries() -> List[JDEntry]:
    return service.list_entries()


@router.post("/jd/entries", response_model=JDEntry)
def create_jd_entry(request: JDEntryCreate) -> JDEntry:
    return service.create_entry(request)


@router.post("/jd/import/image", response_model=JDImageImportResult)
def import_jd_image(request: JDImageImportRequest) -> JDImageImportResult:
    return service.import_image(request)


@router.post("/jd/discussion/messages", response_model=JDDiscussionResponse)
def send_jd_discussion_message(request: JDDiscussionRequest) -> JDDiscussionResponse:
    return JDDiscussionResponse(
        content=service.discuss(
            content=request.content,
            messages=[message.model_dump() for message in request.messages],
        )
    )


@router.get("/jd/entries/{entry_id}", response_model=JDEntry)
def get_jd_entry(entry_id: str) -> JDEntry:
    entry = service.get_entry(entry_id)
    if entry is None:
        raise HTTPException(status_code=404, detail="JD entry not found")
    return entry


@router.patch("/jd/entries/{entry_id}", response_model=JDEntry)
def update_jd_entry(entry_id: str, request: JDEntryUpdate) -> JDEntry:
    entry = service.update_entry(entry_id, request)
    if entry is None:
        raise HTTPException(status_code=404, detail="JD entry not found")
    return entry


@router.delete("/jd/entries/{entry_id}", status_code=204)
def delete_jd_entry(entry_id: str) -> Response:
    deleted = service.delete_entry(entry_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="JD entry not found")
    return Response(status_code=204)


@router.post("/jd/entries/{entry_id}/preference", response_model=JDPreferenceMark)
def save_jd_preference(entry_id: str, request: JDPreferenceMarkCreate) -> JDPreferenceMark:
    mark = service.save_preference(entry_id, request)
    if mark is None:
        raise HTTPException(status_code=404, detail="JD entry not found")
    return mark


@router.get("/jd/entries/{entry_id}/preference", response_model=JDPreferenceMark)
def get_jd_preference(entry_id: str) -> JDPreferenceMark:
    mark = service.get_preference(entry_id)
    if mark is None:
        raise HTTPException(status_code=404, detail="JD preference not found")
    return mark


@router.post("/jd/entries/{entry_id}/analyze", response_model=JDFitAnalysisResult)
def analyze_jd_entry(entry_id: str) -> JDFitAnalysisResult:
    result = service.analyze_entry(entry_id)
    if result is None:
        raise HTTPException(status_code=404, detail="JD entry not found")
    return result


@router.get("/jd/entries/{entry_id}/analyses", response_model=List[JDFitAnalysis])
def list_jd_analyses(entry_id: str) -> List[JDFitAnalysis]:
    return service.list_analyses(entry_id)


@router.get("/capability/skill-snapshot/latest", response_model=SkillStackSnapshot)
def latest_skill_snapshot() -> SkillStackSnapshot:
    return service.latest_skill_snapshot()


@router.post("/capability/skill-snapshots", response_model=SkillStackSnapshot)
def create_skill_snapshot(request: SkillStackSnapshotCreate) -> SkillStackSnapshot:
    return service.create_skill_snapshot(request)


@router.get("/capability/task-snapshot/latest", response_model=TaskStateSnapshot)
def latest_task_snapshot() -> TaskStateSnapshot:
    return service.latest_task_snapshot()


@router.post("/capability/task-snapshots", response_model=TaskStateSnapshot)
def create_task_snapshot(request: TaskStateSnapshotCreate) -> TaskStateSnapshot:
    return service.create_task_snapshot(request)


@router.get("/jd/actions", response_model=List[CandidateAction])
def list_candidate_actions(
    status: Optional[CandidateActionStatus] = Query(default=None),
) -> List[CandidateAction]:
    return service.list_actions(status)


@router.post("/jd/actions/{action_id}/accept", response_model=CandidateAction)
def accept_candidate_action(action_id: str, request: CandidateActionDecision) -> CandidateAction:
    action = service.decide_action(action_id, CandidateActionStatus.accepted, request)
    if action is None:
        raise HTTPException(status_code=404, detail="Candidate action not found")
    return action


@router.post("/jd/actions/{action_id}/defer", response_model=CandidateAction)
def defer_candidate_action(action_id: str, request: CandidateActionDecision) -> CandidateAction:
    action = service.decide_action(action_id, CandidateActionStatus.deferred, request)
    if action is None:
        raise HTTPException(status_code=404, detail="Candidate action not found")
    return action


@router.post("/jd/actions/{action_id}/reject", response_model=CandidateAction)
def reject_candidate_action(action_id: str, request: CandidateActionDecision) -> CandidateAction:
    action = service.decide_action(action_id, CandidateActionStatus.rejected, request)
    if action is None:
        raise HTTPException(status_code=404, detail="Candidate action not found")
    return action


@router.post("/jd/actions/{action_id}/convert-to-task", response_model=CandidateAction)
def convert_candidate_action_to_task(
    action_id: str,
    request: CandidateActionDecision,
) -> CandidateAction:
    action = service.decide_action(action_id, CandidateActionStatus.converted_to_task, request)
    if action is None:
        raise HTTPException(status_code=404, detail="Candidate action not found")
    return action
