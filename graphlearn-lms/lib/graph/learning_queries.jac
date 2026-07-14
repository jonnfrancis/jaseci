"""Canonical root-scoped lookups for generated learning records."""

import from nodes.lesson { GeneratedLesson, LessonGenerationStatus }
import from lib.observability.instrumentation { graph_operation_event }
import from lib.observability.tracing { monotonic_ms }

def generated_lesson_for(
    learner_id: str,
    roadmap_id: str,
    roadmap_lesson_id: str
) -> GeneratedLesson | None {
    started = monotonic_ms();
    for lesson in [root -->][?:GeneratedLesson] {
        if (
            lesson.learner_id == learner_id
            and lesson.roadmap_id == roadmap_id
            and lesson.roadmap_lesson_id == roadmap_lesson_id
            and lesson.generation_status == LessonGenerationStatus.generated
        ) {
            graph_operation_event("generated_lesson_for", "read", True, max(0, monotonic_ms() - started), 1);
            return lesson;
        }
    }
    graph_operation_event("generated_lesson_for", "read", True, max(0, monotonic_ms() - started), 0);
    return None;
}
