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
    AssessmentQuestionType,
    AssessmentResponse,
    AssessmentStatus
}
import from nodes.learner { Learner }
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
    submit_assessment
}

glob JOURNEY_LEARNER_ID = "phase-1-assessment-learner";

obj LanguageTrackView {
    has id: str;
    has name: str;
    has description: str;
    has topics: list[str] = [];
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
    return [
        LanguageTrackView(
            id="Python",
            name="Python",
            description="Fundamentals, syntax, functions, and control flow.",
            topics=["fundamentals", "syntax", "functions", "control flow"]
        ),
        LanguageTrackView(
            id="Jac",
            name="Jac",
            description="Graph-native programming with walkers, nodes, edges, and traversal concepts.",
            topics=["graph-native programming", "walkers", "nodes", "edges", "traversal concepts"]
        )
    ];
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

def _question_type_value(question_type: AssessmentQuestionType) -> str {
    return question_type.value;
}

def _difficulty_value(difficulty: AssessmentDifficulty) -> str {
    return difficulty.value;
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
        status=assessment.status.value,
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
        learner_id=assessment.learner_id,
        assessment_id=assessment.id,
        assessment=_assessment_to_view(assessment),
        error_message=error_message
    );
}

def _response_type_from_payload(question_type: str) -> AssessmentQuestionType {
    if question_type == "multiple_choice" {
        return AssessmentQuestionType.multiple_choice;
    }
    if question_type == "multi_select" {
        return AssessmentQuestionType.multi_select;
    }
    return AssessmentQuestionType.short_answer;
}

def _answer_value_from_payload(response: dict[str, str]) -> str {
    if response["question_type"] == "multiple_choice" or response["question_type"] == "multi_select" {
        return response["selected_option_id"];
    }
    return response["short_answer"];
}

def:pub load_assessment_journey(learner_id: str = JOURNEY_LEARNER_ID) -> AssessmentJourneyState {
    if learner_id.strip() == "" {
        return AssessmentJourneyState(status="unauthenticated", error_message="Log in to continue your assessment journey.");
    }
    assessment = _latest_assessment(learner_id);
    if assessment is None {
        return AssessmentJourneyState(status="landing", learner_id=learner_id);
    }
    return _state_for_assessment(assessment, "assessment");
}

def:pub start_assessment_journey(
    language: str,
    learner_id: str = JOURNEY_LEARNER_ID,
    learner_name: str = "Assessment Learner"
) -> AssessmentJourneyState {
    if not _language_supported(language) {
        raise Exception("Unsupported assessment language.");
    }
    if learner_id.strip() == "" {
        raise Exception("Log in before starting an assessment.");
    }

    _ensure_journey_learner(learner_id, learner_name);
    result = root spawn initialize_assessment(
        learner_id=learner_id,
        learner_goals=f"Assess readiness for {language}.",
        learner_interests=[language],
        learner_experience_level="beginner",
        target_skills=[],
        target_role=f"{language} learner",
        assessment_length=3,
        created_at="assessment-started",
        selected_language=language
    );
    if len(result.reports) == 0 {
        raise Exception("Unable to start assessment.");
    }
    return _state_for_assessment(result.reports[0], "assessment");
}

def:pub submit_and_evaluate_assessment(
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
        response_inputs = response_inputs + [
            AssessmentResponseInput(
                question_id=response["question_id"],
                answer_value=_answer_value_from_payload(response),
                response_type=_response_type_from_payload(response["question_type"])
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
        raise Exception("Unable to submit assessment.");
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

def:pub retry_assessment_evaluation(
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

def:pub generate_roadmap_for_journey(
    learner_id: str,
    assessment_id: str,
    attempt_id: str,
    evaluation_id: str,
    language: str
) -> AssessmentJourneyState {
    if learner_id.strip() == "" {
        raise Exception("Log in before generating a roadmap.");
    }
    result = root spawn generate_roadmap(
        learner_id=learner_id,
        assessment_id=assessment_id,
        assessment_attempt_id=attempt_id,
        assessment_evaluation_id=evaluation_id,
        language=language
    );
    if len(result.errors) > 0 or len(result.reports) == 0 {
        raise Exception("Unable to generate roadmap.");
    }

    assessments = [root -->][?:Assessment, id == assessment_id];
    if len(assessments) == 0 {
        raise Exception("Assessment is unavailable.");
    }
    state = _state_for_assessment(assessments[0], "results");
    state.roadmap_id = result.reports[0].id;
    return state;
}
