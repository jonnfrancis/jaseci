"""Assessment journey application service.

This service orchestrates the Phase 1 landing-page assessment flow. It calls the
assessment walkers and projects graph records into UI-safe view models.
"""

import from nodes.assessment {
    Assessment,
    AssessmentAttempt,
    AssessmentAttemptLink,
    AssessmentAttemptResponseLink,
    AssessmentAttemptStatus,
    AssessmentDifficulty,
    AssessmentEvaluation,
    AssessmentEvaluationLink,
    AssessmentQuestion,
    AssessmentQuestionLink,
    AssessmentQuestionType,
    AssessmentResponse,
    AssessmentStatus
}
import from nodes.learner { Learner }
import from nodes.roadmap { Roadmap }
import from services.assessment {
    AssessmentOptionView,
    AssessmentQuestionView,
    AssessmentView,
    QuestionResponsePayload
}
import from walkers.evaluate_assessment { evaluate_assessment }
import from walkers.generate_roadmap { generate_roadmap }
import from walkers.initialize_assessment { initialize_assessment }
import from walkers.submit_assessment {
    AssessmentResponseInput,
    AssessmentSubmissionError,
    submit_assessment
}
import from lib.learning_track.registry { BUILTIN_PROGRAMMING_TRACKS }
import from lib.learning_track.service { resolve_track_context, seed_builtin_tracks }

glob JOURNEY_LEARNER_ID = "phase-1-assessment-learner";

obj LanguageTrackView {
    has id: str;
    has name: str;
    has description: str;
    has topics: list[str] = [];
    has track_id: str = "";
    has track_version_id: str = "";
    has slug: str = "";
    has track_type: str = "PROGRAMMING_LANGUAGE";
    has legacy_language: str = "";
}

obj AssessmentScoreView {
    has earned_points: int;
    has possible_points: int;
    has percentage: int;
}

obj SkillSignalView {
    has skill_id: str;
    has correct_count: int;
    has incorrect_count: int;
    has accuracy: int;
}

obj AssessmentEvaluationView {
    has evaluation_id: str;
    has assessment_id: str;
    has attempt_id: str;
    has learner_id: str;
    has score: AssessmentScoreView;
    has question_count: int;
    has submitted_at: str;
    has completion_time: str;
    has created_at: str;
    has skill_signals: list[SkillSignalView] = [];
}

obj AssessmentJourneyState {
    has status: str;
    has selected_language: str = "";
    has track_id: str = "";
    has track_version_id: str = "";
    has learner_id: str = JOURNEY_LEARNER_ID;
    has assessment_id: str = "";
    has attempt_id: str = "";
    has evaluation_id: str = "";
    has roadmap_id: str = "";
    has assessment: AssessmentView | None = None;
    has evaluation: AssessmentEvaluationView | None = None;
    has error_message: str = "";
}

def:pub supported_language_tracks() -> list[LanguageTrackView] {
    _ = seed_builtin_tracks();
    views: list[LanguageTrackView] = [];
    for definition in BUILTIN_PROGRAMMING_TRACKS {
        if definition.enabled {
            legacy_id = "Python" if definition.canonical_language == "python" else "Jac";
            topics = ["fundamentals", "syntax", "functions", "control flow"] if definition.canonical_language == "python" else ["graph-native programming", "walkers", "nodes", "edges", "traversal concepts"];
            views.append(LanguageTrackView(
                id=legacy_id,
                name=legacy_id,
                description=definition.description,
                topics=topics,
                track_id=definition.track_id,
                track_version_id=definition.track_version_id,
                slug=definition.slug,
                legacy_language=definition.canonical_language
            ));
        }
    }
    return views;
}

def _ensure_journey_learner(learner_id: str, learner_name: str = "Assessment Learner") -> Learner {
    for learner in [root -->][?:Learner, id == learner_id] {
        return learner;
    }
    return (root ++> Learner(
        id=learner_id,
        name=learner_name,
        createdAt="phase-1",
        updatedAt="phase-1"
    ))[0];
}

def _language_supported(language: str) -> bool {
    return language == "Python" or language == "Jac";
}

