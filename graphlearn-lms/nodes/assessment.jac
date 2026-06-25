"""Assessment domain nodes."""

enum AssessmentStatus: str {
    draft = "draft",
    active = "active",
    completed = "completed"
}

enum AssessmentQuestionType: str {
    multiple_choice = "multiple_choice",
    short_answer = "short_answer"
}

enum AssessmentDifficulty: str {
    beginner = "beginner",
    intermediate = "intermediate",
    advanced = "advanced"
}

node AssessmentOption {
    has id: str;
    has label: str;
    has value: str;
}

node AssessmentQuestion {
    has id: str;
    has question_text: str;
    has question_type: AssessmentQuestionType;
    has skill: str;
    has difficulty: AssessmentDifficulty;
    has options: list[AssessmentOption] = [];
}

node Assessment {
    has id: str;
    has learner_id: str;
    has title: str;
    has description: str;
    has status: AssessmentStatus;
    has created_at: str;
    has questions: list[AssessmentQuestion] = [];
}

edge AssessmentQuestionLink: Assessment --> AssessmentQuestion {}

edge AssessmentOptionLink: AssessmentQuestion --> AssessmentOption {}
