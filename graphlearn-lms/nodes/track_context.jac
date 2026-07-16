"""Track-aware optional persisted records and validation contracts."""

obj TrackValidationResult {
    has valid: bool;
    has track_id: str | None = None;
    has track_version_id: str | None = None;
    has error_code: str | None = None;
    has message: str = "";
}

node Recommendation {
    has recommendation_id: str;
    has learner_id: str;
    has recommendation_type: str;
    has rationale: str;
    has status: str;
    has generated_at: str;
    has track_id: str | None = None;
    has track_version_id: str | None = None;
    has roadmap_id: str | None = None;
    has target_skill_id: str | None = None;
    has target_lesson_id: str | None = None;
    has consumed_at: str | None = None;
}

node SkillMapSnapshot {
    has skill_map_id: str;
    has learner_id: str;
    has snapshot_json: str;
    has generated_at: str;
    has track_id: str | None = None;
    has track_version_id: str | None = None;
    has roadmap_id: str | None = None;
}

node DashboardSnapshot {
    has dashboard_snapshot_id: str;
    has learner_id: str;
    has summary_json: str;
    has generated_at: str;
    has track_id: str | None = None;
    has track_version_id: str | None = None;
    has roadmap_id: str | None = None;
    has expires_at: str | None = None;
}
