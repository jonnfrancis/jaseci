"""Lesson domain node."""

enum Difficulty: str {
    beginner = "beginner",
    intermediate = "intermediate",
    advanced = "advanced"
}

enum LessonGenerationStatus: str {
    pending = "pending",
    generated = "generated"
}

node Lesson {
    has id: str;
    has title: str;
    has summary: str;
    has skillId: str;
    has difficulty: Difficulty;
    has estimatedMinutes: int;
}

node GeneratedLesson {
    has id: str;
    has learner_id: str;
    has roadmap_id: str;
    has roadmap_lesson_id: str;
    has language: str;
    has title: str;
    has summary: str;
    has difficulty: str;
    has estimated_minutes: int;
    has created_at: str;
    has updated_at: str;
    has generation_status: LessonGenerationStatus;
    has sections: list[LessonSection] = [];
    has examples: list[LessonExample] = [];
    has mini_exercises: list[LessonMiniExercise] = [];
    has key_takeaways: list[LessonTakeaway] = [];
}

node LessonSection {
    has id: str;
    has lesson_id: str;
    has title: str;
    has content: str;
    has order_index: int;
}

node LessonExample {
    has id: str;
    has lesson_id: str;
    has title: str;
    has code: str;
    has explanation: str;
    has order_index: int;
}

node LessonMiniExercise {
    has id: str;
    has lesson_id: str;
    has prompt: str;
    has expected_concept: str;
    has order_index: int;
}

node LessonTakeaway {
    has id: str;
    has lesson_id: str;
    has content: str;
    has order_index: int;
}
