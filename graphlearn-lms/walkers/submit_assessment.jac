"""Assessment submission persistence walker."""

import from nodes.assessment {
    Assessment,
    AssessmentAttempt,
    AssessmentAttemptLink,
    AssessmentAttemptResponseLink,
    AssessmentAttemptStatus,
    AssessmentOption,
    AssessmentQuestion,
    AssessmentQuestionLink,
    AssessmentQuestionType,
    AssessmentResponse,
    AssessmentResponseQuestionLink,
    LearnerAssessmentAttemptLink
}
import from nodes.learner { Learner }
import from edges.domain_edges { assigned }

obj AssessmentResponseInput {
    has question_id: str;
    has answer_value: str;
    has response_type: AssessmentQuestionType;
}

obj AssessmentSubmissionError {
    has code: str;
    has message: str;
}

def get_attempt(attempt_id: str) -> AssessmentAttempt | None {
    for attempt in [root -->][?:AssessmentAttempt] {
        if attempt.id == attempt_id {
            return attempt;
        }
    }
    for assessment in [root -->][?:Assessment] {
        for attempt in [assessment ->:AssessmentAttemptLink:->][?:AssessmentAttempt] {
            if attempt.id == attempt_id {
                return attempt;
            }
        }
    }
    return None;
}

def get_attempt_responses(attempt_id: str) -> list[AssessmentResponse] {
    attempt = get_attempt(attempt_id);
    if attempt is None {
        return [];
    }
    return [attempt ->:AssessmentAttemptResponseLink:->][?:AssessmentResponse];
}

def get_learner_attempts(learner_id: str) -> list[AssessmentAttempt] {
    attempts: list[AssessmentAttempt] = [];
    for learner in [root -->][?:Learner, id == learner_id] {
        attempts = attempts + [learner ->:LearnerAssessmentAttemptLink:->][?:AssessmentAttempt];
    }
    return attempts;
}

def get_assessment_attempts(assessment_id: str) -> list[AssessmentAttempt] {
    assessment = _find_assessment(assessment_id);
    if assessment is None {
        return [];
    }
    return [assessment ->:AssessmentAttemptLink:->][?:AssessmentAttempt];
}

def _find_assessment(assessment_id: str) -> Assessment | None {
    for assessment in [root -->][?:Assessment, id == assessment_id] {
        return assessment;
    }
    return None;
}

def _find_learner(learner_id: str) -> Learner | None {
    for learner in [root -->][?:Learner, id == learner_id] {
        return learner;
    }
    return None;
}

def _assessment_learner(assessment: Assessment | None, learner_id: str) -> Learner | None {
    if assessment is not None {
        for learner in [(assessment as Assessment) <-:assigned:<-][?:Learner, id == learner_id] {
            return learner;
        }
    }
    return _find_learner(learner_id);
}

def _find_question(assessment: Assessment, question_id: str) -> AssessmentQuestion | None {
    for question in assessment.questions {
        if question.id == question_id {
            return question;
        }
    }
    for question in [assessment ->:AssessmentQuestionLink:->][?:AssessmentQuestion] {
        if question.id == question_id {
            return question;
        }
    }
    return None;
}

def _question_ids(assessment: Assessment) -> list[str] {
    ids: list[str] = [];
    for question in assessment.questions {
        ids = ids + [question.id];
    }
    for question in [assessment ->:AssessmentQuestionLink:->][?:AssessmentQuestion] {
        if question.id not in ids {
            ids = ids + [question.id];
        }
    }
    return ids;
}

def _has_valid_option(question: AssessmentQuestion, answer_value: str) -> bool {
    for option in question.options {
        if option.id == answer_value or option.value == answer_value {
            return True;
        }
    }
    for option in [question -->][?:AssessmentOption] {
        if option.id == answer_value or option.value == answer_value {
            return True;
        }
    }
    return False;
}

def _response_type_matches(question: AssessmentQuestion, response: AssessmentResponseInput) -> bool {
    return question.question_type == response.response_type;
}

