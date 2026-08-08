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
from app.services.llm_service import (
    DEEP_DIVE_DISCUSSION_SYSTEM_PROMPT,
    JD_DISCUSSION_SYSTEM_PROMPT,
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
        thread = AIChatThread(
            id=session.ai_chat_thread_id or f"chat_{uuid4().hex[:12]}",
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

        user_messages = [message.content for message in thread.messages if message.role == ChatRole.user]
        assistant_messages = [
            message.content for message in thread.messages if message.role == ChatRole.assistant
        ]

        latest_user = user_messages[-1] if user_messages else "No user question yet."
        latest_assistant = assistant_messages[-1] if assistant_messages else "No agent answer yet."
        context_label = ", ".join(thread.context_refs) if thread.context_refs else "current material"

        if self.settings.llm_provider == "openrouter":
            try:
                summary_text = self.openrouter.generate_text(
                    system_prompt=self._system_prompt_for(thread),
                    messages=[
                        {
                            "role": "user",
                            "content": (
                                "请把以下 Deep Dive 讨论整理成可归档的 check-in 草稿，"
                                "包含简短总结、关键收获和下一步。\n"
                                f"用户消息：{user_messages}\nAgent 回复：{assistant_messages}"
                            ),
                        }
                    ],
                )
                return AIChatSummary(
                    thread_id=thread.id,
                    session_id=thread.session_id,
                    suggested_title=f"Discussion note: {thread.task_type.value}",
                    summary=summary_text,
                    key_insights=[summary_text],
                    action_items=["把该讨论结果并入本次 Deep Dive check-in 或后续阅读计划。"],
                    context_refs=thread.context_refs,
                )
            except Exception:
                pass

        return AIChatSummary(
            thread_id=thread.id,
            session_id=thread.session_id,
            suggested_title=f"Discussion note: {thread.task_type.value}",
            summary=(
                "Mock summary: discussed the current material with the Agent. "
                f"Context: {context_label}. Main user question: {latest_user}"
            ),
            key_insights=[
                f"Agent response to keep: {latest_assistant}",
                "This note is generated by the mock summarizer and can be edited before saving.",
            ],
            action_items=[
                "Review whether this discussion changes the current study or tracking plan.",
                "Replace the mock summarizer with an LLM-backed summarizer later.",
            ],
            context_refs=thread.context_refs,
        )

    def _reply(self, thread: AIChatThread, content: str) -> str:
        if self.settings.llm_provider != "openrouter":
            return self.mock_llm.reply(thread.task_type, content)

        try:
            return self.openrouter.generate_text(
                system_prompt=self._system_prompt_for(thread),
                messages=self._messages_for(thread, content),
            )
        except Exception as exc:
            return (
                f"Mock fallback（OpenRouter 调用失败：{self._format_openrouter_error(exc)}）："
                f"{self.mock_llm.reply(thread.task_type, content)}"
            )

    def _system_prompt_for(self, thread: AIChatThread) -> str:
        if thread.task_type.value == "jd_analysis":
            return JD_DISCUSSION_SYSTEM_PROMPT
        return DEEP_DIVE_DISCUSSION_SYSTEM_PROMPT

    def _messages_for(self, thread: AIChatThread, content: str) -> list[dict[str, str]]:
        messages = [
            {
                "role": "assistant" if message.role == ChatRole.assistant else "user",
                "content": message.content,
            }
            for message in thread.messages[-8:]
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
        if session is None or session.task_type != TaskType.research_feeder:
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
                    f"summary={material.summary}; "
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
                    f"- summary: {paper.summary}",
                    f"- why_selected: {paper.why_selected}",
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
                    f"extracted_text={section.extracted_text}"
                )

        passages = matching_passages or reader.selected_passages[:3]
        if passages:
            lines.append("精选段落:")
            for passage in passages:
                lines.append(
                    "- "
                    f"section={passage.section_name}; "
                    f"page={passage.page or ''}; "
                    f"text={passage.text_excerpt}; "
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
