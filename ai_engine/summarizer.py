import os
import google.generativeai as genai

# Try to load from .env file if available
try:
    from dotenv import load_dotenv
    env_path = os.path.join(os.path.dirname(__file__), '.env')
    if os.path.exists(env_path):
        load_dotenv(env_path)
except ImportError:
    pass


class Summarizer:
    def summarize(self, messages: list[str]) -> str:
        """
        Generate a journal-style first-person summary from chat messages.
        Uses Gemini for natural phrasing if available, otherwise falls back to simple concatenation.
        """
        if not messages:
            return ""
        
        # Try using Gemini for journal-style summary if available
        api_key = os.getenv('GEMINI_API_KEY')
        if api_key:
            try:
                return self._generate_journal_summary(messages)
            except Exception as e:
                print(f"Gemini summarization error: {e}. Using fallback.")
        
        # Fallback: simple concatenation
        joined = " ".join(messages)
        if len(joined.split()) < 40:
            return joined
        important_words = joined.split()[:40]
        return " ".join(important_words) + "..."
    
    def _generate_journal_summary(self, messages: list[str]) -> str:
        """Generate journal-style summary using Gemini."""
        api_key = os.getenv('GEMINI_API_KEY')
        genai.configure(api_key=api_key)
        model = genai.GenerativeModel('gemini-2.0-flash-exp')
        
        # Extract only user messages (not AI responses)
        user_messages = []
        for msg in messages:
            # If message doesn't start with "SoulSync AI:" or "AI:", assume it's a user message
            if not msg.strip().startswith(("SoulSync AI:", "AI:", "You:")):
                user_messages.append(msg.strip())
        
        if not user_messages:
            # If no user messages found, use all messages
            user_messages = [msg.strip() for msg in messages if msg.strip()]
        
        conversation_text = "\n".join(user_messages)
        
        prompt = f"""Convert this conversation into a first-person journal entry. Write it as if the user is reflecting on their day and feelings.

CONVERSATION:
{conversation_text}

REQUIREMENTS:
- Write in FIRST PERSON ("I", "my", "me") - like a personal diary entry
- Include emotional tone and feelings naturally
- Use 1-2 appropriate emojis naturally within the text
- Write as ONE smooth paragraph (no bullet points, no line breaks)
- Keep it concise (2-4 sentences)
- Reflect the user's actual words and feelings - DO NOT invent events or details not mentioned
- Make it feel like a genuine journal reflection, not a summary

Generate ONLY the journal entry text. No explanations, no markdown, just the plain journal entry."""
        
        try:
            response = model.generate_content(prompt)
            summary = response.text.strip()
            
            # Clean up any markdown formatting that might slip through
            summary = summary.replace("**", "").replace("*", "").replace("#", "").strip()
            
            # Ensure it's a single paragraph
            summary = " ".join(summary.split())
            
            return summary if summary else self._get_fallback_summary(messages)
        except Exception as e:
            print(f"Gemini journal summary error: {e}")
            return self._get_fallback_summary(messages)
    
    def _get_fallback_summary(self, messages: list[str]) -> str:
        """Simple fallback summary."""
        user_messages = [msg.strip() for msg in messages if msg.strip() and not msg.strip().startswith(("SoulSync AI:", "AI:"))]
        if not user_messages:
            user_messages = [msg.strip() for msg in messages if msg.strip()]
        
        joined = " ".join(user_messages)
        if len(joined.split()) < 40:
            return f"Today I {joined.lower()}"
        
        important_words = joined.split()[:40]
        return f"Today I {' '.join(important_words)}..."
