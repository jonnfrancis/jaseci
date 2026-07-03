"""Coverage for read-only AI tutor next-action recommendations."""

import lib.ai.utilities as ai_utilities;
import from byllm.lib { MockLLM }
import from edges.domain_edges { assigned, contains }
import from lib.ai.schemas {
    TutorRecommendationPriority,
    TutorRecommendationResult,
    TutorRecommendationType
}
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
import from nodes.mastery { MasteryLevel, SkillMastery }
import from nodes.progression {
    LessonProgress,
    LessonUnlockState,
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
import from walkers.recommend_next_action { recommend_next_action }

obj TutorSeed {
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
        name="Tutor Learner",
        createdAt="2026-06-30",
        updatedAt="2026-06-30"
    ))[0];
}

def _seed_assessment(learner: Learner, prefix: str, evaluated: bool = True) {
    assessment = (root ++> Assessment(
        id=f"{prefix}-assessment",
        learner_id=learner.id,
        title="Tutor Assessment",
        description="Seeded assessment.",
        status=AssessmentStatus.completed if evaluated else AssessmentStatus.active,
        created_at="2026-06-30T00:00:00Z"
    ))[0];
    learner +>:assigned:+> assessment;
    if evaluated {
        attempt = (assessment +>:AssessmentAttemptLink:+> AssessmentAttempt(
            id=f"{prefix}-attempt",
            learner_id=learner.id,
            assessment_id=assessment.id,
            status=AssessmentAttemptStatus.submitted,
            submitted_at="2026-06-30T01:00:00Z",
            completed_at="2026-06-30T01:00:00Z"
        ))[0];
        attempt +>:AssessmentEvaluationLink:+> AssessmentEvaluation(
            id=f"{prefix}-assessment-evaluation",
            assessment_id=assessment.id,
            assessment_attempt_id=attempt.id,
            learner_id=learner.id,
            score=AssessmentScore(earned_points=8, possible_points=10, percentage=80),
            evaluation_version="test",
            created_at="2026-06-30T02:00:00Z"
        );
    }
}

def _seed_skill(skill_id: str, language: str) -> Skill {
    existing = [root -->][?:Skill, id == skill_id];
    if len(existing) > 0 {
        return existing[0];
    }
    return (root ++> Skill(
        id=skill_id,
        name=skill_id,
        description="Seeded tutor skill.",
        category=language
    ))[0];
}

def _seed_roadmap(prefix: str, lesson_count: int = 2, language: str = "python") -> TutorSeed {
    learner_id = f"{prefix}-learner";
    roadmap_id = f"{prefix}-roadmap";
    learner = _seed_learner(learner_id);
    _seed_assessment(learner, prefix, True);
    roadmap = (root ++> Roadmap(
        id=roadmap_id,
        learner_id=learner_id,
        language=language,
        title="Tutor Roadmap",
        description="Seeded roadmap.",
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
    ids: list[str] = [];
    for index in range(1, lesson_count + 1) {
        skill_id = f"{prefix}-skill-{index}";
        skill = _seed_skill(skill_id, language);
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
            generation_status=RoadmapLessonGenerationStatus.pending
        ))[0];
        lesson +>:contains:+> skill;
        week.lessons.append(lesson);
        roadmap.lessons.append(lesson);
        ids = ids + [lesson.id];
    }
    return TutorSeed(learner_id=learner_id, roadmap_id=roadmap_id, lesson_ids=ids);
}

