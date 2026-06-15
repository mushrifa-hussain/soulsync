"""
Simple in-memory session-scoped memory store.
Stores facts like name, preferences, etc. for the current chat session only.
"""


class SessionMemory:
    """Session-scoped memory for storing simple facts."""
    
    def __init__(self):
        self.memory: dict[str, str] = {}
    
    def store(self, key: str, value: str):
        """Store a fact in memory."""
        self.memory[key] = value
    
    def get(self, key: str) -> str | None:
        """Retrieve a fact from memory."""
        return self.memory.get(key)
    
    def has(self, key: str) -> bool:
        """Check if a fact exists in memory."""
        return key in self.memory
    
    def clear(self):
        """Clear all memory (called when session ends)."""
        self.memory.clear()
    
    def get_all(self) -> dict[str, str]:
        """Get all stored facts."""
        return self.memory.copy()
    
    def to_context_string(self) -> str:
        """Convert memory to a context string for LLM."""
        if not self.memory:
            return "No facts remembered yet."
        
        facts = []
        for key, value in self.memory.items():
            facts.append(f"{key}: {value}")
        
        return "Remembered facts: " + "; ".join(facts)

