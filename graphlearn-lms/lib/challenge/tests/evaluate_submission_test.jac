"""MockLLM coverage for coding challenge submission evaluation."""

import lib.ai.utilities as ai_utilities;
import from byllm.lib { MockLLM }
import from edges.domain_edges { assigned, attempted, contains, evaluated, signals, submitted_for, targets }
import from lib.ai.schemas {
    GeneratedCriterionResult,
    GeneratedFeedbackItem,
    GeneratedSkillSignal,
    SubmissionEvaluationResult
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
    GeneratedChallenge,
    SubmissionEvaluation,
    SubmissionSkillSignal
}
import from nodes.learner { Learner }
import from nodes.lesson { GeneratedLesson, LessonGenerationStatus }
import from nodes.roadmap {
    Roadmap,
    RoadmapLesson,
    RoadmapLessonGenerationStatus,
    RoadmapStatus,
    RoadmapWeek
}
import from nodes.skill { Skill }
import from walkers.evaluate_submission {
    evaluate_submission,
    get_submission_evaluation
}

def _unique_id(prefix: str) -> str {
    return f"{prefix}-{len([root -->][?:Learner]) + 1}";
}

def _evaluation_result(
    score: int,
    skill_id: str,
    criterion_id: str,
    criterion_score: float,
    criterion_met: bool
) -> SubmissionEvaluationResult {
    return SubmissionEvaluationResult(
        score=score,
        feedback_summary="Good alignment with the challenge requirements. Tighten the final output and naming for a stronger solution.",
        criterion_results=[
            GeneratedCriterionResult(
                criterion_id=criterion_id,
                skill_id=skill_id,
                score=criterion_score,
                feedback="The solution addresses the persisted criterion with visible code evidence.",
                met=criterion_met
            )
        ],
        skill_signals=[
            GeneratedSkillSignal(
                skill_id=skill_id,
                score=criterion_score,
                confidence=0.86,
                evidence="The submitted code demonstrates the target concept in the challenge context."
            )
        ],
        feedback_items=[
            GeneratedFeedbackItem(
                feedback_type="strength",
                content="You used the target concept directly in your solution."
            ),
            GeneratedFeedbackItem(
                feedback_type="improvement",
                content="Make variable names and output formatting more consistent."
            ),
            GeneratedFeedbackItem(
                feedback_type="suggestion",
                content="Revise once and compare each line against the challenge criteria."
            )
        ],
        suggested_next_step="Review the criterion feedback, revise the code, and resubmit when ready."
    );
}

def _malformed_result(skill_id: str) -> SubmissionEvaluationResult {
    return SubmissionEvaluationResult(
        score=80,
        feedback_summary="This response intentionally references the wrong criterion.",
        criterion_results=[
            GeneratedCriterionResult(
                criterion_id="not-a-persisted-criterion",
                skill_id=skill_id,
                score=0.8,
                feedback="Wrong criterion id.",
                met=True
            )
        ],
        skill_signals=[
            GeneratedSkillSignal(
                skill_id=skill_id,
                score=0.8,
                confidence=0.8,
                evidence="Evidence exists."
            )
        ],
        feedback_items=[
            GeneratedFeedbackItem(feedback_type="strength", content="Specific strength.")
        ],
        suggested_next_step="Try again."
    );
}

