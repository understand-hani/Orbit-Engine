import json
from typing import Any, Dict, List, Optional, Type

import httpx
from pydantic import BaseModel

from app.config import get_settings
from app.schemas.common import TaskType
from app.schemas.jd_intelligence import (
    CandidateActionType,
    JDRoleType,
    MatchLevel,
    PriorityLevel,
    RiskLevel,
    TimeSensitivity,
    TimingRecommendation,
)


class MockLLMService:
    def reply(self, task_type: TaskType, user_content: str) -> str:
        if task_type == TaskType.tech_radar:
            prefix = "这是 mock 雷达讨论回复："
            guidance = "你可以继续追问该信号的技术实质、营销噪音或是否值得跟踪。"
        elif task_type == TaskType.jd_analysis:
            prefix = "这是 mock JD 分析回复："
            guidance = "你可以继续追问岗位匹配、红旗、简历表达或能力提升动作。"
        else:
            prefix = "这是 mock 论文阅读回复："
            guidance = "你可以继续追问论文段落、输入输出、核心方法、证据或局限性。"
        return f"{prefix}我已收到你的问题：{user_content}。{guidance}"


class LLMCandidateActionOutput(BaseModel):
    action_type: CandidateActionType
    title: str
    reason: str = ""
    expected_output: str = ""
    effort_estimate_min: int = 30
    priority: PriorityLevel = PriorityLevel.medium
    time_sensitivity: TimeSensitivity = TimeSensitivity.this_month
    risk: str = ""
    suggested_slot: str = ""
    related_skill_ids: List[str] = []
    related_task_ids: List[str] = []


class LLMJDFitAnalysisOutput(BaseModel):
    role_type: JDRoleType
    match_level: MatchLevel
    interest_adjusted_priority: PriorityLevel
    timing_recommendation: TimingRecommendation
    technical_overlap: List[str] = []
    missing_skills: List[str] = []
    fatal_gaps: List[str] = []
    trainable_gaps: List[str] = []
    evidence_needed: List[str] = []
    red_flags: List[str] = []
    tpm_risk_level: RiskLevel = RiskLevel.unknown
    company_style_risk: RiskLevel = RiskLevel.unknown
    resume_suggestions: List[str] = []
    interview_selling_points: List[str] = []
    questions_to_ask_recruiter: List[str] = []
    recommendation: str = ""
    reasoning: str = ""
    candidate_actions: List[LLMCandidateActionOutput] = []


class LLMCompletionDraftOutput(BaseModel):
    summary: str
    key_insight: str
    next_action: str


class LLMWeeklyStudioDraftOutput(BaseModel):
    completion_summary: str
    suggested_priorities: List[str] = []


class OpenRouterChatService:
    def __init__(self) -> None:
        self.settings = get_settings()

    def generate_json(
        self,
        *,
        system_prompt: str,
        user_payload: Dict[str, Any],
        output_model: Type[BaseModel],
        schema_name: str,
        timeout_sec: Optional[float] = None,
        max_tokens: Optional[int] = None,
    ) -> BaseModel:
        if not self.settings.openrouter_api_key:
            raise RuntimeError("OPENROUTER_API_KEY is not configured")

        body: Dict[str, Any] = {
            "model": self.settings.openrouter_model,
            "messages": [
                {
                    "role": "system",
                    "content": system_prompt,
                },
                {
                    "role": "user",
                    "content": json.dumps(user_payload, ensure_ascii=False, indent=2),
                },
            ],
            "response_format": {
                "type": "json_schema",
                "json_schema": {
                    "name": schema_name,
                    "strict": True,
                    "schema": output_model.model_json_schema(),
                },
            },
            "provider": {
                "require_parameters": True,
            },
        }
        if max_tokens is not None:
            body["max_tokens"] = max_tokens

        url = f"{self.settings.openrouter_base_url.rstrip('/')}/chat/completions"
        headers = {
            "Authorization": f"Bearer {self.settings.openrouter_api_key}",
            "Content-Type": "application/json",
            "X-Title": self.settings.app_name,
        }
        if self.settings.openrouter_site_url:
            headers["HTTP-Referer"] = self.settings.openrouter_site_url

        timeout = timeout_sec if timeout_sec is not None else self.settings.openrouter_timeout_sec
        with httpx.Client(timeout=timeout, trust_env=False) as client:
            response = client.post(url, headers=headers, json=body)
            response.raise_for_status()
        raw = response.json()
        output_text = self._extract_output_text(raw)
        return output_model.model_validate_json(output_text)

    def generate_text(
        self,
        *,
        system_prompt: str,
        messages: List[Dict[str, str]],
        timeout_sec: Optional[float] = None,
        max_tokens: Optional[int] = None,
    ) -> str:
        if not self.settings.openrouter_api_key:
            raise RuntimeError("OPENROUTER_API_KEY is not configured")

        body: Dict[str, Any] = {
            "model": self.settings.openrouter_model,
            "messages": [{"role": "system", "content": system_prompt}] + messages,
        }
        if max_tokens is not None:
            body["max_tokens"] = max_tokens
        url = f"{self.settings.openrouter_base_url.rstrip('/')}/chat/completions"
        headers = {
            "Authorization": f"Bearer {self.settings.openrouter_api_key}",
            "Content-Type": "application/json",
            "X-Title": self.settings.app_name,
        }
        if self.settings.openrouter_site_url:
            headers["HTTP-Referer"] = self.settings.openrouter_site_url

        timeout = timeout_sec if timeout_sec is not None else self.settings.openrouter_timeout_sec
        with httpx.Client(timeout=timeout, trust_env=False) as client:
            response = client.post(url, headers=headers, json=body)
            response.raise_for_status()
        return self._extract_output_text(response.json())

    def _extract_output_text(self, response: Dict[str, Any]) -> str:
        choices = response.get("choices", [])
        if choices:
            message = choices[0].get("message", {})
            content = message.get("content")
            if isinstance(content, str):
                return content
            if isinstance(content, list):
                parts = [item.get("text", "") for item in content if isinstance(item, dict)]
                text = "".join(parts).strip()
                if text:
                    return text

        raise RuntimeError("OpenRouter response did not contain message content")


