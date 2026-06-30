"""Progression domain nodes."""

enum LessonUnlockState: str {
    locked = "locked",
    available = "available",
    in_progress = "in_progress",
    completed = "completed"
}

enum RoadmapProgressStatus: str {
    not_started = "not_started",
    in_progress = "in_progress",
    completed = "completed"
}

enum ProgressionEventType: str {
    lesson_unlocked = "lesson_unlocked",
    lesson_completed = "lesson_completed",
    roadmap_started = "roadmap_started",
    roadmap_completed = "roadmap_completed"
}

node LessonProgress {
    has id: str;
    has learner_id: str;
    has roadmap_id: str;
    has roadmap_lesson_id: str;
    has status: LessonUnlockState;
    has completed_at: str;
    has unlocked_at: str;
    has updated_at: str;
}

node RoadmapProgress {
    has id: str;
    has learner_id: str;
    has roadmap_id: str;
    has total_lessons: int;
    has completed_lessons: int;
    has available_lessons: int;
    has locked_lessons: int;
    has percent_complete: int;
    has current_roadmap_lesson_id: str;
    has status: RoadmapProgressStatus;
    has updated_at: str;
}

node ProgressionEvent {
    has id: str;
    has learner_id: str;
    has roadmap_id: str;
    has roadmap_lesson_id: str;
    has event_type: ProgressionEventType;
    has source_type: str;
    has source_id: str;
    has message: str;
    has created_at: str;
}