def _seed_progress(seed: TutorSeed, current_index: int = 0, completed: bool = False) {
    for index in range(0, len(seed.lesson_ids)) {
        status: LessonUnlockState = LessonUnlockState.locked;
        completed_at = "";
        unlocked_at = "";
        if completed {
            status = LessonUnlockState.completed;
            completed_at = "2026-06-30T06:00:00Z";
            unlocked_at = "2026-06-30T04:00:00Z";
        } elif index == current_index {
            status = LessonUnlockState.available;
            unlocked_at = "2026-06-30T04:00:00Z";
        } elif index < current_index {
            status = LessonUnlockState.completed;
            completed_at = "2026-06-30T06:00:00Z";
            unlocked_at = "2026-06-30T04:00:00Z";
        }
        root ++> LessonProgress(
            id=f"{seed.learner_id}-{seed.lesson_ids[index]}-progress",
            learner_id=seed.learner_id,
            roadmap_id=seed.roadmap_id,
            roadmap_lesson_id=seed.lesson_ids[index],
            status=status,
            completed_at=completed_at,
            unlocked_at=unlocked_at,
            updated_at="2026-06-30T06:00:00Z"
        );
    }
    root ++> RoadmapProgress(
        id=f"{seed.learner_id}-{seed.roadmap_id}-progress",
        learner_id=seed.learner_id,
        roadmap_id=seed.roadmap_id,
        total_lessons=len(seed.lesson_ids),
        completed_lessons=len(seed.lesson_ids) if completed else current_index,
        available_lessons=0 if completed else 1,
        locked_lessons=0 if completed else len(seed.lesson_ids) - current_index - 1,
        percent_complete=100 if completed else int((current_index * 100) / len(seed.lesson_ids)),
        current_roadmap_lesson_id="" if completed else seed.lesson_ids[current_index],
        status=RoadmapProgressStatus.completed if completed else RoadmapProgressStatus.in_progress,
        updated_at="2026-06-30T06:00:00Z"
    );
}

def _seed_generated_lesson(seed: TutorSeed, lesson_id: str) -> GeneratedLesson {
    return (root ++> GeneratedLesson(
        id=f"{lesson_id}-generated",
        learner_id=seed.learner_id,
        roadmap_id=seed.roadmap_id,
        roadmap_lesson_id=lesson_id,
        language="python",
        title="Generated Lesson",
        summary="Generated summary.",
        difficulty="beginner",
        estimated_minutes=10,
        created_at="2026-06-30T07:00:00Z",
        updated_at="2026-06-30T07:00:00Z",
        generation_status=LessonGenerationStatus.generated
    ))[0];
}

def _seed_challenge(seed: TutorSeed, lesson_id: str, passed: bool | None = None) -> GeneratedChallenge {
    generated = _seed_generated_lesson(seed, lesson_id);
    challenge = (root ++> GeneratedChallenge(
        id=f"{lesson_id}-challenge",
        learner_id=seed.learner_id,
        roadmap_id=seed.roadmap_id,
        roadmap_lesson_id=lesson_id,
        generated_lesson_id=generated.id,
        language="python",
        title="Seeded Challenge",
        prompt="Solve it.",
        difficulty="beginner",
        starter_code="# starter",
        created_at="2026-06-30T08:00:00Z",
        updated_at="2026-06-30T08:00:00Z"
    ))[0];
    if passed is not None {
        submission = (root ++> ChallengeSubmission(
            id=f"{lesson_id}-submission",
            learner_id=seed.learner_id,
            challenge_id=challenge.id,
            language="python",
            code="print('ok')",
            status=ChallengeSubmissionStatus.submitted,
            submitted_at="2026-06-30T09:00:00Z",
            created_at="2026-06-30T08:30:00Z",
            updated_at="2026-06-30T09:00:00Z"
        ))[0];
        root ++> SubmissionEvaluation(
            id=f"{lesson_id}-evaluation",
            learner_id=seed.learner_id,
            challenge_id=challenge.id,
            submission_id=submission.id,
            language="python",
            score=82 if passed as bool else 45,
            passed=passed as bool,
            feedback_summary="Seeded feedback.",
            suggested_next_step="Try again.",
            evaluation_version="test",
            evaluated_at="2026-06-30T10:00:00Z",
            created_at="2026-06-30T10:00:00Z"
        );
    }
    return challenge;
}

def _seed_mastery(seed: TutorSeed, score: int) {
    root ++> SkillMastery(
        id=f"{seed.learner_id}-weak-mastery",
        learner_id=seed.learner_id,
        skill_id=f"{seed.learner_id.replace('-learner', '')}-skill-1",
        score=score,
        level=MasteryLevel.beginner if score < 40 else MasteryLevel.developing,
        evidence_count=1,
        last_source_type="submission_evaluation",
        last_source_id="seed",
        updated_at="2026-06-30T10:00:00Z",
        created_at="2026-06-30T10:00:00Z"
    );
}

