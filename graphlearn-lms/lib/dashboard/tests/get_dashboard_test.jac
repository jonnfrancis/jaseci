"""Coverage for read-only dashboard aggregation."""

import from edges.domain_edges { assigned, contains }
import from nodes.assessment {
    Assessment,
    AssessmentAttempt,
    AssessmentAttemptLink,
    AssessmentAttemptStatus,
    AssessmentEvaluation,
    AssessmentEvaluationLink,
    AssessmentScore,
    AssessmentStatus
}
import from nodes.challenge {
    ChallengeSubmission,
    ChallengeSubmissionStatus,
    GeneratedChallenge,
    SubmissionEvaluation
}
import from nodes.learner { Learner }
import from nodes.lesson { GeneratedLesson, LessonGenerationStatus }
import from nodes.mastery { MasteryEvidence, MasteryLevel, MasterySourceType, SkillMastery }
import from nodes.progression {
    LessonProgress,
    LessonUnlockState,
    ProgressionEvent,
    ProgressionEventType,
    RoadmapProgress,
    RoadmapProgressStatus
}
import from nodes.roadmap {
    Roadmap,
    RoadmapLesson,
    RoadmapLessonGenerationStatus,
    RoadmapStatus,
    RoadmapWeek
}
import from nodes.skill { Skill }
import from walkers.get_dashboard { get_dashboard }

obj DashboardSeed {
    has learner_id: str;
    has roadmap_id: str;
    has lesson_ids: list[str];
}

def _unique_id(prefix: str) -> str {
    return f"{prefix}-{len([root -->][?:Learner]) + 1}";
}

def _seed_learner(learner_id: str) -> Learner {
    return (root ++> Learner(
        id=learner_id,
        name="Dashboard Learner",
        createdAt="2026-06-30",
        updatedAt="2026-06-30"
    ))[0];
}

def _seed_assessment(learner: Learner, prefix: str, evaluated: bool = False) -> AssessmentEvaluation | None {
    assessment = (root ++> Assessment(
        id=f"{prefix}-assessment",
        learner_id=learner.id,
        title="Dashboard Assessment",
        description="Seeded dashboard assessment.",
        status=AssessmentStatus.completed if evaluated else AssessmentStatus.active,
        created_at="2026-06-30T00:00:00Z"
    ))[0];
    learner +>:assigned:+> assessment;
    if not evaluated {
        return None;
    }
    attempt = (assessment +>:AssessmentAttemptLink:+> AssessmentAttempt(
        id=f"{prefix}-attempt",
        learner_id=learner.id,
        assessment_id=assessment.id,
        status=AssessmentAttemptStatus.submitted,
        submitted_at="2026-06-30T01:00:00Z",
        completed_at="2026-06-30T01:00:00Z"
    ))[0];
    evaluation = (attempt +>:AssessmentEvaluationLink:+> AssessmentEvaluation(
        id=f"{prefix}-assessment-evaluation",
        assessment_id=assessment.id,
        assessment_attempt_id=attempt.id,
        learner_id=learner.id,
        score=AssessmentScore(earned_points=8, possible_points=10, percentage=80),
        evaluation_version="test",
        created_at="2026-06-30T02:00:00Z"
    ))[0];
    return evaluation;
}

def _seed_skill(skill_id: str, name: str, category: str = "python") -> Skill {
    return (root ++> Skill(
        id=skill_id,
        name=name,
        description=f"{name} skill.",
        category=category
    ))[0];
}

