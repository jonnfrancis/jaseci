"""Coverage for deterministic roadmap lesson progression."""

import from edges.domain_edges {
    Prerequisite,
    assigned,
    attempted,
    completed,
    contains,
    evaluated,
    progresses,
    submitted_for,
    targets,
    tracks
}
import from nodes.challenge {
    ChallengeSubmission,
    ChallengeSubmissionStatus,
    GeneratedChallenge,
    SubmissionEvaluation
}
import from nodes.learner { Learner }
import from nodes.lesson { GeneratedLesson, LessonGenerationStatus }
import from nodes.mastery { MasteryLevel, SkillMastery }
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
import from walkers.unlock_next_lesson { unlock_next_lesson }

obj ProgressionSeed {
    has learner_id: str;
    has roadmap_id: str;
    has lesson_ids: list[str];
}

def _unique_id(prefix: str) -> str {
    return f"{prefix}-{len([root -->][?:Learner]) + 1}";
}

def _seed_skill(skill_id: str, name: str = "") -> Skill {
    existing = [root -->][?:Skill, id == skill_id];
    if len(existing) > 0 {
        return existing[0];
    }
    return (root ++> Skill(
        id=skill_id,
        name=name if name != "" else skill_id,
        description="Seeded progression skill.",
        category="python"
    ))[0];
}

