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
import from lib.observability.instrumentation { graph_operation_event }
import from lib.observability.tracing { monotonic_ms }

def assessment_attempts(assessment: Assessment) -> list[AssessmentAttempt] {
    started = monotonic_ms();
    results = [assessment ->:AssessmentAttemptLink:->][?:AssessmentAttempt];
    graph_operation_event("assessment_attempts", "read", True, max(0, monotonic_ms() - started), len(results));
    return results;
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
