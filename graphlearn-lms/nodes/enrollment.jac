"""Enrollment-scoped learner graph nodes introduced by Feature 32."""

node Enrollment {
    has enrollment_id: str;
    has learner_id: str;
    has track_id: str;
    has track_version_id: str;
    has enrolled_at: str;
    has status: str = "ACTIVE";
    has source: str = "SELF_ENROLLED";
    has started_at: str | None = None;
    has completed_at: str | None = None;
    has archived_at: str | None = None;
    has current_roadmap_id: str | None = None;
    has overall_mastery: float = 0.0;
}

node RoadmapItem {
    has roadmap_item_id: str;
    has roadmap_id: str;
    has track_id: str;
    has track_version_id: str;
    has order_index: int;
    has target_skill_id: str;
    has week_number: int | None = None;
    has status: str = "LOCKED";
    has lesson_template_id: str | None = None;
    has unlocked_at: str | None = None;
    has started_at: str | None = None;
    has completed_at: str | None = None;
}

node Submission {
    has submission_id: str;
    has learner_id: str;
    has enrollment_id: str;
    has track_id: str;
    has track_version_id: str;
    has activity_template_id: str;
    has submitted_at: str;
    has answer_text: str | None = None;
    has answer_payload_json: str | None = None;
    has status: str = "SUBMITTED";
    has score: float | None = None;
    has passed: bool | None = None;
    has feedback: str | None = None;
    has grading_metadata_json: str = "{}";
    has graded_at: str | None = None;
}
