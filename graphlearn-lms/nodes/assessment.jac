"""Assessment domain nodes."""

enum AssessmentStatus: str {
    draft = "draft",
    active = "active",
    completed = "completed"
}

enum AssessmentAttemptStatus: str {
    draft = "draft",
    in_progress = "in_progress",
    submitted = "submitted"
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

obj StoredQuestionResponse {
    has question_id: str;
    has question_type: AssessmentQuestionType;
    has selected_option_id: str = "";
    has short_answer: str = "";
}

node AssessmentSubmission {
    has id: str;
    has assessment_id: str;
    has learner_id: str;
    has submitted_at: str;
    has responses: list[StoredQuestionResponse] = [];
}

node AssessmentAttempt {
    has id: str;
    has learner_id: str;
    has assessment_id: str;
    has status: AssessmentAttemptStatus;
    has submitted_at: str;
    has completed_at: str;
}

node AssessmentResponse {
    has id: str;
    has question_id: str;
    has answer_value: str;
    has response_type: AssessmentQuestionType;
}

edge AssessmentQuestionLink: Assessment --> AssessmentQuestion {}

edge AssessmentOptionLink: AssessmentQuestion --> AssessmentOption {}

edge LearnerAssessmentAttemptLink {}

edge AssessmentAttemptLink: Assessment --> AssessmentAttempt {}

edge AssessmentAttemptResponseLink: AssessmentAttempt --> AssessmentResponse {}

edge AssessmentResponseQuestionLink: AssessmentResponse --> AssessmentQuestion {}