def _seed_context(
    prefix: str,
    language: str,
    skill_id: str,
    status: ChallengeSubmissionStatus = ChallengeSubmissionStatus.submitted,
    mismatch_submission_challenge: bool = False
) -> ChallengeSubmission {
    learner_id = f"{prefix}-learner";
    roadmap_id = f"{prefix}-roadmap";
    week_id = f"{roadmap_id}-week-1";
    roadmap_lesson_id = f"{week_id}-lesson-1";
    generated_lesson_id = f"generated-{learner_id}-{roadmap_lesson_id}";
    challenge_id = f"challenge-{learner_id}-{generated_lesson_id}";
    submission_challenge_id = "other-challenge" if mismatch_submission_challenge else challenge_id;

    learner = (root ++> Learner(
        id=learner_id,
        name="Submission Evaluation Learner",
        createdAt="2026-06-30",
        updatedAt="2026-06-30"
    ))[0];
    roadmap = (root ++> Roadmap(
        id=roadmap_id,
        learner_id=learner_id,
        language=language,
        title="Submission Evaluation Roadmap",
        description="Seeded roadmap for evaluation tests.",
        estimated_weeks=1,
        status=RoadmapStatus.active,
        created_at="2026-06-30T00:00:00Z",
        assessment_id=f"{prefix}-assessment",
        assessment_attempt_id=f"{prefix}-attempt",
        assessment_evaluation_id=f"{prefix}-assessment-evaluation"
    ))[0];
    learner +>:assigned:+> roadmap;

    week = (roadmap +>:contains:+> RoadmapWeek(
        id=week_id,
        roadmap_id=roadmap_id,
        week_number=1,
        title="Week One",
        summary="Seeded week."
    ))[0];
    roadmap.weeks.append(week);

    roadmap_lesson = (week +>:contains:+> RoadmapLesson(
        id=roadmap_lesson_id,
        roadmap_id=roadmap_id,
        week_id=week_id,
        title="Variables" if language == "python" else "Walkers",
        summary="Practice the target skill through a small coding task.",
        target_skill_ids=[skill_id],
        difficulty="beginner" if language == "python" else "intermediate",
        estimated_minutes=12,
        order_index=1,
        generation_status=RoadmapLessonGenerationStatus.generated
    ))[0];
    week.lessons.append(roadmap_lesson);
    roadmap.lessons.append(roadmap_lesson);

    skill = (root ++> Skill(
        id=skill_id,
        name=skill_id,
        description="Seeded evaluation skill.",
        category=language
    ))[0];
    roadmap_lesson +>:targets:+> skill;

    lesson = (root ++> GeneratedLesson(
        id=generated_lesson_id,
        learner_id=learner_id,
        roadmap_id=roadmap_id,
        roadmap_lesson_id=roadmap_lesson_id,
        language=language,
        title=roadmap_lesson.title,
        summary=roadmap_lesson.summary,
        difficulty=roadmap_lesson.difficulty,
        estimated_minutes=12,
        created_at="2026-06-30T01:00:00Z",
        updated_at="2026-06-30T01:00:00Z",
        generation_status=LessonGenerationStatus.generated
    ))[0];
    learner +>:assigned:+> lesson;
    roadmap +>:contains:+> lesson;
    roadmap_lesson +>:contains:+> lesson;

    challenge = (root ++> GeneratedChallenge(
        id=challenge_id,
        learner_id=learner_id,
        roadmap_id=roadmap_id,
        roadmap_lesson_id=roadmap_lesson_id,
        generated_lesson_id=generated_lesson_id,
        language=language,
        title="Practice Variables" if language == "python" else "Practice Walkers",
        prompt="Write a small solution that demonstrates the target skill.",
        difficulty=roadmap_lesson.difficulty,
        starter_code="# Write your code here\n" if language == "python" else "walker Demo {}\n",
        created_at="2026-06-30T02:00:00Z",
        updated_at="2026-06-30T02:00:00Z"
    ))[0];
    learner +>:assigned:+> challenge;
    roadmap +>:contains:+> challenge;
    roadmap_lesson +>:contains:+> challenge;
    lesson +>:contains:+> challenge;
    challenge +>:targets:+> skill;

    instruction = (challenge +>:contains:+> ChallengeInstruction(
        id=f"{challenge_id}-instruction-1",
        challenge_id=challenge_id,
        content="Write code that uses the target skill.",
        order_index=1
    ))[0];
    challenge.instructions.append(instruction);
    outcome = (challenge +>:contains:+> ChallengeExpectedOutcome(
        id=f"{challenge_id}-outcome-1",
        challenge_id=challenge_id,
        content="The solution visibly demonstrates the skill.",
        order_index=1
    ))[0];
    challenge.expected_outcomes.append(outcome);
    constraint = (challenge +>:contains:+> ChallengeConstraint(
        id=f"{challenge_id}-constraint-1",
        challenge_id=challenge_id,
        content="Do not use external packages, files, shell commands, or network calls.",
        order_index=1
    ))[0];
    challenge.constraints.append(constraint);
    hint = (challenge +>:contains:+> ChallengeHint(
        id=f"{challenge_id}-hint-1",
        challenge_id=challenge_id,
        content="Start with the smallest working example.",
        order_index=1
    ))[0];
    challenge.hints.append(hint);
    criterion = (challenge +>:contains:+> ChallengeEvaluationCriterion(
        id=f"{challenge_id}-criterion-1",
        challenge_id=challenge_id,
        skill_id=skill_id,
        description="Demonstrates the target skill correctly.",
        weight=1.0,
        order_index=1
    ))[0];
    challenge.evaluation_criteria.append(criterion);

    submission = (root ++> ChallengeSubmission(
        id=f"submission-{prefix}-1",
        learner_id=learner_id,
        challenge_id=submission_challenge_id,
        language=language,
        code="name = 'Ada'\nprint(name)" if language == "python" else "walker Demo {\n    can start with Root entry { visit [-->]; }\n}\n",
        status=status,
        submitted_at="2026-06-30T03:00:00Z" if status == ChallengeSubmissionStatus.submitted else "",
        created_at="2026-06-30T02:30:00Z",
        updated_at="2026-06-30T03:00:00Z"
    ))[0];
    learner +>:attempted:+> submission;
    challenge +>:submitted_for:+> submission;
    submission +>:submitted_for:+> challenge;
    return submission;
}

