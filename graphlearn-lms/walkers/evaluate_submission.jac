"""AI-backed static evaluation for persisted coding challenge submissions."""

import from datetime { datetime }
import from byllm.lib { ByLLMError }
import from edges.domain_edges { contains, evaluated, signals, submitted_for, targets }
import from lib.observability.instrumentation { ai_call_completed, ai_call_failed, ai_call_started, observe_walker_finish, observe_walker_start }
import from lib.learning_track.context_resolver { ResolveTrackContextInput, resolve_track_context }
import from lib.ai.utilities {
    GeneratedFeedbackItem,
    SubmissionEvaluationContext,
    SubmissionEvaluationCriterionContext,
    SubmissionEvaluationResult,
    evaluate_code_submission,
    standard_ai_error_policy
}
import from nodes.challenge {
    ChallengeConstraint,
    ChallengeEvaluationCriterion,
    ChallengeExpectedOutcome,
    ChallengeHint,
    ChallengeInstruction,
    ChallengeSubmission,
    ChallengeSubmissionStatus,
    CriterionResult,
    FeedbackItem,
    FeedbackType,
    GeneratedChallenge,
    SubmissionEvaluation,
    SubmissionSkillSignal
}
import from nodes.learner { Learner }
import from nodes.lesson { GeneratedLesson }
import from nodes.roadmap { Roadmap, RoadmapLesson, RoadmapWeek }
import from nodes.skill { Skill }

glob SUBMISSION_PASSING_SCORE = 70;
glob SUBMISSION_EVALUATION_VERSION = "submission-evaluation-v1";

obj SubmissionEvaluationError {
    has code: str;
    has message: str;
}

obj CriterionResultView {
    has id: str;
    has criterion_id: str;
    has skill_id: str;
    has score: float;
    has feedback: str;
    has met: bool;
    has order_index: int;
}

obj SubmissionSkillSignalView {
    has id: str;
    has skill_id: str;
    has score: float;
    has confidence: float;
    has evidence: str;
    has order_index: int;
}

obj FeedbackItemView {
    has id: str;
    has feedback_type: str;
    has content: str;
    has order_index: int;
}

obj SubmissionEvaluationView {
    has id: str;
    has learner_id: str;
    has challenge_id: str;
    has submission_id: str;
    has language: str;
    has score: int;
    has passed: bool;
    has feedback_summary: str;
    has suggested_next_step: str;
    has evaluated_at: str;
    has criterion_results: list[CriterionResultView] = [];
    has skill_signals: list[SubmissionSkillSignalView] = [];
    has strengths: list[str] = [];
    has improvement_areas: list[str] = [];
}

def _current_timestamp -> str {
    return datetime.utcnow().isoformat() + "Z";
}

def _find_learner(learner_id: str) -> Learner | None {
    for learner in [root -->][?:Learner, id == learner_id] {
        return learner;
    }
    return None;
}

def _find_challenge(challenge_id: str) -> GeneratedChallenge | None {
    for challenge in [root -->][?:GeneratedChallenge, id == challenge_id] {
        return challenge;
    }
    return None;
}

def _find_submission(
    challenge: GeneratedChallenge,
    submission_id: str
) -> ChallengeSubmission | None {
    for submission in [challenge ->:submitted_for:->][?:ChallengeSubmission] {
        if submission.id == submission_id {
            return submission;
        }
    }
    for submission in [root -->][?:ChallengeSubmission, id == submission_id] {
        return submission;
    }
    return None;
}

def _find_roadmap(roadmap_id: str) -> Roadmap | None {
    for roadmap in [root -->][?:Roadmap, id == roadmap_id] {
        return roadmap;
    }
    return None;
}

def _find_roadmap_lesson(roadmap: Roadmap, roadmap_lesson_id: str) -> RoadmapLesson | None {
    for lesson in roadmap.lessons {
        if lesson.id == roadmap_lesson_id {
            return lesson;
        }
    }
    for week in [roadmap ->:contains:->][?:RoadmapWeek] {
        for lesson in [week ->:contains:->][?:RoadmapLesson] {
            if lesson.id == roadmap_lesson_id {
                return lesson;
            }
        }
    }
    return None;
}

def _find_generated_lesson(generated_lesson_id: str) -> GeneratedLesson | None {
    for lesson in [root -->][?:GeneratedLesson, id == generated_lesson_id] {
        return lesson;
    }
    return None;
}

def _find_skill(skill_id: str) -> Skill | None {
    for skill in [root -->][?:Skill, id == skill_id] {
        return skill;
    }
    return None;
}

