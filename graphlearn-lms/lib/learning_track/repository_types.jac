"""Shared contracts for track-aware repositories and application services."""

obj RepositoryError {
    has code: str;
    has message: str;
    has details: dict[str, str] = {};
}

obj RepositoryResult {
    has ok: bool;
    has value: object | None = None;
    has error: RepositoryError | None = None;
}

obj ServiceError {
    has code: str;
    has message: str;
    has details: dict[str, str] = {};
}

obj ServiceResult {
    has ok: bool;
    has value: object | None = None;
    has error: ServiceError | None = None;
    has replayed: bool = False;
}

obj PageRequest {
    has limit: int = 20;
    has cursor: str | None = None;
}

obj PageResult {
    has items: list[object];
    has next_cursor: str | None = None;
    has has_more: bool = False;
}

obj ActorContext {
    has user_id: str;
    has request_id: str;
    has learner_id: str | None = None;
    has lecturer_id: str | None = None;
    has roles: list[str] = [];
    has institution_ids: list[str] = [];
}

obj IdempotencyContext {
    has key: str;
    has operation: str;
    has actor_id: str;
    has request_id: str;
}

obj ResolvedTrackContext {
    has track_id: str;
    has track_version_id: str;
    has title: str;
    has legacy_language: str | None = None;
    has resolution_source: str = "TRACK_ID";
}

obj TrackCatalogueItem {
    has track_id: str;
    has track_version_id: str;
    has slug: str;
    has title: str;
    has short_description: str;
    has track_type: str;
    has subject_area: str | None;
    has academic_level: str | None;
    has estimated_duration_weeks: int | None;
}

obj TrackProgressSummary {
    has enrollment_id: str;
    has track_id: str;
    has track_version_id: str;
    has completion_percent: float;
    has mastered_skill_count: int;
    has total_skill_count: int;
    has current_lesson_id: str | None;
}

node ApplicationOperation {
    has key: str;
    has operation: str;
    has actor_id: str;
    has request_id: str;
    has status: str;
    has created_at: str;
    has updated_at: str;
    has entity_id: str | None = None;
    has error_code: str | None = None;
}