JD_ANALYSIS_SYSTEM_PROMPT = """
You are the JD Career Agent in a private personal Infra Agent app.

Analyze one job description against this user's actual constraints and current
research plan. Return only structured JSON matching the supplied schema.

User background:
- Female, 32, Shanghai, M.S. Navigation Guidance and Control, B.S. Automation.
- About 7 years work experience.
- Strong production autonomous-driving high-precision localization background:
  GNSS/IMU fusion, SLAM, pose estimation, HD-map and lane-level localization.
- Current differentiator: SLAM geometric intuition x 4DGS dynamic reconstruction
  x autonomous-driving engineering experience.
- Current learning line: StreetGaussian/4DGS reconstruction evidence, then
  lightweight driving world-model inference pipeline, then direction decision.
- Current timing: do not push immediate job change during pregnancy preparation
  and expected childbirth/recovery window. Maintain market awareness, build
  capability and evidence, and build contact only when useful.

Judgment rules:
- Explicitly detect TPM/project coordination variants. Coordination, supplier
  management, resource pushing, or obedience-heavy roles are red flags unless
  the JD is still clearly hands-on technical.
- Prefer research engineer, research-engineering, or algorithm engineer roles
  connected to SLAM, 3D/4D reconstruction, autonomous driving, embodied AI,
  driving world models, simulation, or deep learning training.
- Distinguish fatal gaps from trainable gaps.
- Candidate actions must not disrupt low-adjustability current reconstruction
  tasks unless the action directly strengthens the user's main direction.
- Recommendations should preserve optionality and avoid encouraging immediate
  application unless the JD is unusually strong and timing risk is low.

Candidate actions should be concrete and small enough to fit the current window.
Use existing skill/task ids when relevant:
- skill_localization_gnss_imu
- skill_slam_geometric_consistency
- skill_4dgs_dynamic_reconstruction
- skill_world_model_generation
- task_reconstruction_wrap_up
- task_world_model_entry
""".strip()


JD_DISCUSSION_SYSTEM_PROMPT = """
You are the JD discussion agent in a private personal Infra Agent app.

Help the user reason about job descriptions, market signals, skill gaps,
candidate actions, resume evidence, and timing. Keep the user's strategy:
maintain market awareness, do not push immediate applications, avoid TPM-like
roles, and preserve the differentiator of SLAM geometry x 4D dynamic
reconstruction x autonomous-driving engineering.

The backend may attach a compact JSON context containing JD library entries,
latest analyses, skill stack, task state, and candidate actions. Use that
context actively when the user mentions a company, role, JD, action, task, week,
or capability. If a referenced item cannot be found in the attached context,
say what is missing.

Answer in concise Chinese unless the user asks otherwise. Be concrete and
actionable.
""".strip()


DEEP_DIVE_DISCUSSION_SYSTEM_PROMPT = """
You are the Deep Dive research reading agent in a private personal Infra Agent app.

Help the user understand one research/material reading task and turn it into
clear next actions. Focus on:
- what the material is about;
- why it matters to the user's SLAM / 4DGS / driving world model direction;
- what to read next;
- what evidence or notes should be archived.

Answer in concise Chinese. Be concrete, avoid generic encouragement, and keep
the user moving toward a usable check-in or archive note.
""".strip()


RADAR_DISCUSSION_SYSTEM_PROMPT = """
你是圆周引擎的 Signal Radar 讨论助手，负责陪用户讨论一条行业雷达信号（Signal Radar item）。

后端会附上这条信号的上下文：摘要、技术实质、营销噪音、为何重要、证据状态、
推荐深度、关键段落（含摘录、分析、建议）以及扫描范围。回答时必须优先基于这些内容，
不要把 signal id 当成唯一信息。

帮助用户判断：
- 这条信号是否改变当前计划或值得转入 Deep Dive；
- 证据是否充分，是否只是标题或宣传口径；
- 该信号的技术实质、噪音和可验证点；
- 下一步该做什么（读原文、暂存、忽略或追问细节）。

规则：
- 区分事实证据与营销 / 宣传口径，不要替报道背书；
- 上下文不足时明确说出还缺什么信息，不要编造；
- 回答用简洁中文，具体、可执行，避免泛泛鼓励。
""".strip()


