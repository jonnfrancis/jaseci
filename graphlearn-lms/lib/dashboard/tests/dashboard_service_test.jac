"""Coverage for the dashboard UI read service boundary."""

import from nodes.learner { Learner }
import from nodes.roadmap {
    Roadmap,
    RoadmapLesson,
    RoadmapLessonGenerationStatus,
    RoadmapStatus,
    RoadmapWeek
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
import from edges.domain_edges { assigned, contains }
import from services.dashboard { load_dashboard }

def _unique_id(prefix: str) -> str {
    return f"{prefix}-{len([root -->][?:Learner]) + 1}";
}

def _seed_ready_dashboard(prefix: str) -> tuple[str, str] {
    learner_id = f"{prefix}-learner";
    roadmap_id = f"{prefix}-roadmap";
    learner = (root ++> Learner(
        id=learner_id,
        name="Dashboard Service Learner",
        createdAt="2026-06-30",
        updatedAt="2026-06-30"
    ))[0];
    assessment = (root ++> Assessment(
        id=f"{prefix}-assessment",
        learner_id=learner_id,
        title="Assessment",
        description="Seeded assessment.",
        status=AssessmentStatus.completed,
        created_at="2026-06-30T00:00:00Z"
    ))[0];
    attempt = (assessment +>:AssessmentAttemptLink:+> AssessmentAttempt(
        id=f"{prefix}-attempt",
        learner_id=learner_id,
        assessment_id=assessment.id,
        status=AssessmentAttemptStatus.submitted,
        submitted_at="2026-06-30T01:00:00Z",
        completed_at="2026-06-30T01:00:00Z"
    ))[0];
    attempt +>:AssessmentEvaluationLink:+> AssessmentEvaluation(
        id=f"{prefix}-evaluation",
        assessment_id=assessment.id,
        assessment_attempt_id=attempt.id,
        learner_id=learner_id,
        score=AssessmentScore(earned_points=8, possible_points=10, percentage=80),
        evaluation_version="test",
        created_at="2026-06-30T02:00:00Z"
    );
    roadmap = (root ++> Roadmap(
        id=roadmap_id,
        learner_id=learner_id,
        language="python",
        title="Service Roadmap",
        description="Seeded roadmap.",
        estimated_weeks=1,
        status=RoadmapStatus.active,
        created_at="2026-06-30T03:00:00Z",
        assessment_id=assessment.id,
        assessment_attempt_id=attempt.id,
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

test "dashboard service returns missing learner without spawning invalid request" {
    state = load_dashboard("");

    assert state.status == "missing_learner";
    assert state.dashboard is None;
}

test "dashboard service projects ready dashboard" {
    ids = _seed_ready_dashboard(_unique_id("dashboard-service-ready"));

    state = load_dashboard(ids[0], "python", ids[1]);

    assert state.status == "ready";
    assert state.dashboard is not None;
    dashboard = state.dashboard as any;
    assert dashboard.active_roadmap.roadmap_id == ids[1];
    assert dashboard.roadmap_progress.total_lessons == 1;
    assert dashboard.dashboard_state == "roadmap_ready";
}

test "dashboard service surfaces walker errors" {
    ids = _seed_ready_dashboard(_unique_id("dashboard-service-error"));

    state = load_dashboard(ids[0], "javascript", ids[1]);

    assert state.status == "unsupported_language";
    assert state.dashboard is None;
}
