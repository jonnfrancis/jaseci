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
    has importance: str = "REQUIRED";
    has estimated_learning_hours: float | None = None;
    has status: str = "ACTIVE";
    has blueprint_id: str | None = None;
    has blueprint_module_key: str | None = None;
    has graph_generation_id: str | None = None;
    has evidence_json: str = "[]";
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

enum BlueprintGenerationStatus: str { NOT_STARTED = "NOT_STARTED", QUEUED = "QUEUED", ANALYZING_CHUNKS = "ANALYZING_CHUNKS", MERGING_CONCEPTS = "MERGING_CONCEPTS", SYNTHESIZING_BLUEPRINT = "SYNTHESIZING_BLUEPRINT", INFERRING_PREREQUISITES = "INFERRING_PREREQUISITES", CRITIQUING = "CRITIQUING", VALIDATING = "VALIDATING", GENERATED = "GENERATED", REVIEW_REQUIRED = "REVIEW_REQUIRED", FAILED = "FAILED" }
enum BlueprintGenerationErrorCode: str { SOURCE_NOT_READY = "BLUEPRINT_SOURCE_NOT_READY", CHUNK_SET_INVALID = "BLUEPRINT_CHUNK_SET_INVALID", ALREADY_RUNNING = "BLUEPRINT_GENERATION_ALREADY_RUNNING", CHUNK_ANALYSIS_FAILED = "BLUEPRINT_CHUNK_ANALYSIS_FAILED", CONCEPT_MERGE_FAILED = "BLUEPRINT_CONCEPT_MERGE_FAILED", OUTCOME_SYNTHESIS_FAILED = "BLUEPRINT_OUTCOME_SYNTHESIS_FAILED", MODULE_SYNTHESIS_FAILED = "BLUEPRINT_MODULE_SYNTHESIS_FAILED", PREREQUISITE_INFERENCE_FAILED = "BLUEPRINT_PREREQUISITE_INFERENCE_FAILED", CRITIQUE_FAILED = "BLUEPRINT_CRITIQUE_FAILED", GROUNDING_FAILED = "BLUEPRINT_GROUNDING_FAILED", SOURCE_COVERAGE_LOW = "BLUEPRINT_SOURCE_COVERAGE_LOW", CONCEPT_COVERAGE_LOW = "BLUEPRINT_CONCEPT_COVERAGE_LOW", MODULE_COVERAGE_LOW = "BLUEPRINT_MODULE_COVERAGE_LOW", PREREQUISITE_CYCLE = "BLUEPRINT_PREREQUISITE_CYCLE", PERSIST_FAILED = "BLUEPRINT_PERSIST_FAILED", RETRY_EXHAUSTED = "BLUEPRINT_GENERATION_RETRY_EXHAUSTED", INTERNAL_ERROR = "BLUEPRINT_GENERATION_INTERNAL_ERROR" }

node CourseBlueprint {
    has blueprint_id: str, track_id: str, track_version_id: str;
    has document_id: str = "", extraction_id: str = "", chunk_set_id: str = "";
    has schema_version: int = 1;
    has generation_status: BlueprintGenerationStatus = BlueprintGenerationStatus.NOT_STARTED;
    has source_checksum_sha256: str = "";
    has course_title: str = "", course_summary: str = "";
    has confidence: str = "LOW", prompt_versions_json: str = "{}", ai_execution_ids_json: str = "[]";
    has created_at: str = "", updated_at: str = "";
    has generation_number: int = 1;
    has generation_config_hash: str = "";
    has generation_identity: str = "";
    has is_active: bool = False;
    has source_coverage_ratio: float = 0.0, concept_coverage_ratio: float = 0.0, module_coverage_ratio: float = 0.0;
    has estimated_duration_weeks: int | None = None, validation_status: str | None = None, generated_at: str | None = None, approved_at: str | None = None;
    # Compatibility fields retained for pre-Feature-46 development records.
    has status: str = "NOT_STARTED", summary: str = "", learning_outcomes_json: str = "[]", warnings_json: str = "[]", approved_by: str | None = None;
}

