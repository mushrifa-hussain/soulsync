from vaderSentiment.vaderSentiment import SentimentIntensityAnalyzer
from text_processor import TextProcessor


class EmotionDetector:
    def __init__(self):
        self.analyzer = SentimentIntensityAnalyzer()
        self.processor = TextProcessor()

    def detect(self, text: str) -> dict:
        clean = self.processor.clean_text(text)

        # 🚨 crisis detection
        crisis_words = [
            "i am dying",
            "i want to die",
            "kill myself",
            "end my life",
            "no reason to live"
        ]
        if any(word in clean for word in crisis_words):
            return {"emotion": "crisis"}

        # keyword based detection
        if any(w in clean for w in ["sad", "crying", "lonely", "empty", "hurt"]):
            return {"emotion": "sad"}

        if any(w in clean for w in ["stress", "stressed", "pressure", "overwhelmed", "fed up"]):
            return {"emotion": "stressed"}

        if any(w in clean for w in ["anxious", "worried", "scared", "afraid"]):
            return {"emotion": "anxious"}

        # fallback sentiment
        score = self.analyzer.polarity_scores(clean)["compound"]

        if score > 0.3:
            return {"emotion": "happy"}

        return {"emotion": "neutral"}
