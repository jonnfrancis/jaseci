"""Client-side lesson viewer DTO mirrors."""

obj:pub LessonSectionView {
    has id: str;
    has title: str;
    has content: str;
    has order_index: int;
}

obj:pub LessonExampleView {
    has id: str;
    has title: str;
    has code: str;
    has explanation: str;
    has order_index: int;
}

obj:pub LessonMiniExerciseView {
    has id: str;
    has prompt: str;
    has expected_concept: str;
    has order_index: int;
}

obj:pub LessonTakeawayView {
    has id: str;
    has content: str;
    has order_index: int;
}

obj:pub GeneratedLessonView {
    has id: str;
    has roadmap_id: str;
    has roadmap_lesson_id: str;
    has learner_id: str;
    has language: str;
    has title: str;
    has summary: str;
    has difficulty: str;
    has estimated_minutes: int;
    has generation_status: str;
    has created_at: str;
    has updated_at: str;
    has sections: list[LessonSectionView] = [];
    has examples: list[LessonExampleView] = [];
    has mini_exercises: list[LessonMiniExerciseView] = [];
    has key_takeaways: list[LessonTakeawayView] = [];
}

obj:pub LessonLinkView {
    has roadmap_lesson_id: str;
    has title: str;
    has order_label: str;
}