node BlueprintConcept { has blueprint_concept_id: str, blueprint_id: str, local_concept_key: str, canonical_name: str, description: str, concept_type: str, aliases_json: str, learning_objectives_json: str, key_terms_json: str, confidence: str; has should_be_taught_explicitly: bool; has evidence_json: str; has edited_by_lecturer: bool = False; has last_edited_at: str | None = None, last_edited_by: str | None = None; }
node BlueprintLearningOutcomeNode { has blueprint_outcome_id: str, blueprint_id: str, local_outcome_key: str, statement: str, level: str, confidence: str, evidence_json: str; has edited_by_lecturer: bool = False; has last_edited_at: str | None = None, last_edited_by: str | None = None; }
node BlueprintModule { has blueprint_module_id: str, blueprint_id: str, local_module_key: str, title: str, description: str; has order_index: int; has importance: str, concept_keys_json: str, learning_outcome_keys_json: str; has confidence: str, evidence_json: str, warnings_json: str; has estimated_learning_hours: float | None = None; has edited_by_lecturer: bool = False; has last_edited_at: str | None = None, last_edited_by: str | None = None; }
node BlueprintPrerequisite { has blueprint_prerequisite_id: str, blueprint_id: str, prerequisite_concept_key: str, dependent_concept_key: str, strength: str, rationale: str, confidence: str, evidence_json: str; has edited_by_lecturer: bool = False; has last_edited_at: str | None = None, last_edited_by: str | None = None; }
node BlueprintWarningNode { has blueprint_warning_id: str, blueprint_id: str, warning_type: str, message: str, severity: str, evidence_json: str; }
node BlueprintGenerationRun { has generation_run_id: str, track_version_id: str, chunk_set_id: str, status: str, current_step: str, generation_config_hash: str, started_at: str, updated_at: str; has blueprint_id: str | None = None, completed_at: str | None = None, error_code: str | None = None; }

enum CurriculumGraphGenerationStatus: str { NOT_STARTED = "NOT_STARTED", GENERATING = "GENERATING", GENERATED = "GENERATED", GENERATED_WITH_WARNINGS = "GENERATED_WITH_WARNINGS", FAILED = "FAILED", SUPERSEDED = "SUPERSEDED" }

node CurriculumGraphGenerationRun {
    has graph_generation_id: str, track_id: str, track_version_id: str, blueprint_id: str;
    has blueprint_schema_version: int, graph_schema_version: int;
    has status: CurriculumGraphGenerationStatus; has generation_number: int;
    has source_blueprint_hash: str, generation_config_hash: str, generation_identity: str;
    has created_at: str; has completed_at: str | None = None; has error_code: str | None = None;
    has module_count: int = 0; has skill_count: int = 0; has learning_outcome_count: int = 0; has prerequisite_count: int = 0;
    has warnings_json: str = "[]"; has is_active: bool = False;
}

node LearningOutcome {
    has learning_outcome_id: str, track_id: str, track_version_id: str, statement: str, level: str;
    has blueprint_id: str; has blueprint_outcome_key: str; has graph_generation_id: str; has created_at: str;
    has status: str = "DRAFT_INACTIVE"; has evidence_json: str = "[]";
}

node BlueprintDomainMapping {
    has mapping_id: str, blueprint_id: str, blueprint_local_key: str;
    has domain_entity_type: str, domain_entity_id: str, graph_generation_id: str, created_at: str;
}

