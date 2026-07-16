"""Version-scoped shared curriculum and source-material nodes."""

node CourseModule {
    has module_id: str;
    has track_id: str;
    has track_version_id: str;
    has title: str;
    has order_index: int;
    has created_at: str;
    has updated_at: str;
    has description: str = "";
    has estimated_minutes: int | None = None;
    has learning_outcomes_json: str = "[]";
}

node LessonTemplate {
    has lesson_template_id: str;
    has track_id: str;
    has track_version_id: str;
    has title: str;
    has created_at: str;
    has updated_at: str;
    has summary: str = "";
    has content: str = "";
    has content_format: str = "MARKDOWN";
    has difficulty: str = "MIXED";
    has estimated_minutes: int = 30;
    has generation_status: str = "READY";
    has source_references_json: str = "[]";
    has generation_metadata_json: str = "{}";
}

node ActivityTemplate {
    has activity_template_id: str;
    has track_id: str;
    has track_version_id: str;
    has title: str;
    has instructions: str;
    has activity_type: str;
    has created_at: str;
    has updated_at: str;
    has max_score: float = 100.0;
    has pass_score: float = 70.0;
    has difficulty: str = "MIXED";
    has answer_key_json: str | None = None;
    has rubric_json: str | None = None;
    has test_cases_json: str | None = None;
    has source_references_json: str = "[]";
}

node CourseDocument {
    has document_id: str;
    has track_id: str;
    has track_version_id: str;
    has filename: str;
    has mime_type: str;
    has storage_key: str;
    has checksum: str;
    has processing_status: str;
    has uploaded_by: str;
    has uploaded_at: str;
}

node CourseContentChunk {
    has chunk_id: str;
    has document_id: str;
    has track_id: str;
    has track_version_id: str;
    has order_index: int;
    has content: str;
    has heading: str | None = None;
    has page_start: int | None = None;
    has page_end: int | None = None;
    has token_count: int = 0;
}

node CourseBlueprint {
    has blueprint_id: str;
    has track_id: str;
    has track_version_id: str;
    has status: str;
    has generated_at: str;
    has summary: str = "";
    has learning_outcomes_json: str = "[]";
    has warnings_json: str = "[]";
    has approved_by: str | None = None;
    has approved_at: str | None = None;
}