def _language_from_assessment(assessment: Assessment | None) -> str {
    if assessment is None {
        return "";
    }
    if "Python" in assessment.title {
        return "Python";
    }
    if "Jac" in assessment.title {
        return "Jac";
    }
    return "";
}

def _question_type_value(question_type: AssessmentQuestionType | str) -> str {
    return str(question_type);
}

def _difficulty_value(difficulty: AssessmentDifficulty | str) -> str {
    return str(difficulty);
}

def _assessment_to_view(assessment: Assessment) -> AssessmentView {
    questions: list[AssessmentQuestionView] = [];
    for question in assessment.questions {
        option_views: list[AssessmentOptionView] = [];
        for option in question.options {
            option_views = option_views + [
                AssessmentOptionView(
                    id=option.id,
                    label=option.label,
                    value=option.value
                )
            ];
        }
        questions = questions + [
            AssessmentQuestionView(
                id=question.id,
                question_text=question.question_text,
                question_type=_question_type_value(question.question_type),
                skill=question.skill,
                difficulty=_difficulty_value(question.difficulty),
                required=True,
                options=option_views
            )
        ];
    }
    return AssessmentView(
        id=assessment.id,
        learner_id=assessment.learner_id,
        title=assessment.title,
        description=assessment.description,
        status=str(assessment.status),
        created_at=assessment.created_at,
        questions=questions
    );
}

def _latest_assessment(learner_id: str) -> Assessment | None {
    latest: Assessment | None = None;
    for assessment in [root -->][?:Assessment] {
        if assessment.learner_id == learner_id {
            latest = assessment;
        }
    }
    return latest;
}

def _latest_attempt(assessment: Assessment) -> AssessmentAttempt | None {
    latest: AssessmentAttempt | None = None;
    for attempt in [assessment ->:AssessmentAttemptLink:->][?:AssessmentAttempt] {
        latest = attempt;
    }
    return latest;
}

def _attempt_responses(attempt: AssessmentAttempt) -> list[AssessmentResponse] {
    return [attempt ->:AssessmentAttemptResponseLink:->][?:AssessmentResponse];
}

def _evaluation_for_attempt(attempt: AssessmentAttempt) -> AssessmentEvaluation | None {
    for evaluation in [attempt ->:AssessmentEvaluationLink:->][?:AssessmentEvaluation] {
        return evaluation;
    }
    return None;
}

def _evaluation_to_view(
    assessment: Assessment,
    attempt: AssessmentAttempt,
    evaluation: AssessmentEvaluation
) -> AssessmentEvaluationView {
    skill_signals: list[SkillSignalView] = [];
    for signal in evaluation.skill_signals {
        skill_signals = skill_signals + [
            SkillSignalView(
                skill_id=signal.skill_id,
                correct_count=signal.correct_count,
                incorrect_count=signal.incorrect_count,
                accuracy=int(signal.accuracy * 100)
            )
        ];
    }

    return AssessmentEvaluationView(
        evaluation_id=evaluation.id,
        assessment_id=assessment.id,
        attempt_id=attempt.id,
        learner_id=attempt.learner_id,
        score=AssessmentScoreView(
            earned_points=evaluation.score.earned_points,
            possible_points=evaluation.score.possible_points,
            percentage=evaluation.score.percentage
        ),
        skill_signals=skill_signals,
        question_count=len(evaluation.question_results),
        submitted_at=attempt.submitted_at,
        completion_time=f"{assessment.created_at} to {attempt.completed_at}",
        created_at=evaluation.created_at
    );
}

