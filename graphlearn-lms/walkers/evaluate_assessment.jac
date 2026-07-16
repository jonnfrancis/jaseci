"""Assessment evaluation walker."""

import from lib.assessment.evaluation {
    AssessmentEvaluationError,
    evaluate_assessment_responses,
    validate_evaluation_inputs
}
import from lib.observability.instrumentation { observe_walker_finish, observe_walker_start }
import from lib.graph.assessment_queries {
    assessment_attempt_for,
    attempt_evaluations,
    attempt_responses
}
import from nodes.assessment {
    Assessment,
    AssessmentAttempt,
    AssessmentAttemptLink,
    AssessmentAttemptResponseLink,
    AssessmentAttemptStatus,
    AssessmentEvaluation,
    AssessmentEvaluationLink,
    AssessmentResponse,
    AssessmentStatus
}

glob EVALUATION_VERSION = "assessment-evaluation-v1";

def get_assessment_evaluation(attempt_id: str) -> AssessmentEvaluation | None {
    attempt = _find_attempt(attempt_id);
    if attempt is None {
        return None;
    }
    for evaluation in attempt_evaluations(attempt) {
        return evaluation;
    }
    return None;
}

def _find_assessment(assessment_id: str) -> Assessment | None {
    for assessment in [root -->][?:Assessment, id == assessment_id] {
        return assessment;
    }
    return None;
}

def _find_attempt(attempt_id: str) -> AssessmentAttempt | None {
    for attempt in [root -->][?:AssessmentAttempt, id == attempt_id] {
        return attempt;
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

walker evaluate_assessment {
    has assessment_id: str;
    has assessment_attempt_id: str;
    has evaluated_at: str;
    has errors: list[AssessmentEvaluationError] = [];
    has reports: list[AssessmentEvaluation] = [];
    has request_id: str = "";
    has correlation_id: str = "";

    can observability_start with Root entry { observe_walker_start(self); }
    can observability_finish with Root exit { observe_walker_finish(self); }

    can evaluate with Root entry {
        assessments = [root -->][?:Assessment, id == self.assessment_id];
        attempts: list[AssessmentAttempt] = [];

        if len(assessments) == 0 {
            self.errors = self.errors + [
                AssessmentEvaluationError(
                    code="missing_assessment",
                    message="Assessment does not exist."
                )
            ];
        }
        if len(self.errors) > 0 {
            return;
        }

        assessment = assessments[0];
        found_attempt = assessment_attempt_for(assessment, self.assessment_attempt_id);
        if found_attempt is not None {
            attempts = attempts + [found_attempt as AssessmentAttempt];
        }
        if len(attempts) == 0 {
            self.errors = self.errors + [
                AssessmentEvaluationError(
                    code="missing_attempt",
                    message="Assessment attempt does not exist."
                )
            ];
            return;
        }
        attempt = attempts[0];

        if assessment.status != AssessmentStatus.active {
            self.errors = self.errors + [
                AssessmentEvaluationError(
                    code="assessment_not_active",
                    message="Assessment is not active."
                )
            ];
        }
        if attempt.assessment_id != assessment.id {
            self.errors = self.errors + [
                AssessmentEvaluationError(
                    code="attempt_assessment_mismatch",
                    message="Assessment attempt does not belong to the assessment."
                )
            ];
        }
        if attempt.status != AssessmentAttemptStatus.submitted {
            self.errors = self.errors + [
                AssessmentEvaluationError(
                    code="attempt_not_submitted",
                    message="Assessment attempt has not been submitted."
                )
            ];
        }
        if len(self.errors) > 0 {
            return;
        }

        existing_evaluations = attempt_evaluations(attempt);
        if len(existing_evaluations) > 0 {
            report existing_evaluations[0];
            return;
        }

        responses = attempt_responses(attempt);
        self.errors = validate_evaluation_inputs(assessment, responses);
        if len(self.errors) > 0 {
            return;
        }

        outcome = evaluate_assessment_responses(assessment, responses);
        evaluation = (attempt +>:AssessmentEvaluationLink:+> AssessmentEvaluation(
            id=f"{attempt.id}-evaluation",
            assessment_id=assessment.id,
            assessment_attempt_id=attempt.id,
            learner_id=attempt.learner_id,
            score=outcome.score,
            question_results=outcome.question_results,
            skill_signals=outcome.skill_signals,
            evaluation_version=EVALUATION_VERSION,
            created_at=self.evaluated_at
            , track_id=assessment.track_id
            , track_version_id=assessment.track_version_id
        ))[0];

        report evaluation;
    }
}