def _seed_roadmap(prefix: str, lesson_count: int, second_prereq_skill_id: str = "") -> ProgressionSeed {
    learner_id = f"{prefix}-learner";
    roadmap_id = f"{prefix}-roadmap";
    learner = (root ++> Learner(
        id=learner_id,
        name="Progression Learner",
        createdAt="2026-06-30",
        updatedAt="2026-06-30"
    ))[0];
    roadmap = (root ++> Roadmap(
        id=roadmap_id,
        learner_id=learner_id,
        language="python",
        title="Progression Roadmap",
        description="Seeded roadmap for progression tests.",
        estimated_weeks=1,
        status=RoadmapStatus.active,
        created_at="2026-06-30T00:00:00Z",
        assessment_id=f"{prefix}-assessment",
        assessment_attempt_id=f"{prefix}-attempt",
        assessment_evaluation_id=f"{prefix}-evaluation"
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
        skill = _seed_skill(skill_id, f"Skill {index}");
        lesson = (week +>:contains:+> RoadmapLesson(
            id=f"{roadmap_id}-lesson-{index}",
            roadmap_id=roadmap_id,
            week_id=week.id,
            title=f"Lesson {index}",
            summary="Seeded lesson.",
            target_skill_ids=[skill_id],
            difficulty="beginner",
            estimated_minutes=10,
            order_index=index,
            generation_status=RoadmapLessonGenerationStatus.generated
        ))[0];
        lesson +>:targets:+> skill;
        week.lessons.append(lesson);
        roadmap.lessons.append(lesson);
        lesson_ids = lesson_ids + [lesson.id];
        if index == 2 and second_prereq_skill_id != "" {
            prereq_skill = _seed_skill(second_prereq_skill_id, "Python Functions");
            lesson +>:Prerequisite:+> prereq_skill;
        }
    }
    return ProgressionSeed(learner_id=learner_id, roadmap_id=roadmap_id, lesson_ids=lesson_ids);
}

def _find_lesson(lesson_id: str) -> RoadmapLesson | None {
    for lesson in [root -->][?:RoadmapLesson, id == lesson_id] {
        return lesson;
    }
    for roadmap in [root -->][?:Roadmap] {
        for lesson in roadmap.lessons {
            if lesson.id == lesson_id {
                return lesson;
            }
        }
        for week in [roadmap ->:contains:->][?:RoadmapWeek] {
            for lesson in [week ->:contains:->][?:RoadmapLesson] {
                if lesson.id == lesson_id {
                    return lesson;
                }
            }
        }
    }
    return None;
}

def _seed_passing_completion(seed: ProgressionSeed, lesson_id: str, passed: bool = True) -> SubmissionEvaluation {
    found_lesson = _find_lesson(lesson_id);
    assert found_lesson is not None, f"missing lesson {lesson_id}";
    lesson = found_lesson as RoadmapLesson;
    generated_lesson = (root ++> GeneratedLesson(
        id=f"generated-{seed.learner_id}-{lesson_id}",
        learner_id=seed.learner_id,
        roadmap_id=seed.roadmap_id,
        roadmap_lesson_id=lesson_id,
        language="python",
        title=lesson.title,
        summary=lesson.summary,
        difficulty=lesson.difficulty,
        estimated_minutes=lesson.estimated_minutes,
        created_at="2026-06-30T01:00:00Z",
        updated_at="2026-06-30T01:00:00Z",
        generation_status=LessonGenerationStatus.generated
    ))[0];
    challenge = (root ++> GeneratedChallenge(
        id=f"challenge-{seed.learner_id}-{lesson_id}",
        learner_id=seed.learner_id,
        roadmap_id=seed.roadmap_id,
        roadmap_lesson_id=lesson_id,
        generated_lesson_id=generated_lesson.id,
        language="python",
        title=f"Challenge for {lesson.title}",
        prompt="Write a small solution.",
        difficulty=lesson.difficulty,
        starter_code="# starter",
        created_at="2026-06-30T02:00:00Z",
        updated_at="2026-06-30T02:00:00Z"
    ))[0];
    submission = (root ++> ChallengeSubmission(
        id=f"submission-{seed.learner_id}-{lesson_id}",
        learner_id=seed.learner_id,
        challenge_id=challenge.id,
        language="python",
        code="print('ok')",
        status=ChallengeSubmissionStatus.submitted,
        submitted_at="2026-06-30T03:00:00Z",
        created_at="2026-06-30T02:30:00Z",
        updated_at="2026-06-30T03:00:00Z"
    ))[0];
    evaluation = (root ++> SubmissionEvaluation(
        id=f"evaluation-{seed.learner_id}-{lesson_id}",
        learner_id=seed.learner_id,
        challenge_id=challenge.id,
        submission_id=submission.id,
        language="python",
        score=82 if passed else 45,
        passed=passed,
        feedback_summary="Seeded evaluation.",
        suggested_next_step="Continue.",
        evaluation_version="test",
        evaluated_at="2026-06-30T04:00:00Z",
        created_at="2026-06-30T04:00:00Z"
    ))[0];
    roadmap = [root -->][?:Roadmap, id == seed.roadmap_id][0];
    learner = [root -->][?:Learner, id == seed.learner_id][0];
    learner +>:attempted:+> submission;
    learner +>:evaluated:+> evaluation;
    roadmap +>:contains:+> generated_lesson;
    roadmap +>:contains:+> challenge;
    lesson +>:contains:+> generated_lesson;
    lesson +>:contains:+> challenge;
    challenge +>:submitted_for:+> submission;
    submission +>:submitted_for:+> challenge;
    challenge +>:evaluated:+> evaluation;
    submission +>:evaluated:+> evaluation;
    return evaluation;
}

def _seed_mastery(learner_id: str, skill_id: str, score: int) -> SkillMastery {
    learner = [root -->][?:Learner, id == learner_id][0];
    skill = _seed_skill(skill_id, "Python Functions");
    mastery = (root ++> SkillMastery(
        id=f"skill-mastery-{learner_id}-{skill_id}",
        learner_id=learner_id,
        skill_id=skill_id,
        score=score,
        level=MasteryLevel.developing if score >= 40 else MasteryLevel.beginner,
        evidence_count=1,
        last_source_type="submission_evaluation",
        last_source_id="seeded",
        updated_at="2026-06-30T00:00:00Z",
        created_at="2026-06-30T00:00:00Z"
    ))[0];
    learner +>:progresses:+> mastery;
    mastery +>:targets:+> skill;
    return mastery;
}

def _event_count(
    learner_id: str,
    roadmap_id: str,
    lesson_id: str,
    event_type: ProgressionEventType
) -> int {
    count = 0;
    for event in [root -->][?:ProgressionEvent] {
        if event.learner_id == learner_id and event.roadmap_id == roadmap_id and event.roadmap_lesson_id == lesson_id and event.event_type == event_type {
            count += 1;
        }
    }
    return count;
}

test "first lesson unlock initializes progress" {
    prefix = _unique_id("progress-first");
    seed = _seed_roadmap(prefix, 3);

    result = root spawn unlock_next_lesson(learner_id=seed.learner_id, roadmap_id=seed.roadmap_id);

    assert len(result.errors) == 0;
    view = result.reports[0];
    assert view.current_lesson is not None;
    assert (view.current_lesson as any).roadmap_lesson_id == seed.lesson_ids[0];
    assert len(view.locked_lessons) == 2;
    assert view.roadmap_progress is not None;
    assert (view.roadmap_progress as any).status == "in_progress";
    assert (view.roadmap_progress as any).total_lessons == 3;
    assert _event_count(seed.learner_id, seed.roadmap_id, "roadmap", ProgressionEventType.roadmap_started) == 1;
}

test "roadmap progress initialization persists records" {
    prefix = _unique_id("progress-init");
    seed = _seed_roadmap(prefix, 2);

    result = root spawn unlock_next_lesson(learner_id=seed.learner_id, roadmap_id=seed.roadmap_id);

    assert len(result.errors) == 0;
    lesson_progress_matches: list[LessonProgress] = [];
    for lesson_progress in [root -->][?:LessonProgress] {
        if lesson_progress.learner_id == seed.learner_id {
            lesson_progress_matches = lesson_progress_matches + [lesson_progress];
        }
    }
    assert len(lesson_progress_matches) >= 2;
    roadmap_progress_matches: list[RoadmapProgress] = [];
    for item in [root -->][?:RoadmapProgress] {
        if item.learner_id == seed.learner_id {
            roadmap_progress_matches = roadmap_progress_matches + [item];
        }
    }
    progress = roadmap_progress_matches[0];
    assert progress.available_lessons == 1;
    assert progress.locked_lessons == 1;
    assert progress.percent_complete == 0;
}

test "completing lesson unlocks next lesson" {
    prefix = _unique_id("progress-complete");
    seed = _seed_roadmap(prefix, 2);
    root spawn unlock_next_lesson(learner_id=seed.learner_id, roadmap_id=seed.roadmap_id);
    evaluation = _seed_passing_completion(seed, seed.lesson_ids[0]);

    result = root spawn unlock_next_lesson(
        learner_id=seed.learner_id,
        roadmap_id=seed.roadmap_id,
        completed_roadmap_lesson_id=seed.lesson_ids[0],
        source_type="submission_evaluation",
        source_id=evaluation.id
    );

    assert len(result.errors) == 0;
    view = result.reports[0];
    assert len(view.completed_lessons) == 1;
    assert view.completed_lessons[0].roadmap_lesson_id == seed.lesson_ids[0];
    assert len(view.newly_unlocked_lessons) == 1;
    assert view.newly_unlocked_lessons[0].roadmap_lesson_id == seed.lesson_ids[1];
    assert (view.current_lesson as any).roadmap_lesson_id == seed.lesson_ids[1];
}

test "completion without passing challenge is blocked" {
    prefix = _unique_id("progress-block-no-eval");
    seed = _seed_roadmap(prefix, 2);
    root spawn unlock_next_lesson(learner_id=seed.learner_id, roadmap_id=seed.roadmap_id);

    result = root spawn unlock_next_lesson(
        learner_id=seed.learner_id,
        roadmap_id=seed.roadmap_id,
        completed_roadmap_lesson_id=seed.lesson_ids[0]
    );

    assert len(result.reports) == 0;
    assert result.errors[0].code == "missing_generated_lesson";
}

test "failed evaluation blocks completion" {
    prefix = _unique_id("progress-block-failed-eval");
    seed = _seed_roadmap(prefix, 2);
    root spawn unlock_next_lesson(learner_id=seed.learner_id, roadmap_id=seed.roadmap_id);
    _seed_passing_completion(seed, seed.lesson_ids[0], False);

    result = root spawn unlock_next_lesson(
        learner_id=seed.learner_id,
        roadmap_id=seed.roadmap_id,
        completed_roadmap_lesson_id=seed.lesson_ids[0]
    );

    assert len(result.reports) == 0;
    assert result.errors[0].code == "missing_passing_evaluation";
}

test "low prerequisite mastery blocks next unlock" {
    prefix = _unique_id("progress-low-mastery");
    prereq_skill_id = f"{prefix}-prereq-functions";
    seed = _seed_roadmap(prefix, 2, prereq_skill_id);
    _seed_mastery(seed.learner_id, prereq_skill_id, 30);
    root spawn unlock_next_lesson(learner_id=seed.learner_id, roadmap_id=seed.roadmap_id);
    _seed_passing_completion(seed, seed.lesson_ids[0]);

    result = root spawn unlock_next_lesson(
        learner_id=seed.learner_id,
        roadmap_id=seed.roadmap_id,
        completed_roadmap_lesson_id=seed.lesson_ids[0]
    );

    assert len(result.errors) == 0;
    view = result.reports[0];
    assert len(view.newly_unlocked_lessons) == 0;
    assert len(view.locked_lessons) == 1;
    assert "Python Functions" in view.locked_lessons[0].locked_reason;
}

test "sufficient prerequisite mastery unlocks next lesson" {
    prefix = _unique_id("progress-good-mastery");
    prereq_skill_id = f"{prefix}-prereq-functions";
    seed = _seed_roadmap(prefix, 2, prereq_skill_id);
    _seed_mastery(seed.learner_id, prereq_skill_id, 40);
    root spawn unlock_next_lesson(learner_id=seed.learner_id, roadmap_id=seed.roadmap_id);
    _seed_passing_completion(seed, seed.lesson_ids[0]);

    result = root spawn unlock_next_lesson(
        learner_id=seed.learner_id,
        roadmap_id=seed.roadmap_id,
        completed_roadmap_lesson_id=seed.lesson_ids[0]
    );

    assert len(result.errors) == 0;
    assert len(result.reports[0].newly_unlocked_lessons) == 1;
    assert result.reports[0].newly_unlocked_lessons[0].roadmap_lesson_id == seed.lesson_ids[1];
}

test "completing final lesson marks roadmap completed" {
    prefix = _unique_id("progress-final");
    seed = _seed_roadmap(prefix, 2);
    root spawn unlock_next_lesson(learner_id=seed.learner_id, roadmap_id=seed.roadmap_id);
    _seed_passing_completion(seed, seed.lesson_ids[0]);
    root spawn unlock_next_lesson(
        learner_id=seed.learner_id,
        roadmap_id=seed.roadmap_id,
        completed_roadmap_lesson_id=seed.lesson_ids[0]
    );
    _seed_passing_completion(seed, seed.lesson_ids[1]);

    result = root spawn unlock_next_lesson(
        learner_id=seed.learner_id,
        roadmap_id=seed.roadmap_id,
        completed_roadmap_lesson_id=seed.lesson_ids[1]
    );

    assert len(result.errors) == 0;
    view = result.reports[0];
    assert view.roadmap_completed;
    assert len(view.completed_lessons) == 2;
    assert (view.roadmap_progress as any).status == "completed";
    assert _event_count(seed.learner_id, seed.roadmap_id, "roadmap", ProgressionEventType.roadmap_completed) == 1;
}

test "repeated unlock call is idempotent" {
    prefix = _unique_id("progress-idem-unlock");
    seed = _seed_roadmap(prefix, 2);

    first = root spawn unlock_next_lesson(learner_id=seed.learner_id, roadmap_id=seed.roadmap_id);
    second = root spawn unlock_next_lesson(learner_id=seed.learner_id, roadmap_id=seed.roadmap_id);

    assert len(first.errors) == 0;
    assert len(second.errors) == 0;
    assert _event_count(seed.learner_id, seed.roadmap_id, seed.lesson_ids[0], ProgressionEventType.lesson_unlocked) == 1;
    matches: list[LessonProgress] = [];
    for progress in [root -->][?:LessonProgress] {
        if progress.learner_id == seed.learner_id {
            matches = matches + [progress];
        }
    }
    assert len(matches) == 2;
}

test "repeated completion call is idempotent" {
    prefix = _unique_id("progress-idem-complete");
    seed = _seed_roadmap(prefix, 2);
    root spawn unlock_next_lesson(learner_id=seed.learner_id, roadmap_id=seed.roadmap_id);
    evaluation = _seed_passing_completion(seed, seed.lesson_ids[0]);

    first = root spawn unlock_next_lesson(
        learner_id=seed.learner_id,
        roadmap_id=seed.roadmap_id,
        completed_roadmap_lesson_id=seed.lesson_ids[0],
        source_type="submission_evaluation",
        source_id=evaluation.id
    );
    second = root spawn unlock_next_lesson(
        learner_id=seed.learner_id,
        roadmap_id=seed.roadmap_id,
        completed_roadmap_lesson_id=seed.lesson_ids[0],
        source_type="submission_evaluation",
        source_id=evaluation.id
    );

    assert len(first.errors) == 0;
    assert len(second.errors) == 0;
    assert _event_count(seed.learner_id, seed.roadmap_id, seed.lesson_ids[0], ProgressionEventType.lesson_completed) == 1;
    assert len(second.reports[0].newly_unlocked_lessons) == 0;
}

test "missing roadmap is rejected" {
    prefix = _unique_id("progress-missing-roadmap");
    learner = (root ++> Learner(
        id=f"{prefix}-learner",
        name="Progression Learner",
        createdAt="2026-06-30",
        updatedAt="2026-06-30"
    ))[0];

    result = root spawn unlock_next_lesson(learner_id=learner.id, roadmap_id="missing-roadmap");

    assert len(result.reports) == 0;
    assert result.errors[0].code == "missing_roadmap";
}

test "roadmap with no lessons is rejected" {
    prefix = _unique_id("progress-no-lessons");
    learner = (root ++> Learner(
        id=f"{prefix}-learner",
        name="Progression Learner",
        createdAt="2026-06-30",
        updatedAt="2026-06-30"
    ))[0];
    roadmap = (root ++> Roadmap(
        id=f"{prefix}-roadmap",
        learner_id=learner.id,
        language="python",
        title="Empty Roadmap",
        description="No lessons.",
        estimated_weeks=1,
        status=RoadmapStatus.active,
        created_at="2026-06-30T00:00:00Z",
        assessment_id=f"{prefix}-assessment",
        assessment_attempt_id=f"{prefix}-attempt",
        assessment_evaluation_id=f"{prefix}-evaluation"
    ))[0];
    learner +>:assigned:+> roadmap;

    result = root spawn unlock_next_lesson(learner_id=learner.id, roadmap_id=roadmap.id);

    assert len(result.reports) == 0;
    assert result.errors[0].code == "roadmap_has_no_lessons";
}
