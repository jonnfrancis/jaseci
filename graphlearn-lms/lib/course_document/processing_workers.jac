"""Trusted stage-worker adapters over validation, extraction, and chunking services."""
import from lib.course_document.chunking_service { DocumentContentChunkingService }
import from lib.course_document.chunk_repository { DocumentChunkRepository }
import from lib.course_document.extraction_repository { DocumentExtractionRepository }
import from lib.course_document.extraction_service { DocumentTextExtractionService }
import from lib.course_document.processing_service { DocumentProcessingOrchestrator }
import from lib.course_document.validation_service { DocumentSecurityValidationService }
import from lib.course_blueprint.generation_service { CourseBlueprintGenerationService }
import from lib.course_blueprint.planner { default_blueprint_generation_config }
import from lib.blueprint_validation.application_services { execute_blueprint_validation_job }
import from nodes.curriculum { BlueprintGenerationContext, BlueprintGenerationStatus, ChunkingConfig, ChunkingRequestContext, CourseDocument, DocumentChunkingStatus, DocumentExtractionStatus, DocumentProcessingJob, DocumentProcessingStage, DocumentValidationContext, DocumentValidationStatus, ExtractionRequestContext, ProcessingWorkerContext, StageExecutionResult, StageReconciliationResult }

obj ProcessingStageWorker {
    def stage -> DocumentProcessingStage { return DocumentProcessingStage.STORAGE; }
    def execute(job: DocumentProcessingJob, document: CourseDocument, context: ProcessingWorkerContext) -> StageExecutionResult { _ = job; _ = document; _ = context; return StageExecutionResult(succeeded=False, retryable=False, error_code="DOCUMENT_PROCESSING_STAGE_NOT_IMPLEMENTED"); }
    def reconcile(job: DocumentProcessingJob, document: CourseDocument) -> StageReconciliationResult { return StageReconciliationResult(completed=DocumentProcessingOrchestrator().artifact_satisfies(document, job.stage)); }
}

obj SecurityValidationWorker(ProcessingStageWorker) {
    def stage -> DocumentProcessingStage { return DocumentProcessingStage.SECURITY_VALIDATION; }
    def execute(job: DocumentProcessingJob, document: CourseDocument, context: ProcessingWorkerContext) -> StageExecutionResult { result = DocumentSecurityValidationService().validate_document(document.document_id, DocumentValidationContext(document_id=document.document_id, track_id=document.track_id, track_version_id=document.track_version_id, request_id=context.request_id, actor_id="processing-worker:" + context.worker_id)); if result.status == DocumentValidationStatus.VALIDATED { return StageExecutionResult(succeeded=True, retryable=False, artifact_id=document.document_id); } retryable = result.status == DocumentValidationStatus.VALIDATION_FAILED and result.error_code in ["DOCUMENT_VALIDATION_INTERNAL_ERROR", "DOCUMENT_MALWARE_SCANNER_UNAVAILABLE", "DOCUMENT_VALIDATION_TIMEOUT"]; return StageExecutionResult(succeeded=False, retryable=retryable, error_code=result.error_code or "DOCUMENT_VALIDATION_FAILED", error_message=result.user_message or "Document validation failed."); }
}

obj TextExtractionWorker(ProcessingStageWorker) {
    def stage -> DocumentProcessingStage { return DocumentProcessingStage.TEXT_EXTRACTION; }
    def execute(job: DocumentProcessingJob, document: CourseDocument, context: ProcessingWorkerContext) -> StageExecutionResult { result = DocumentTextExtractionService().extract_document(document.document_id, ExtractionRequestContext(document_id=document.document_id, track_id=document.track_id, track_version_id=document.track_version_id, request_id=context.request_id, actor_id="processing-worker:" + context.worker_id)); if result.status == DocumentExtractionStatus.EXTRACTED { return StageExecutionResult(succeeded=True, retryable=False, artifact_id=result.extraction_id, warnings=result.warnings); } retryable = result.error_code in ["DOCUMENT_EXTRACTION_PDF_FAILED", "DOCUMENT_EXTRACTION_DOCX_FAILED", "DOCUMENT_EXTRACTION_PERSIST_FAILED", "DOCUMENT_EXTRACTION_INTERNAL_ERROR"]; return StageExecutionResult(succeeded=False, retryable=retryable, error_code=result.error_code or "DOCUMENT_EXTRACTION_FAILED", error_message=result.user_message or "Text extraction failed.", warnings=result.warnings); }
}

