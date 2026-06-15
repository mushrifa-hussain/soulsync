import random
import os
import re
from emotion_detector import EmotionDetector
from conversation_state import ConversationState
from session_memory import SessionMemory

# Try to load .env file if available
try:
    from dotenv import load_dotenv
    env_path = os.path.join(os.path.dirname(__file__), '.env')
    if os.path.exists(env_path):
        load_dotenv(env_path)
except ImportError:
    pass

# Import Gemini phraser (with fallback if not available)
try:
    from gemini_phraser import generate_hybrid_reply
    GEMINI_AVAILABLE = True
except ImportError:
    GEMINI_AVAILABLE = False
    print("Warning: gemini_phraser not available. Using fallback responses.")


class ResponseEngine:
    def __init__(self, memory: SessionMemory = None):
        self.detector = EmotionDetector()
        self.state = ConversationState()
        self.memory = memory or SessionMemory()

    def _detect_intent(self, user_text: str) -> str:
        """
        Simple intent detection based on keywords.
        Your existing AIML logic can replace this method.
        """
        text_lower = user_text.lower()
        
        # Crisis intent
        if any(word in text_lower for word in ["die", "kill", "end my life", "suicide"]):
            return "crisis_support"
        
        # Emotional support intent (including requests for comfort and emotional states)
        if any(word in text_lower for word in ["feel", "feeling", "hurt", "pain", "sad", "lonely", 
                                                "make me feel better", "cheer me up", "comfort me", 
                                                "help me feel", "make me happy", "i am tired", 
                                                "i'm tired", "i am sad", "i'm sad", "i am stressed",
                                                "i'm stressed", "i am anxious", "i'm anxious",
                                                "i am worried", "i'm worried", "i am upset", "i'm upset"]):
            return "emotional_support"
        
        # Venting intent
        if any(word in text_lower for word in ["hate", "frustrated", "angry", "annoyed", "tired of"]):
            return "venting"
        
        # Seeking advice or help
        if any(word in text_lower for word in ["should i", "what should", "advice", "help me", "how do i", 
                                                "can you help", "what can i do"]):
            return "seeking_advice"
        
        # Sharing positive
        if any(word in text_lower for word in ["great", "happy", "excited", "good", "wonderful"]):
            return "sharing"
        
        # Default
        return "general"

    def _extract_memory(self, user_text: str) -> dict[str, str] | None:
        """
        Extract simple facts from user message (e.g., "my name is X").
        Returns dict with key-value pairs to store, or None if no memory detected.
        """
        text_lower = user_text.lower().strip()
        memory_updates = {}
        
        # Check if name already exists in memory
        name_already_exists = self.memory.has("name")
        
        # Common adjectives/emotions that should NOT be treated as names
        excluded_words = {
            'tired', 'exhausted', 'drained', 'weary', 'fatigued', 'worn', 'spent',
            'happy', 'sad', 'angry', 'excited', 'nervous', 'anxious',
            'stressed', 'worried', 'scared', 'afraid', 'confused', 'lost',
            'fine', 'okay', 'ok', 'good', 'bad', 'great', 'awesome', 'terrible',
            'amazing', 'wonderful', 'horrible', 'awful', 'fantastic', 'perfect',
            'ready', 'done', 'finished', 'here', 'there', 'back', 'away',
            'alone', 'together', 'free', 'busy', 'available', 'unavailable',
            'overwhelmed', 'frustrated', 'disappointed', 'upset', 'hurt',
            'lonely', 'empty', 'numb', 'broken', 'defeated', 'hopeless',
            'grateful', 'blessed', 'lucky', 'proud', 'confident', 'strong',
            'weak', 'vulnerable', 'fragile', 'sensitive', 'emotional'
        }
        
        # Explicit name patterns - always check these (user might be changing their name)
        explicit_name_patterns = [
            r"my name is ([a-zA-Z]+(?:\s+[a-zA-Z]+)*)",  # "my name is John" or "my name is John Smith"
            r"call me ([a-zA-Z]+(?:\s+[a-zA-Z]+)*)",  # "call me John"
        ]
        
        # Implicit name patterns - only check if name doesn't exist yet
        implicit_name_patterns = [
            r"i'?m ([a-zA-Z]+)(?:\s|$|,|\.)",  # "I'm John" (but not "I'm tired")
            r"i am ([a-zA-Z]+)(?:\s|$|,|\.)",  # "I am John" (but not "I am exhausted")
        ]
        
        # Always check explicit patterns (user might be changing their name)
        for pattern in explicit_name_patterns:
            match = re.search(pattern, text_lower)
            if match:
                potential_name = match.group(1).strip().lower()
                # Check if it's NOT an excluded word (adjective/emotion)
                if potential_name not in excluded_words:
                    if len(potential_name) > 1 and len(potential_name) < 50:
                        name_parts = potential_name.split()
                        capitalized_name = ' '.join(word.capitalize() for word in name_parts)
                        memory_updates["name"] = capitalized_name
                        break
        
        # Only check implicit patterns if name doesn't exist yet
        # This prevents "I am exhausted" from being treated as a name when name already exists
        if not name_already_exists:
            for pattern in implicit_name_patterns:
                match = re.search(pattern, text_lower)
                if match:
                    potential_name = match.group(1).strip().lower()
                    # Check if it's NOT an excluded word (adjective/emotion)
                    if potential_name not in excluded_words:
                        if len(potential_name) > 1 and len(potential_name) < 50:
                            name_parts = potential_name.split()
                            capitalized_name = ' '.join(word.capitalize() for word in name_parts)
                            memory_updates["name"] = capitalized_name
                            break
        
        # Pattern: "I like X" or "I love X" or "I prefer X"
        preference_patterns = [
            r"i (?:like|love|prefer) ([^.!?]+)",
        ]
        
        for pattern in preference_patterns:
            match = re.search(pattern, text_lower)
            if match:
                preference = match.group(1).strip()
                if len(preference) < 100:  # Reasonable length
                    memory_updates["preference"] = preference
                    break
        
        return memory_updates if memory_updates else None
    
    def _is_memory_query(self, user_text: str) -> bool:
        """
        Check if user is asking about remembered facts.
        """
        text_lower = user_text.lower().strip()
        memory_query_patterns = [
            r"what (?:is|'s) my name",
            r"what did i tell you (?:my name|about)",
            r"do you remember (?:my name|what i said)",
            r"what (?:do you know|did i say) about me",
        ]
        
        return any(re.search(pattern, text_lower) for pattern in memory_query_patterns)
    
    def _is_ai_name_query(self, user_text: str) -> bool:
        """
        Check if user is asking about the AI's name (not their own).
        """
        text_lower = user_text.lower().strip()
        ai_name_query_patterns = [
            r"what (?:is|'s) your name",
            r"what (?:is|'s) (?:the )?ai'?s name",
            r"who are you",
            r"what are you called",
            r"tell me your name",
        ]
        
        return any(re.search(pattern, text_lower) for pattern in ai_name_query_patterns)

    def reply(self, user_text: str) -> dict:
        # Your existing AIML logic - emotion detection
        analysis = self.detector.detect(user_text)
        emotion = analysis["emotion"]

        # Detect intent first (before updating state)
        intent = self._detect_intent(user_text)
        
        # Extract and store memory if detected
        memory_updates = self._extract_memory(user_text)
        if memory_updates:
            for key, value in memory_updates.items():
                self.memory.store(key, value)
        
        # Check if user is asking about memory (e.g., "what is my name?")
        is_memory_query = self._is_memory_query(user_text)
        
        # Check if user is asking about AI's name (e.g., "what is your name?")
        is_ai_name_query = self._is_ai_name_query(user_text)
        
        # If user is explicitly asking for emotional support (make me feel better, cheer me up),
        # they're likely in a negative state even if emotion detection didn't catch it
        if intent == "emotional_support":
            # Always treat requests for emotional support as indicating sadness
            emotion = "sad"  # Override emotion to ensure supporting mode
        
        # Update conversation state
        self.state.update(emotion)

        short_replies = ["yes", "ok", "okay", "no", "hmm", "ya"]

        # Handle short replies naturally
        if user_text.lower().strip() in short_replies:
            if self.state.mode == "supporting":
                return {"reply": "🤗 I'm listening. You can share whatever you feel."}
            if self.state.mode == "crisis":
                return {"reply": "🫂 I'm still here with you."}
            return {"reply": "🤗 Got it. Tell me more."}

        # Handle AI name query directly (before Gemini, to ensure correct response)
        if is_ai_name_query:
            return {"reply": "I'm SoulSync AI, your companion 🤗💜"}
        
        # Try using Gemini phraser if available and API key is set
        if GEMINI_AVAILABLE and os.getenv('GEMINI_API_KEY'):
            try:
                context = {
                    "emotion": emotion,
                    "intent": intent,
                    "conversation_mode": self.state.mode,
                    "user_message": user_text,
                    "memory": self.memory.to_context_string(),
                    "is_memory_query": is_memory_query,
                    "is_ai_name_query": is_ai_name_query
                }
                reply = generate_hybrid_reply(context)
                return {"reply": reply}
            except Exception as e:
                # Fallback to existing responses if Gemini fails
                print(f"Gemini phraser error: {e}. Using fallback responses.")

        # Fallback: Use existing hardcoded responses
        # 🚨 crisis reply
        if self.state.mode == "crisis":
            return {
                "reply": "🫂 I'm really glad you told me this. Your life matters. Please reach out to someone you trust or a mental health professional."
            }

        responses = {
            "sad": [
                "💙 That sounds really painful. I'm here with you.",
                "🫂 I'm glad you shared this with me.",
                "🤗 It feels like you're carrying a lot inside.",
                "🥲 I'm here with you through this."
            ],
            "stressed": [
                "🤗 That sounds overwhelming. Anyone would feel tired.",
                "💭 It feels like today asked too much from you.",
                "☕ Let's take this one step at a time.",
                "🫂 I'm here to listen."
            ],
            "anxious": [
                "🌊 Your thoughts seem heavy right now.",
                "🫂 It's okay to feel this way.",
                "🤗 Let's slow down together.",
                "💙 I'm here with you."
            ],
            "happy": [
                "🥰 That's really nice to hear.",
                "✨ I'm glad something good happened today.",
                "🌱 Hold on to this feeling.",
                "💛 That makes me happy for you!"
            ],
            "neutral": [
                "🤗 I'm here with you.",
                "🥰 Tell me more about your day.",
                "💜 I'm listening.",
                "🤗 What's on your mind?"
            ]
        }

        reply = random.choice(responses.get(emotion, responses["neutral"]))

        return {"reply": reply}