def _seed_roadmap(prefix: str, lesson_count: int = 3, language: str = "python") -> DashboardSeed {
    learner_id = f"{prefix}-learner";
    roadmap_id = f"{prefix}-roadmap";
    learner = _seed_learner(learner_id);
    _seed_assessment(learner, prefix, True);
    roadmap = (root ++> Roadmap(
        id=roadmap_id,
        learner_id=learner_id,
        language=language,
        title="Dashboard Roadmap",
        description="Seeded dashboard roadmap.",
        estimated_weeks=1,
        status=RoadmapStatus.active,
        created_at="2026-06-30T03:00:00Z",
        assessment_id=f"{prefix}-assessment",
        assessment_attempt_id=f"{prefix}-attempt",
        assessment_evaluation_id=f"{prefix}-assessment-evaluation"
    ))[0];
    learner +>:assigned:+> roadmap;
    week = (roadmap +>:contains:+> RoadmapWeek(
        id=f"{roadmap_id}-week-1",
        roadmap_id=roadmap_id,
        week_number=1,
        title="Week One",
        summary="Seeded week."
    ))[0];
    roadmap.weeks.append(week);
    lesson_ids: list[str] = [];
    for index in range(1, lesson_count + 1) {
        skill_id = f"{prefix}-skill-{index}";
        skill = _seed_skill(skill_id, f"Skill {index}", language);
        lesson = (week +>:contains:+> RoadmapLesson(
            id=f"{roadmap_id}-lesson-{index}",
            roadmap_id=roadmap_id,
            week_id=week.id,
            title=f"Lesson {index}",
            summary=f"Summary {index}.",
            target_skill_ids=[skill_id],
            difficulty="beginner",
            estimated_minutes=10,
            order_index=index,
            generation_status=RoadmapLessonGenerationStatus.generated if index == 1 else RoadmapLessonGenerationStatus.pending
        ))[0];
        lesson +>:contains:+> skill;
        week.lessons.append(lesson);
        roadmap.lessons.append(lesson);
        lesson_ids = lesson_ids + [lesson.id];
    }
    return DashboardSeed(learner_id=learner_id, roadmap_id=roadmap_id, lesson_ids=lesson_ids);
}

def _seed_progress(seed: DashboardSeed, completed: bool = False) {
    for index in range(0, len(seed.lesson_ids)) {
        status = LessonUnlockState.completed if completed else LessonUnlockState.locked;
        completed_at = "2026-06-30T06:00:00Z" if completed else "";
        if not completed and index == 0 {
            status = LessonUnlockState.completed;
            completed_at = "2026-06-30T06:00:00Z";
        }
        if not completed and index == 1 {
            status = LessonUnlockState.available;
        }
        root ++> LessonProgress(
            id=f"{seed.learner_id}-{seed.lesson_ids[index]}-progress",
            learner_id=seed.learner_id,
            roadmap_id=seed.roadmap_id,
            roadmap_lesson_id=seed.lesson_ids[index],
            status=status,
            completed_at=completed_at,
            unlocked_at="2026-06-30T04:00:00Z",
            updated_at="2026-06-30T06:00:00Z"
        );
    }
    root ++> RoadmapProgress(
        id=f"{seed.learner_id}-{seed.roadmap_id}-roadmap-progress",
        learner_id=seed.learner_id,
        roadmap_id=seed.roadmap_id,
        total_lessons=3,
        completed_lessons=3 if completed else 1,
        available_lessons=0 if completed else 1,
        locked_lessons=0 if completed else 1,
        percent_complete=100 if completed else 33,
        current_roadmap_lesson_id="" if completed else seed.lesson_ids[1],
        status=RoadmapProgressStatus.completed if completed else RoadmapProgressStatus.in_progress,
        updated_at="2026-06-30T06:00:00Z"
    );
}