def _get_or_create_skill(skill_id: str, language: str) -> Skill {
    existing = _find_skill(skill_id);
    if existing is not None {
        return existing;
    }
    return (root ++> Skill(
        id=skill_id,
        name=skill_id,
        description="Submission evaluation skill evidence placeholder.",
        category=language
    ))[0];
}

def get_submission_evaluation(target_submission_id: str) -> SubmissionEvaluation | None {
    for submission in [root -->][?:ChallengeSubmission, id == target_submission_id] {
        for evaluation in [submission ->:evaluated:->][?:SubmissionEvaluation] {
            return evaluation;
        }
    }
    for evaluation in [root -->][?:SubmissionEvaluation] {
        if evaluation.submission_id == target_submission_id {
            return evaluation;
        }
    }
    return None;
}

def _instruction_strings(challenge: GeneratedChallenge) -> list[str] {
    values: list[str] = [];
    for item in challenge.instructions {
        values = values + [item.content];
    }
    return values;
}

def _outcome_strings(challenge: GeneratedChallenge) -> list[str] {
    values: list[str] = [];
    for item in challenge.expected_outcomes {
        values = values + [item.content];
    }
    return values;
}

def _constraint_strings(challenge: GeneratedChallenge) -> list[str] {
    values: list[str] = [];
    for item in challenge.constraints {
        values = values + [item.content];
    }
    return values;
}

def _hint_strings(challenge: GeneratedChallenge) -> list[str] {
    values: list[str] = [];
    for item in challenge.hints {
        values = values + [item.content];
    }
    return values;
}

def _criterion_contexts(
    criteria: list[ChallengeEvaluationCriterion]
) -> list[SubmissionEvaluationCriterionContext] {
    values: list[SubmissionEvaluationCriterionContext] = [];
    for criterion in criteria {
        values = values + [
            SubmissionEvaluationCriterionContext(
                criterion_id=criterion.id,
                skill_id=criterion.skill_id,
                description=criterion.description,
                weight=criterion.weight
            )
        ];
    }
    return values;
}

def _target_skill_ids(
    challenge: GeneratedChallenge,
    roadmap_lesson: RoadmapLesson,
    criteria: list[ChallengeEvaluationCriterion]
) -> list[str] {
    ids: list[str] = [];
    for skill in [challenge ->:targets:->][?:Skill] {
        if skill.id not in ids {
            ids = ids + [skill.id];
        }
    }
    for skill_id in roadmap_lesson.target_skill_ids {
        if skill_id not in ids {
            ids = ids + [skill_id];
        }
    }
    for criterion in criteria {
        if criterion.skill_id not in ids {
            ids = ids + [criterion.skill_id];
        }
    }
    return ids;
}

def _clamp_int(value: int, low: int, high: int) -> int {
    if value < low {
        return low;
    }
    if value > high {
        return high;
    }
    return value;
}

def _clamp_float(value: float, low: float, high: float) -> float {
    if value < low {
        return low;
    }
    if value > high {
        return high;
    }
    return value;
}

def _feedback_type(value: str) -> FeedbackType | None {
    if value == "strength" {
        return FeedbackType.strength;
    }
    if value == "improvement" {
        return FeedbackType.improvement;
    }
    if value == "suggestion" {
        return FeedbackType.suggestion;
    }
    return None;
}

def _criterion_ids(criteria: list[ChallengeEvaluationCriterion]) -> list[str] {
    ids: list[str] = [];
    for criterion in criteria {
        ids = ids + [criterion.id];
    }
    return ids;
}

