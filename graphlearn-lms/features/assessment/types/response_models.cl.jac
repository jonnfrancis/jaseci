"""Client-side assessment response models."""

obj:pub MultipleChoiceResponse {
    has question_id: str;
    has selected_option_id: str;
}

obj:pub ShortAnswerResponse {
    has question_id: str;
    has answer_text: str;
}

obj:pub QuestionResponse {
    has question_id: str;
    has question_type: str;
    has selected_option_id: str = "";
    has short_answer: str = "";
}

obj:pub AssessmentResponse {
    has assessment_id: str;
    has learner_id: str;
    has responses: list[QuestionResponse] = [];
}
