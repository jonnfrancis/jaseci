"""Assessment-taking state management."""

import from "..types.response_models" { AssessmentResponse, QuestionResponse }
sv import from "....services.assessment" {
    AssessmentSubmissionReceipt,
    AssessmentView,
    load_assessment,
    submit_assessment_responses
}

def _has_answer(response: QuestionResponse) -> bool {
    if response.question_type == "multiple_choice" {
        return response.selected_option_id != "";
    }
    return response.short_answer.strip() != "";
}

def _find_response(responses: list[QuestionResponse], question_id: str) -> QuestionResponse | None {
    for response in responses {
        if response.question_id == question_id {
            return response;
        }
    }
    return None;
}

def _question_is_answered(responses: list[QuestionResponse], question_id: str) -> bool {
    response = _find_response(responses, question_id);
    return response is not None and _has_answer(response);
}

def _invalid_question_ids(assessment: AssessmentView | None, responses: list[QuestionResponse]) -> list[str] {
    if assessment is None {
        return [];
    }

    missing: list[str] = [];
    for question in assessment.questions {
        if question.required and not _question_is_answered(responses, question.id) {
            missing = missing + [question.id];
        }
    }
    return missing;
}

def _answered_count(assessment: AssessmentView | None, responses: list[QuestionResponse]) -> int {
    if assessment is None {
        return 0;
    }

    count: int = 0;
    for question in assessment.questions {
        if _question_is_answered(responses, question.id) {
            count += 1;
        }
    }
    return count;
}

def _completion_percentage(assessment: AssessmentView | None, responses: list[QuestionResponse]) -> int {
    if assessment is None or len(assessment.questions) == 0 {
        return 0;
    }
    return int((_answered_count(assessment, responses) * 100) / len(assessment.questions));
}

def _to_payload_response(response: QuestionResponse) -> dict[str, str] {
    return {
        "question_id": response.question_id,
        "question_type": response.question_type,
        "selected_option_id": response.selected_option_id,
        "short_answer": response.short_answer
    };
}

def:pub useAssessmentState(learner_id: str) -> dict[str, any] {
    has assessment: AssessmentView | None = None;
    has responses: list[QuestionResponse] = [];
    has loading: bool = True;
    has load_error: str = "";
    has submitting: bool = False;
    has submission_error: str = "";
    has submission_receipt: AssessmentSubmissionReceipt | None = None;
    has attempted_submit: bool = False;

    async can with entry {
        loaded: AssessmentView | None = None;
        try {
            loaded = await load_assessment(learner_id);
            assessment = loaded;
        } except Exception {
            load_error = "Assessment could not be loaded.";
        }
        loading = False;
    }

    def answer_multiple_choice(question_id: str, option_id: str) -> None {
        next_responses: list[QuestionResponse] = [];
        replaced: bool = False;

        for response in responses {
            if response.question_id == question_id {
                next_responses = next_responses + [
                    QuestionResponse(
                        question_id=question_id,
                        question_type="multiple_choice",
                        selected_option_id=option_id
                    )
                ];
                replaced = True;
            } else {
                next_responses = next_responses + [response];
            }
        }

        if not replaced {
            next_responses = next_responses + [
                QuestionResponse(
                    question_id=question_id,
                    question_type="multiple_choice",
                    selected_option_id=option_id
                )
            ];
        }
        responses = next_responses;
    }

    def answer_short(question_id: str, answer_text: str) -> None {
        next_responses: list[QuestionResponse] = [];
        replaced: bool = False;

        for response in responses {
            if response.question_id == question_id {
                next_responses = next_responses + [
                    QuestionResponse(
                        question_id=question_id,
                        question_type="short_answer",
                        short_answer=answer_text
                    )
                ];
                replaced = True;
            } else {
                next_responses = next_responses + [response];
            }
        }

        if not replaced {
            next_responses = next_responses + [
                QuestionResponse(
                    question_id=question_id,
                    question_type="short_answer",
                    short_answer=answer_text
                )
            ];
        }
        responses = next_responses;
    }

    async def submit() -> None {
        attempted_submit = True;
        submission_error = "";

        if assessment is None {
            submission_error = "Assessment is unavailable.";
            return;
        }

        invalid: list[str] = _invalid_question_ids(assessment, responses);
        if len(invalid) > 0 {
            submission_error = "Answer every required question before submitting.";
            return;
        }

        submitting = True;
        response_model = AssessmentResponse(
            assessment_id=assessment.id,
            learner_id=assessment.learner_id,
            responses=responses
        );
        payload = {
            "assessment_id": response_model.assessment_id,
            "learner_id": response_model.learner_id,
            "submitted_at": "client-submitted",
            "responses": [_to_payload_response(response) for response in response_model.responses]
        };

        try {
            submission_receipt = await submit_assessment_responses(payload);
        } except Exception {
            submission_error = "Assessment responses could not be submitted.";
        }

        submitting = False;
    }

    invalid_ids = _invalid_question_ids(assessment, responses) if attempted_submit else [];

    return {
        "assessment": assessment,
        "responses": responses,
        "loading": loading,
        "load_error": load_error,
        "submitting": submitting,
        "submission_error": submission_error,
        "submission_receipt": submission_receipt,
        "attempted_submit": attempted_submit,
        "invalid_question_ids": invalid_ids,
        "answered_count": _answered_count(assessment, responses),
        "completion_percentage": _completion_percentage(assessment, responses),
        "answer_multiple_choice": answer_multiple_choice,
        "answer_short": answer_short,
        "submit": submit
    };
}