def _seed_learning_activity(seed: DashboardSeed) {
    generated_lesson = (root ++> GeneratedLesson(
        id=f"{seed.lesson_ids[0]}-generated",
        learner_id=seed.learner_id,
        roadmap_id=seed.roadmap_id,
        roadmap_lesson_id=seed.lesson_ids[0],
        language="python",
        title="Lesson 1",
        summary="Generated lesson.",
        difficulty="beginner",
        estimated_minutes=10,
        created_at="2026-06-30T07:00:00Z",
        updated_at="2026-06-30T07:00:00Z",
        generation_status=LessonGenerationStatus.generated
    ))[0];
    challenge = (root ++> GeneratedChallenge(
        id=f"{seed.lesson_ids[0]}-challenge",
        learner_id=seed.learner_id,
        roadmap_id=seed.roadmap_id,
        roadmap_lesson_id=seed.lesson_ids[0],
        generated_lesson_id=generated_lesson.id,
        language="python",
        title="Lesson 1 Challenge",
        prompt="Solve it.",
        difficulty="beginner",
        starter_code="# starter",
        created_at="2026-06-30T08:00:00Z",
        updated_at="2026-06-30T08:00:00Z"
    ))[0];
    submitted = (root ++> ChallengeSubmission(
        id=f"{seed.lesson_ids[0]}-submission",
        learner_id=seed.learner_id,
        challenge_id=challenge.id,
        language="python",
        code="print('ok')",
        status=ChallengeSubmissionStatus.submitted,
        submitted_at="2026-06-30T09:00:00Z",
        created_at="2026-06-30T08:30:00Z",
        updated_at="2026-06-30T09:00:00Z"
    ))[0];
    root ++> ChallengeSubmission(
        id=f"{seed.lesson_ids[0]}-draft",
        learner_id=seed.learner_id,
        challenge_id=challenge.id,
        language="python",
        code="# draft",
        status=ChallengeSubmissionStatus.draft,
        submitted_at="",
        created_at="2026-06-30T08:15:00Z",
        updated_at="2026-06-30T08:15:00Z"
    );
    root ++> SubmissionEvaluation(
        id=f"{seed.lesson_ids[0]}-evaluation",
        learner_id=seed.learner_id,
        challenge_id=challenge.id,
        submission_id=submitted.id,
        language="python",
        score=86,
        passed=True,
        feedback_summary="Passed.",
        suggested_next_step="Continue.",
        evaluation_version="test",
        evaluated_at="2026-06-30T10:00:00Z",
        created_at="2026-06-30T10:00:00Z"
    );
    root ++> ProgressionEvent(
        id=f"{seed.lesson_ids[1]}-unlocked-event",
        learner_id=seed.learner_id,
        roadmap_id=seed.roadmap_id,
        roadmap_lesson_id=seed.lesson_ids[1],
        event_type=ProgressionEventType.lesson_unlocked,
        source_type="submission_evaluation",
        source_id=f"{seed.lesson_ids[0]}-evaluation",
        message="Lesson 2 unlocked.",
        created_at="2026-06-30T11:00:00Z"
    );
}

def _seed_mastery(seed: DashboardSeed) {
    scores = [92, 65, 25];
    levels = [MasteryLevel.mastered, MasteryLevel.developing, MasteryLevel.beginner];
    for index in range(0, len(seed.lesson_ids)) {
        skill_id = f"{seed.learner_id.replace('-learner', '')}-skill-{index + 1}";
        root ++> SkillMastery(
            id=f"{seed.learner_id}-{skill_id}-mastery",
            learner_id=seed.learner_id,
            skill_id=skill_id,
            score=scores[index],
            level=levels[index],
            evidence_count=1,
            last_source_type="submission_evaluation",
            last_source_id="seed",
            updated_at=f"2026-06-30T0{index + 4}:30:00Z",
            created_at=f"2026-06-30T0{index + 4}:30:00Z"
        );
    }
    root ++> MasteryEvidence(
        id=f"{seed.learner_id}-mastery-evidence",
        learner_id=seed.learner_id,
        skill_id=f"{seed.learner_id.replace('-learner', '')}-skill-1",
        source_type=MasterySourceType.submission_evaluation,
        source_id="seed",
        signal_score=0.9,
        confidence=0.8,
        weighted_score=0.72,
        evidence_summary="Seeded evidence.",
        created_at="2026-06-30T12:00:00Z"
    );
}

test "dashboard returns no assessment state" {
    prefix = _unique_id("dashboard-no-assessment");
    learner = _seed_learner(f"{prefix}-learner");

    result = root spawn get_dashboard(learner_id=learner.id);

    assert len(result.errors) == 0;
    assert result.reports[0].dashboard_state == "no_assessment";
    assert result.reports[0].active_roadmap is None;
}

