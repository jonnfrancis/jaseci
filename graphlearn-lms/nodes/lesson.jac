"""Lesson domain node."""

enum Difficulty: str {
    beginner = "beginner",
    intermediate = "intermediate",
    advanced = "advanced"
}

node Lesson {
    has id: str;
    has title: str;
    has summary: str;
    has skillId: str;
    has difficulty: Difficulty;
    has estimatedMinutes: int;
}