obj BlueprintGraphIdMap { has blueprint_id: str; has concept_key_to_skill_id: dict[str, str] = {}; has module_key_to_module_id: dict[str, str] = {}; has outcome_key_to_outcome_id: dict[str, str] = {}; }
obj CurriculumGraphGenerationConfig { has graph_schema_version: int = 1; has include_medium_confidence_prerequisites: bool = True; has include_low_confidence_prerequisites: bool = False; has create_topic_compatibility_nodes: bool = False; has enforce_single_primary_module: bool = True; }
obj GraphGenerationContext { has track_id: str, track_version_id: str, blueprint_id: str, request_id: str; has actor_id: str | None = None; has graph_schema_version: int = 1; has force_regenerate: bool = False; has config: CurriculumGraphGenerationConfig = CurriculumGraphGenerationConfig(); }
obj GraphGenerationResult { has status: CurriculumGraphGenerationStatus; has module_count: int = 0, skill_count: int = 0, learning_outcome_count: int = 0, prerequisite_count: int = 0; has warnings: list[str] = []; has graph_generation_id: str | None = None; has error_code: str | None = None; has reused: bool = False; }
obj GraphRollbackResult { has succeeded: bool; has graph_generation_id: str; has removed_entity_count: int = 0; has error_code: str | None = None; }
obj CurriculumGraphIntegrityReport { has valid: bool; has module_count: int, skill_count: int, prerequisite_count: int; has orphan_skills: list[str] = [], duplicate_skills: list[str] = [], dangling_edges: list[str] = [], cycle_paths: list[str] = [], cross_version_edges: list[str] = [], missing_provenance: list[str] = [], warnings: list[str] = []; }
obj GraphPreviewModule { has module_key: str, title: str; has order_index: int; has skill_keys: list[str] = []; has evidence_count: int = 0; }
obj GraphPreviewSkill { has concept_key: str, canonical_name: str, concept_type: str; has module_key: str | None = None; has evidence_count: int = 0; }
obj GraphPreviewEdge { has prerequisite_key: str, dependent_key: str, strength: str, confidence: str; has evidence_count: int = 0; }
obj CurriculumGraphPreview { has modules: list[GraphPreviewModule] = []; has skills: list[GraphPreviewSkill] = []; has prerequisites: list[GraphPreviewEdge] = []; has warnings: list[str] = []; }

enum BlueprintValidationStatus: str { NOT_VALIDATED = "NOT_VALIDATED", VALIDATING = "VALIDATING", VALID = "VALID", VALID_WITH_WARNINGS = "VALID_WITH_WARNINGS", INVALID = "INVALID" }
enum BlueprintValidationSeverity: str { INFO = "INFO", WARNING = "WARNING", ERROR = "ERROR", CRITICAL = "CRITICAL" }
enum BlueprintValidationCategory: str { SCHEMA = "SCHEMA", REFERENCE = "REFERENCE", EVIDENCE = "EVIDENCE", GROUNDING = "GROUNDING", COVERAGE = "COVERAGE", DUPLICATE = "DUPLICATE", LEARNING_OUTCOME = "LEARNING_OUTCOME", MODULE_STRUCTURE = "MODULE_STRUCTURE", PREREQUISITE = "PREREQUISITE", GRAPH_INTEGRITY = "GRAPH_INTEGRITY", SOURCE_CONFLICT = "SOURCE_CONFLICT", AI_CRITIQUE = "AI_CRITIQUE" }
enum BlueprintRepairAction: str { NONE = "NONE", AUTO_RETRY_STAGE = "AUTO_RETRY_STAGE", REGENERATE_BLUEPRINT = "REGENERATE_BLUEPRINT", REGENERATE_GRAPH = "REGENERATE_GRAPH", LECTURER_REVIEW = "LECTURER_REVIEW", REPLACE_SOURCE_DOCUMENT = "REPLACE_SOURCE_DOCUMENT" }

node BlueprintValidationReport {
    has validation_report_id: str, blueprint_id: str, track_id: str, track_version_id: str;
    has status: BlueprintValidationStatus; has validation_schema_version: int; has validator_version: str;
    has validation_identity: str, blueprint_content_hash: str; has graph_generation_id: str | None;
    has created_at: str; has validated_at: str | None = None; has is_latest: bool = False;
    has source_coverage_ratio: float = 0.0, concept_coverage_ratio: float = 0.0, module_coverage_ratio: float = 0.0, grounding_ratio: float = 0.0;
    has warning_count: int = 0, error_count: int = 0, critical_count: int = 0;
    has grounded_concept_count: int = 0, unsupported_concept_count: int = 0;
    has eligible_for_review: bool = False, requires_regeneration: bool = False, requires_source_replacement: bool = False;
}