DEEP_DIVE_COMPLETION_DRAFT_SYSTEM_PROMPT = """
You are the Deep Dive check-in drafting agent in a private personal Infra Agent app.

Generate a concise Chinese check-in draft for one Deep Dive session. Return only
structured JSON matching the supplied schema.

Rules:
- summary: one or two sentences describing what was done in this reading session.
- key_insight: the most useful learning, judgment, or evidence captured.
- next_action: one concrete next step the user can do later.
- Prefer concrete evidence from selected_materials, primary_paper, paper_reader,
  user notes, and agent_discussions when they are present.
- If source/user notes are thin, produce a safe, specific draft based on the
available reading goal and completion criteria. Do not invent paper facts.
""".strip()


WEEKLY_STUDIO_DRAFT_SYSTEM_PROMPT = """
You are the Weekly Studio review agent in a private personal Infra Agent app.
Return only structured JSON matching the supplied schema.

Write a concise but substantive weekly learning summary only from the supplied
completed check-ins and their linked Radar or Deep Dive evidence. Output
Simplified Chinese only, in 2-4 short sentences. Extract the core method,
evidence, or technical judgment and explain its implication for the current
plan. Translate and synthesize English source material; never paste an English
paper title, abstract, reading goal, or raw source passage. Treat the Check-in
summary as a completion marker only: the summary must be grounded in the linked
Radar signal or Deep Dive notes/material evidence, not a restatement of the
Check-in sentence. Do not say only that a paper or task was completed. Do not
invent achievements.

Then propose at most three next priorities that preserve the user's confirmed
weekly focus and active tasks. Reorder, narrow, or continue existing work; do
not replace the plan with a different direction.
""".strip()


DIRECTION_PROFILE_SUGGESTION_SYSTEM_PROMPT = """
You are the onboarding agent for a private personal Infra Agent app.

Given a user's broad direction, generate a practical configuration that can drive
daily Deep Dive material discovery. Return only structured JSON matching the
supplied schema.

Rules:
- Do not assume the user is in 4DGS, world models, AI, software, or research.
- Adapt to the domain described by the user.
- If full_cycle_plan is provided, treat it as the user-confirmed plan and generate
  downstream content based on that edited version instead of replacing it.
- When generating weekly_focus and active_tasks from full_cycle_plan, use only
  the execution step matching the current week, starting with Week 1 during
  onboarding. Do not copy an entire phase into weekly_focus.
- If weekly_focus or active_tasks are provided, preserve that confirmed week-level
  intent and mainly improve downstream retrieval strategy fields.
- Keep weekly_focus concrete enough to generate search queries this week.
- Use target_cycle to create a full_cycle_plan, with 3-4 editable milestones only.
- Do not output vague labels like just a tool, framework, or topic name.
- Each milestone should describe a concrete phase objective plus the specific
  work to do or output to produce in that phase.
- Format each full_cycle_plan item as a readable block:
  第 N 阶段（时间范围）
  目标：
  1. ...
  2. ...
  具体执行计划：
  1. ...
  2. ...
  3. ...
  产出：
  1. ...
- Keep goals, execution steps, and outputs semantically distinct. Do not repeat
  the same statement in more than one section.
- Execution steps must be detailed enough for the user to act without guessing:
  name the questions to answer, material types to collect, comparison dimensions,
  validation task shape, and the concrete note/result to write.
- Execution steps must cover the whole phase, but do not add mechanical labels
  such as Week 1-2 / Day 1-5. The phase heading already carries the time range.
- Avoid non-actionable steps such as "complete a project", "learn basics",
  "do research", or "improve ability" unless they are immediately followed by
  specific week/day actions and observable completion criteria.
- Generate execution steps and outputs specifically for each milestone's goal.
  Never reuse the same execution plan or output list across different phases.
- active_tasks should be small, observable actions.
- active_tasks must be specific enough that a user can immediately act on them.
- tracking_keywords should be useful search keywords, not generic motivation.
- Build tracking_keywords and fields from the user's current_direction,
  long_term_goal, confirmed full_cycle_plan, weekly_focus, and active_tasks.
- Never substitute generic app concepts such as personal agent, learning
  workflow, material source, execution loop, career capability, or
  self-directed learning unless the user explicitly declared that direction.
- Prefer concrete domain terms, methods, systems, applications, datasets, and
  research questions that can be used directly in a search query.
- source_preferences must use only: pdf, url, manual, public_source, arxiv,
  github, official_doc.
- constraints should help the Agent avoid broad, unfocused reading.
""".strip()
