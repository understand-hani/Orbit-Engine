import json
from datetime import datetime, timezone
from typing import List, Optional
from uuid import uuid4

from app.config import get_settings
from app.db.repositories import (
    CandidateActionRepository,
    JDEntryRepository,
    JDFitAnalysisRepository,
    JDPreferenceRepository,
    SkillStackRepository,
    TaskStateRepository,
)
from app.schemas.jd_intelligence import (
    Adjustability,
    CandidateAction,
    CandidateActionDecision,
    CandidateActionStatus,
    CandidateActionType,
    CapabilityLevel,
    ConfidenceLevel,
    InterestLevel,
    JDEntry,
    JDEntryCreate,
    JDImageImportRequest,
    JDImageImportResult,
    JDEntryStatus,
    JDEntryUpdate,
    JDFitAnalysis,
    JDFitAnalysisResult,
    JDPreferenceMark,
    JDPreferenceMarkCreate,
    JDRoleType,
    MatchLevel,
    PriorityLevel,
    RiskLevel,
    SkillCategory,
    SkillProfile,
    SkillStackSnapshot,
    SkillStackSnapshotCreate,
    TaskCategory,
    TaskProfile,
    TaskStateSnapshot,
    TaskStateSnapshotCreate,
    TaskStatus,
    TimeSensitivity,
    TimingRecommendation,
)
from app.services.llm_service import (
    JD_ANALYSIS_SYSTEM_PROMPT,
    JD_DISCUSSION_SYSTEM_PROMPT,
    LLMJDFitAnalysisOutput,
    OpenRouterChatService,
)


