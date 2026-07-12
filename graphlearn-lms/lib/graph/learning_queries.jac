"""Canonical root-scoped lookups for generated learning records."""

import from nodes.lesson { GeneratedLesson, LessonGenerationStatus }

def generated_lesson_for(
    learner_id: str,
    roadmap_id: str,
    roadmap_lesson_id: str
) -> GeneratedLesson | None {
    for lesson in [root -->][?:GeneratedLesson] {
        if (
            lesson.learner_id == learner_id
            and lesson.roadmap_id == roadmap_id
            and lesson.roadmap_lesson_id == roadmap_lesson_id
            and lesson.generation_status == LessonGenerationStatus.generated
        ) {
            return lesson;
        }
    }
    return None;
}
