from __future__ import annotations

from datetime import datetime, timezone
from typing import List, Optional
from uuid import uuid4

from app.db.repositories import ChatRepository, SessionRepository
from app.schemas.common import TaskType
from app.schemas.chat import (
    AIChatMessage,
    AIChatSendResponse,
    AIChatSummary,
    AIChatThread,
    AIChatThreadCreate,
    ChatRole,
)
from app.schemas.research_feeder import PaperReader, ResearchFeederPayload
from app.schemas.tech_radar import RadarItem, TechRadarPayload
from app.services.llm_service import (
    DEEP_DIVE_DISCUSSION_SYSTEM_PROMPT,
    DISCUSSION_ARCHIVE_SYSTEM_PROMPT,
    JD_DISCUSSION_SYSTEM_PROMPT,
    LLMCompletionDraftOutput,
    RADAR_DISCUSSION_SYSTEM_PROMPT,
    MockLLMService,
    OpenRouterChatService,
)
from app.config import get_settings


class ChatService:
    def __init__(self) -> None:
        self.chats = ChatRepository()
        self.sessions = SessionRepository()
        self.settings = get_settings()
        self.mock_llm = MockLLMService()
        self.openrouter = OpenRouterChatService()

    def create_thread(self, request: AIChatThreadCreate) -> Optional[AIChatThread]:
        session = self.sessions.get_by_id(request.session_id)
        if session is None:
            return None
        now = datetime.now(timezone.utc)
        existing_threads = self.chats.get_by_session(session.id)
        for thread in existing_threads:
            if sorted(thread.context_refs) == sorted(request.context_refs):
                return thread
        thread_id = session.ai_chat_thread_id
        if existing_threads:
            thread_id = f"chat_{uuid4().hex[:12]}"
        thread = AIChatThread(
            id=thread_id,
            session_id=session.id,
            task_type=session.task_type,
            context_refs=request.context_refs,
            messages=[],
            created_at=now,
            updated_at=now,
        )
        return self.chats.save_thread(thread)

    def get_thread(self, thread_id: str) -> Optional[AIChatThread]:
        return self.chats.get_thread(thread_id)

    def get_threads_by_session(self, session_id: str) -> List[AIChatThread]:
        return self.chats.get_by_session(session_id)

    def send_message(self, thread_id: str, content: str) -> Optional[AIChatSendResponse]:
        thread = self.chats.get_thread(thread_id)
        if thread is None:
            return None
        now = datetime.now(timezone.utc)
        user_message = AIChatMessage(
            id=f"msg_{uuid4().hex[:12]}",
            role=ChatRole.user,
            content=content,
            created_at=now,
        )
        assistant_message = AIChatMessage(
            id=f"msg_{uuid4().hex[:12]}",
            role=ChatRole.assistant,
            content=self._reply(thread, content),
            created_at=datetime.now(timezone.utc),
        )
        updated_thread = thread.model_copy(
            update={
                "messages": thread.messages + [user_message, assistant_message],
                "updated_at": datetime.now(timezone.utc),
            }
        )
        self.chats.save_thread(updated_thread)
        return AIChatSendResponse(
            thread=updated_thread,
            user_message=user_message,
            assistant_message=assistant_message,
        )

    def summarize_thread(self, thread_id: str) -> Optional[AIChatSummary]:
        thread = self.chats.get_thread(thread_id)
        if thread is None:
            return None

        conversation = [
            {
                "role": message.role.value,
                "content": self._truncate(message.content, 800),
            }
            for message in thread.messages
            if self._is_valid_discussion_message(message)
        ]
        conversation = conversation[-6:]

        if self.settings.llm_provider == "openrouter" and conversation:
            try:
                draft = self.openrouter.generate_json(
                    system_prompt=DISCUSSION_ARCHIVE_SYSTEM_PROMPT,
                    user_payload={"conversation": conversation},
                    output_model=LLMCompletionDraftOutput,
                    schema_name="discussion_archive_draft",
                    timeout_sec=10,
                    max_tokens=240,
                )
                return AIChatSummary(
                    thread_id=thread.id,
                    session_id=thread.session_id,
                    suggested_title=f"Discussion note: {thread.task_type.value}",
                    summary=draft.summary,
                    key_insights=[draft.key_insight],
                    action_items=[draft.next_action],
                    context_refs=thread.context_refs,
                )
            except Exception:
                pass

        fallback_summary, fallback_insight, fallback_action = self._fallback_discussion_takeaway(
            thread.task_type
        )
        return AIChatSummary(
            thread_id=thread.id,
            session_id=thread.session_id,
            suggested_title=f"Discussion note: {thread.task_type.value}",
            summary=fallback_summary,
            key_insights=[fallback_insight],
            action_items=[fallback_action],
            context_refs=thread.context_refs,
        )

    def _reply(self, thread: AIChatThread, content: str) -> str:
        if self.settings.llm_provider != "openrouter":
            return self.mock_llm.reply(thread.task_type, content)

        try:
            return self.openrouter.generate_text(
                system_prompt=self._system_prompt_for(thread),
                messages=self._messages_for(thread, content),
                timeout_sec=8,
                max_tokens=320,
            )
        except Exception as exc:
            return (
                f"Mock fallback（OpenRouter 调用失败：{self._format_openrouter_error(exc)}）："
                f"{self.mock_llm.reply(thread.task_type, content)}"
            )

    def _system_prompt_for(self, thread: AIChatThread) -> str:
        if thread.task_type.value == "jd_analysis":
            return JD_DISCUSSION_SYSTEM_PROMPT
        if thread.task_type.value == "tech_radar":
            return RADAR_DISCUSSION_SYSTEM_PROMPT
        return DEEP_DIVE_DISCUSSION_SYSTEM_PROMPT

    def _messages_for(self, thread: AIChatThread, content: str) -> list[dict[str, str]]:
        messages = [
            {
                "role": "assistant" if message.role == ChatRole.assistant else "user",
                "content": message.content,
            }
            for message in thread.messages[-4:]
            if message.role in {ChatRole.user, ChatRole.assistant}
        ]
        context_message = self._context_message_for(thread)
        if context_message:
            messages.append(
                {
                    "role": "user",
                    "content": context_message,
                }
            )
        elif thread.context_refs:
            messages.append(
                {
                    "role": "user",
                    "content": f"上下文引用：{', '.join(thread.context_refs)}",
                }
            )
        messages.append({"role": "user", "content": content})
        return messages

    def _context_message_for(self, thread: AIChatThread) -> str:
        session = self.sessions.get_by_id(thread.session_id)
        if session is None:
            return ""
        if session.task_type == TaskType.tech_radar:
            return self._radar_context_message(thread, session)
        if session.task_type != TaskType.research_feeder:
            return ""
        payload = session.payload
        if not isinstance(payload, ResearchFeederPayload):
            return ""

        lines = [
            "Deep Dive 当前材料上下文如下。回答用户时必须优先基于这些内容，不要把 paper_id 当成唯一信息。",
            f"Session: {session.title}",
            f"当前方向: {payload.research_context.current_direction}",
            f"当前任务: {payload.research_context.current_task}",
            f"本周目标: {payload.research_context.week_goal}",
            f"相关项目: {payload.research_context.related_project}",
            f"选材理由: {payload.reading_pack.selection_reason}",
            f"阅读目标: {payload.reading_pack.reading_goal}",
        ]

        if payload.selected_materials:
            lines.append("已确认材料:")
            for material in payload.selected_materials[:5]:
                material_url = str(material.url) if material.url else ""
                lines.append(
                    "- "
                    f"title={material.title}; "
                    f"summary={self._truncate(material.summary, 500)}; "
                    f"url={material_url}; "
                    f"source_type={material.source_type}"
                )

        paper_ref = self._first_matching_paper_ref(thread.context_refs, payload)
        paper = next((item for item in payload.papers if item.id == paper_ref), None)
        if paper is not None:
            lines.extend(
                [
                    "当前论文:",
                    f"- id: {paper.id}",
                    f"- title: {paper.title}",
                    f"- authors: {', '.join(paper.authors)}",
                    f"- venue/year: {paper.venue} {paper.year or ''}".strip(),
                    f"- url: {str(paper.url) if paper.url else ''}",
                    f"- pdf_url: {str(paper.pdf_url) if paper.pdf_url else ''}",
                    f"- repo_url: {str(paper.repo_url) if paper.repo_url else ''}",
                    f"- summary: {self._truncate(paper.summary, 800)}",
                    f"- why_selected: {self._truncate(paper.why_selected, 400)}",
                    f"- tags: {', '.join(paper.tags)}",
                ]
            )

            reader = self._reader_for(payload, paper.id)
            if reader is not None:
                self._append_reader_context(lines, reader, thread.context_refs)

        if payload.notes:
            lines.extend(
                [
                    "当前笔记:",
                    f"- input_output: {payload.notes.input_output}",
                    f"- core_idea: {payload.notes.core_idea}",
                    f"- evidence: {payload.notes.evidence}",
                    f"- relation_to_my_plan: {payload.notes.relation_to_my_plan}",
                    f"- next_action: {payload.notes.next_action}",
                ]
            )

        return "\n".join(line for line in lines if line.strip())

    def _radar_context_message(self, thread: AIChatThread, session) -> str:
        payload = session.payload
        if not isinstance(payload, TechRadarPayload):
            return ""
        lines = [
            "Signal Radar 信号上下文如下。回答用户时必须优先基于这些内容，不要把 signal id 当成唯一信息。",
            f"Session: {session.title}",
            f"Signal Radar 类型: {payload.radar_type.value}",
            f"本轮摘要: {payload.digest.summary}",
        ]
        scope_parts = [
            f"topics={', '.join(payload.scope.topics)}" if payload.scope.topics else "",
            f"companies={', '.join(payload.scope.companies)}" if payload.scope.companies else "",
            f"research_groups={', '.join(payload.scope.research_groups)}" if payload.scope.research_groups else "",
        ]
        if any(scope_parts):
            lines.append(f"扫描范围: {', '.join(part for part in scope_parts if part)}")

        item = self._matching_radar_item(thread.context_refs, payload)
        if item is not None:
            lines.extend(self._radar_item_lines(item))
        elif payload.digest.items:
            lines.append("当前信号列表（未匹配到具体 signal 引用时使用前 3 条）:")
            for item in payload.digest.items[:3]:
                lines.extend(self._radar_item_lines(item))
        return "\n".join(line for line in lines if line.strip())

    def _matching_radar_item(self, context_refs: List[str], payload: TechRadarPayload) -> Optional[RadarItem]:
        item_ids = {item.id for item in payload.digest.items}
        for ref in context_refs:
            candidate = ref
            if ref.startswith("signal:"):
                candidate = ref[len("signal:"):]
            if candidate in item_ids:
                return next(item for item in payload.digest.items if item.id == candidate)
        return None

    def _radar_item_lines(self, item: RadarItem) -> List[str]:
        lines = [
            "Signal Radar 信号:",
            f"- id: {item.id}",
            f"- title: {item.title}",
            f"- source: {item.source}",
            f"- signal_type: {item.signal_type}",
            f"- url: {str(item.url) if item.url else ''}",
            f"- summary: {item.summary}",
            f"- technical_substance: {item.technical_substance}",
            f"- marketing_noise: {item.marketing_noise}",
            f"- why_it_matters: {item.why_it_matters}",
            f"- evidence_status: {item.evidence_status}",
            f"- recommended_depth: {item.recommended_depth.value}",
            f"- tags: {', '.join(item.tags)}",
            f"- user_mark: {item.user_mark.value}",
        ]
        if item.source_passages:
            lines.append("- source_passages:")
            for passage in item.source_passages[:5]:
                passage_url = str(passage.source_url) if passage.source_url else ""
                lines.append(
                    f"  - [{passage.title}] {passage.excerpt}"
                    f"（analysis: {passage.analysis}；suggestion: {passage.suggestion}；"
                    f"url: {passage_url}；location: {passage.location}）"
                )
        return lines

    def _first_matching_paper_ref(
        self,
        context_refs: List[str],
        payload: ResearchFeederPayload,
    ) -> Optional[str]:
        paper_ids = {paper.id for paper in payload.papers}
        for ref in context_refs:
            if ref in paper_ids:
                return ref
        for material in payload.selected_materials:
            if material.paper_id and material.paper_id in paper_ids:
                return material.paper_id
            if material.id in paper_ids:
                return material.id
        return payload.reading_pack.primary_paper_id if payload.reading_pack.primary_paper_id in paper_ids else None

    def _reader_for(self, payload: ResearchFeederPayload, paper_id: str) -> Optional[PaperReader]:
        for reader in payload.paper_readers:
            if reader.paper_id == paper_id:
                return reader
        if payload.paper_reader and payload.paper_reader.paper_id == paper_id:
            return payload.paper_reader
        return None

    def _append_reader_context(
        self,
        lines: List[str],
        reader: PaperReader,
        context_refs: List[str],
    ) -> None:
        lines.append("阅读器上下文:")
        if reader.pdf_url:
            lines.append(f"- pdf_url: {str(reader.pdf_url)}")

        matching_sections = [section for section in reader.sections if section.id in context_refs]
        matching_passages = [passage for passage in reader.selected_passages if passage.id in context_refs]
        matching_figures = [figure for figure in reader.key_figures if figure.id in context_refs]

        sections = matching_sections or reader.sections[:3]
        if sections:
            lines.append("阅读章节:")
            for section in sections:
                page = self._page_range(section.page_start, section.page_end)
                lines.append(
                    "- "
                    f"{section.section_name}; "
                    f"page={page}; "
                    f"mode={section.read_mode.value}; "
                    f"why_read={section.why_read}; "
                    f"agent_instruction={section.agent_instruction}; "
                    f"knowledge_points={', '.join(section.knowledge_points)}; "
                    f"extracted_text={self._truncate(section.extracted_text, 1200)}"
                )

        passages = matching_passages or reader.selected_passages[:3]
        if passages:
            lines.append("精选段落:")
            for passage in passages:
                lines.append(
                    "- "
                    f"section={passage.section_name}; "
                    f"page={passage.page or ''}; "
                    f"text={self._truncate(passage.text_excerpt, 1000)}; "
                    f"why_selected={passage.why_selected}; "
                    f"reading_question={passage.reading_question}"
                )

        figures = matching_figures or reader.key_figures[:2]
        if figures:
            lines.append("关键图:")
            for figure in figures:
                lines.append(
                    "- "
                    f"{figure.figure_label}; "
                    f"page={figure.page or ''}; "
                    f"caption={figure.visual.caption}; "
                    f"why_important={figure.why_important}; "
                    f"reading_question={figure.reading_question}"
                )

    def _page_range(self, page_start: Optional[int], page_end: Optional[int]) -> str:
        if page_start is None:
            return ""
        if page_end is None or page_end == page_start:
            return str(page_start)
        return f"{page_start}-{page_end}"

    def _format_openrouter_error(self, exc: Exception) -> str:
        text = str(exc)
        if "429" in text or "Too Many Requests" in text:
            return "429 rate limit or quota issue"
        if "OPENROUTER_API_KEY" in text:
            return "missing OPENROUTER_API_KEY"
        return text[:180]

    def _truncate(self, value: str, limit: int) -> str:
        text = value.strip()
        if len(text) <= limit:
            return text
        return f"{text[:limit].rstrip()}..."

    def _is_valid_discussion_message(self, message: AIChatMessage) -> bool:
        content = message.content.strip()
        if message.role not in {ChatRole.user, ChatRole.assistant} or not content:
            return False
        if message.role == ChatRole.user:
            return True
        failure_markers = (
            "Mock fallback",
            "The request timed out",
            "讨论请求失败",
            "远端 Agent 暂未响应",
        )
        return not any(marker in content for marker in failure_markers)

    def _fallback_discussion_takeaway(self, task_type: TaskType) -> tuple[str, str, str]:
        if task_type == TaskType.tech_radar:
            return (
                "本次讨论聚焦于当前信号的信息可信度、技术实质与跟进价值。",
                "核心判断是先区分一手证据与转载信息，再评估信号的技术实质和跟进价值。",
                "核验信号的一手来源，并据此决定是否转入 Deep Dive。",
            )
        if task_type == TaskType.research_feeder:
            return (
                "本次讨论聚焦于论文结论、证据支撑及其与当前研究任务的关联。",
                "核心判断是用原文段落和图表证据校验结论，避免把材料概述视为已验证事实。",
                "回到原文核对一条能直接支持当前判断的证据。",
            )
        return (
            "本次讨论聚焦于岗位要求、现有能力证据与优先补齐方向。",
            "核心判断是把岗位要求映射到已有经历与能力缺口，再确定可验证的优先行动。",
            "选择一个最关键的能力缺口，完成对应的验证行动。",
        )
