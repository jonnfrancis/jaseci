"""Lesson viewer service for generated lesson content."""

import from edges.domain_edges { contains }
import from lib.graph.roadmap_queries { roadmap_for, roadmap_lesson_for, roadmap_lessons }
import from lib.learning_track.service { seed_builtin_tracks }
import from nodes.roadmap { Roadmap, RoadmapLesson, RoadmapWeek }
import from walkers.generate_lesson {
    GeneratedLessonView,
    LessonGenerationError,
    generate_lesson,
    generated_lesson_to_view,
    get_generated_lesson
}

obj LessonLinkView {
    has roadmap_lesson_id: str;
    has title: str;
    has order_label: str;
}

obj LessonOpenState {
    has status: str;
    has lesson: GeneratedLessonView | None = None;
    has previous_lesson: LessonLinkView | None = None;
    has next_lesson: LessonLinkView | None = None;
    has message: str = "";
    has generated_now: bool = False;
}

def _find_roadmap(roadmap_id: str) -> Roadmap | None {
    return roadmap_for(roadmap_id);
}

def _find_roadmap_lesson(roadmap: Roadmap, roadmap_lesson_id: str) -> RoadmapLesson | None {
    return roadmap_lesson_for(roadmap, roadmap_lesson_id);
}

def _week_number_for_lesson(roadmap: Roadmap, roadmap_lesson: RoadmapLesson) -> int {
    for week in roadmap.weeks {
        if week.id == roadmap_lesson.week_id {
            return week.week_number;
        }
    }
    for week in [roadmap ->:contains:->][?:RoadmapWeek] {
        if week.id == roadmap_lesson.week_id {
            return week.week_number;
        }
    }
    return 0;
}

def _week_order(week: RoadmapWeek) -> int {
    return week.week_number;
}

def _lesson_order(lesson: RoadmapLesson) -> int {
    return lesson.order_index;
}

def _ordered_lessons(roadmap: Roadmap) -> list[RoadmapLesson] {
    return roadmap_lessons(roadmap);
}

def _lesson_link(roadmap: Roadmap, lesson: RoadmapLesson) -> LessonLinkView {
    week_number = _week_number_for_lesson(roadmap, lesson);
    label = f"Week {week_number} - Lesson {lesson.order_index}" if week_number > 0 else f"Lesson {lesson.order_index}";
    return LessonLinkView(
        roadmap_lesson_id=lesson.id,
        title=lesson.title,
        order_label=label
    );
}

def _previous_lesson(roadmap: Roadmap, current_lesson: RoadmapLesson) -> LessonLinkView | None {
    lessons = _ordered_lessons(roadmap);
    previous: RoadmapLesson | None = None;
    for lesson in lessons {
        if lesson.id == current_lesson.id {
            if previous is not None {
                return _lesson_link(roadmap, previous as RoadmapLesson);
            }
            return None;
        }
        previous = lesson;
    }
    return None;
}

def _next_lesson(roadmap: Roadmap, current_lesson: RoadmapLesson) -> LessonLinkView | None {
    lessons = _ordered_lessons(roadmap);
    found = False;
    for lesson in lessons {
        if found {
            return _lesson_link(roadmap, lesson);
        }
        if lesson.id == current_lesson.id {
            found = True;
        }
    }
    return None;
}

def _error_message(errors: list[LessonGenerationError]) -> str {
    if len(errors) == 0 {
        return "Lesson generation failed.";
    }
    return errors[0].message;
}

def:priv open_lesson(
    learner_id: str,
    roadmap_id: str,
    roadmap_lesson_id: str
) -> LessonOpenState {
    _ = seed_builtin_tracks();
    if learner_id.strip() == "" {
        return LessonOpenState(status="missing_learner", message="Log in again to open this lesson.");
    }
    if roadmap_id.strip() == "" {
        return LessonOpenState(status="missing_roadmap", message="No roadmap id was provided.");
    }
    if roadmap_lesson_id.strip() == "" {
        return LessonOpenState(status="missing_roadmap_lesson", message="No roadmap lesson id was provided.");
    }

    roadmap = _find_roadmap(roadmap_id);
    if roadmap is None {
        return LessonOpenState(status="missing_roadmap", message="Roadmap could not be found.");
    }
    if roadmap.learner_id != learner_id {
        return LessonOpenState(status="learner_mismatch", message="This roadmap does not belong to the current learner.");
    }
    if roadmap.language not in ["python", "jac"] {
        return LessonOpenState(status="unsupported_language", message="This lesson language is not supported yet.");
    }

    roadmap_lesson = _find_roadmap_lesson(roadmap, roadmap_lesson_id);
    if roadmap_lesson is None {
        return LessonOpenState(status="missing_roadmap_lesson", message="Roadmap lesson could not be found.");
    }

    existing = get_generated_lesson(learner_id, roadmap_lesson_id);
    if existing is not None {
        return LessonOpenState(
            status="ready",
            lesson=generated_lesson_to_view(existing),
            previous_lesson=_previous_lesson(roadmap, roadmap_lesson),
            next_lesson=_next_lesson(roadmap, roadmap_lesson)
        );
    }

    result = root spawn generate_lesson(
        learner_id=learner_id,
        roadmap_id=roadmap_id,
        roadmap_lesson_id=roadmap_lesson_id,
        language=roadmap.language,
        track_id=roadmap.track_id,
        track_version_id=roadmap.track_version_id,
        enrollment_id=roadmap.enrollment_id
    );
    if len(result.errors) > 0 or len(result.reports) == 0 {
        return LessonOpenState(
            status="generation_failed",
            previous_lesson=_previous_lesson(roadmap, roadmap_lesson),
            next_lesson=_next_lesson(roadmap, roadmap_lesson),
            message=_error_message(result.errors)
        );
    }

    return LessonOpenState(
        status="ready",
        lesson=result.reports[0],
        previous_lesson=_previous_lesson(roadmap, roadmap_lesson),
        next_lesson=_next_lesson(roadmap, roadmap_lesson),
        generated_now=True
    );
}