obj ContentChunkingWorker(ProcessingStageWorker) {
    def stage -> DocumentProcessingStage { return DocumentProcessingStage.CONTENT_CHUNKING; }
    def execute(job: DocumentProcessingJob, document: CourseDocument, context: ProcessingWorkerContext) -> StageExecutionResult { extraction = DocumentExtractionRepository().find_active_for_document(document); if extraction is None { return StageExecutionResult(succeeded=False, retryable=False, error_code="DOCUMENT_NOT_EXTRACTED", error_message="Text extraction is not ready."); } result = DocumentContentChunkingService().chunk_document(document.document_id, ChunkingRequestContext(document_id=document.document_id, track_id=document.track_id, track_version_id=document.track_version_id, extraction_id=extraction.extraction_id, request_id=context.request_id, actor_id="processing-worker:" + context.worker_id, config=ChunkingConfig())); if result.status == DocumentChunkingStatus.CHUNKED { return StageExecutionResult(succeeded=True, retryable=False, artifact_id=extraction.extraction_id, warnings=result.warnings); } retryable = result.error_code in ["DOCUMENT_CHUNK_PERSIST_FAILED", "DOCUMENT_CHUNKING_INTERNAL_ERROR"]; return StageExecutionResult(succeeded=False, retryable=retryable, error_code=result.error_code or "DOCUMENT_CHUNKING_FAILED", error_message="Course section preparation failed.", warnings=result.warnings); }
}

obj BlueprintGenerationWorker(ProcessingStageWorker) {
    def stage -> DocumentProcessingStage { return DocumentProcessingStage.BLUEPRINT_GENERATION; }
    def execute(job: DocumentProcessingJob, document: CourseDocument, context: ProcessingWorkerContext) -> StageExecutionResult { extraction = DocumentExtractionRepository().find_active_for_document(document); if extraction is None { return StageExecutionResult(succeeded=False, retryable=False, error_code="BLUEPRINT_SOURCE_NOT_READY"); } chunk_set = DocumentProcessingOrchestrator().artifact_satisfies(document, DocumentProcessingStage.CONTENT_CHUNKING); if not chunk_set { return StageExecutionResult(succeeded=False, retryable=False, error_code="BLUEPRINT_CHUNK_SET_INVALID"); } active_set = DocumentChunkRepository().find_active_chunk_set(extraction); if active_set is None { return StageExecutionResult(succeeded=False, retryable=False, error_code="BLUEPRINT_CHUNK_SET_INVALID"); } result = CourseBlueprintGenerationService().execute_generation(BlueprintGenerationContext(track_id=document.track_id, track_version_id=document.track_version_id, document_id=document.document_id, chunk_set_id=active_set.chunk_set_id, request_id=context.request_id, actor_id="processing-worker:" + context.worker_id, config=default_blueprint_generation_config())); return StageExecutionResult(succeeded=result.status == BlueprintGenerationStatus.GENERATED, retryable=result.error_code in ["BYLLM_BLUEPRINT_PROVIDER_UNAVAILABLE", "BYLLM_BLUEPRINT_TIMEOUT", "BYLLM_BLUEPRINT_RATE_LIMITED", "BYLLM_BLUEPRINT_OUTPUT_INVALID", "BLUEPRINT_GENERATION_INTERNAL_ERROR"], error_code=result.error_code, error_message=None if result.status == BlueprintGenerationStatus.GENERATED else "We could not generate a reliable course structure from these notes.", artifact_id=result.blueprint_id, warnings=result.warnings); }
}

