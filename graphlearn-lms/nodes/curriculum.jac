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

enum CourseDocumentUploadStatus: str {
    PENDING = "PENDING", UPLOADING = "UPLOADING", STORED = "STORED",
    FAILED = "FAILED", DELETED = "DELETED"
}

enum CourseDocumentProcessingStatus: str {
    NOT_STARTED = "NOT_STARTED", QUEUED = "QUEUED", EXTRACTING = "EXTRACTING",
    CHUNKING = "CHUNKING", ANALYZING = "ANALYZING",
    REVIEW_REQUIRED = "REVIEW_REQUIRED", COMPLETED = "COMPLETED", FAILED = "FAILED"
}

node CourseDocument {
    has document_id: str;
    has track_id: str;
    has track_version_id: str;
    has original_filename: str;
    has normalized_filename: str;
    has mime_type: str;
    has file_extension: str;
    has file_size_bytes: int;
    has storage_provider: str;
    has storage_key: str;
    has checksum_algorithm: str;
    has checksum: str;
    has upload_status: CourseDocumentUploadStatus;
    has processing_status: CourseDocumentProcessingStatus;
    has uploaded_by: str;
    has uploaded_at: str;
    has updated_at: str;
    has idempotency_scope: str;
    has processing_error_code: str | None = None;
    has processing_error_message: str | None = None;
    has is_active: bool = True;
    has deleted_at: str | None = None;
}

obj UploadCourseDocumentInput {
    has track_id: str;
    has track_version_id: str;
    has original_filename: str;
    has mime_type: str;
    has file_size_bytes: int;
    has idempotency_key: str;
    has content_base64: str;
    has replace_existing: bool = False;
}

obj CourseDocumentError {
    has code: str;
    has message: str;
    has details: dict[str, str] = {};
}

obj CourseDocumentUploadResult {
    has ok: bool;
    has document_id: str | None = None;
    has track_id: str | None = None;
    has track_version_id: str | None = None;
    has filename: str | None = None;
    has mime_type: str | None = None;
    has file_size_bytes: int | None = None;
    has storage_key: str | None = None;
    has checksum: str | None = None;
    has upload_status: str | None = None;
    has processing_status: str | None = None;
    has duplicate: bool = False;
    has replaced_document_id: str | None = None;
    has error: CourseDocumentError | None = None;
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