node BlueprintValidationIssue {
    has issue_id: str; has category: BlueprintValidationCategory; has severity: BlueprintValidationSeverity;
    has code: str, message: str; has repair_action: BlueprintRepairAction;
    has blueprint_entity_type: str | None = None, blueprint_entity_key: str | None = None;
    has evidence_chunk_ids_json: str = "[]"; has repairable: bool = False; has requires_lecturer_review: bool = False;
}

obj BlueprintValidationConfig { has min_source_chunk_coverage: float = 1.0; has min_concept_coverage: float = 0.95; has min_module_coverage: float = 1.0; has min_grounding_ratio: float = 0.90; has max_concepts_per_module: int = 30; has enable_critic_pass: bool = False; }
obj BlueprintValidationContext { has track_id: str, track_version_id: str, blueprint_id: str, request_id: str; has graph_generation_id: str | None = None; has actor_id: str | None = None; has validation_schema_version: int = 1; has force_revalidate: bool = False; has config: BlueprintValidationConfig = BlueprintValidationConfig(); }
obj BlueprintValidationResult { has validation_report_id: str; has status: BlueprintValidationStatus; has source_coverage_ratio: float = 0.0, concept_coverage_ratio: float = 0.0, module_coverage_ratio: float = 0.0, grounding_ratio: float = 0.0; has issue_count: int = 0, warning_count: int = 0, error_count: int = 0, critical_count: int = 0; has eligible_for_review: bool = False, requires_regeneration: bool = False, requires_source_replacement: bool = False, reused: bool = False; has error_code: str | None = None; }
obj BlueprintReviewEligibility { has eligible: bool; has validation_status: BlueprintValidationStatus; has blocking_issue_codes: list[str] = []; has warning_codes: list[str] = []; has requires_regeneration: bool = False, requires_source_replacement: bool = False; }
obj PrerequisiteCycleResult { has has_cycle: bool; has cycle_paths: list[list[str]] = []; }
node ChunkAnalysisArtifact { has analysis_id: str, chunk_set_id: str, chunk_ids_json: str, input_hash: str; has prompt_version: int, contract_schema_version: int; has result_json: str, created_at: str; has ai_execution_id: str | None = None; }
node MergedConceptArtifact { has artifact_id: str, generation_run_id: str, input_hash: str, result_json: str, created_at: str; }

obj BlueprintGenerationConfig { has schema_version: int, chunk_analysis_batch_size: int, max_input_tokens_per_call: int, max_parallel_chunk_calls: int; has min_source_coverage_ratio: float; has max_concepts: int, max_modules: int, max_prerequisites: int; has prompt_versions_json: str; has enable_critic_pass: bool = True; }
obj BlueprintAnalysisUnit { has unit_id: str; has chunk_ids: list[str]; has total_estimated_tokens: int, start_order_index: int, end_order_index: int; has heading_context: list[str]; }
obj ConceptExclusion { has source_candidate_id: str, reason: str, warning_type: str; }
enum OutcomeProvenanceType: str { LECTURER_DECLARED = "LECTURER_DECLARED", SOURCE_EXPLICIT = "SOURCE_EXPLICIT", CONCEPT_DERIVED = "CONCEPT_DERIVED" }
obj BlueprintGenerationContext { has track_id: str, track_version_id: str, document_id: str, chunk_set_id: str, request_id: str; has actor_id: str | None; has config: BlueprintGenerationConfig; has force_regenerate: bool = False; }
obj BlueprintGenerationResult { has status: BlueprintGenerationStatus; has concept_count: int, module_count: int, outcome_count: int, prerequisite_count: int; has source_coverage_ratio: float; has warnings: list[str]; has blueprint_id: str | None = None, confidence: str | None = None, error_code: str | None = None; }
obj BlueprintGenerationStatusView { has status: BlueprintGenerationStatus; has current_step: str; has progress_percent: int, warning_count: int; has retry_available: bool; has blueprint_id: str | None = None, error_code: str | None = None, user_message: str | None = None; }

