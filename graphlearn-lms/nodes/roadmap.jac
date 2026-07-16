"""Roadmap domain nodes."""

enum RoadmapStatus: str {
    draft = "draft",
    active = "active",
    completed = "completed"
}

enum RoadmapLessonGenerationStatus: str {
    pending = "pending",
    generated = "generated"
}

node RoadmapLesson {
    has id: str;
    has roadmap_id: str;
    has week_id: str;
    has title: str;
    has summary: str;
    has target_skill_ids: list[str];
    has difficulty: str;
    has estimated_minutes: int;
    has order_index: int;
    has generation_status: RoadmapLessonGenerationStatus;
    has track_id: str | None = None;
    has track_version_id: str | None = None;
}

node RoadmapMilestone {
    has id: str;
    has roadmap_id: str;
    has week_id: str;
    has title: str;
    has description: str;
    has required_skill_ids: list[str];
    has track_id: str | None = None;
    has track_version_id: str | None = None;
}

node RoadmapWeek {
    has id: str;
    has roadmap_id: str;
    has week_number: int;
    has title: str;
    has summary: str;
    has lessons: list[RoadmapLesson] = [];
    has milestones: list[RoadmapMilestone] = [];
    has track_id: str | None = None;
    has track_version_id: str | None = None;
}

node Roadmap {
    has id: str;
    has learner_id: str;
    has language: str;
    has title: str;
    has description: str;
    has estimated_weeks: int;
    has status: RoadmapStatus;
    has created_at: str;
    has assessment_id: str;
    has assessment_attempt_id: str;
    has assessment_evaluation_id: str;
    has weeks: list[RoadmapWeek] = [];
    has lessons: list[RoadmapLesson] = [];
    has milestones: list[RoadmapMilestone] = [];
    has track_id: str | None = None;
    has track_version_id: str | None = None;
    has roadmap_id: str | None = None;
    has enrollment_id: str | None = None;
    has generation_version: int = 1;
    has updated_at: str = "";
    has completed_at: str | None = None;
}
