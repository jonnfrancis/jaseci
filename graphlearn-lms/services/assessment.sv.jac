"""Assessment UI service endpoints.

These functions project assessment graph entities into UI-safe view models and
persist learner answers. They do not run learner-outcome workflows.
"""

import from nodes.assessment {
    Assessment,
    AssessmentOption,
    AssessmentQuestion,
    AssessmentQuestionType,
    AssessmentStatus,
    AssessmentSubmission,
    StoredQuestionResponse
}

obj AssessmentOptionView {
    has id: str;
    has label: str;
    has value: str;
}

obj AssessmentQuestionView {
    has id: str;
    has question_text: str;
    has question_type: str;
    has skill: str;
    has difficulty: str;
    has required: bool = True;
    has options: list[AssessmentOptionView] = [];
}

obj AssessmentView {
    has id: str;
    has learner_id: str;
    has title: str;
    has description: str;
    has status: str;
    has created_at: str;
    has questions: list[AssessmentQuestionView] = [];
}

obj QuestionResponsePayload {
    has question_id: str;
    has question_type: str;
    has selected_option_id: str = "";
    has short_answer: str = "";
}

obj AssessmentSubmissionPayload {
    has assessment_id: str;
    has learner_id: str;
    has submitted_at: str;
    has responses: list[QuestionResponsePayload] = [];
}

obj AssessmentSubmissionReceipt {
    has submission_id: str;
    has assessment_id: str;
    has learner_id: str;
    has response_count: int;
    has submitted_at: str;
}

def _question_type_from_payload(question_type: str) -> AssessmentQuestionType {
    if question_type == "multiple_choice" {
        return AssessmentQuestionType.multiple_choice;
    }
    return AssessmentQuestionType.short_answer;
}

def _option_to_view(option: AssessmentOption) -> AssessmentOptionView {
    return AssessmentOptionView(
        id=option.id,
        label=option.label,
        value=option.value
    );
}

def _question_to_view(question: AssessmentQuestion) -> AssessmentQuestionView {
    return AssessmentQuestionView(
        id=question.id,
        question_text=question.question_text,
        question_type=question.question_type.value,
        skill=question.skill,
        difficulty=question.difficulty.value,
        required=True,
        options=[_option_to_view(option) for option in question.options]
    );
}

def _assessment_to_view(assessment: Assessment) -> AssessmentView {
    return AssessmentView(
        id=assessment.id,
        learner_id=assessment.learner_id,
        title=assessment.title,
        description=assessment.description,
        status=assessment.status.value,
        created_at=assessment.created_at,
        questions=[_question_to_view(question) for question in assessment.questions]
    );
}

def:pub load_assessment(learner_id: str) -> AssessmentView | None {
    for assessment in [root -->][?:Assessment] {
        if assessment.learner_id == learner_id and assessment.status != AssessmentStatus.completed {
            return _assessment_to_view(assessment);
        }
    }
    return None;
}

def:pub submit_assessment_responses(payload: dict[str, str | list[dict[str, str]]]) -> AssessmentSubmissionReceipt {
    assessment_id = payload["assessment_id"] as str;
    learner_id = payload["learner_id"] as str;
    submitted_at = payload["submitted_at"] as str;
    responses = payload["responses"] as list[dict[str, str]];
    prior_count: int = 0;
    for existing in [root -->][?:AssessmentSubmission] {
        if existing.assessment_id == assessment_id {
            prior_count += 1;
        }
    }
    submission_id = f"{assessment_id}-submission-{prior_count + 1}";
    stored_responses: list[StoredQuestionResponse] = [];

    for response in responses {
        stored_responses = stored_responses + [
            StoredQuestionResponse(
                question_id=response["question_id"],
                question_type=_question_type_from_payload(response["question_type"]),
                selected_option_id=response["selected_option_id"],
                short_answer=response["short_answer"]
            )
        ];
    }

    submission = (root ++> AssessmentSubmission(
        id=submission_id,
        assessment_id=assessment_id,
        learner_id=learner_id,
        submitted_at=submitted_at,
        responses=stored_responses
    ))[0];

    return AssessmentSubmissionReceipt(
        submission_id=submission.id,
        assessment_id=submission.assessment_id,
        learner_id=submission.learner_id,
        response_count=len(submission.responses),
        submitted_at=submission.submitted_at
    );
}