# Feature 49: lecturer blueprint review and immutable approval history.
enum BlueprintReviewStatus: str { NOT_READY = "NOT_READY", READY_FOR_REVIEW = "READY_FOR_REVIEW", IN_REVIEW = "IN_REVIEW", CHANGES_REQUIRED = "CHANGES_REQUIRED", APPROVED = "APPROVED", SUPERSEDED = "SUPERSEDED" }
enum BlueprintApprovalStatus: str { NOT_APPROVED = "NOT_APPROVED", APPROVED = "APPROVED", REVOKED = "REVOKED" }
enum BlueprintReviewChangeType: str { UPDATE_FIELD = "UPDATE_FIELD", ADD_ENTITY = "ADD_ENTITY", REMOVE_ENTITY = "REMOVE_ENTITY", REORDER_ENTITY = "REORDER_ENTITY", ADD_RELATIONSHIP = "ADD_RELATIONSHIP", REMOVE_RELATIONSHIP = "REMOVE_RELATIONSHIP", REGENERATE_SECTION = "REGENERATE_SECTION", RESTORE_AI_VERSION = "RESTORE_AI_VERSION" }
enum BlueprintRegenerationStrategy: str { KEEP_MANUAL = "KEEP_MANUAL", REGENERATE_SELECTED = "REGENERATE_SELECTED", REGENERATE_ALL_UNEDITED = "REGENERATE_ALL_UNEDITED", REGENERATE_FULL_BLUEPRINT = "REGENERATE_FULL_BLUEPRINT" }
enum ReviewIssueResolutionStatus: str { OPEN = "OPEN", ACKNOWLEDGED = "ACKNOWLEDGED", RESOLVED = "RESOLVED", WAIVED = "WAIVED" }

node BlueprintReviewSession { has review_session_id: str, blueprint_id: str, track_id: str, track_version_id: str, lecturer_id: str; has status: BlueprintReviewStatus; has blueprint_revision: int; has started_at: str, updated_at: str; has approved_at: str | None = None, approved_by: str | None = None, last_validation_report_id: str | None = None, review_notes: str | None = None; }
node BlueprintReviewChange { has change_id: str, review_session_id: str, blueprint_id: str, actor_id: str, entity_type: str, entity_key: str, field_name: str, old_value_json: str, new_value_json: str, change_type: str, created_at: str; has revision: int = 0; has idempotency_key: str | None = None; }
node BlueprintIssueResolution { has resolution_id: str, validation_issue_id: str, review_session_id: str; has status: ReviewIssueResolutionStatus; has resolved_by: str, created_at: str; has resolution_note: str | None = None; }
node BlueprintApproval { has approval_id: str, blueprint_id: str, track_version_id: str; has approved_revision: int, approved_by: str, approved_at: str, validation_report_id: str, graph_generation_id: str; has approval_note: str | None = None; has status: BlueprintApprovalStatus = BlueprintApprovalStatus.APPROVED; }