test "evaluate submission creates passing python evaluation" {
    prefix = _unique_id("eval-python-pass");
    submission = _seed_context(prefix, "python", "python_variables");
    criterion_id = f"challenge-{prefix}-learner-generated-{prefix}-learner-{prefix}-roadmap-week-1-lesson-1-criterion-1";
    ai_utilities.llm = MockLLM(model_name="mockllm", config={"outputs": [_evaluation_result(82, "python_variables", criterion_id, 0.9, True)]});

    result = root spawn evaluate_submission(
        learner_id=f"{prefix}-learner",
        challenge_id=submission.challenge_id,
        submission_id=submission.id
    );

    assert len(result.errors) == 0;
    view = result.reports[0];
    assert view.language == "python";
    assert view.score == 82;
    assert view.passed;
    assert len(view.criterion_results) == 1;
    assert len(view.skill_signals) == 1;
    assert len(view.strengths) == 1;
    assert len(view.improvement_areas) == 1;
    assert view.suggested_next_step != "";
}

test "evaluate submission creates jac evaluation" {
    prefix = _unique_id("eval-jac-pass");
    submission = _seed_context(prefix, "jac", "jac_walkers");
    criterion_id = f"challenge-{prefix}-learner-generated-{prefix}-learner-{prefix}-roadmap-week-1-lesson-1-criterion-1";
    ai_utilities.llm = MockLLM(model_name="mockllm", config={"outputs": [_evaluation_result(88, "jac_walkers", criterion_id, 0.92, True)]});

    result = root spawn evaluate_submission(
        learner_id=f"{prefix}-learner",
        challenge_id=submission.challenge_id,
        submission_id=submission.id
    );

    assert len(result.errors) == 0;
    assert result.reports[0].language == "jac";
    assert result.reports[0].passed;
}

test "evaluate submission records failing result below threshold" {
    prefix = _unique_id("eval-fail");
    submission = _seed_context(prefix, "python", "python_variables");
    criterion_id = f"challenge-{prefix}-learner-generated-{prefix}-learner-{prefix}-roadmap-week-1-lesson-1-criterion-1";
    ai_utilities.llm = MockLLM(model_name="mockllm", config={"outputs": [_evaluation_result(45, "python_variables", criterion_id, 0.35, False)]});

    result = root spawn evaluate_submission(
        learner_id=f"{prefix}-learner",
        challenge_id=submission.challenge_id,
        submission_id=submission.id
    );

    assert len(result.errors) == 0;
    assert result.reports[0].score == 45;
    assert not result.reports[0].passed;
}

test "evaluate submission records partial success" {
    prefix = _unique_id("eval-partial");
    submission = _seed_context(prefix, "python", "python_variables");
    criterion_id = f"challenge-{prefix}-learner-generated-{prefix}-learner-{prefix}-roadmap-week-1-lesson-1-criterion-1";
    ai_utilities.llm = MockLLM(model_name="mockllm", config={"outputs": [_evaluation_result(69, "python_variables", criterion_id, 0.68, False)]});

    result = root spawn evaluate_submission(
        learner_id=f"{prefix}-learner",
        challenge_id=submission.challenge_id,
        submission_id=submission.id
    );

    assert len(result.errors) == 0;
    assert result.reports[0].score == 69;
    assert not result.reports[0].passed;
    assert result.reports[0].criterion_results[0].score == 0.68;
}