def _validate_submission(
    assessment: Assessment | None,
    learner: Learner | None,
    responses: list[AssessmentResponseInput]
) -> list[AssessmentSubmissionError] {
    errors: list[AssessmentSubmissionError] = [];
    if assessment is None {
        errors = errors + [
            AssessmentSubmissionError(
                code="invalid_assessment",
                message="Assessment does not exist."
            )
        ];
    }
    if learner is None {
        errors = errors + [
            AssessmentSubmissionError(
                code="invalid_learner",
                message="Learner does not exist."
            )
        ];
    }
    if assessment is None or learner is None {
        return errors;
    }

    valid_question_ids = _question_ids(assessment);
    response_question_ids: list[str] = [];
    for response in responses {
        if response.question_id in response_question_ids {
            errors = errors + [
                AssessmentSubmissionError(
                    code="duplicate_response",
                    message=f"Question {response.question_id} has multiple responses."
                )
            ];
        }
        response_question_ids = response_question_ids + [response.question_id];

        if response.question_id not in valid_question_ids {
            errors = errors + [
                AssessmentSubmissionError(
                    code="invalid_question",
                    message=f"Question {response.question_id} does not belong to the assessment."
                )
            ];
            continue;
        }

        question = _find_question(assessment, response.question_id);
        if question is None {
            errors = errors + [
                AssessmentSubmissionError(
                    code="invalid_question",
                    message=f"Question {response.question_id} could not be retrieved."
                )
            ];
            continue;
        }
        if not _response_type_matches(question, response) {
            errors = errors + [
                AssessmentSubmissionError(
                    code="invalid_response_type",
                    message=f"Question {response.question_id} response type does not match the assessment question."
                )
            ];
        }
        if response.answer_value == "" {
            errors = errors + [
                AssessmentSubmissionError(
                    code="missing_answer",
                    message=f"Question {response.question_id} requires an answer."
                )
            ];
        }
        if question.question_type == AssessmentQuestionType.multiple_choice and not _has_valid_option(question, response.answer_value) {
            errors = errors + [
                AssessmentSubmissionError(
                    code="invalid_answer",
                    message=f"Question {response.question_id} references an invalid answer option."
                )
            ];
        }
    }

    for question_id in valid_question_ids {
        if question_id not in response_question_ids {
            errors = errors + [
                AssessmentSubmissionError(
                    code="missing_required_response",
                    message=f"Question {question_id} requires a response."
                )
            ];
        }
    }
    return errors;
}

walker submit_assessment {
    has learner_id: str;
    has assessment_id: str;
    has submitted_at: str;
    has responses: list[AssessmentResponseInput] = [];
    has errors: list[AssessmentSubmissionError] = [];
    has reports: list[AssessmentAttempt] = [];

    can submit with Root entry {
        assessment = _find_assessment(self.assessment_id);
        learner = _assessment_learner(assessment, self.learner_id);
        self.errors = _validate_submission(assessment, learner, self.responses);
        if len(self.errors) > 0 {
            return;
        }

        if assessment is None or learner is None {
            return;
        }
        assessment_node = assessment as Assessment;
        learner_node = learner as Learner;

        prior_count = len([assessment_node ->:AssessmentAttemptLink:->][?:AssessmentAttempt]);
        attempt = (assessment_node +>:AssessmentAttemptLink:+> AssessmentAttempt(
            id=f"{self.assessment_id}-attempt-{prior_count + 1}",
            learner_id=self.learner_id,
            assessment_id=self.assessment_id,
            status=AssessmentAttemptStatus.submitted,
            submitted_at=self.submitted_at,
            completed_at=self.submitted_at
        ))[0];
        learner_node +>:LearnerAssessmentAttemptLink:+> attempt;

        response_index = 0;
        for submitted_response in self.responses {
            response_index += 1;
            question = _find_question(assessment_node, submitted_response.question_id);
            if question is not None {
                response = (attempt +>:AssessmentAttemptResponseLink:+> AssessmentResponse(
                    id=f"{attempt.id}-response-{response_index}",
                    question_id=submitted_response.question_id,
                    answer_value=submitted_response.answer_value,
                    response_type=submitted_response.response_type
                ))[0];
                response +>:AssessmentResponseQuestionLink:+> question;
            }
        }

        report attempt;
    }
}
