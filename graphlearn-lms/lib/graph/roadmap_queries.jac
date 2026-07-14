"""Canonical root-scoped roadmap lookup and ordered topology traversal."""

import from edges.domain_edges { contains }
import from nodes.roadmap { Roadmap, RoadmapLesson, RoadmapMilestone, RoadmapWeek }
import from lib.observability.instrumentation { graph_operation_event }
import from lib.observability.tracing { monotonic_ms }

def roadmap_for(roadmap_id: str) -> Roadmap | None {
    started = monotonic_ms();
    for roadmap in [root -->][?:Roadmap, id == roadmap_id] {
        graph_operation_event("roadmap_for", "read", True, max(0, monotonic_ms() - started), 1);
        return roadmap;
    }
    graph_operation_event("roadmap_for", "read", True, max(0, monotonic_ms() - started), 0);
    return None;
}

def roadmap_weeks(roadmap: Roadmap) -> list[RoadmapWeek] {
    started = monotonic_ms();
    results = sorted(
        [roadmap ->:contains:->][?:RoadmapWeek],
        key=lambda week: RoadmapWeek : week.week_number
    );
    graph_operation_event("roadmap_weeks", "read", True, max(0, monotonic_ms() - started), len(results));
    return results;
}

def week_lessons(week: RoadmapWeek) -> list[RoadmapLesson] {
    return sorted(
        [week ->:contains:->][?:RoadmapLesson],
        key=lambda lesson: RoadmapLesson : lesson.order_index
    );
}

def roadmap_lessons(roadmap: Roadmap) -> list[RoadmapLesson] {
    lessons: list[RoadmapLesson] = [];
    for week in roadmap_weeks(roadmap) {
        lessons = lessons + week_lessons(week);
    }
    return lessons;
}

def roadmap_lesson_for(
    roadmap: Roadmap,
    roadmap_lesson_id: str
) -> RoadmapLesson | None {
    for lesson in roadmap_lessons(roadmap) {
        if lesson.id == roadmap_lesson_id {
            return lesson;
        }
    }
    return None;
}

def week_milestones(week: RoadmapWeek) -> list[RoadmapMilestone] {
    return [week ->:contains:->][?:RoadmapMilestone];
}

def roadmap_milestones(roadmap: Roadmap) -> list[RoadmapMilestone] {
    milestones: list[RoadmapMilestone] = [];
    for week in roadmap_weeks(roadmap) {
        milestones = milestones + week_milestones(week);
    }
    return milestones;
}