def _evaluation_output_errors(
    result: SubmissionEvaluationResult,
    criteria: list[ChallengeEvaluationCriterion],
    target_skills: list[str]
) -> list[SubmissionEvaluationError] {
    errors: list[SubmissionEvaluationError] = [];
    if result.feedback_summary.strip() == "" {
        errors = errors + [SubmissionEvaluationError(code="invalid_ai_output", message="Submission evaluation needs a feedback summary.")];
    }
    if result.suggested_next_step.strip() == "" {
        errors = errors + [SubmissionEvaluationError(code="invalid_ai_output", message="Submission evaluation needs a suggested next step.")];
    }
    if len(result.criterion_results) != len(criteria) {
        errors = errors + [SubmissionEvaluationError(code="invalid_ai_output", message="Submission evaluation must include one result per persisted criterion.")];
    }
    if len(result.skill_signals) == 0 {
        errors = errors + [SubmissionEvaluationError(code="invalid_ai_output", message="Submission evaluation needs at least one skill signal.")];
    }
    if len(result.feedback_items) == 0 {
        errors = errors + [SubmissionEvaluationError(code="invalid_ai_output", message="Submission evaluation needs structured feedback items.")];
    }

    known_criteria = _criterion_ids(criteria);
    for criterion_result in result.criterion_results {
        if criterion_result.criterion_id not in known_criteria {
            errors = errors + [SubmissionEvaluationError(code="invalid_ai_output", message="Criterion result must reference a persisted criterion id.")];
        }
        if criterion_result.skill_id.strip() == "" or criterion_result.feedback.strip() == "" {
            errors = errors + [SubmissionEvaluationError(code="invalid_ai_output", message="Criterion result needs a skill id and feedback.")];
        }
        if criterion_result.skill_id not in target_skills {
            errors = errors + [SubmissionEvaluationError(code="invalid_ai_output", message="Criterion result skill must match challenge target skills.")];
        }
    }
    for signal in result.skill_signals {
        if signal.skill_id.strip() == "" or signal.evidence.strip() == "" {
            errors = errors + [SubmissionEvaluationError(code="invalid_ai_output", message="Skill signal needs a skill id and evidence.")];
        }
        if signal.skill_id not in target_skills {
            errors = errors + [SubmissionEvaluationError(code="invalid_ai_output", message="Skill signal must reference a target skill.")];
        }
    }
    for feedback in result.feedback_items {
        if _feedback_type(feedback.feedback_type) is None or feedback.content.strip() == "" {
            errors = errors + [SubmissionEvaluationError(code="invalid_ai_output", message="Feedback items must be strength, improvement, or suggestion with content.")];
        }
    }
    return errors;
}

def _result_order(result: CriterionResult) -> int {
    return result.order_index;
}

def _signal_order(signal: SubmissionSkillSignal) -> int {
    return signal.order_index;
}

def _feedback_order(item: FeedbackItem) -> int {
    return item.order_index;
}

def submission_evaluation_to_view(evaluation: SubmissionEvaluation) -> SubmissionEvaluationView {
    criterion_views: list[CriterionResultView] = [];
    for result in sorted(evaluation.criterion_results, key=_result_order) {
        criterion_views = criterion_views + [
            CriterionResultView(
                id=result.id,
                criterion_id=result.criterion_id,
                skill_id=result.skill_id,
                score=result.score,
                feedback=result.feedback,
                met=result.met,
                order_index=result.order_index
            )
        ];
    }

    signal_views: list[SubmissionSkillSignalView] = [];
    for signal in sorted(evaluation.skill_signals, key=_signal_order) {
        signal_views = signal_views + [
            SubmissionSkillSignalView(
                id=signal.id,
                skill_id=signal.skill_id,
                score=signal.score,
                confidence=signal.confidence,
                evidence=signal.evidence,
                order_index=signal.order_index
            )
        ];
    }

    strengths: list[str] = [];
    improvement_areas: list[str] = [];
    for item in sorted(evaluation.feedback_items, key=_feedback_order) {
        if item.feedback_type == FeedbackType.strength {
            strengths = strengths + [item.content];
        } elif item.feedback_type == FeedbackType.improvement {
            improvement_areas = improvement_areas + [item.content];
        }
    }

    return SubmissionEvaluationView(
        id=evaluation.id,
        learner_id=evaluation.learner_id,
        challenge_id=evaluation.challenge_id,
        submission_id=evaluation.submission_id,
        language=evaluation.language,
        score=evaluation.score,
        passed=evaluation.passed,
        feedback_summary=evaluation.feedback_summary,
        criterion_results=criterion_views,
        skill_signals=signal_views,
        strengths=strengths,
        improvement_areas=improvement_areas,
        suggested_next_step=evaluation.suggested_next_step,
        evaluated_at=evaluation.evaluated_at
    );
}