obj BlueprintEvidenceRef { has chunk_id: str = ""; has page_start: int | None = None, page_end: int | None = None; has heading: str | None = None; has excerpt: str = ""; has strength: str = ""; }
obj ReviewModuleView { has module_id: str, local_module_key: str, title: str, description: str; has order_index: int; has concept_keys: list[str], outcome_keys: list[str], evidence: list[BlueprintEvidenceRef]; has confidence: str; has validation_issues: list[str]; has edited_by_lecturer: bool; }
obj ReviewConceptView { has concept_id: str, local_concept_key: str, canonical_name: str, description: str; has aliases: list[str], key_terms: list[str], learning_objectives: list[str], evidence: list[BlueprintEvidenceRef]; has confidence: str; has validation_issues: list[str]; has edited_by_lecturer: bool; }
obj ReviewOutcomeView { has outcome_id: str, local_outcome_key: str, statement: str, level: str; has evidence: list[BlueprintEvidenceRef], validation_issues: list[str]; has edited_by_lecturer: bool; }
obj ReviewPrerequisiteView { has prerequisite_id: str, prerequisite_concept_key: str, dependent_concept_key: str, strength: str, rationale: str, confidence: str; has evidence: list[BlueprintEvidenceRef], validation_issues: list[str]; has edited_by_lecturer: bool; }
obj ReviewValidationSummary { has status: str; has source_coverage_ratio: float, concept_coverage_ratio: float, module_coverage_ratio: float, grounding_ratio: float; has warning_count: int, blocking_issue_count: int; has blocking_issue_codes: list[str]; }
obj LecturerBlueprintReviewView { has blueprint_id: str; has review_status: BlueprintReviewStatus; has blueprint_revision: int; has course_title: str, course_summary: str; has modules: list[ReviewModuleView], concepts: list[ReviewConceptView], outcomes: list[ReviewOutcomeView], prerequisites: list[ReviewPrerequisiteView]; has validation_summary: ReviewValidationSummary; has approval_available: bool; has warnings: list[str]; has review_session_id: str = ""; }
obj BlueprintEntityPatchRequest { has blueprint_id: str; has expected_revision: int; has entity_type: str; has entity_key: str; has patch_json: str; has reason: str | None = None; has idempotency_key: str | None = None; }
obj BlueprintApprovalRequest { has blueprint_id: str; has expected_revision: int; has approval_note: str | None = None; }

node CoursePublication { has publication_id: str, track_id: str, track_version_id: str; has version_number: int; has blueprint_id: str; has blueprint_revision: int; has approval_id: str, validation_report_id: str, graph_generation_id: str; has source_document_id: str, source_checksum_sha256: str, chunk_set_id: str, extraction_id: str; has published_by: str, published_at: str, publication_status: str, publication_hash: str; has idempotency_key: str; has release_notes: str | None = None; }
node CoursePublicationEvent { has event_id: str, track_id: str, track_version_id: str, event_type: str, actor_id: str, created_at: str; has from_version_id: str | None = None, to_version_id: str | None = None, reason: str | None = None; }
obj PublicationReadinessResult { has ready: bool; has track_id: str, track_version_id: str; has blocking_codes: list[str], warnings: list[str]; has blueprint_id: str | None = None, approval_id: str | None = None, validation_report_id: str | None = None, graph_generation_id: str | None = None; has blueprint_revision: int | None = None; has expected_version_number: int | None = None; has version_number: int | None = None; has module_count: int = 0, skill_count: int = 0, outcome_count: int = 0; has validation_status: str = "NOT_VALIDATED", approval_status: str = "NOT_APPROVED"; }
obj PublishCourseVersionRequest { has track_id: str, track_version_id: str; has expected_revision: int; has idempotency_key: str; has publish_note: str | None = None; }
obj CoursePublicationResult { has track_id: str, track_version_id: str; has status: str; has warnings: list[str]; has publication_id: str | None = None; has version_number: int | None = None; has active_version_id: str | None = None, previous_active_version_id: str | None = None, error_code: str | None = None; }
obj RollbackPublicationRequest { has track_id: str, target_track_version_id: str, reason: str, idempotency_key: str; }
obj CreateDraftVersionRequest { has track_id: str; has idempotency_key: str; has base_version_id: str | None = None; has clone_curriculum: bool = True; }
obj DraftVersionResult { has track_version_id: str; has status: str; has version_number_hint: int | None = None; has base_version_id: str | None = None; has error_code: str | None = None; }
obj PublicationHistoryItem { has publication_id: str, track_version_id: str; has version_number: int; has status: str, published_at: str, published_by: str; has release_notes: str | None = None; }
obj PublicationStateAudit { has valid: bool; has issues: list[str]; has active_version_id: str | None = None; has published_version_count: int = 0; }