def _ai_result() -> TutorRecommendationResult {
    return TutorRecommendationResult(
        recommendation_type=TutorRecommendationType.view_skill_map,
        title="Check your skill map",
        recommended_action="Open the skill map and review your strongest and weakest areas.",
        explanation="Your recent activity is mixed, so orientation is the safest next step.",
        confidence=0.66,
        priority=TutorRecommendationPriority.low,
        suggested_cta_label="View skill map"
    );
}

test "recommendation returns no assessment action" {
    learner = _seed_learner(_unique_id("tutor-no-assessment") + "-learner");

    result = root spawn recommend_next_action(learner_id=learner.id);

    assert len(result.errors) == 0;
    assert result.reports[0].recommendation_type == "start_assessment";
    assert result.reports[0].confidence == 0.9;
}

test "recommendation returns roadmap generation action" {
    prefix = _unique_id("tutor-no-roadmap");
    learner = _seed_learner(f"{prefix}-learner");
    _seed_assessment(learner, prefix, True);

    result = root spawn recommend_next_action(learner_id=learner.id);

    assert len(result.errors) == 0;
    assert result.reports[0].recommendation_type == "generate_roadmap";
}

test "recommendation returns roadmap start action" {
    seed = _seed_roadmap(_unique_id("tutor-start-roadmap"));

    result = root spawn recommend_next_action(learner_id=seed.learner_id, roadmap_id=seed.roadmap_id);

    assert len(result.errors) == 0;
    assert result.reports[0].recommendation_type == "start_roadmap";
    assert result.reports[0].related_roadmap_lesson_id == seed.lesson_ids[0];
}

test "recommendation opens generated current lesson when no challenge exists" {
    seed = _seed_roadmap(_unique_id("tutor-start-challenge"));
    _seed_progress(seed);
    _seed_generated_lesson(seed, seed.lesson_ids[0]);

    result = root spawn recommend_next_action(learner_id=seed.learner_id, roadmap_id=seed.roadmap_id);

    assert len(result.errors) == 0;
    assert result.reports[0].recommendation_type == "start_challenge";
}

test "recommendation asks to generate current lesson when missing" {
    seed = _seed_roadmap(_unique_id("tutor-generate-lesson"));
    _seed_progress(seed);

    result = root spawn recommend_next_action(learner_id=seed.learner_id, roadmap_id=seed.roadmap_id);

    assert len(result.errors) == 0;
    assert result.reports[0].recommendation_type == "generate_lesson";
}

test "recommendation retries failed challenge" {
    seed = _seed_roadmap(_unique_id("tutor-retry"));
    _seed_progress(seed);
    challenge = _seed_challenge(seed, seed.lesson_ids[0], False);

    result = root spawn recommend_next_action(learner_id=seed.learner_id, roadmap_id=seed.roadmap_id);

    assert len(result.errors) == 0;
    assert result.reports[0].recommendation_type == "retry_challenge";
    assert result.reports[0].related_challenge_id == challenge.id;
}

test "recommendation practices weak skill" {
    seed = _seed_roadmap(_unique_id("tutor-weak"));
    _seed_progress(seed);
    _seed_challenge(seed, seed.lesson_ids[0]);
    _seed_mastery(seed, 25);

    result = root spawn recommend_next_action(learner_id=seed.learner_id, roadmap_id=seed.roadmap_id);

    assert len(result.errors) == 0;
    assert result.reports[0].recommendation_type == "practice_weak_skill";
    assert len(result.reports[0].related_skill_ids) == 1;
}

test "recommendation returns completed state" {
    seed = _seed_roadmap(_unique_id("tutor-completed"));
    _seed_progress(seed, 0, True);

    result = root spawn recommend_next_action(learner_id=seed.learner_id, roadmap_id=seed.roadmap_id);

    assert len(result.errors) == 0;
    assert result.reports[0].recommendation_type == "completed";
}