def _state_for_assessment(
    assessment: Assessment,
    status: str,
    error_message: str = ""
) -> AssessmentJourneyState {
    attempt = _latest_attempt(assessment);
    if attempt is not None {
        evaluation = _evaluation_for_attempt(attempt);
        if evaluation is not None {
            return AssessmentJourneyState(
                status="results",
                selected_language=_language_from_assessment(assessment),
                track_id=assessment.track_id or "",
                track_version_id=assessment.track_version_id or "",
                learner_id=assessment.learner_id,
                assessment_id=assessment.id,
                attempt_id=attempt.id,
                evaluation_id=evaluation.id,
                assessment=_assessment_to_view(assessment),
                evaluation=_evaluation_to_view(assessment, attempt, evaluation),
                error_message=error_message
            );
        }
        return AssessmentJourneyState(
            status=status,
            selected_language=_language_from_assessment(assessment),
            track_id=assessment.track_id or "",
            track_version_id=assessment.track_version_id or "",
            learner_id=assessment.learner_id,
            assessment_id=assessment.id,
            attempt_id=attempt.id,
            assessment=_assessment_to_view(assessment),
            error_message=error_message
        );
    }
    return AssessmentJourneyState(
        status=status,
        selected_language=_language_from_assessment(assessment),
        track_id=assessment.track_id or "",
        track_version_id=assessment.track_version_id or "",
        learner_id=assessment.learner_id,
        assessment_id=assessment.id,
        assessment=_assessment_to_view(assessment),
        error_message=error_message
    );
}

