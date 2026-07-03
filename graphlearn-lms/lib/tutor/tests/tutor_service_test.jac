"""Coverage for the AI tutor recommendation service boundary."""

import from edges.domain_edges { assigned, contains }
import from nodes.assessment {
    Assessment,
    AssessmentAttempt,
    AssessmentAttemptStatus,
    AssessmentEvaluation,
    AssessmentScore,
    AssessmentStatus
}
import from nodes.learner { Learner }
import from nodes.roadmap {
    Roadmap,
    RoadmapLesson,
    RoadmapLessonGenerationStatus,
    RoadmapStatus,
    RoadmapWeek
}
import from services.tutor { load_tutor_recommendation }

def _unique_id(prefix: str) -> str {
    return f"{prefix}-{len([root -->][?:Learner]) + 1}";
}

def _seed_learner(learner_id: str) -> Learner {
    return (root ++> Learner(
        id=learner_id,
        name="Tutor Service Learner",
        createdAt="2026-06-30",
        updatedAt="2026-06-30"
    ))[0];
}

def _seed_assessment(learner: Learner, prefix: str) {
    assessment = (root ++> Assessment(
        id=f"{prefix}-assessment",
        learner_id=learner.id,
        title="Assessment",
        description="Seeded assessment.",
        status=AssessmentStatus.completed,
        created_at="2026-06-30T00:00:00Z"
    ))[0];
    learner +>:assigned:+> assessment;
    attempt = (root ++> AssessmentAttempt(
        id=f"{prefix}-attempt",
        learner_id=learner.id,
        assessment_id=assessment.id,
        status=AssessmentAttemptStatus.submitted,
        submitted_at="2026-06-30T01:00:00Z",
        completed_at="2026-06-30T01:00:00Z"
    ))[0];
    root ++> AssessmentEvaluation(
        id=f"{prefix}-evaluation",
        assessment_id=assessment.id,
        assessment_attempt_id=attempt.id,
        learner_id=learner.id,
        score=AssessmentScore(earned_points=8, possible_points=10, percentage=80),
        evaluation_version="test",
        created_at="2026-06-30T02:00:00Z"
    );
}

def _seed_roadmap(prefix: str) -> tuple[str, str] {
    learner_id = f"{prefix}-learner";
    roadmap_id = f"{prefix}-roadmap";
    learner = _seed_learner(learner_id);
    _seed_assessment(learner, prefix);
    roadmap = (root ++> Roadmap(
        id=roadmap_id,
        learner_id=learner_id,
        language="python",
        title="Tutor Service Roadmap",
        description="Seeded roadmap.",
        estimated_weeks=1,
        status=RoadmapStatus.active,
        created_at="2026-06-30T03:00:00Z",
        assessment_id=f"{prefix}-assessment",
        assessment_attempt_id=f"{prefix}-attempt",
        assessment_evaluation_id=f"{prefix}-evaluation"
    ))[0];
    learner +>:assigned:+> roadmap;
    week = (roadmap +>:contains:+> RoadmapWeek(
        id=f"{prefix}-week",
        roadmap_id=roadmap_id,
        week_number=1,
        title="Week One",
        summary="Seeded week."
    ))[0];
    lesson = (week +>:contains:+> RoadmapLesson(
        id=f"{prefix}-lesson",
        roadmap_id=roadmap_id,
        week_id=week.id,
        title="Variables",
        summary="Practice variables.",
        target_skill_ids=["python_variables"],
        difficulty="beginner",
        estimated_minutes=10,
        order_index=1,
        generation_status=RoadmapLessonGenerationStatus.pending
    ))[0];
    week.lessons.append(lesson);
    roadmap.weeks.append(week);
    roadmap.lessons.append(lesson);
    return (learner_id, roadmap_id);
}

test "tutor service returns missing learner without spawning invalid request" {
    state = load_tutor_recommendation("");

    assert state.status == "missing_learner";
    assert state.recommendation is None;
}

test "tutor service projects deterministic recommendation" {
    learner = _seed_learner(_unique_id("tutor-service-no-assessment") + "-learner");

    state = load_tutor_recommendation(learner.id);

    assert state.status == "ready";
    assert state.recommendation is not None;
    recommendation = state.recommendation as any;
    assert recommendation.recommendation_type == "start_assessment";
    assert recommendation.suggested_cta_label == "Start assessment";
}

test "tutor service surfaces walker errors" {
    ids = _seed_roadmap(_unique_id("tutor-service-error"));

    state = load_tutor_recommendation(ids[0], ids[1], "javascript");

    assert state.status == "unsupported_language";
    assert state.recommendation is None;
}