class JDIntelligenceService:
    def __init__(self) -> None:
        self.entries = JDEntryRepository()
        self.preferences = JDPreferenceRepository()
        self.skill_snapshots = SkillStackRepository()
        self.task_snapshots = TaskStateRepository()
        self.analyses = JDFitAnalysisRepository()
        self.actions = CandidateActionRepository()
        self.settings = get_settings()
        self.llm = OpenRouterChatService()

    def create_entry(self, request: JDEntryCreate) -> JDEntry:
        now = datetime.now(timezone.utc)
        entry = JDEntry(
            id=f"jd_{uuid4().hex[:12]}",
            created_at=now,
            updated_at=now,
            **request.model_dump(),
        )
        return self.entries.save(entry)

    def update_entry(self, entry_id: str, request: JDEntryUpdate) -> Optional[JDEntry]:
        entry = self.entries.get(entry_id)
        if entry is None:
            return None
        updates = request.model_dump(exclude_unset=True)
        updated = entry.model_copy(
            update={
                **updates,
                "updated_at": datetime.now(timezone.utc),
            }
        )
        return self.entries.save(updated)

    def get_entry(self, entry_id: str) -> Optional[JDEntry]:
        return self.entries.get(entry_id)

    def list_entries(self) -> List[JDEntry]:
        return self.entries.list()

    def delete_entry(self, entry_id: str) -> bool:
        return self.entries.delete(entry_id)

    def import_image(self, request: JDImageImportRequest) -> JDImageImportResult:
        mock_text = (
            "Mock OCR result from uploaded JD image. "
            "岗位：Research Engineer - 4D Reconstruction / World Model。"
            "要求：3DGS / 4DGS / SLAM / PyTorch / 自动驾驶数据经验。"
            "加分：World Model、Driving Video Generation、nuScenes。"
        )
        draft = JDEntryCreate(
            company="Mock Image Company",
            team_or_department="Autonomous AI Team",
            role_title="Research Engineer - 4D Reconstruction / World Model",
            city="Shanghai",
            source_type="screenshot_ocr",
            source_name=request.source_name or "image_upload",
            jd_text=mock_text,
            notes=f"Mock image import from {request.filename or 'uploaded image'}.",
            must_have_skills=["3DGS", "4DGS", "SLAM", "PyTorch"],
            bonus_skills=["World Model", "Driving Video Generation", "nuScenes"],
            new_keywords=["4D reconstruction", "world model"],
            role_orientation="research_engineering",
            application_priority="high",
        )
        return JDImageImportResult(
            ocr_text=mock_text,
            draft_entry=draft,
            notes="Mock OCR/parser result. Replace with OCR or multimodal LLM later.",
        )

    def save_preference(self, entry_id: str, request: JDPreferenceMarkCreate) -> Optional[JDPreferenceMark]:
        if self.entries.get(entry_id) is None:
            return None
        existing = self.preferences.latest_for_entry(entry_id)
        now = datetime.now(timezone.utc)
        mark = JDPreferenceMark(
            id=existing.id if existing else f"jd_pref_{uuid4().hex[:12]}",
            jd_entry_id=entry_id,
            created_at=existing.created_at if existing else now,
            updated_at=now,
            **request.model_dump(),
        )
        entry_updates = {}
        if request.interest_level == InterestLevel.favorite:
            entry_updates["status"] = JDEntryStatus.favorite
        if entry_updates:
            entry = self.entries.get(entry_id)
            if entry is not None:
                self.entries.save(entry.model_copy(update={**entry_updates, "updated_at": now}))
        return self.preferences.save(mark)

    def get_preference(self, entry_id: str) -> Optional[JDPreferenceMark]:
        return self.preferences.latest_for_entry(entry_id)

    def create_skill_snapshot(self, request: SkillStackSnapshotCreate) -> SkillStackSnapshot:
        snapshot = SkillStackSnapshot(
            id=f"skill_snapshot_{uuid4().hex[:12]}",
            created_at=datetime.now(timezone.utc),
            **request.model_dump(),
        )
        return self.skill_snapshots.save(snapshot)

    def latest_skill_snapshot(self) -> SkillStackSnapshot:
        existing = self.skill_snapshots.latest()
        if existing is not None:
            return existing
        return self.create_skill_snapshot(
            SkillStackSnapshotCreate(
                summary="Initial capability snapshot seeded from project context.",
                skills=[
                    SkillProfile(
                        id="skill_localization_gnss_imu",
                        name="GNSS/IMU Fusion Localization",
                        category=SkillCategory.localization,
                        level=CapabilityLevel.strong,
                        confidence=ConfidenceLevel.high,
                        evidence=["Production autonomous-driving localization experience"],
                        target_level=CapabilityLevel.strong,
                        priority=PriorityLevel.high,
                    ),
                    SkillProfile(
                        id="skill_slam_geometric_consistency",
                        name="SLAM Geometric Consistency",
                        category=SkillCategory.slam,
                        level=CapabilityLevel.solid,
                        confidence=ConfidenceLevel.high,
                        evidence=["SLAM theory, pose estimation, autonomous-driving localization architecture"],
                        target_level=CapabilityLevel.strong,
                        priority=PriorityLevel.high,
                    ),
                    SkillProfile(
                        id="skill_4dgs_dynamic_reconstruction",
                        name="4DGS Dynamic Reconstruction",
                        category=SkillCategory.reconstruction,
                        level=CapabilityLevel.working,
                        confidence=ConfidenceLevel.medium,
                        evidence=["Current StreetGaussian / 4DGaussians nuScenes plan"],
                        target_level=CapabilityLevel.strong,
                        gap_notes="Need comparison videos, metrics, and stronger training evidence.",
                        priority=PriorityLevel.high,
                    ),
                    SkillProfile(
                        id="skill_world_model_generation",
                        name="World Model / Driving Video Generation",
                        category=SkillCategory.world_model,
                        level=CapabilityLevel.beginner,
                        confidence=ConfidenceLevel.medium,
                        evidence=["Planned Week 9-10 pipeline entry"],
                        target_level=CapabilityLevel.working,
                        gap_notes="Need one runnable lightweight WM pipeline.",
                        priority=PriorityLevel.high,
                    ),
                ],
            )
        )

    def create_task_snapshot(self, request: TaskStateSnapshotCreate) -> TaskStateSnapshot:
        snapshot = TaskStateSnapshot(
            id=f"task_snapshot_{uuid4().hex[:12]}",
            created_at=datetime.now(timezone.utc),
            **request.model_dump(),
        )
        return self.task_snapshots.save(snapshot)

    def latest_task_snapshot(self) -> TaskStateSnapshot:
        existing = self.task_snapshots.latest()
        if existing is not None:
            return existing
        return self.create_task_snapshot(
            TaskStateSnapshotCreate(
                current_phase="Week 7-12 decision plan",
                summary="Reconstruction line is producing evidence; WM line is planned for hands-on direction judgment.",
                tasks=[
                    TaskProfile(
                        id="task_reconstruction_wrap_up",
                        title="Week 7-8 Reconstruction Wrap-up",
                        category=TaskCategory.reconstruction_line,
                        status=TaskStatus.active,
                        current_phase="StreetGaussian / 4DGS on nuScenes",
                        related_skill_ids=["skill_4dgs_dynamic_reconstruction", "skill_slam_geometric_consistency"],
                        weekly_slot="current main line",
                        progress_summary="Need baseline, comparison videos, and metric table.",
                        next_milestone="GT-box vs SLAM filtering comparison on nuScenes",
                        evidence_outputs=["comparison video", "metric table", "technical documentation"],
                        adjustability=Adjustability.low,
                    ),
                    TaskProfile(
                        id="task_world_model_entry",
                        title="Week 9-10 World Model Pipeline Entry",
                        category=TaskCategory.world_model_line,
                        status=TaskStatus.planned,
                        current_phase="candidate model selection",
                        related_skill_ids=["skill_world_model_generation"],
                        weekly_slot="planned after reconstruction wrap-up",
                        next_milestone="Run one lightweight driving video generation inference demo",
                        adjustability=Adjustability.medium,
                    ),
                ],
            )
        )

    def analyze_entry(self, entry_id: str) -> Optional[JDFitAnalysisResult]:
        entry = self.entries.get(entry_id)
        if entry is None:
            return None
        existing_result = self._existing_analysis_result(entry.id)
        if existing_result is not None:
            return existing_result

        preference = self.preferences.latest_for_entry(entry_id)
        skill_snapshot = self.latest_skill_snapshot()
        task_snapshot = self.latest_task_snapshot()

        if self.settings.llm_provider == "openrouter":
            try:
                return self._analyze_entry_with_llm(entry, preference, skill_snapshot, task_snapshot)
            except Exception:
                return self._analyze_entry_mock(entry, preference, skill_snapshot, task_snapshot)

        return self._analyze_entry_mock(entry, preference, skill_snapshot, task_snapshot)

    def _existing_analysis_result(self, entry_id: str) -> Optional[JDFitAnalysisResult]:
        analysis = self.analyses.latest_by_entry(entry_id)
        if analysis is None:
            return None
        return JDFitAnalysisResult(
            analysis=analysis,
            candidate_actions=self.actions.list_by_analysis(analysis.id),
        )

    def _analyze_entry_mock(
        self,
        entry: JDEntry,
        preference: Optional[JDPreferenceMark],
        skill_snapshot: SkillStackSnapshot,
        task_snapshot: TaskStateSnapshot,
    ) -> JDFitAnalysisResult:
        text = " ".join(
            [
                entry.company,
                entry.role_title,
                entry.jd_text,
                " ".join(entry.must_have_skills),
                " ".join(entry.bonus_skills),
            ]
        ).lower()
        technical_terms = ["3dgs", "4dgs", "slam", "world model", "世界模型", "pytorch", "重建", "自动驾驶"]
        overlap = [term for term in technical_terms if term in text]
        has_tpm_risk = any(term in text for term in ["tpm", "项目管理", "供应商", "协调", "推进"])
        wants_wm = any(term in text for term in ["world model", "世界模型", "video generation", "生成"])
        wants_reconstruction = any(term in text for term in ["3dgs", "4dgs", "重建", "nerf"])

        role_type = JDRoleType.research_engineering if overlap else JDRoleType.unclear
        if has_tpm_risk and not overlap:
            role_type = JDRoleType.tpm_variant

        match_level = MatchLevel.medium_high if overlap else MatchLevel.medium
        if role_type == JDRoleType.tpm_variant:
            match_level = MatchLevel.low

        priority = PriorityLevel.medium
        if preference and preference.interest_level == InterestLevel.favorite and overlap:
            priority = PriorityLevel.high
        elif role_type == JDRoleType.tpm_variant:
            priority = PriorityLevel.low

        trainable_gaps = []
        evidence_needed = []
        if wants_wm:
            trainable_gaps.append("World Model / driving video generation hands-on evidence")
            evidence_needed.append("Run and document one lightweight WM pipeline on driving data")
        if wants_reconstruction:
            trainable_gaps.append("4DGS dynamic reconstruction quantitative evidence")
            evidence_needed.append("Produce nuScenes comparison videos and metrics")

        red_flags = []
        if has_tpm_risk:
            red_flags.append("JD contains coordination / project-management signals; confirm whether this is a TPM variant.")

        now = datetime.now(timezone.utc)
        analysis = JDFitAnalysis(
            id=f"jd_analysis_{uuid4().hex[:12]}",
            jd_entry_id=entry.id,
            skill_snapshot_id=skill_snapshot.id,
            task_snapshot_id=task_snapshot.id,
            role_type=role_type,
            match_level=match_level,
            interest_adjusted_priority=priority,
            timing_recommendation=TimingRecommendation.build_contact_only,
            technical_overlap=overlap,
            missing_skills=trainable_gaps,
            trainable_gaps=trainable_gaps,
            evidence_needed=evidence_needed,
            red_flags=red_flags,
            tpm_risk_level=RiskLevel.medium if has_tpm_risk else RiskLevel.low,
            company_style_risk=RiskLevel.unknown,
            resume_suggestions=[
                "Emphasize production-grade GNSS/IMU localization and SLAM geometric intuition.",
                "Add current SLAM x 4DGS dynamic reconstruction evidence when available.",
            ],
            interview_selling_points=[
                "Autonomous-driving localization engineering experience",
                "SLAM geometry x dynamic reconstruction differentiator",
            ],
            questions_to_ask_recruiter=[
                "Is this role hands-on research engineering or cross-functional project coordination?",
                "What are the expected outputs in the first 3-6 months?",
            ],
            recommendation=(
                "Keep contact and use this JD to guide capability building; do not authorize application yet."
            ),
            reasoning="Mock analysis based on JD keywords, preference mark, skill snapshot, and current task adjustability.",
            created_at=now,
        )
        self.analyses.save(analysis)

        actions = self._recommend_actions(entry, analysis, wants_wm, wants_reconstruction, now)
        for action in actions:
            self.actions.save(action)

        updated_entry = entry.model_copy(update={"status": JDEntryStatus.analyzed, "updated_at": now})
        self.entries.save(updated_entry)

        return JDFitAnalysisResult(analysis=analysis, candidate_actions=actions)

    def _analyze_entry_with_llm(
        self,
        entry: JDEntry,
        preference: Optional[JDPreferenceMark],
        skill_snapshot: SkillStackSnapshot,
        task_snapshot: TaskStateSnapshot,
    ) -> JDFitAnalysisResult:
        payload = {
            "jd_entry": entry.model_dump(mode="json"),
            "preference_mark": preference.model_dump(mode="json") if preference else None,
            "skill_stack_snapshot": skill_snapshot.model_dump(mode="json"),
            "task_state_snapshot": task_snapshot.model_dump(mode="json"),
            "required_output_notes": [
                "Return 1-4 candidate actions.",
                "Do not recommend immediate application unless timing is explicitly low risk.",
                "Use concise Chinese for user-facing text unless the JD itself is English-only.",
            ],
        }
        llm_output = self.llm.generate_json(
            system_prompt=JD_ANALYSIS_SYSTEM_PROMPT,
            user_payload=payload,
            output_model=LLMJDFitAnalysisOutput,
            schema_name="jd_fit_analysis",
        )
        if not isinstance(llm_output, LLMJDFitAnalysisOutput):
            llm_output = LLMJDFitAnalysisOutput.model_validate(llm_output)

        now = datetime.now(timezone.utc)
        analysis = JDFitAnalysis(
            id=f"jd_analysis_{uuid4().hex[:12]}",
            jd_entry_id=entry.id,
            skill_snapshot_id=skill_snapshot.id,
            task_snapshot_id=task_snapshot.id,
            role_type=llm_output.role_type,
            match_level=llm_output.match_level,
            interest_adjusted_priority=llm_output.interest_adjusted_priority,
            timing_recommendation=llm_output.timing_recommendation,
            technical_overlap=llm_output.technical_overlap,
            missing_skills=llm_output.missing_skills,
            fatal_gaps=llm_output.fatal_gaps,
            trainable_gaps=llm_output.trainable_gaps,
            evidence_needed=llm_output.evidence_needed,
            red_flags=llm_output.red_flags,
            tpm_risk_level=llm_output.tpm_risk_level,
            company_style_risk=llm_output.company_style_risk,
            resume_suggestions=llm_output.resume_suggestions,
            interview_selling_points=llm_output.interview_selling_points,
            questions_to_ask_recruiter=llm_output.questions_to_ask_recruiter,
            recommendation=llm_output.recommendation,
            reasoning=llm_output.reasoning,
            created_at=now,
        )
        self.analyses.save(analysis)

        actions = [
            CandidateAction(
                id=f"candidate_action_{uuid4().hex[:12]}",
                source_jd_ids=[entry.id],
                source_analysis_ids=[analysis.id],
                related_skill_ids=action.related_skill_ids,
                related_task_ids=action.related_task_ids,
                action_type=action.action_type,
                title=action.title,
                reason=action.reason,
                expected_output=action.expected_output,
                effort_estimate_min=action.effort_estimate_min,
                priority=action.priority,
                time_sensitivity=action.time_sensitivity,
                risk=action.risk,
                suggested_slot=action.suggested_slot,
                created_at=now,
                updated_at=now,
            )
            for action in llm_output.candidate_actions[:4]
        ]
        if not actions:
            actions = self._recommend_actions(entry, analysis, wants_wm=False, wants_reconstruction=True, now=now)
        for action in actions:
            self.actions.save(action)

        updated_entry = entry.model_copy(update={"status": JDEntryStatus.analyzed, "updated_at": now})
        self.entries.save(updated_entry)

        return JDFitAnalysisResult(analysis=analysis, candidate_actions=actions)

    def list_analyses(self, entry_id: str) -> List[JDFitAnalysis]:
        return self.analyses.list_by_entry(entry_id)

    def list_actions(self, status: Optional[CandidateActionStatus] = None) -> List[CandidateAction]:
        return self._dedupe_actions(self.actions.list(status))

    def discuss(self, content: str, messages: List[dict]) -> str:
        if self.settings.llm_provider != "openrouter":
            return self._mock_discussion_reply(
                "LLM_PROVIDER is not openrouter; current backend is running in mock mode."
            )

        try:
            llm_messages = [
                {
                    "role": "assistant" if item.get("role") == "Agent" else "user",
                    "content": item.get("content", ""),
                }
                for item in messages
                if item.get("content")
            ]
            if self._should_attach_discussion_context(content):
                llm_messages.append(
                    {
                        "role": "user",
                        "content": (
                            "下面是后端自动检索到的 JD Intelligence 上下文 JSON。"
                            "请优先结合这些信息回答用户问题。\n"
                            f"{json.dumps(self._build_discussion_context(content), ensure_ascii=False, indent=2)}"
                        ),
                    }
                )
            llm_messages.append({"role": "user", "content": content})
            return self.llm.generate_text(
                system_prompt=JD_DISCUSSION_SYSTEM_PROMPT,
                messages=llm_messages,
            )
        except Exception as exc:
            return self._mock_discussion_reply(self._format_openrouter_error(exc))

    def _mock_discussion_reply(self, reason: str) -> str:
        return (
            f"Mock JD Agent 回复（{reason}）：我已收到你的问题。你可以围绕岗位匹配、TPM 风险、"
            "能力差距、候选行动是否值得 convert、以及当前 4DGS/WM 主线的关系继续追问。"
        )

    def _format_openrouter_error(self, exc: Exception) -> str:
        text = str(exc)
        if "429" in text or "Too Many Requests" in text:
            return (
                "OpenRouter rate limit hit: 429 Too Many Requests. "
                "请稍后重试，或在 backend/.env 中换一个额度更充足的 OPENROUTER_MODEL，"
                "或检查 OpenRouter 账号余额/限额。"
            )
        return f"OpenRouter request failed: {text}"

    def _should_attach_discussion_context(self, content: str) -> bool:
        query = content.strip().lower()
        generic_inputs = {
            "hi",
            "hello",
            "hey",
            "你好",
            "在吗",
            "test",
            "测试",
        }
        if query in generic_inputs:
            return False
        context_keywords = [
            "jd",
            "job",
            "岗位",
            "公司",
            "简历",
            "skill",
            "能力",
            "gap",
            "action",
            "convert",
            "task",
            "week",
            "周",
            "任务",
            "candidate",
            "world model",
            "slam",
            "4dgs",
            "3dgs",
        ]
        return any(keyword in query for keyword in context_keywords)

    def _build_discussion_context(self, content: str) -> dict:
        query = content.lower()
        entries = self.entries.list()
        actions = self._dedupe_actions(self.actions.list())
        skill_snapshot = self.latest_skill_snapshot()
        task_snapshot = self.latest_task_snapshot()

        matched_entries = [entry for entry in entries if self._matches_entry(query, entry)]
        matched_actions = [action for action in actions if self._matches_action(query, action)]
        matched_tasks = [task for task in task_snapshot.tasks if self._matches_task(query, task)]

        context = {
            "context_version": "jd_discussion_v1",
            "jd_library_summary": [
                {
                    "id": entry.id,
                    "company": entry.company,
                    "role_title": entry.role_title,
                    "city": entry.city,
                    "status": entry.status.value,
                    "priority": entry.application_priority.value,
                    "role_orientation": entry.role_orientation.value,
                    "must_have_skills": entry.must_have_skills[:8],
                    "bonus_skills": entry.bonus_skills[:8],
                }
                for entry in entries[:20]
            ],
            "skill_stack_summary": {
                "id": skill_snapshot.id,
                "summary": skill_snapshot.summary,
                "skills": [
                    {
                        "id": skill.id,
                        "name": skill.name,
                        "category": skill.category.value,
                        "level": skill.level.value,
                        "target_level": skill.target_level.value,
                        "gap_notes": skill.gap_notes,
                        "priority": skill.priority.value,
                    }
                    for skill in skill_snapshot.skills
                ],
            },
            "task_state_summary": {
                "id": task_snapshot.id,
                "current_phase": task_snapshot.current_phase,
                "summary": task_snapshot.summary,
                "tasks": [
                    {
                        "id": task.id,
                        "title": task.title,
                        "category": task.category.value,
                        "status": task.status.value,
                        "weekly_slot": task.weekly_slot,
                        "progress_summary": task.progress_summary,
                        "next_milestone": task.next_milestone,
                        "adjustability": task.adjustability.value,
                    }
                    for task in task_snapshot.tasks
                ],
            },
            "candidate_actions_summary": [
                {
                    "id": action.id,
                    "title": action.title,
                    "status": action.status.value,
                    "priority": action.priority.value,
                    "action_type": action.action_type.value,
                    "source_jd_ids": action.source_jd_ids,
                    "related_task_ids": action.related_task_ids,
                    "suggested_slot": action.suggested_slot,
                    "expected_output": action.expected_output,
                }
                for action in actions[:30]
            ],
            "matched_details": {
                "jd_entries": [self._entry_detail(entry) for entry in matched_entries[:5]],
                "analyses": [
                    analysis.model_dump(mode="json")
                    for entry in matched_entries[:5]
                    for analysis in self.analyses.list_by_entry(entry.id)[:2]
                ],
                "candidate_actions": [
                    action.model_dump(mode="json")
                    for action in matched_actions[:8]
                ],
                "tasks": [
                    task.model_dump(mode="json")
                    for task in matched_tasks[:8]
                ],
            },
        }
        return context

    def _matches_entry(self, query: str, entry: JDEntry) -> bool:
        text = " ".join(
            [
                entry.id,
                entry.company,
                entry.team_or_department,
                entry.role_title,
                entry.city,
                entry.jd_text,
                " ".join(entry.must_have_skills),
                " ".join(entry.bonus_skills),
                " ".join(entry.new_keywords),
            ]
        ).lower()
        return any(token and token in query for token in self._match_tokens(text))

    def _matches_action(self, query: str, action: CandidateAction) -> bool:
        text = " ".join(
            [
                action.id,
                action.title,
                action.reason,
                action.expected_output,
                action.suggested_slot,
                action.action_type.value,
                action.status.value,
            ]
        ).lower()
        return any(token and token in query for token in self._match_tokens(text))

    def _matches_task(self, query: str, task: TaskProfile) -> bool:
        text = " ".join(
            [
                task.id,
                task.title,
                task.category.value,
                task.current_phase,
                task.weekly_slot,
                task.progress_summary,
                task.next_milestone,
            ]
        ).lower()
        return any(token and token in query for token in self._match_tokens(text))

    def _match_tokens(self, text: str) -> List[str]:
        raw_tokens = [
            token.strip(" ,./|:;()[]{}-_")
            for token in text.replace("/", " ").replace("-", " ").split()
        ]
        return [token for token in raw_tokens if len(token) >= 3]

    def _entry_detail(self, entry: JDEntry) -> dict:
        return {
            "id": entry.id,
            "company": entry.company,
            "team_or_department": entry.team_or_department,
            "role_title": entry.role_title,
            "city": entry.city,
            "source_name": entry.source_name,
            "jd_text": entry.jd_text,
            "recruiter_context": entry.recruiter_context,
            "notes": entry.notes,
            "must_have_skills": entry.must_have_skills,
            "bonus_skills": entry.bonus_skills,
            "new_keywords": entry.new_keywords,
            "role_orientation": entry.role_orientation.value,
            "application_priority": entry.application_priority.value,
            "status": entry.status.value,
            "personal_gap_assessment": entry.personal_gap_assessment,
        }

    def _dedupe_actions(self, actions: List[CandidateAction]) -> List[CandidateAction]:
        seen = set()
        deduped = []
        for action in actions:
            key = (
                tuple(sorted(action.source_jd_ids)),
                action.action_type.value,
                action.title,
                action.expected_output,
            )
            if key in seen:
                continue
            seen.add(key)
            deduped.append(action)
        return deduped

    def decide_action(
        self,
        action_id: str,
        status: CandidateActionStatus,
        decision: CandidateActionDecision,
    ) -> Optional[CandidateAction]:
        action = self.actions.get(action_id)
        if action is None:
            return None
        updated = action.model_copy(
            update={
                "status": status,
                "user_decision_reason": decision.reason,
                "converted_task_id": decision.converted_task_id,
                "updated_at": datetime.now(timezone.utc),
            }
        )
        return self.actions.save(updated)

    def _recommend_actions(
        self,
        entry: JDEntry,
        analysis: JDFitAnalysis,
        wants_wm: bool,
        wants_reconstruction: bool,
        now: datetime,
    ) -> List[CandidateAction]:
        actions = [
            CandidateAction(
                id=f"candidate_action_{uuid4().hex[:12]}",
                source_jd_ids=[entry.id],
                source_analysis_ids=[analysis.id],
                action_type=CandidateActionType.update_resume,
                title="Update resume material with SLAM x 4DGS reconstruction evidence",
                reason="This JD can be answered better if the resume shows reconstruction evidence, not only localization history.",
                expected_output="One resume bullet and one project evidence note.",
                effort_estimate_min=45,
                priority=PriorityLevel.medium,
                time_sensitivity=TimeSensitivity.this_month,
                suggested_slot="Wednesday JD follow-up",
                created_at=now,
                updated_at=now,
            )
        ]
        if wants_wm:
            actions.append(
                CandidateAction(
                    id=f"candidate_action_{uuid4().hex[:12]}",
                    source_jd_ids=[entry.id],
                    source_analysis_ids=[analysis.id],
                    related_skill_ids=["skill_world_model_generation"],
                    action_type=CandidateActionType.run_experiment,
                    title="Run one lightweight driving video generation demo",
                    reason="This JD highlights WM / generation evidence, while the current task plan has WM entry planned next.",
                    expected_output="Runnable demo note with input/output form and generated video.",
                    effort_estimate_min=120,
                    priority=PriorityLevel.high,
                    time_sensitivity=TimeSensitivity.this_month,
                    suggested_slot="Week 9-10 WM pipeline slot",
                    created_at=now,
                    updated_at=now,
                )
            )
        if wants_reconstruction:
            actions.append(
                CandidateAction(
                    id=f"candidate_action_{uuid4().hex[:12]}",
                    source_jd_ids=[entry.id],
                    source_analysis_ids=[analysis.id],
                    related_skill_ids=["skill_4dgs_dynamic_reconstruction"],
                    action_type=CandidateActionType.run_experiment,
                    title="Finish nuScenes reconstruction comparison evidence",
                    reason="This JD values 3D/4D reconstruction; current reconstruction line should produce visible proof first.",
                    expected_output="GT-box vs SLAM filtering comparison video and metric table.",
                    effort_estimate_min=180,
                    priority=PriorityLevel.high,
                    time_sensitivity=TimeSensitivity.this_week,
                    suggested_slot="Current reconstruction main line",
                    created_at=now,
                    updated_at=now,
                )
            )
        return actions