def _question_for_assessment(
    assessment: Assessment,
    question_id: str
) -> AssessmentQuestion | None {
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

def _answer_value_from_payload(
    response: dict[str, str],
    question_type: AssessmentQuestionType
) -> str {
    if question_type == AssessmentQuestionType.multiple_choice or question_type == AssessmentQuestionType.multi_select {
        return response["selected_option_id"];
    }
    return response["short_answer"];
}

def _submission_error_message(errors: list[AssessmentSubmissionError]) -> str {
    if len(errors) == 0 {
        return "Unable to submit assessment.";
    }
    return errors[0].message;
}

def _roadmap_id_from_report(report_value: any) -> str {
    if isinstance(report_value, Roadmap) {
        return report_value.id;
    }
    report_dict = report_value as dict[str, any];
    if "roadmap_id" in report_dict {
        return str(report_dict["roadmap_id"]);
    }
    if "id" in report_dict {
        return str(report_dict["id"]);
    }
    return "";
}

def:priv load_assessment_journey(learner_id: str = JOURNEY_LEARNER_ID) -> AssessmentJourneyState {
    if learner_id.strip() == "" {
        return AssessmentJourneyState(status="unauthenticated", error_message="Log in to continue your assessment journey.");
    }
    assessment = _latest_assessment(learner_id);
    if assessment is None {
        return AssessmentJourneyState(status="landing", learner_id=learner_id);
    }
    return _state_for_assessment(assessment, "assessment");
}

def:priv start_assessment_journey(
    language: str,
    learner_id: str = JOURNEY_LEARNER_ID,
    learner_name: str = "Assessment Learner",
    track_id: str | None = None,
    track_version_id: str | None = None
) -> AssessmentJourneyState {
    _ = seed_builtin_tracks();
    context = resolve_track_context(track_id, track_version_id, language);
    if context is None or context.legacy_language is None {
        raise Exception("Unsupported assessment language.");
    }
    if learner_id.strip() == "" {
        raise Exception("Log in before starting an assessment.");
    }

    learner = _ensure_journey_learner(learner_id, learner_name);
    learner.active_track_id = context.track_id;
    learner.active_track_version_id = context.track_version_id;
    learner.track_id = context.track_id;
    learner.track_version_id = context.track_version_id;
    selected_language = "Python" if context.legacy_language == "python" else "Jac";
    result = root spawn initialize_assessment(
        learner_id=learner_id,
        learner_goals=f"Assess readiness for {selected_language}.",
        learner_interests=[selected_language],
        learner_experience_level="beginner",
        target_skills=[],
        target_role=f"{selected_language} learner",
        assessment_length=3,
        created_at="assessment-started",
        selected_language=selected_language,
        track_id=context.track_id,
        track_version_id=context.track_version_id
    );
    if len(result.reports) == 0 {
        raise Exception("Unable to start assessment.");
    }
    return _state_for_assessment(result.reports[0], "assessment");
}

def:priv submit_and_evaluate_assessment(
    learner_id: str,
    assessment_id: str,
    responses: list[dict[str, str]],
    submitted_at: str
) -> AssessmentJourneyState {
    if learner_id.strip() == "" {
        raise Exception("Log in before submitting an assessment.");
    }
    assessments = [root -->][?:Assessment, id == assessment_id];
    if len(assessments) == 0 {
        raise Exception("Assessment is unavailable.");
    }
    assessment = assessments[0];
    if assessment.learner_id != learner_id {
        raise Exception("Assessment does not belong to the current learner.");
    }

    response_inputs: list[AssessmentResponseInput] = [];
    for response in responses {
        question = _question_for_assessment(assessment, response["question_id"]);
        if question is None {
            raise Exception("A submitted question is not part of this assessment.");
        }
        response_inputs = response_inputs + [
            AssessmentResponseInput(
                question_id=response["question_id"],
                answer_value=_answer_value_from_payload(response, question.question_type),
                response_type=question.question_type
            )
        ];
    }

    submit_result = root spawn submit_assessment(
        learner_id=learner_id,
        assessment_id=assessment.id,
        submitted_at=submitted_at,
        responses=response_inputs
    );
    if len(submit_result.errors) > 0 or len(submit_result.reports) == 0 {
        raise Exception(_submission_error_message(submit_result.errors));
    }

    attempt = submit_result.reports[0];
    evaluation_result = root spawn evaluate_assessment(
        assessment_id=assessment.id,
        assessment_attempt_id=attempt.id,
        evaluated_at=submitted_at
    );
    if len(evaluation_result.errors) > 0 or len(evaluation_result.reports) == 0 {
        return _state_for_assessment(
            assessment,
            "evaluation_pending",
            "Assessment submitted successfully. Evaluation pending."
        );
    }

    return _state_for_assessment(assessment, "results");
}

def:priv retry_assessment_evaluation(
    learner_id: str,
    assessment_id: str,
    attempt_id: str,
    evaluated_at: str
) -> AssessmentJourneyState {
    if learner_id.strip() == "" {
        raise Exception("Log in before evaluating an assessment.");
    }
    assessments = [root -->][?:Assessment, id == assessment_id];
    if len(assessments) == 0 {
        raise Exception("Assessment is unavailable.");
    }
    assessment = assessments[0];
    if assessment.learner_id != learner_id {
        raise Exception("Assessment does not belong to the current learner.");
    }

    evaluation_result = root spawn evaluate_assessment(
        assessment_id=assessment_id,
        assessment_attempt_id=attempt_id,
        evaluated_at=evaluated_at
    );
    if len(evaluation_result.errors) > 0 or len(evaluation_result.reports) == 0 {
        return _state_for_assessment(
            assessment,
            "evaluation_pending",
            "Assessment submitted successfully. Evaluation pending."
        );
    }
    return _state_for_assessment(assessment, "results");
}

def:priv generate_roadmap_for_journey(
    learner_id: str,
    assessment_id: str,
    attempt_id: str,
    evaluation_id: str,
    language: str,
    track_id: str | None = None,
    track_version_id: str | None = None
) -> AssessmentJourneyState {
    if learner_id.strip() == "" {
        raise Exception("Log in before generating a roadmap.");
    }
    _ = seed_builtin_tracks();
    context = resolve_track_context(track_id, track_version_id, language);
    if context is None or context.legacy_language is None { raise Exception("Unable to resolve learning track."); }
    result = root spawn generate_roadmap(
        learner_id=learner_id,
        assessment_id=assessment_id,
        assessment_attempt_id=attempt_id,
        assessment_evaluation_id=evaluation_id,
        language=context.legacy_language,
        track_id=context.track_id,
        track_version_id=context.track_version_id
    );
    if len(result.errors) > 0 or len(result.reports) == 0 {
        print("generate_roadmap errors:", result.errors);
        print("generate_roadmap reports:", result.reports);
        raise Exception("Unable to generate roadmap.");
    }

    roadmap_id: str = "";

    roadmap_id = _roadmap_id_from_report(result.reports[0]);

    if roadmap_id == "" {
        raise Exception("Roadmap was generated but no roadmap id was returned.");
    }

    assessments = [root -->][?:Assessment, id == assessment_id];
    if len(assessments) == 0 {
        raise Exception("Assessment is unavailable.");
    }

    state = _state_for_assessment(assessments[0], "results");
    state.roadmap_id = roadmap_id;
    return state;
}
