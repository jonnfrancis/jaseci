"""Trusted stage-worker adapters over validation, extraction, and chunking services."""
import from lib.course_document.chunking_service { DocumentContentChunkingService }
import from lib.course_document.extraction_repository { DocumentExtractionRepository }
import from lib.course_document.extraction_service { DocumentTextExtractionService }
import from lib.course_document.processing_service { DocumentProcessingOrchestrator }
import from lib.course_document.validation_service { DocumentSecurityValidationService }
import from nodes.curriculum { ChunkingConfig, ChunkingRequestContext, CourseDocument, DocumentChunkingStatus, DocumentExtractionStatus, DocumentProcessingJob, DocumentProcessingStage, DocumentValidationContext, DocumentValidationStatus, ExtractionRequestContext, ProcessingWorkerContext, StageExecutionResult, StageReconciliationResult }

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

obj DocumentProcessingWorkerService {
    has orchestrator: DocumentProcessingOrchestrator = DocumentProcessingOrchestrator();
    def worker_for(stage: DocumentProcessingStage) -> ProcessingStageWorker { if stage == DocumentProcessingStage.SECURITY_VALIDATION { return SecurityValidationWorker(); } if stage == DocumentProcessingStage.TEXT_EXTRACTION { return TextExtractionWorker(); } if stage == DocumentProcessingStage.CONTENT_CHUNKING { return ContentChunkingWorker(); } return ProcessingStageWorker(); }
    def run_next(document: CourseDocument, worker_id: str, request_id: str = "") -> bool { job = self.orchestrator.claim_job(document, worker_id); if job is None { return False; } attempts = self.orchestrator.repository.list_stage_attempts(job); if len(attempts) == 0 { return False; } context = ProcessingWorkerContext(worker_id=worker_id, job_id=job.job_id, attempt_id=attempts[len(attempts) - 1].attempt_id, request_id=request_id); result = self.worker_for(job.stage).execute(job, document, context); if result.succeeded { return self.orchestrator.complete_job(document, job, worker_id, result.artifact_id); } return self.orchestrator.fail_job(document, job, worker_id, result.error_code or "DOCUMENT_PROCESSING_FAILED", result.error_message or "Document processing failed.", result.retryable); }
}