test "evaluate submission persists evaluation children and graph links" {
    prefix = _unique_id("eval-persist");
    submission = _seed_context(prefix, "python", "python_variables");
    criterion_id = f"challenge-{prefix}-learner-generated-{prefix}-learner-{prefix}-roadmap-week-1-lesson-1-criterion-1";
    ai_utilities.llm = MockLLM(model_name="mockllm", config={"outputs": [_evaluation_result(82, "python_variables", criterion_id, 0.9, True)]});

    result = root spawn evaluate_submission(
        learner_id=f"{prefix}-learner",
        challenge_id=submission.challenge_id,
        submission_id=submission.id
    );

    assert len(result.errors) == 0;
    evaluation = get_submission_evaluation(submission.id);
    assert evaluation is not None;
    stored = evaluation as SubmissionEvaluation;
    assert len([stored ->:contains:->][?:CriterionResult]) == 1;
    assert len([stored ->:signals:->][?:SubmissionSkillSignal]) == 1;
    assert len([stored ->:contains:->][?:FeedbackItem]) == 3;
    assert len([submission ->:evaluated:->][?:SubmissionEvaluation]) == 1;
    assert len([stored ->:signals:-> ->:targets:->][?:Skill]) == 1;
}

test "evaluate submission reuses existing evaluation" {
    prefix = _unique_id("eval-reuse");
    submission = _seed_context(prefix, "python", "python_variables");
    criterion_id = f"challenge-{prefix}-learner-generated-{prefix}-learner-{prefix}-roadmap-week-1-lesson-1-criterion-1";
    ai_utilities.llm = MockLLM(model_name="mockllm", config={"outputs": [
        _evaluation_result(82, "python_variables", criterion_id, 0.9, True),
        _malformed_result("python_variables")
    ]});

    first = root spawn evaluate_submission(
        learner_id=f"{prefix}-learner",
        challenge_id=submission.challenge_id,
        submission_id=submission.id
    );
    second = root spawn evaluate_submission(
        learner_id=f"{prefix}-learner",
        challenge_id=submission.challenge_id,
        submission_id=submission.id
    );

    assert len(first.errors) == 0;
    assert len(second.errors) == 0;
    assert first.reports[0].id == second.reports[0].id;
    matches: list[SubmissionEvaluation] = [];
    for evaluation in [root -->][?:SubmissionEvaluation] {
        if evaluation.submission_id == submission.id {
            matches = matches + [evaluation];
        }
    }
    assert len(matches) == 1;
}

test "evaluate submission rejects draft submission" {
    prefix = _unique_id("eval-draft");
    submission = _seed_context(prefix, "python", "python_variables", ChallengeSubmissionStatus.draft);

    result = root spawn evaluate_submission(
        learner_id=f"{prefix}-learner",
        challenge_id=f"challenge-{prefix}-learner-generated-{prefix}-learner-{prefix}-roadmap-week-1-lesson-1",
        submission_id=submission.id
    );

    assert len(result.reports) == 0;
    assert result.errors[0].code == "submission_not_submitted";
}

test "evaluate submission rejects challenge mismatch" {
    prefix = _unique_id("eval-mismatch");
    submission = _seed_context(prefix, "python", "python_variables", ChallengeSubmissionStatus.submitted, True);

    result = root spawn evaluate_submission(
        learner_id=f"{prefix}-learner",
        challenge_id=f"challenge-{prefix}-learner-generated-{prefix}-learner-{prefix}-roadmap-week-1-lesson-1",
        submission_id=submission.id
    );

    assert len(result.reports) == 0;
    assert result.errors[0].code == "submission_challenge_mismatch";
}

test "evaluate submission rejects unsupported language" {
    prefix = _unique_id("eval-unsupported");
    submission = _seed_context(prefix, "javascript", "js_variables");

    result = root spawn evaluate_submission(
        learner_id=f"{prefix}-learner",
        challenge_id=submission.challenge_id,
        submission_id=submission.id
    );

    assert len(result.reports) == 0;
    assert result.errors[0].code == "unsupported_language";
}

test "evaluate submission rejects malformed ai output" {
    prefix = _unique_id("eval-malformed");
    submission = _seed_context(prefix, "python", "python_variables");
    ai_utilities.llm = MockLLM(model_name="mockllm", config={"outputs": [_malformed_result("python_variables")]});

    result = root spawn evaluate_submission(
        learner_id=f"{prefix}-learner",
        challenge_id=submission.challenge_id,
        submission_id=submission.id
    );

    assert len(result.reports) == 0;
    assert result.errors[0].code == "invalid_ai_output";
    assert get_submission_evaluation(submission.id) is None;
}
