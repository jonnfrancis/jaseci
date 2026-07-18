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
    PENDING = "PENDING", UPLOADING = "UPLOADING", STORED_PENDING_COMMIT = "STORED_PENDING_COMMIT",
    STORED = "STORED", REPLACED = "REPLACED", FAILED = "FAILED", ORPHANED = "ORPHANED",
    DELETING = "DELETING", DELETED = "DELETED"
}

enum CourseDocumentProcessingStatus: str {
    NOT_STARTED = "NOT_STARTED", QUEUED = "QUEUED", EXTRACTING = "EXTRACTING",
    EXTRACTED = "EXTRACTED", OCR_REQUIRED = "OCR_REQUIRED", NO_EXTRACTABLE_TEXT = "NO_EXTRACTABLE_TEXT",
    CHUNKING = "CHUNKING", ANALYZING = "ANALYZING",
    REVIEW_REQUIRED = "REVIEW_REQUIRED", COMPLETED = "COMPLETED", FAILED = "FAILED"
}

enum DocumentExtractionStatus: str {
    NOT_STARTED = "NOT_STARTED", QUEUED = "QUEUED", EXTRACTING = "EXTRACTING",
    EXTRACTED = "EXTRACTED", OCR_REQUIRED = "OCR_REQUIRED",
    NO_EXTRACTABLE_TEXT = "NO_EXTRACTABLE_TEXT", EXTRACTION_FAILED = "EXTRACTION_FAILED"
}

enum ExtractionQuality: str { HIGH = "HIGH", MEDIUM = "MEDIUM", LOW = "LOW" }

enum ExtractionBlockType: str {
    HEADING = "HEADING", PARAGRAPH = "PARAGRAPH", LIST_ITEM = "LIST_ITEM",
    TABLE_TEXT = "TABLE_TEXT", CAPTION = "CAPTION", FOOTNOTE = "FOOTNOTE",
    HEADER = "HEADER", FOOTER = "FOOTER", PAGE_BREAK = "PAGE_BREAK", OTHER = "OTHER"
}

enum DocumentValidationStatus: str {
    PENDING = "PENDING", VALIDATING = "VALIDATING", VALIDATED = "VALIDATED",
    REJECTED = "REJECTED", QUARANTINED = "QUARANTINED",
    VALIDATION_FAILED = "VALIDATION_FAILED"
}

enum MalwareScanStatus: str {
    NOT_RUN = "NOT_RUN", CLEAN = "CLEAN", INFECTED = "INFECTED",
    SUSPICIOUS = "SUSPICIOUS", ERROR = "ERROR"
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
    has extraction_status: DocumentExtractionStatus = DocumentExtractionStatus.NOT_STARTED;
    has validation_status: DocumentValidationStatus = DocumentValidationStatus.PENDING;
    has validation_version: int = 1;
    has validation_error_code: str | None = None;
    has validation_error_message: str | None = None;
    has detected_mime_type: str | None = None;
    has detected_file_type: str | None = None;
    has page_count: int | None = None;
    has is_encrypted: bool | None = None;
    has has_macros: bool | None = None;
    has malware_scan_status: str | None = None;
    has malware_scan_provider: str | None = None;
    has validated_at: str | None = None;
    has validated_by_service: str | None = None;
    has processing_error_code: str | None = None;
    has processing_error_message: str | None = None;
    has is_active: bool = True;
    has replaced_document_id: str | None = None;
    has deleted_at: str | None = None;
}

node DocumentExtraction {
    has extraction_id: str;
    has document_id: str;
    has track_id: str;
    has track_version_id: str;
    has status: DocumentExtractionStatus;
    has extractor_name: str;
    has extractor_version: str;
    has source_checksum_sha256: str;
    has schema_version: int = 1;
    has total_characters: int = 0;
    has total_words: int = 0;
    has total_blocks: int = 0;
    has total_pages: int | None = None;
    has detected_language: str | None = None;
    has extraction_quality: str | None = None;
    has plain_text: str | None = None;
    has warnings_json: str = "[]";
    has started_at: str | None = None;
    has completed_at: str | None = None;
    has error_code: str | None = None;
    has error_message: str | None = None;
    has is_active: bool = True;
}

node ExtractionBlock {
    has extraction_block_id: str;
    has extraction_id: str;
    has order_index: int;
    has block_type: str;
    has text: str;
    has character_start: int;
    has character_end: int;
    has word_count: int;
    has page_start: int | None = None;
    has page_end: int | None = None;
    has heading_level: int | None = None;
    has heading_text: str | None = None;
    has paragraph_index: int | None = None;
    has source_locator: str | None = None;
    has metadata_json: str | None = None;
}

obj RawExtractionBlock {
    has block_type: str;
    has text: str;
    has page_start: int | None = None;
    has page_end: int | None = None;
    has heading_level: int | None = None;
    has heading_text: str | None = None;
    has source_locator: str | None = None;
    has metadata_json: str | None = None;
}

obj RawExtractionResult {
    has blocks: list[RawExtractionBlock];
    has warnings: list[str];
    has total_pages: int | None = None;
    has parser_metadata_json: str | None = None;
    has pages_with_text: int = 0;
    has pages_without_text: int = 0;
    has pages_with_images: int = 0;
}

obj ExtractionContext {
    has extraction_id: str;
    has document_id: str;
    has track_id: str;
    has track_version_id: str;
    has source_checksum_sha256: str;
    has request_id: str;
    has schema_version: int;
    has max_characters: int;
    has max_blocks: int;
    has timeout_seconds: int;
}

obj ExtractionRequestContext {
    has document_id: str;
    has track_id: str;
    has track_version_id: str;
    has request_id: str;
    has extraction_schema_version: int = 1;
    has actor_id: str | None = None;
    has force_reextract: bool = False;
}

obj DocumentExtractionResult {
    has document_id: str;
    has status: DocumentExtractionStatus;
    has reused: bool = False;
    has extraction_id: str | None = None;
    has quality: str | None = None;
    has total_pages: int | None = None;
    has total_characters: int = 0;
    has total_words: int = 0;
    has total_blocks: int = 0;
    has warnings: list[str] = [];
    has error_code: str | None = None;
    has user_message: str | None = None;
}

obj DocumentValidationCheck {
    has name: str;
    has status: str;
    has required: bool;
    has code: str | None = None;
}

obj DocumentValidationResult {
    has document_id: str;
    has status: DocumentValidationStatus;
    has policy_version: int;
    has size_bytes: int;
    has validated_at: str;
    has detected_file_type: str | None = None;
    has detected_mime_type: str | None = None;
    has page_count: int | None = None;
    has encrypted: bool | None = None;
    has macro_content: bool | None = None;
    has malware_status: str | None = None;
    has duplicate_of_document_id: str | None = None;
    has checks: list[DocumentValidationCheck] = [];
    has error_code: str | None = None;
    has user_message: str | None = None;
}

obj DocumentValidationContext {
    has document_id: str;
    has track_id: str;
    has track_version_id: str;
    has request_id: str;
    has validation_policy_version: int = 1;
    has actor_id: str | None = None;
}

obj MalwareScanResult {
    has status: MalwareScanStatus;
    has provider: str;
    has scanned_at: str;
    has signature_name: str | None = None;
    has retryable: bool = False;
}

node StorageOrphanCandidate {
    has orphan_id: str;
    has storage_key: str;
    has upload_id: str | None;
    has document_id: str | None;
    has reason: str;
    has detected_at: str;
    has eligible_for_cleanup_at: str;
    has cleanup_status: str = "PENDING";
    has cleanup_error_code: str | None = None;
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
