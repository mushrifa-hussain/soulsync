class ConversationState:
    def __init__(self):
        self.mode = "neutral"  # neutral | supporting | crisis

    def update(self, emotion):
        if emotion == "crisis":
            self.mode = "crisis"
        elif emotion in ["sad", "stressed", "anxious"]:
            self.mode = "supporting"
        else:
            self.mode = "neutral"