# Feature 50.5: one server-owned projection for the complete lecturer build lifecycle.
enum CourseBuildStage: str { COURSE_SETUP = "COURSE_SETUP", SOURCE_REQUIRED = "SOURCE_REQUIRED", SOURCE_PROCESSING = "SOURCE_PROCESSING", SOURCE_FAILED = "SOURCE_FAILED", READY_FOR_GENERATION = "READY_FOR_GENERATION", GENERATING_BLUEPRINT = "GENERATING_BLUEPRINT", GENERATION_FAILED = "GENERATION_FAILED", VALIDATING_BLUEPRINT = "VALIDATING_BLUEPRINT", READY_FOR_REVIEW = "READY_FOR_REVIEW", REVIEW_IN_PROGRESS = "REVIEW_IN_PROGRESS", CHANGES_REQUIRED = "CHANGES_REQUIRED", APPROVED = "APPROVED", PUBLICATION_BLOCKED = "PUBLICATION_BLOCKED", READY_TO_PUBLISH = "READY_TO_PUBLISH", PUBLISHING = "PUBLISHING", PUBLISHED = "PUBLISHED", SUPERSEDED = "SUPERSEDED" }
enum CourseBuildAction: str { COMPLETE_SETUP = "COMPLETE_SETUP", UPLOAD_SOURCE = "UPLOAD_SOURCE", WAIT_FOR_SOURCE = "WAIT_FOR_SOURCE", RETRY_SOURCE = "RETRY_SOURCE", GENERATE_BLUEPRINT = "GENERATE_BLUEPRINT", WAIT_FOR_GENERATION = "WAIT_FOR_GENERATION", RETRY_GENERATION = "RETRY_GENERATION", REVIEW_BLUEPRINT = "REVIEW_BLUEPRINT", RESOLVE_REVIEW_ISSUES = "RESOLVE_REVIEW_ISSUES", APPROVE_BLUEPRINT = "APPROVE_BLUEPRINT", REVIEW_PUBLICATION_READINESS = "REVIEW_PUBLICATION_READINESS", PUBLISH_VERSION = "PUBLISH_VERSION", VIEW_PUBLISHED_VERSION = "VIEW_PUBLISHED_VERSION", CREATE_NEW_VERSION = "CREATE_NEW_VERSION", NONE = "NONE" }
obj CourseBuildBlocker { has code: str; has stage: CourseBuildStage; has message: str; has remediation_action: CourseBuildAction; has retryable: bool = False; }
obj CourseBuildReviewSummary { has status: str; has revision: int; has validation_status: str; has warning_count: int; has blocking_issue_count: int; has approval_available: bool; has approved_revision: int | None = None; }
obj CourseBuildWorkflowView { has track_id: str, track_version_id: str; has course_status: str, version_status: str; has active_version_id: str | None; has version_number: int; has current_stage: CourseBuildStage; has stage_label: str; has progress_percent: int; has next_action: CourseBuildAction; has source: CourseSourceWorkspaceView; has blueprint: BlueprintGenerationStatusView; has review: CourseBuildReviewSummary | None = None; has publication: PublicationReadinessResult | None = None; has blockers: list[CourseBuildBlocker] = []; has warnings: list[str] = []; has can_generate: bool = False, can_review: bool = False, can_approve: bool = False, can_publish: bool = False, can_create_new_version: bool = False; has updated_at: str = ""; }
obj LearnerIntegrationHandoffView { has ready: bool; has track_id: str; has track_version_id: str | None; has version_number: int | None; has publication_id: str | None; has title: str; has short_description: str; has course_code: str | None; has subject_area: str | None; has academic_level: str | None; has visibility: str; has enrollment_open: bool; has module_count: int; has skill_count: int; has outcome_count: int; has blocking_codes: list[str] = []; }
