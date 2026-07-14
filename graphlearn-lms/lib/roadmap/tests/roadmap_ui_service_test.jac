"""Roadmap UI read service tests."""

import from nodes.roadmap {
    Roadmap,
    RoadmapLesson,
    RoadmapLessonGenerationStatus,
    RoadmapMilestone,
    RoadmapStatus,
    RoadmapWeek
}
import from nodes.lesson { GeneratedLesson, LessonGenerationStatus }
import from services.roadmap { load_roadmap }

def _unique_roadmap_id(prefix: str) -> str {
    return f"{prefix}-{len([root -->][?:Roadmap]) + 1}";
}

test "load roadmap returns ordered roadmap view" {
    roadmap_id = _unique_roadmap_id("ui-roadmap");
    roadmap = (root ++> Roadmap(
        id=roadmap_id,
        learner_id=f"{roadmap_id}-learner",
        language="python",
        title="Roadmap UI Test",
        description="A persisted roadmap used by the read-only UI.",
        estimated_weeks=2,
        status=RoadmapStatus.active,
        created_at="2026-06-27T00:00:00Z",
        assessment_id=f"{roadmap_id}-assessment",
        assessment_attempt_id=f"{roadmap_id}-attempt",
        assessment_evaluation_id=f"{roadmap_id}-evaluation"
    ))[0];
    week_two = RoadmapWeek(
        id=f"{roadmap_id}-week-2",
        roadmap_id=roadmap_id,
        week_number=2,
        title="Second Week",
        summary="Later material."
    );
    week_one = RoadmapWeek(
        id=f"{roadmap_id}-week-1",
        roadmap_id=roadmap_id,
        week_number=1,
        title="First Week",
        summary="Earlier material."
    );
    lesson_two = RoadmapLesson(
        id=f"{roadmap_id}-lesson-2",
        roadmap_id=roadmap_id,
        week_id=week_one.id,
        title="Second Lesson",
        summary="Second ordered lesson.",
        target_skill_ids=["python_control_flow"],
        difficulty="beginner",
        estimated_minutes=30,
        order_index=2,
        generation_status=RoadmapLessonGenerationStatus.pending
    );
    lesson_one = RoadmapLesson(
        id=f"{roadmap_id}-lesson-1",
        roadmap_id=roadmap_id,
        week_id=week_one.id,
        title="First Lesson",
        summary="First ordered lesson.",
        target_skill_ids=["python_variables"],
        difficulty="beginner",
        estimated_minutes=20,
        order_index=1,
        generation_status=RoadmapLessonGenerationStatus.generated
    );
    milestone = RoadmapMilestone(
        id=f"{roadmap_id}-milestone-1",
        roadmap_id=roadmap_id,
        week_id=week_one.id,
        title="Checkpoint",
        description="Explain the first skills.",
        required_skill_ids=["python_variables"]
    );
    week_one.lessons = [lesson_two, lesson_one];
    week_one.milestones = [milestone];
    roadmap.weeks = [week_two, week_one];

    state = load_roadmap(roadmap_id);

    assert state.status == "ready";
    assert state.roadmap is not None;
    view = state.roadmap;
    assert view.weeks[0].week_number == 1;
    assert view.weeks[0].lessons[0].order_index == 1;
    assert view.weeks[0].lessons[0].generation_status == "generated";
    assert view.weeks[0].milestones[0].required_skill_ids == ["python_variables"];
}

test "load roadmap returns not found state" {
    state = load_roadmap("missing-roadmap-for-ui");

    assert state.status == "not_found";
    assert state.roadmap is None;
}

test "load roadmap derives generated state from persisted lesson" {
    roadmap_id = _unique_roadmap_id("ui-roadmap-generated-recovery");
    roadmap = (root ++> Roadmap(
        id=roadmap_id,
        learner_id=f"{roadmap_id}-learner",
        language="python",
        title="Recovered Roadmap",
        description="A roadmap whose generated lesson survived restart.",
        estimated_weeks=1,
        status=RoadmapStatus.active,
        created_at="2026-07-12T00:00:00Z",
        assessment_id=f"{roadmap_id}-assessment",
        assessment_attempt_id=f"{roadmap_id}-attempt",
        assessment_evaluation_id=f"{roadmap_id}-evaluation"
    ))[0];
    week = RoadmapWeek(
        id=f"{roadmap_id}-week-1",
        roadmap_id=roadmap_id,
        week_number=1,
        title="First Week",
        summary="Recovered content."
    );
    lesson = RoadmapLesson(
        id=f"{roadmap_id}-lesson-1",
        roadmap_id=roadmap_id,
        week_id=week.id,
        title="Variables",
        summary="Practice variables.",
        target_skill_ids=["python_variables"],
        difficulty="beginner",
        estimated_minutes=20,
        order_index=1,
        generation_status=RoadmapLessonGenerationStatus.pending
    );
    week.lessons = [lesson];
    roadmap.weeks = [week];
    root ++> GeneratedLesson(
        id=f"generated-{lesson.id}",
        learner_id=roadmap.learner_id,
        roadmap_id=roadmap.id,
        roadmap_lesson_id=lesson.id,
        language="python",
        title=lesson.title,
        summary=lesson.summary,
        difficulty=lesson.difficulty,
        estimated_minutes=lesson.estimated_minutes,
        created_at="2026-07-12T00:01:00Z",
        updated_at="2026-07-12T00:01:00Z",
        generation_status=LessonGenerationStatus.generated
    );

    state = load_roadmap(roadmap_id);

    assert state.roadmap is not None;
    assert state.roadmap.weeks[0].lessons[0].generation_status == "generated";
}
