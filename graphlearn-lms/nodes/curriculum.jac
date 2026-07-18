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

enum DocumentChunkingStatus: str {
    NOT_STARTED = "NOT_STARTED", QUEUED = "QUEUED", CHUNKING = "CHUNKING",
    CHUNKED = "CHUNKED", CHUNKING_FAILED = "CHUNKING_FAILED"
}

enum DocumentProcessingStage: str {
    STORAGE = "STORAGE", SECURITY_VALIDATION = "SECURITY_VALIDATION",
    TEXT_EXTRACTION = "TEXT_EXTRACTION", CONTENT_CHUNKING = "CONTENT_CHUNKING",
    BLUEPRINT_GENERATION = "BLUEPRINT_GENERATION", BLUEPRINT_VALIDATION = "BLUEPRINT_VALIDATION"
}

enum ProcessingJobStatus: str {
    PENDING = "PENDING", QUEUED = "QUEUED", RUNNING = "RUNNING", RETRY_WAIT = "RETRY_WAIT",
    SUCCEEDED = "SUCCEEDED", FAILED = "FAILED", CANCEL_REQUESTED = "CANCEL_REQUESTED",
    CANCELLED = "CANCELLED", STALE = "STALE", BLOCKED = "BLOCKED"
}

enum DocumentProcessingState: str {
    UPLOADED = "UPLOADED", STORED = "STORED", VALIDATION_PENDING = "VALIDATION_PENDING",
    VALIDATING = "VALIDATING", VALIDATION_FAILED = "VALIDATION_FAILED", VALIDATED = "VALIDATED",
    EXTRACTION_PENDING = "EXTRACTION_PENDING", EXTRACTING = "EXTRACTING", OCR_REQUIRED = "OCR_REQUIRED",
    NO_EXTRACTABLE_TEXT = "NO_EXTRACTABLE_TEXT", EXTRACTION_FAILED = "EXTRACTION_FAILED",
    EXTRACTED = "EXTRACTED", CHUNKING_PENDING = "CHUNKING_PENDING", CHUNKING = "CHUNKING",
    CHUNKING_FAILED = "CHUNKING_FAILED", CHUNKED = "CHUNKED",
    READY_FOR_BLUEPRINT = "READY_FOR_BLUEPRINT", CANCELLED = "CANCELLED", BLOCKED = "BLOCKED"
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
    has processing_state: DocumentProcessingState = DocumentProcessingState.UPLOADED;
    has extraction_status: DocumentExtractionStatus = DocumentExtractionStatus.NOT_STARTED;
    has chunking_status: DocumentChunkingStatus = DocumentChunkingStatus.NOT_STARTED;
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

obj HeadingPathItem { has level: int; has text: str; }

obj LogicalSection {
    has heading_path: list[HeadingPathItem];
    has blocks: list[ExtractionBlock];
    has page_start: int | None;
    has page_end: int | None;
    has character_count: int;
}

obj ChunkingConfig {
    has target_tokens: int = 800;
    has max_tokens: int = 1200;
    has min_tokens: int = 150;
    has overlap_tokens: int = 100;
    has max_characters: int = 6000;
    has max_chunks: int = 10000;
    has include_footnotes: bool = True;
    has include_captions: bool = True;
    has include_headers: bool = False;
    has include_footers: bool = False;
    has strategy_name: str = "structural-v1";
    has schema_version: int = 1;
}

obj ChunkingRequestContext {
    has document_id: str; has track_id: str; has track_version_id: str;
    has extraction_id: str; has request_id: str; has actor_id: str | None;
    has config: ChunkingConfig; has force_rechunk: bool = False;
}

obj DocumentChunkingResult {
    has document_id: str; has extraction_id: str; has status: DocumentChunkingStatus;
    has chunk_count: int = 0; has total_characters: int = 0; has total_words: int = 0;
    has total_estimated_tokens: int = 0; has average_chunk_tokens: float = 0.0;
    has source_coverage_ratio: float = 0.0; has warnings: list[str] = [];
    has error_code: str | None = None;
}

node DocumentChunkSet {
    has chunk_set_id: str; has document_id: str; has extraction_id: str;
    has track_id: str; has track_version_id: str; has source_checksum_sha256: str;
    has schema_version: int; has strategy_name: str; has config_hash: str;
    has status: DocumentChunkingStatus; has created_at: str;
    has chunk_count: int = 0;
    has total_characters: int = 0; has total_words: int = 0; has total_estimated_tokens: int = 0;
    has average_chunk_tokens: float = 0.0; has source_coverage_ratio: float = 0.0;
    has warnings_json: str = "[]"; has contains_untrusted_instruction_like_text: bool = False;
    has is_active: bool = False; has completed_at: str | None = None;
    has error_code: str | None = None;
}

node DocumentProcessingJob {
    has job_id: str; has document_id: str; has track_id: str; has track_version_id: str;
    has stage: DocumentProcessingStage; has status: ProcessingJobStatus;
    has idempotency_key: str; has created_at: str; has updated_at: str;
    has job_generation: int = 1; has attempt_number: int = 0; has max_attempts: int = 3;
    has priority: int = 100; has queued_at: str | None = None; has started_at: str | None = None;
    has completed_at: str | None = None; has next_retry_at: str | None = None;
    has worker_id: str | None = None; has lease_expires_at: str | None = None;
    has last_heartbeat_at: str | None = None; has progress_percent: int = 0;
    has progress_message: str | None = None; has error_code: str | None = None;
    has error_message: str | None = None; has retryable: bool | None = None;
    has cancel_requested_at: str | None = None; has cancelled_at: str | None = None;
    has cancellation_reason: str | None = None;
}

node ProcessingJobAttempt {
    has attempt_id: str; has job_id: str; has attempt_number: int; has status: str;
    has started_at: str; has worker_id: str | None = None; has completed_at: str | None = None;
    has error_code: str | None = None; has error_message: str | None = None;
    has retryable: bool | None = None; has duration_ms: int | None = None;
    has metadata_json: str | None = None;
}

obj StageEligibility {
    has eligible: bool; has stage: DocumentProcessingStage;
    has blocking_stage: DocumentProcessingStage | None = None;
    has error_code: str | None = None; has message: str | None = None;
}

obj ProcessingWorkerContext {
    has worker_id: str; has job_id: str; has attempt_id: str; has request_id: str;
    has cancellation_check_interval: int = 25;
}

obj StageExecutionResult {
    has succeeded: bool; has retryable: bool; has error_code: str | None = None;
    has error_message: str | None = None; has artifact_id: str | None = None;
    has warnings: list[str] = [];
}

obj StageReconciliationResult {
    has completed: bool; has artifact_id: str | None = None; has error_code: str | None = None;
}

obj DocumentProcessingSummary {
    has document_id: str; has state: DocumentProcessingState; has overall_progress_percent: int;
    has retry_available: bool; has cancel_available: bool; has updated_at: str;
    has current_stage: DocumentProcessingStage | None = None; has progress_message: str | None = None;
    has error_code: str | None = None; has user_message: str | None = None;
    has started_at: str | None = None; has completed_at: str | None = None;
}

obj ProcessingStageSummary {
    has stage: DocumentProcessingStage; has status: str; has attempt_count: int;
    has started_at: str | None = None; has completed_at: str | None = None;
    has error_code: str | None = None;
}

obj DocumentProcessingStatusView {
    has summary: DocumentProcessingSummary; has stages: list[ProcessingStageSummary] = [];
    has warnings: list[str] = [];
}

obj CourseSourceDocumentView {
    has document_id: str;
    has filename: str;
    has file_type: str;
    has file_size_bytes: int;
    has uploaded_at: str;
    has is_active: bool;
}

obj CourseSourceWorkspaceView {
    has track_id: str;
    has track_version_id: str;
    has source_required: bool;
    has status_label: str;
    has next_action_label: str;
    has blocker_message: str;
    has interpretation_eligible: bool;
    has document: CourseSourceDocumentView | None = None;
    has processing: DocumentProcessingStatusView | None = None;
}

node CourseContentChunk {
    has chunk_id: str;
    has document_id: str;
    has extraction_id: str;
    has track_id: str;
    has track_version_id: str;
    has chunking_strategy: str;
    has order_index: int;
    has content: str;
    has character_count: int;
    has word_count: int;
    has estimated_token_count: int;
    has source_block_ids_json: str;
    has content_hash: str;
    has created_at: str;
    has chunking_schema_version: int = 1;
    has title: str | None = None;
    has heading_path_json: str | None = None;
    has page_start: int | None = None;
    has page_end: int | None = None;
    has source_locator_json: str | None = None;
    has overlap_prefix_characters: int = 0;
    has overlap_suffix_characters: int = 0;
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
