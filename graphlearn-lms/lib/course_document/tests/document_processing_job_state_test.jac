"""Feature 44 durable state-machine, dependency, lease, retry, cancellation, and recovery tests."""
import from uuid { uuid4 }
import from lib.course_document.processing_job_repository { DocumentProcessingJobRepository, valid_job_transition }
import from lib.course_document.processing_service { DocumentProcessingDependencyService, DocumentProcessingOrchestrator, processing_time_after }
import from nodes.curriculum { CourseDocument, CourseDocumentProcessingStatus, CourseDocumentUploadStatus, DocumentProcessingJob, DocumentProcessingStage, DocumentProcessingState, DocumentValidationStatus, ProcessingJobStatus }

def _document(suffix: str) -> CourseDocument { document = CourseDocument(document_id="job_doc_" + suffix, track_id="job_track_" + suffix, track_version_id="job_version_" + suffix, original_filename="notes.pdf", normalized_filename="notes.pdf", mime_type="application/pdf", file_extension="pdf", file_size_bytes=100, storage_provider="test", storage_key="test/notes.pdf", checksum_algorithm="sha256", checksum="checksum_" + suffix, upload_status=CourseDocumentUploadStatus.STORED, processing_status=CourseDocumentProcessingStatus.NOT_STARTED, uploaded_by="lecturer", uploaded_at="2026-01-01T00:00:00+00:00", updated_at="2026-01-01T00:00:00+00:00", idempotency_scope="scope_" + suffix); root ++> document; return document; }

test "valid job transitions are explicit and terminal states cannot restart" {
    assert valid_job_transition(ProcessingJobStatus.PENDING, ProcessingJobStatus.QUEUED);
    assert valid_job_transition(ProcessingJobStatus.QUEUED, ProcessingJobStatus.RUNNING);
    assert valid_job_transition(ProcessingJobStatus.RUNNING, ProcessingJobStatus.SUCCEEDED);
    assert not valid_job_transition(ProcessingJobStatus.SUCCEEDED, ProcessingJobStatus.RUNNING);
    assert not valid_job_transition(ProcessingJobStatus.CANCELLED, ProcessingJobStatus.QUEUED);
}

test "dependencies prevent extraction and chunking stage jumps" {
    document = _document(uuid4().hex); service = DocumentProcessingDependencyService();
    assert service.can_start_stage(document, DocumentProcessingStage.SECURITY_VALIDATION).eligible;
    assert not service.can_start_stage(document, DocumentProcessingStage.TEXT_EXTRACTION).eligible;
    assert not service.can_start_stage(document, DocumentProcessingStage.CONTENT_CHUNKING).eligible;
    document.validation_status = DocumentValidationStatus.VALIDATED;
    assert service.can_start_stage(document, DocumentProcessingStage.TEXT_EXTRACTION).eligible;
}

test "duplicate pipeline start reuses one equivalent durable job" {
    document = _document(uuid4().hex); orchestrator = DocumentProcessingOrchestrator();
    first = orchestrator.start_pipeline(document).summary; second = orchestrator.start_pipeline(document).summary;
    jobs = DocumentProcessingJobRepository().list_jobs_for_document(document);
    assert len(jobs) == 1 and jobs[0].stage == DocumentProcessingStage.SECURITY_VALIDATION;
    assert first.document_id == second.document_id and first.state == DocumentProcessingState.VALIDATION_PENDING;
}

test "worker lease allows one claim and rejects wrong heartbeat owner" {
    document = _document(uuid4().hex); orchestrator = DocumentProcessingOrchestrator(); _ = orchestrator.start_pipeline(document);
    winner = orchestrator.claim_job(document, "worker-a"); loser = orchestrator.claim_job(document, "worker-b");
    assert winner is not None and loser is None and (winner as DocumentProcessingJob).attempt_number == 1;
    assert not orchestrator.heartbeat(winner as DocumentProcessingJob, "worker-b", 40);
    assert orchestrator.heartbeat(winner as DocumentProcessingJob, "worker-a", 40) and (winner as DocumentProcessingJob).progress_percent == 40;
    assert len(DocumentProcessingJobRepository().list_stage_attempts(winner as DocumentProcessingJob)) == 1;
}

test "retry is bounded and queued when due" {
    document = _document(uuid4().hex); orchestrator = DocumentProcessingOrchestrator(); _ = orchestrator.start_pipeline(document); job = orchestrator.claim_job(document, "worker-retry"); assert job is not None;
    assert orchestrator.fail_job(document, job as DocumentProcessingJob, "worker-retry", "TEMPORARY_SCANNER_ERROR", "Validation service is temporarily unavailable.", True);
    assert (job as DocumentProcessingJob).status == ProcessingJobStatus.RETRY_WAIT and (job as DocumentProcessingJob).attempt_number == 1;
    (job as DocumentProcessingJob).next_retry_at = "2000-01-01T00:00:00+00:00";
    assert orchestrator.queue_due_retries(document) == 1 and (job as DocumentProcessingJob).status == ProcessingJobStatus.QUEUED;
}

test "queued cancellation is terminal and prevents downstream work" {
    document = _document(uuid4().hex); orchestrator = DocumentProcessingOrchestrator(); _ = orchestrator.start_pipeline(document);
    assert orchestrator.request_cancel(document, "LECTURER_CANCELLED") == 1;
    jobs = DocumentProcessingJobRepository().list_jobs_for_document(document);
    assert jobs[0].status == ProcessingJobStatus.CANCELLED and orchestrator.projection.project(document).summary.state == DocumentProcessingState.CANCELLED;
}

test "expired lease becomes stale and is safely requeued" {
    document = _document(uuid4().hex); orchestrator = DocumentProcessingOrchestrator(); _ = orchestrator.start_pipeline(document); job = orchestrator.claim_job(document, "crashed-worker"); assert job is not None;
    (job as DocumentProcessingJob).lease_expires_at = "2000-01-01T00:00:00+00:00";
    assert orchestrator.recover_stale_jobs(document) == 1 and (job as DocumentProcessingJob).status == ProcessingJobStatus.QUEUED;
}

test "durable validation artifact reconciles without re-execution" {
    document = _document(uuid4().hex); orchestrator = DocumentProcessingOrchestrator(); _ = orchestrator.start_pipeline(document); document.validation_status = DocumentValidationStatus.VALIDATED;
    assert orchestrator.reconcile_completed_artifacts(document) == 1;
    jobs = DocumentProcessingJobRepository().list_jobs_for_document(document);
    assert jobs[0].status == ProcessingJobStatus.SUCCEEDED and len(jobs) == 2 and jobs[1].stage == DocumentProcessingStage.TEXT_EXTRACTION;
}
