from response_engine import ResponseEngine
from summarizer import Summarizer
from session_memory import SessionMemory

class SolSyncAI:
    def __init__(self):
        self.memory = SessionMemory()
        self.responder = ResponseEngine(memory=self.memory)
        self.summarizer = Summarizer()

    def chat(self, message: str) -> dict:
        return self.responder.reply(message)

    def summarize_chat(self, chat_history: list[str]) -> str:
        return self.summarizer.summarize(chat_history)

    def reflect_entry(self, entry_text: str) -> str:
        return self.responder.reflect(entry_text)