obj DocumentProcessingWorkerService {
    has orchestrator: DocumentProcessingOrchestrator = DocumentProcessingOrchestrator();
    def worker_for(stage: DocumentProcessingStage) -> ProcessingStageWorker { if stage == DocumentProcessingStage.SECURITY_VALIDATION { return SecurityValidationWorker(); } if stage == DocumentProcessingStage.TEXT_EXTRACTION { return TextExtractionWorker(); } if stage == DocumentProcessingStage.CONTENT_CHUNKING { return ContentChunkingWorker(); } if stage == DocumentProcessingStage.BLUEPRINT_GENERATION { return BlueprintGenerationWorker(); } return ProcessingStageWorker(); }
    def run_next(document: CourseDocument, worker_id: str, request_id: str = "") -> bool { job = self.orchestrator.claim_job(document, worker_id); if job is None { return False; } attempts = self.orchestrator.repository.list_stage_attempts(job); if len(attempts) == 0 { return False; } context = ProcessingWorkerContext(worker_id=worker_id, job_id=job.job_id, attempt_id=attempts[len(attempts) - 1].attempt_id, request_id=request_id); result = self.worker_for(job.stage).execute(job, document, context); if result.succeeded { return self.orchestrator.complete_job(document, job, worker_id, result.artifact_id); } return self.orchestrator.fail_job(document, job, worker_id, result.error_code or "DOCUMENT_PROCESSING_FAILED", result.error_message or "Document processing failed.", result.retryable); }
    def run_stage(document: CourseDocument, stage: DocumentProcessingStage, worker_id: str, request_id: str = "") -> bool { job = self.orchestrator.claim_stage_job(document, stage, worker_id); if job is None { return False; } attempts = self.orchestrator.repository.list_stage_attempts(job); if len(attempts) == 0 { return False; } context = ProcessingWorkerContext(worker_id=worker_id, job_id=job.job_id, attempt_id=attempts[len(attempts) - 1].attempt_id, request_id=request_id); result = self.worker_for(job.stage).execute(job, document, context); if result.succeeded { return self.orchestrator.complete_job(document, job, worker_id, result.artifact_id); } return self.orchestrator.fail_job(document, job, worker_id, result.error_code or "DOCUMENT_PROCESSING_FAILED", result.error_message or "Document processing failed.", result.retryable); }
    def run_blueprint_validation(document: CourseDocument, worker_id: str) -> bool {
        # First reconcile jobs that were left retrying or running by an interrupted
        # request, then claim a normal queued validation job.
        _ = self.orchestrator.recover_stale_jobs(document);
        _ = self.orchestrator.queue_due_retries(document);
        job = self.orchestrator.claim_stage_job(document, DocumentProcessingStage.BLUEPRINT_VALIDATION, worker_id);
        if job is None and self.orchestrator.artifact_satisfies(document, DocumentProcessingStage.BLUEPRINT_GENERATION) and self.orchestrator.repository.find_active_by_stage(document, DocumentProcessingStage.BLUEPRINT_VALIDATION) is None {
            latest = self.orchestrator.repository.latest_by_stage(document, DocumentProcessingStage.BLUEPRINT_VALIDATION);
            fingerprint = "validation-recovery|" + (latest.job_id if latest is not None else document.document_id);
            _ = self.orchestrator.start_stage(document, DocumentProcessingStage.BLUEPRINT_VALIDATION, fingerprint);
            job = self.orchestrator.claim_stage_job(document, DocumentProcessingStage.BLUEPRINT_VALIDATION, worker_id);
        }
        if job is None { return False; }
        result = execute_blueprint_validation_job(document, job, worker_id);
        return result.eligible_for_review;
    }
}
