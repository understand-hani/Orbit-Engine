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

        url = f"{self.settings.openrouter_base_url.rstrip('/')}/chat/completions"
        headers = {
            "Authorization": f"Bearer {self.settings.openrouter_api_key}",
            "Content-Type": "application/json",
            "X-Title": self.settings.app_name,
        }
        if self.settings.openrouter_site_url:
            headers["HTTP-Referer"] = self.settings.openrouter_site_url

        with httpx.Client(timeout=self.settings.openrouter_timeout_sec, trust_env=False) as client:
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
    ) -> str:
        if not self.settings.openrouter_api_key:
            raise RuntimeError("OPENROUTER_API_KEY is not configured")

        body: Dict[str, Any] = {
            "model": self.settings.openrouter_model,
            "messages": [{"role": "system", "content": system_prompt}] + messages,
        }
        url = f"{self.settings.openrouter_base_url.rstrip('/')}/chat/completions"
        headers = {
            "Authorization": f"Bearer {self.settings.openrouter_api_key}",
            "Content-Type": "application/json",
            "X-Title": self.settings.app_name,
        }
        if self.settings.openrouter_site_url:
            headers["HTTP-Referer"] = self.settings.openrouter_site_url

        with httpx.Client(timeout=self.settings.openrouter_timeout_sec, trust_env=False) as client:
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