walker evaluate_submission {
    has learner_id: str;
    has challenge_id: str;
    has submission_id: str;
    has track_id: str | None = None;
    has track_version_id: str | None = None;
    has enrollment_id: str | None = None;
    has language: str | None = None;
    has idempotency_key: str | None = None;
    has errors: list[SubmissionEvaluationError] = [];
    has reports: list[SubmissionEvaluationView] = [];
    has request_id: str = "";
    has correlation_id: str = "";

    can observability_start with Root entry { observe_walker_start(self); }
    can observability_finish with Root exit { observe_walker_finish(self); }

    can evaluate with Root entry {
        resolved = resolve_track_context(ResolveTrackContextInput(
            learner_id=self.learner_id, activity_id=self.challenge_id,
            submission_id=self.submission_id, track_id=self.track_id,
            track_version_id=self.track_version_id,
            enrollment_id=self.enrollment_id, language=self.language
        ), "evaluate_submission");
        if not resolved.ok {
            self.errors = self.errors + [SubmissionEvaluationError(
                code=resolved.error.code if resolved.error is not None else "TRACK_CONTEXT_MISSING",
                message=resolved.error.message if resolved.error is not None else "Track context is required."
            )];
            return;
        }
        if self.learner_id.strip() == "" {
            self.errors = self.errors + [SubmissionEvaluationError(code="missing_learner", message="Log in again to evaluate this submission.")];
            return;
        }
        if self.challenge_id.strip() == "" {
            self.errors = self.errors + [SubmissionEvaluationError(code="missing_challenge", message="No challenge id was provided.")];
            return;
        }
        if self.submission_id.strip() == "" {
            self.errors = self.errors + [SubmissionEvaluationError(code="missing_submission", message="No submission id was provided.")];
            return;
        }

        learner = _find_learner(self.learner_id);
        if learner is None {
            self.errors = self.errors + [SubmissionEvaluationError(code="missing_learner", message="Learner does not exist.")];
            return;
        }

        challenge = _find_challenge(self.challenge_id);
        if challenge is None {
            self.errors = self.errors + [SubmissionEvaluationError(code="missing_challenge", message="Challenge does not exist.")];
            return;
        }
        if challenge.learner_id != self.learner_id {
            self.errors = self.errors + [SubmissionEvaluationError(code="learner_mismatch", message="Challenge does not belong to this learner.")];
            return;
        }
        if challenge.language not in ["python", "jac"] {
            self.errors = self.errors + [SubmissionEvaluationError(code="unsupported_language", message="Challenge language is not supported.")];
            return;
        }

        submission = _find_submission(challenge, self.submission_id);
        if submission is None {
            self.errors = self.errors + [SubmissionEvaluationError(code="missing_submission", message="Submission does not exist.")];
            return;
        }
        if submission.learner_id != self.learner_id {
            self.errors = self.errors + [SubmissionEvaluationError(code="submission_learner_mismatch", message="Submission does not belong to this learner.")];
            return;
        }
        if submission.challenge_id != challenge.id {
            self.errors = self.errors + [SubmissionEvaluationError(code="submission_challenge_mismatch", message="Submission does not belong to this challenge.")];
            return;
        }
        if submission.status != ChallengeSubmissionStatus.submitted {
            self.errors = self.errors + [SubmissionEvaluationError(code="submission_not_submitted", message="Only submitted solutions can be evaluated.")];
            return;
        }
        if submission.language != challenge.language {
            self.errors = self.errors + [SubmissionEvaluationError(code="language_mismatch", message="Submission language does not match the challenge language.")];
            return;
        }

        existing = get_submission_evaluation(submission.id);
        if existing is not None {
            report submission_evaluation_to_view(existing);
            return;
        }

        criteria = challenge.evaluation_criteria;
        if len(criteria) == 0 {
            criteria = [challenge ->:contains:->][?:ChallengeEvaluationCriterion];
        }
        if len(criteria) == 0 {
            self.errors = self.errors + [SubmissionEvaluationError(code="missing_evaluation_criteria", message="Challenge needs evaluation criteria before submission evaluation.")];
            return;
        }

        roadmap = _find_roadmap(challenge.roadmap_id);
        if roadmap is None {
            self.errors = self.errors + [SubmissionEvaluationError(code="missing_roadmap", message="Linked roadmap does not exist.")];
            return;
        }
        roadmap_lesson = _find_roadmap_lesson(roadmap, challenge.roadmap_lesson_id);
        if roadmap_lesson is None {
            self.errors = self.errors + [SubmissionEvaluationError(code="missing_roadmap_lesson", message="Linked roadmap lesson does not exist.")];
            return;
        }
        generated_lesson = _find_generated_lesson(challenge.generated_lesson_id);
        if generated_lesson is None {
            self.errors = self.errors + [SubmissionEvaluationError(code="missing_generated_lesson", message="Linked generated lesson does not exist.")];
            return;
        }
        if generated_lesson.learner_id != self.learner_id or generated_lesson.roadmap_id != roadmap.id or generated_lesson.roadmap_lesson_id != roadmap_lesson.id {
            self.errors = self.errors + [SubmissionEvaluationError(code="generated_lesson_mismatch", message="Generated lesson does not match this challenge context.")];
            return;
        }

        target_skills = _target_skill_ids(challenge, roadmap_lesson, criteria);
        if len(target_skills) == 0 {
            self.errors = self.errors + [SubmissionEvaluationError(code="missing_target_skills", message="Challenge needs target skills before submission evaluation.")];
            return;
        }

        ai_started = ai_call_started("evaluate_submission", "evaluate_code_submission", self.request_id, self.correlation_id, {"language": challenge.language, "challenge_id": challenge.id});
        try {
            generated = evaluate_code_submission(
                SubmissionEvaluationContext(
                    language=challenge.language,
                    challenge_title=challenge.title,
                    challenge_prompt=challenge.prompt,
                    starter_code=challenge.starter_code,
                    instructions=_instruction_strings(challenge),
                    expected_outcomes=_outcome_strings(challenge),
                    constraints=_constraint_strings(challenge),
                    hints=_hint_strings(challenge),
                    evaluation_criteria=_criterion_contexts(criteria),
                    submitted_code=submission.code,
                    lesson_title=generated_lesson.title,
                    lesson_summary=generated_lesson.summary,
                    target_skills=target_skills
                )
            );
            ai_call_completed("evaluate_submission", "evaluate_code_submission", self.request_id, self.correlation_id, ai_started);
        } except ByLLMError as e {
            ai_call_failed("evaluate_submission", "evaluate_code_submission", self.request_id, self.correlation_id, ai_started, e.__class__.__name__);
            policy = standard_ai_error_policy(e);
            self.errors = self.errors + [
                SubmissionEvaluationError(
                    code=f"ai_{policy.kind}",
                    message=policy.user_message
                )
            ];
            return;
        }

        self.errors = _evaluation_output_errors(generated, criteria, target_skills);
        if len(self.errors) > 0 {
            return;
        }

        timestamp = _current_timestamp();
        score = _clamp_int(generated.score, 0, 100);
        evaluation = (root ++> SubmissionEvaluation(
            id=f"evaluation-{submission.id}",
            learner_id=self.learner_id,
            challenge_id=challenge.id,
            submission_id=submission.id,
            language=challenge.language,
            score=score,
            passed=score >= SUBMISSION_PASSING_SCORE,
            feedback_summary=generated.feedback_summary,
            suggested_next_step=generated.suggested_next_step,
            evaluation_version=SUBMISSION_EVALUATION_VERSION,
            evaluated_at=timestamp,
            created_at=timestamp
            , track_id=challenge.track_id
            , track_version_id=challenge.track_version_id
        ))[0];
        learner +>:evaluated:+> evaluation;
        challenge +>:evaluated:+> evaluation;
        submission +>:evaluated:+> evaluation;

        criterion_index = 1;
        for result in generated.criterion_results {
            criterion_result = (evaluation +>:contains:+> CriterionResult(
                id=f"{evaluation.id}-criterion-{criterion_index}",
                evaluation_id=evaluation.id,
                criterion_id=result.criterion_id,
                skill_id=result.skill_id,
                score=_clamp_float(result.score, 0.0, 1.0),
                feedback=result.feedback,
                met=result.met,
                order_index=criterion_index
            ))[0];
            evaluation.criterion_results.append(criterion_result);
            criterion_index += 1;
        }

        signal_index = 1;
        for signal in generated.skill_signals {
            signal_node = (evaluation +>:signals:+> SubmissionSkillSignal(
                id=f"{evaluation.id}-skill-signal-{signal_index}",
                evaluation_id=evaluation.id,
                skill_id=signal.skill_id,
                score=_clamp_float(signal.score, 0.0, 1.0),
                confidence=_clamp_float(signal.confidence, 0.0, 1.0),
                evidence=signal.evidence,
                order_index=signal_index
            ))[0];
            evaluation.skill_signals.append(signal_node);
            signal_node +>:targets:+> _get_or_create_skill(signal.skill_id, challenge.language);
            signal_index += 1;
        }

        feedback_index = 1;
        for feedback in generated.feedback_items {
            parsed_type = _feedback_type(feedback.feedback_type);
            if parsed_type is not None {
                feedback_node = (evaluation +>:contains:+> FeedbackItem(
                    id=f"{evaluation.id}-feedback-{feedback_index}",
                    evaluation_id=evaluation.id,
                    feedback_type=parsed_type,
                    content=feedback.content,
                    order_index=feedback_index
                ))[0];
                evaluation.feedback_items.append(feedback_node);
                feedback_index += 1;
            }
        }

        report submission_evaluation_to_view(evaluation);
    }
}
