"""Coverage for challenge workspace load and submission persistence."""

import from edges.domain_edges { assigned, attempted, contains, submitted_for }
import from nodes.challenge {
    ChallengeConstraint,
    ChallengeEvaluationCriterion,
    ChallengeExpectedOutcome,
    ChallengeHint,
    ChallengeInstruction,
    ChallengeSubmission,
    ChallengeSubmissionStatus,
    GeneratedChallenge
}
import from nodes.learner { Learner }
import from nodes.lesson {
    GeneratedLesson,
    LessonExample,
    LessonGenerationStatus,
    LessonMiniExercise,
    LessonSection
}
import from nodes.roadmap {
    Roadmap,
    RoadmapLesson,
    RoadmapLessonGenerationStatus,
    RoadmapStatus,
    RoadmapWeek
}
import from services.challenge {
    open_challenge,
    start_challenge,
    submit_challenge_solution
}
import from walkers.submit_challenge { submit_challenge }

def _unique_id(prefix: str) -> str {
    return f"{prefix}-{len([root -->][?:Learner]) + 1}";
}

def _seed_workspace_context(prefix: str) -> GeneratedChallenge {
    learner_id = f"{prefix}-learner";
    roadmap_id = f"{prefix}-roadmap";
    week_id = f"{roadmap_id}-week-1";
    roadmap_lesson_id = f"{week_id}-lesson-1";
    generated_lesson_id = f"generated-{learner_id}-{roadmap_lesson_id}";
    challenge_id = f"challenge-{learner_id}-{generated_lesson_id}";

    learner = (root ++> Learner(
        id=learner_id,
        name="Workspace Learner",
        createdAt="2026-06-29",
        updatedAt="2026-06-29"
    ))[0];
    roadmap = (root ++> Roadmap(
        id=roadmap_id,
        learner_id=learner_id,
        language="python",
        title="Workspace Roadmap",
        description="A roadmap for challenge workspace tests.",
        estimated_weeks=1,
        status=RoadmapStatus.active,
        created_at="2026-06-29T10:00:00Z",
        assessment_id=f"{prefix}-assessment",
        assessment_attempt_id=f"{prefix}-attempt",
        assessment_evaluation_id=f"{prefix}-evaluation"
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
        title="Variables and Data Types",
        summary="Practice Python variable basics.",
        target_skill_ids=["python_variables"],
        difficulty="beginner",
        estimated_minutes=12,
        order_index=1,
        generation_status=RoadmapLessonGenerationStatus.generated
    ))[0];
    week.lessons.append(roadmap_lesson);
    roadmap.lessons.append(roadmap_lesson);

    generated_lesson = (root ++> GeneratedLesson(
        id=generated_lesson_id,
        learner_id=learner_id,
        roadmap_id=roadmap_id,
        roadmap_lesson_id=roadmap_lesson_id,
        language="python",
        title="Variables and Data Types",
        summary="Practice Python variable basics.",
        difficulty="beginner",
        estimated_minutes=12,
        created_at="2026-06-29T11:00:00Z",
        updated_at="2026-06-29T11:00:00Z",
        generation_status=LessonGenerationStatus.generated
    ))[0];
    learner +>:assigned:+> generated_lesson;
    roadmap +>:contains:+> generated_lesson;
    roadmap_lesson +>:contains:+> generated_lesson;

    section = (generated_lesson +>:contains:+> LessonSection(
        id=f"{generated_lesson_id}-section-1",
        lesson_id=generated_lesson_id,
        title="Core idea",
        content="Variables store values.",
        order_index=1
    ))[0];
    generated_lesson.sections.append(section);
    example = (generated_lesson +>:contains:+> LessonExample(
        id=f"{generated_lesson_id}-example-1",
        lesson_id=generated_lesson_id,
        title="Variable example",
        code="name = 'Ada'",
        explanation="This assigns a string.",
        order_index=1
    ))[0];
    generated_lesson.examples.append(example);
    exercise = (generated_lesson +>:contains:+> LessonMiniExercise(
        id=f"{generated_lesson_id}-mini-exercise-1",
        lesson_id=generated_lesson_id,
        prompt="Create one variable.",
        expected_concept="python_variables",
        order_index=1
    ))[0];
    generated_lesson.mini_exercises.append(exercise);

    challenge = (root ++> GeneratedChallenge(
        id=challenge_id,
        learner_id=learner_id,
        roadmap_id=roadmap_id,
        roadmap_lesson_id=roadmap_lesson_id,
        generated_lesson_id=generated_lesson_id,
        language="python",
        title="Practice Variables",
        prompt="Create variables and print a summary.",
        difficulty="beginner",
        starter_code="# Write your code here\n",
        created_at="2026-06-29T12:00:00Z",
        updated_at="2026-06-29T12:00:00Z"
    ))[0];
    learner +>:assigned:+> challenge;
    roadmap +>:contains:+> challenge;
    roadmap_lesson +>:contains:+> challenge;
    generated_lesson +>:contains:+> challenge;

    instruction = (challenge +>:contains:+> ChallengeInstruction(
        id=f"{challenge_id}-instruction-1",
        challenge_id=challenge_id,
        content="Create a variable called name.",
        order_index=1
    ))[0];
    challenge.instructions.append(instruction);
    outcome = (challenge +>:contains:+> ChallengeExpectedOutcome(
        id=f"{challenge_id}-outcome-1",
        challenge_id=challenge_id,
        content="Variables are used in output.",
        order_index=1
    ))[0];
    challenge.expected_outcomes.append(outcome);
    constraint = (challenge +>:contains:+> ChallengeConstraint(
        id=f"{challenge_id}-constraint-1",
        challenge_id=challenge_id,
        content="Do not use external packages.",
        order_index=1
    ))[0];
    challenge.constraints.append(constraint);
    hint = (challenge +>:contains:+> ChallengeHint(
        id=f"{challenge_id}-hint-1",
        challenge_id=challenge_id,
        content="Use assignment with equals.",
        order_index=1
    ))[0];
    challenge.hints.append(hint);
    criterion = (challenge +>:contains:+> ChallengeEvaluationCriterion(
        id=f"{challenge_id}-criterion-1",
        challenge_id=challenge_id,
        skill_id="python_variables",
        description="Uses variables correctly.",
        weight=1.0,
        order_index=1
    ))[0];
    challenge.evaluation_criteria.append(criterion);
    return challenge;
}

