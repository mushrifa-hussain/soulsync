"""
FastAPI backend for AIML conversational AI system.
Exposes existing AI classes as REST API endpoints.
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List, Tuple
import uuid
from main_ai import SolSyncAI
from response_engine import ResponseEngine

app = FastAPI(title="SoulSync AI API", version="1.0.0")

# Enable CORS for Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Session storage: session_id -> SolSyncAI instance
sessions: dict[str, SolSyncAI] = {}

# Global AI instance for non-session endpoints
global_ai = SolSyncAI()


class ChatRequest(BaseModel):
    message: str
    session_id: Optional[str] = None
    user_name: Optional[str] = None  # User's name for session initialization


class ChatResponse(BaseModel):
    reply: str
    analysis: Optional[dict] = None
    session_id: Optional[str] = None


class ReflectRequest(BaseModel):
    text: str


class ReflectResponse(BaseModel):
    reflection: str


class SummarizeRequest(BaseModel):
    messages: List[str]


class SummarizeResponse(BaseModel):
    summary: str


class ResetRequest(BaseModel):
    session_id: str


def get_or_create_session(session_id: Optional[str] = None) -> Tuple[SolSyncAI, str]:
    """Get existing session or create new one."""
    if session_id and session_id in sessions:
        return sessions[session_id], session_id
    
    new_session_id = str(uuid.uuid4())
    new_ai = SolSyncAI()
    sessions[new_session_id] = new_ai
    return new_ai, new_session_id


@app.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    """Chat endpoint - processes user message and returns AI reply."""
    try:
        ai, session_id = get_or_create_session(request.session_id)
        
        # If user_name is provided and not already stored, save it to session memory
        if request.user_name and not ai.memory.has("name"):
            ai.memory.store("name", request.user_name)
        
        # Get reply from AI
        result = ai.chat(request.message)
        reply = result.get("reply", "")
        
        # Get analysis if available (emotion, intent, mode)
        analysis = None
        if hasattr(ai.responder, 'detector') and hasattr(ai.responder, 'state'):
            emotion_analysis = ai.responder.detector.detect(request.message)
            analysis = {
                "emotion": emotion_analysis.get("emotion"),
                "conversation_mode": ai.responder.state.mode
            }
        
        return ChatResponse(
            reply=reply,
            analysis=analysis,
            session_id=session_id
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error processing chat: {str(e)}")


@app.post("/reflect", response_model=ReflectResponse)
async def reflect(request: ReflectRequest):
    """Reflect endpoint - generates AI reflection on diary entry."""
    try:
        # Check if reflect method exists
        if hasattr(global_ai.responder, 'reflect'):
            reflection = global_ai.reflect_entry(request.text)
        else:
            # Fallback: use chat method for reflection
            result = global_ai.chat(f"Please reflect on this diary entry: {request.text}")
            reflection = result.get("reply", "Unable to generate reflection.")
        
        return ReflectResponse(reflection=reflection)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error generating reflection: {str(e)}")


@app.post("/summarize", response_model=SummarizeResponse)
async def summarize(request: SummarizeRequest):
    """Summarize endpoint - summarizes list of messages."""
    try:
        if not request.messages:
            raise HTTPException(status_code=400, detail="Messages list cannot be empty")
        
        summary = global_ai.summarize_chat(request.messages)
        return SummarizeResponse(summary=summary)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error generating summary: {str(e)}")


@app.get("/health")
async def health():
    """Health check endpoint."""
    return {"status": "ok", "sessions": len(sessions)}


@app.post("/chat/reset")
async def reset_chat(request: ResetRequest):
    """Reset chat session - clears memory and conversation state."""
    session_id = request.session_id
    if session_id in sessions:
        ai = sessions[session_id]
        ai.memory.clear()
        # Recreate ResponseEngine to reset conversation state
        from response_engine import ResponseEngine
        from session_memory import SessionMemory
        ai.memory = SessionMemory()
        ai.responder = ResponseEngine(memory=ai.memory)
        return {"status": "reset", "session_id": session_id}
    raise HTTPException(status_code=404, detail="Session not found")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

