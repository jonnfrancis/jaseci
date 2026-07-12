"""Roadmap read service for the client UI."""

import from nodes.roadmap {
    Roadmap,
    RoadmapLesson,
    RoadmapMilestone,
    RoadmapWeek
}
import from nodes.lesson { GeneratedLesson, LessonGenerationStatus }

obj RoadmapLessonView {
    has id: str;
    has title: str;
    has summary: str;
    has target_skill_ids: list[str];
    has difficulty: str;
    has estimated_minutes: int;
    has order_index: int;
    has generation_status: str;
}

obj RoadmapMilestoneView {
    has id: str;
    has title: str;
    has description: str;
    has required_skill_ids: list[str];
}

obj RoadmapWeekView {
    has id: str;
    has week_number: int;
    has title: str;
    has summary: str;
    has lessons: list[RoadmapLessonView] = [];
    has milestones: list[RoadmapMilestoneView] = [];
}

obj RoadmapView {
    has id: str;
    has learner_id: str;
    has language: str;
    has title: str;
    has description: str;
    has estimated_weeks: int;
    has status: str;
    has created_at: str;
    has weeks: list[RoadmapWeekView] = [];
}

obj RoadmapLoadState {
    has status: str;
    has roadmap: RoadmapView | None = None;
    has message: str = "";
}

def _week_order(week: RoadmapWeek) -> int {
    return week.week_number;
}

def _lesson_order(lesson: RoadmapLesson) -> int {
    return lesson.order_index;
}

def _roadmap_found(roadmap_id: str) -> Roadmap | None {
    for roadmap in [root -->][?:Roadmap, id == roadmap_id] {
        return roadmap;
    }
    return None;
}

def _lesson_generation_status(lesson: RoadmapLesson) -> str {
    for generated in [root -->][?:GeneratedLesson] {
        if generated.roadmap_lesson_id == lesson.id and str(generated.generation_status) == str(LessonGenerationStatus.generated) {
            return "generated";
        }
    }
    return str(lesson.generation_status);
}

def _lesson_to_view(lesson: RoadmapLesson) -> RoadmapLessonView {
    return RoadmapLessonView(
        id=lesson.id,
        title=lesson.title,
        summary=lesson.summary,
        target_skill_ids=lesson.target_skill_ids,
        difficulty=lesson.difficulty,
        estimated_minutes=lesson.estimated_minutes,
        order_index=lesson.order_index,
        generation_status=_lesson_generation_status(lesson)
    );
}

def _milestone_to_view(milestone: RoadmapMilestone) -> RoadmapMilestoneView {
    return RoadmapMilestoneView(
        id=milestone.id,
        title=milestone.title,
        description=milestone.description,
        required_skill_ids=milestone.required_skill_ids
    );
}

def _week_to_view(week: RoadmapWeek) -> RoadmapWeekView {
    lessons = sorted(week.lessons, key=_lesson_order);
    lesson_views: list[RoadmapLessonView] = [];
    for lesson in lessons {
        lesson_views = lesson_views + [_lesson_to_view(lesson)];
    }

    milestone_views: list[RoadmapMilestoneView] = [];
    for milestone in week.milestones {
        milestone_views = milestone_views + [_milestone_to_view(milestone)];
    }

    return RoadmapWeekView(
        id=week.id,
        week_number=week.week_number,
        title=week.title,
        summary=week.summary,
        lessons=lesson_views,
        milestones=milestone_views
    );
}

def _roadmap_valid(roadmap: Roadmap) -> bool {
    if roadmap.language not in ["python", "jac"] {
        return False;
    }
    if roadmap.title.strip() == "" or roadmap.description.strip() == "" {
        return False;
    }
    return True;
}

def _roadmap_to_view(roadmap: Roadmap) -> RoadmapView {
    weeks = sorted(roadmap.weeks, key=_week_order);
    week_views: list[RoadmapWeekView] = [];
    for week in weeks {
        week_views = week_views + [_week_to_view(week)];
    }
    return RoadmapView(
        id=roadmap.id,
        learner_id=roadmap.learner_id,
        language=roadmap.language,
        title=roadmap.title,
        description=roadmap.description,
        estimated_weeks=roadmap.estimated_weeks,
        status=str(roadmap.status),
        created_at=roadmap.created_at,
        weeks=week_views
    );
}

def:priv load_roadmap(roadmap_id: str) -> RoadmapLoadState {
    if roadmap_id.strip() == "" {
        return RoadmapLoadState(
            status="empty",
            message="No roadmap id was provided."
        );
    }

    roadmap = _roadmap_found(roadmap_id);
    if roadmap is None {
        return RoadmapLoadState(
            status="not_found",
            message="No roadmap found yet."
        );
    }

    if not _roadmap_valid(roadmap) {
        return RoadmapLoadState(
            status="malformed",
            message="This roadmap cannot be displayed yet."
        );
    }

    return RoadmapLoadState(status="ready", roadmap=_roadmap_to_view(roadmap));
}