test "dashboard returns assessment started without evaluation" {
    prefix = _unique_id("dashboard-assessment-started");
    learner = _seed_learner(f"{prefix}-learner");
    _seed_assessment(learner, prefix, False);

    result = root spawn get_dashboard(learner_id=learner.id);

    assert len(result.errors) == 0;
    assert result.reports[0].dashboard_state == "assessment_started";
}

test "dashboard returns roadmap missing after assessment evaluation" {
    prefix = _unique_id("dashboard-roadmap-missing");
    learner = _seed_learner(f"{prefix}-learner");
    _seed_assessment(learner, prefix, True);

    result = root spawn get_dashboard(learner_id=learner.id);

    assert len(result.errors) == 0;
    assert result.reports[0].dashboard_state == "roadmap_missing";
}

test "dashboard derives roadmap summary without progression" {
    prefix = _unique_id("dashboard-roadmap-ready");
    seed = _seed_roadmap(prefix);

    result = root spawn get_dashboard(learner_id=seed.learner_id, roadmap_id=seed.roadmap_id);

    assert len(result.errors) == 0;
    view = result.reports[0];
    assert view.dashboard_state == "roadmap_ready";
    assert (view.active_roadmap as any).roadmap_id == seed.roadmap_id;
    assert view.roadmap_progress.total_lessons == 3;
    assert view.roadmap_progress.locked_lessons == 3;
    assert view.current_lesson is not None;
    assert (view.current_lesson as any).roadmap_lesson_id == seed.lesson_ids[0];
}

test "dashboard aggregates progression lessons challenges mastery and activity" {
    prefix = _unique_id("dashboard-full");
    seed = _seed_roadmap(prefix);
    _seed_progress(seed);
    _seed_learning_activity(seed);
    _seed_mastery(seed);

    result = root spawn get_dashboard(learner_id=seed.learner_id, language="python");

    assert len(result.errors) == 0;
    view = result.reports[0];
    assert view.dashboard_state == "in_progress";
    assert view.roadmap_progress.completed_lessons == 1;
    assert view.lesson_summary.generated_lessons == 1;
    assert view.lesson_summary.completed_lessons == 1;
    assert view.lesson_summary.available_lessons == 1;
    assert view.challenge_summary.generated_challenges == 1;
    assert view.challenge_summary.draft_submissions == 1;
    assert view.challenge_summary.submitted_challenges == 1;
    assert view.challenge_summary.evaluated_submissions == 1;
    assert view.challenge_summary.passed_challenges == 1;
    assert view.mastery_summary.average_mastery == 60;
    assert view.mastery_summary.strongest_skills[0].score == 92;
    assert view.mastery_summary.weakest_skills[0].score == 25;
    assert (view.current_lesson as any).roadmap_lesson_id == seed.lesson_ids[1];
    assert len(view.recent_activity) == 5;
    assert view.recent_activity[0].type == "mastery_updated";
}

test "dashboard returns completed roadmap state" {
    prefix = _unique_id("dashboard-completed");
    seed = _seed_roadmap(prefix);
    _seed_progress(seed, True);

    result = root spawn get_dashboard(learner_id=seed.learner_id, roadmap_id=seed.roadmap_id);

    assert len(result.errors) == 0;
    assert result.reports[0].dashboard_state == "completed";
    assert result.reports[0].roadmap_progress.percent_complete == 100;
}

test "dashboard rejects invalid references" {
    prefix = _unique_id("dashboard-invalid");
    learner = _seed_learner(f"{prefix}-learner");
    other = _seed_roadmap(f"{prefix}-other");

    missing = root spawn get_dashboard(learner_id="missing-learner");
    unsupported = root spawn get_dashboard(learner_id=learner.id, language="javascript");
    wrong_owner = root spawn get_dashboard(learner_id=learner.id, roadmap_id=other.roadmap_id);

    assert missing.errors[0].code == "missing_learner";
    assert unsupported.errors[0].code == "unsupported_language";
    assert wrong_owner.errors[0].code == "roadmap_learner_mismatch";
}
