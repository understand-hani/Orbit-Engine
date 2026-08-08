from datetime import datetime, timezone
from typing import List, Optional
from uuid import uuid4

from app.db.repositories import ChatRepository, SessionRepository
from app.schemas.chat import (
    AIChatMessage,
    AIChatSendResponse,
    AIChatSummary,
    AIChatThread,
    AIChatThreadCreate,
    ChatRole,
)
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
        if thread.context_refs:
            messages.append(
                {
                    "role": "user",
                    "content": f"上下文引用：{', '.join(thread.context_refs)}",
                }
            )
        messages.append({"role": "user", "content": content})
        return messages

    def _format_openrouter_error(self, exc: Exception) -> str:
        text = str(exc)
        if "429" in text or "Too Many Requests" in text:
            return "429 rate limit or quota issue"
        if "OPENROUTER_API_KEY" in text:
            return "missing OPENROUTER_API_KEY"
        return text[:180]
