"""Canonical typed traversals for assessment attempts and evaluations."""

import from nodes.assessment {
    Assessment,
    AssessmentAttempt,
    AssessmentAttemptLink,
    AssessmentAttemptResponseLink,
    AssessmentEvaluation,
    AssessmentEvaluationLink,
    AssessmentResponse
}

def assessment_attempts(assessment: Assessment) -> list[AssessmentAttempt] {
    return [assessment ->:AssessmentAttemptLink:->][?:AssessmentAttempt];
}

def assessment_attempt_for(
    assessment: Assessment,
    attempt_id: str
) -> AssessmentAttempt | None {
    for attempt in assessment_attempts(assessment) {
        if attempt.id == attempt_id {
            return attempt;
        }
    }
    return None;
}

def attempt_responses(attempt: AssessmentAttempt) -> list[AssessmentResponse] {
    return [attempt ->:AssessmentAttemptResponseLink:->][?:AssessmentResponse];
}

def attempt_evaluations(attempt: AssessmentAttempt) -> list[AssessmentEvaluation] {
    return [attempt ->:AssessmentEvaluationLink:->][?:AssessmentEvaluation];
}

def attempt_evaluation_for(
    attempt: AssessmentAttempt,
    evaluation_id: str
) -> AssessmentEvaluation | None {
    for evaluation in attempt_evaluations(attempt) {
        if evaluation.id == evaluation_id {
            return evaluation;
        }
    }
    return None;
}