test "recommendation rejects invalid references" {
    seed = _seed_roadmap(_unique_id("tutor-invalid"));
    other = _seed_roadmap(_unique_id("tutor-other"));

    missing = root spawn recommend_next_action(learner_id="missing-learner");
    unsupported = root spawn recommend_next_action(learner_id=seed.learner_id, language="javascript");
    wrong_owner = root spawn recommend_next_action(learner_id=seed.learner_id, roadmap_id=other.roadmap_id);

    assert missing.errors[0].code == "missing_learner";
    assert unsupported.errors[0].code == "unsupported_language";
    assert wrong_owner.errors[0].code == "roadmap_learner_mismatch";
}

test "recommendation uses structured ai output when deterministic path is exhausted" {
    seed = _seed_roadmap(_unique_id("tutor-ai"), 0);
    root ++> RoadmapProgress(
        id=f"{seed.learner_id}-{seed.roadmap_id}-progress",
        learner_id=seed.learner_id,
        roadmap_id=seed.roadmap_id,
        total_lessons=0,
        completed_lessons=0,
        available_lessons=0,
        locked_lessons=0,
        percent_complete=0,
        current_roadmap_lesson_id="",
        status=RoadmapProgressStatus.in_progress,
        updated_at="2026-06-30T06:00:00Z"
    );
    ai_utilities.llm = MockLLM(model_name="mockllm", config={"outputs": [_ai_result()]});

    result = root spawn recommend_next_action(learner_id=seed.learner_id, roadmap_id=seed.roadmap_id);

    assert len(result.errors) == 0;
    assert result.reports[0].recommendation_type == "view_skill_map";
    assert result.reports[0].confidence == 0.66;
}

test "recommendation rejects malformed structured ai output" {
    seed = _seed_roadmap(_unique_id("tutor-ai-malformed"), 0);
    root ++> RoadmapProgress(
        id=f"{seed.learner_id}-{seed.roadmap_id}-progress",
        learner_id=seed.learner_id,
        roadmap_id=seed.roadmap_id,
        total_lessons=0,
        completed_lessons=0,
        available_lessons=0,
        locked_lessons=0,
        percent_complete=0,
        current_roadmap_lesson_id="",
        status=RoadmapProgressStatus.in_progress,
        updated_at="2026-06-30T06:00:00Z"
    );
    malformed = TutorRecommendationResult(
        recommendation_type=TutorRecommendationType.view_skill_map,
        title="",
        recommended_action="Open the skill map.",
        explanation="Use the map.",
        confidence=0.5,
        priority=TutorRecommendationPriority.low,
        suggested_cta_label="View skill map"
    );
    ai_utilities.llm = MockLLM(model_name="mockllm", config={"outputs": [malformed]});

    result = root spawn recommend_next_action(learner_id=seed.learner_id, roadmap_id=seed.roadmap_id);

    assert len(result.reports) == 0;
    assert result.errors[0].code == "invalid_ai_output";
}

test "recommendation falls back when byllm conversion fails" {
    seed = _seed_roadmap(_unique_id("tutor-ai-fallback"), 0);
    root ++> RoadmapProgress(
        id=f"{seed.learner_id}-{seed.roadmap_id}-progress",
        learner_id=seed.learner_id,
        roadmap_id=seed.roadmap_id,
        total_lessons=0,
        completed_lessons=0,
        available_lessons=0,
        locked_lessons=0,
        percent_complete=0,
        current_roadmap_lesson_id="",
        status=RoadmapProgressStatus.in_progress,
        updated_at="2026-06-30T06:00:00Z"
    );
    ai_utilities.llm = MockLLM(model_name="mockllm", config={"outputs": ["not a structured recommendation"]});

    result = root spawn recommend_next_action(learner_id=seed.learner_id, roadmap_id=seed.roadmap_id);

    assert len(result.errors) == 0;
    assert result.reports[0].recommendation_type == "continue_lesson";
    assert result.reports[0].confidence == 0.75;
}