test "submit challenge persists submitted code and graph links" {
    prefix = _unique_id("workspace-submit");
    challenge = _seed_workspace_context(prefix);

    result = root spawn submit_challenge(
        learner_id=f"{prefix}-learner",
        roadmap_id=f"{prefix}-roadmap",
        roadmap_lesson_id=challenge.roadmap_lesson_id,
        challenge_id=challenge.id,
        code="name = 'Ada'\nprint(name)"
    );

    assert len(result.errors) == 0;
    view = result.reports[0];
    assert view.challenge_id == challenge.id;
    assert view.language == "python";
    assert view.status == "submitted";
    assert "Ada" in view.code;
    assert len([challenge ->:submitted_for:->][?:ChallengeSubmission]) == 1;
    assert len([root -->][?:ChallengeSubmission, id == view.id]) == 1;
}

test "submit challenge rejects empty code" {
    prefix = _unique_id("workspace-empty");
    challenge = _seed_workspace_context(prefix);

    result = root spawn submit_challenge(
        learner_id=f"{prefix}-learner",
        roadmap_id=f"{prefix}-roadmap",
        roadmap_lesson_id=challenge.roadmap_lesson_id,
        challenge_id=challenge.id,
        code="   "
    );

    assert len(result.reports) == 0;
    assert result.errors[0].code == "empty_code";
}

test "open challenge loads route scoped workspace state" {
    prefix = _unique_id("workspace-open");
    challenge = _seed_workspace_context(prefix);

    state = open_challenge(
        f"{prefix}-learner",
        f"{prefix}-roadmap",
        challenge.roadmap_lesson_id,
        challenge.id
    );

    assert state.status == "ready";
    assert state.challenge is not None;
    loaded = state.challenge;
    assert loaded.title == "Practice Variables";
    assert state.lesson_title == "Variables and Data Types";
    assert len(loaded.instructions) == 1;
}

test "submit challenge service returns saved submission" {
    prefix = _unique_id("workspace-service-submit");
    challenge = _seed_workspace_context(prefix);

    state = submit_challenge_solution(
        f"{prefix}-learner",
        f"{prefix}-roadmap",
        challenge.roadmap_lesson_id,
        challenge.id,
        "name = 'Ada'\nprint(name)"
    );

    assert state.status == "submitted";
    assert state.submission is not None;
    submission = state.submission;
    assert submission.challenge_id == challenge.id;
    assert submission.status == "submitted";
}

test "start challenge reuses existing challenge" {
    prefix = _unique_id("workspace-start");
    challenge = _seed_workspace_context(prefix);

    state = start_challenge(
        f"{prefix}-learner",
        f"{prefix}-roadmap",
        challenge.roadmap_lesson_id,
        challenge.generated_lesson_id
    );

    assert state.status == "ready";
    assert not state.generated_now;
    assert state.challenge is not None;
    loaded = state.challenge;
    assert loaded.id == challenge.id;
}

test "open challenge rejects mismatched roadmap lesson" {
    prefix = _unique_id("workspace-mismatch");
    challenge = _seed_workspace_context(prefix);

    state = open_challenge(
        f"{prefix}-learner",
        f"{prefix}-roadmap",
        "other-lesson",
        challenge.id
    );

    assert state.status == "missing_roadmap_lesson";
}
