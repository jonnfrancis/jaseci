"""Durable graph repository and centralized processing-job state machine."""
import from edges.domain_edges { HAS_JOB_ATTEMPT, HAS_PROCESSING_JOB }
import from nodes.curriculum { CourseDocument, DocumentProcessingJob, DocumentProcessingStage, ProcessingJobAttempt, ProcessingJobStatus }

glob ACTIVE_JOB_STATUSES: list[ProcessingJobStatus] = [ProcessingJobStatus.PENDING, ProcessingJobStatus.QUEUED, ProcessingJobStatus.RUNNING, ProcessingJobStatus.RETRY_WAIT, ProcessingJobStatus.CANCEL_REQUESTED, ProcessingJobStatus.STALE];

def valid_job_transition(old: ProcessingJobStatus, new: ProcessingJobStatus) -> bool {
    if old == ProcessingJobStatus.PENDING { return new in [ProcessingJobStatus.QUEUED, ProcessingJobStatus.CANCELLED]; }
    if old == ProcessingJobStatus.QUEUED { return new in [ProcessingJobStatus.RUNNING, ProcessingJobStatus.CANCELLED, ProcessingJobStatus.BLOCKED]; }
    if old == ProcessingJobStatus.RUNNING { return new in [ProcessingJobStatus.SUCCEEDED, ProcessingJobStatus.FAILED, ProcessingJobStatus.RETRY_WAIT, ProcessingJobStatus.CANCEL_REQUESTED, ProcessingJobStatus.STALE]; }
    if old == ProcessingJobStatus.RETRY_WAIT { return new in [ProcessingJobStatus.QUEUED, ProcessingJobStatus.CANCELLED, ProcessingJobStatus.FAILED]; }
    if old == ProcessingJobStatus.CANCEL_REQUESTED { return new in [ProcessingJobStatus.CANCELLED, ProcessingJobStatus.SUCCEEDED]; }
    if old == ProcessingJobStatus.STALE { return new in [ProcessingJobStatus.QUEUED, ProcessingJobStatus.FAILED, ProcessingJobStatus.SUCCEEDED]; }
    if old == ProcessingJobStatus.BLOCKED { return new in [ProcessingJobStatus.QUEUED, ProcessingJobStatus.CANCELLED]; }
    return False;
}

obj DocumentProcessingJobRepository {
    def list_jobs_for_document(document: CourseDocument) -> list[DocumentProcessingJob] { jobs: list[DocumentProcessingJob] = [document ->:HAS_PROCESSING_JOB:->[?:DocumentProcessingJob]]; return sorted(jobs, key=lambda item: DocumentProcessingJob : item.created_at); }
    def find_by_id(document: CourseDocument, job_id: str) -> DocumentProcessingJob | None { for job in self.list_jobs_for_document(document) { if job.job_id == job_id { return job; } } return None; }
    def find_matching_idempotency_key(document: CourseDocument, key: str) -> DocumentProcessingJob | None { for job in self.list_jobs_for_document(document) { if job.idempotency_key == key { return job; } } return None; }
    def find_active_by_stage(document: CourseDocument, stage: DocumentProcessingStage) -> DocumentProcessingJob | None { jobs = self.list_jobs_for_document(document); for index in range(len(jobs) - 1, -1, -1) { if jobs[index].stage == stage and jobs[index].status in ACTIVE_JOB_STATUSES { return jobs[index]; } } return None; }
    def latest_by_stage(document: CourseDocument, stage: DocumentProcessingStage) -> DocumentProcessingJob | None { jobs = self.list_jobs_for_document(document); for index in range(len(jobs) - 1, -1, -1) { if jobs[index].stage == stage { return jobs[index]; } } return None; }
    def list_stage_attempts(job: DocumentProcessingJob) -> list[ProcessingJobAttempt] { attempts: list[ProcessingJobAttempt] = [job ->:HAS_JOB_ATTEMPT:->[?:ProcessingJobAttempt]]; return sorted(attempts, key=lambda item: ProcessingJobAttempt : item.attempt_number); }
    def save_job(document: CourseDocument, job: DocumentProcessingJob) -> bool { if job.document_id != document.document_id or job.track_id != document.track_id or job.track_version_id != document.track_version_id { return False; } if self.find_matching_idempotency_key(document, job.idempotency_key) is not None { return False; } document +>:HAS_PROCESSING_JOB(stage=str(job.stage), created_at=job.created_at):+> job; return True; }
    def save_attempt(job: DocumentProcessingJob, attempt: ProcessingJobAttempt) -> bool { if attempt.job_id != job.job_id or attempt.attempt_number != job.attempt_number { return False; } job +>:HAS_JOB_ATTEMPT(attempt_number=attempt.attempt_number):+> attempt; return True; }
    def compare_and_transition(job: DocumentProcessingJob, expected: list[ProcessingJobStatus], new: ProcessingJobStatus, updated_at: str) -> bool { if job.status not in expected or not valid_job_transition(job.status, new) { return False; } job.status = new; job.updated_at = updated_at; return True; }
    def queued_jobs(document: CourseDocument) -> list[DocumentProcessingJob] { jobs = [job for job in self.list_jobs_for_document(document) if job.status == ProcessingJobStatus.QUEUED]; return sorted(jobs, key=lambda item: DocumentProcessingJob : (item.priority, item.queued_at or item.created_at)); }
    def claim_next_job(document: CourseDocument, worker_id: str, now: str, lease_expires_at: str) -> DocumentProcessingJob | None { for job in self.queued_jobs(document) { if self.compare_and_transition(job, [ProcessingJobStatus.QUEUED], ProcessingJobStatus.RUNNING, now) { job.worker_id = worker_id; job.started_at = now; job.last_heartbeat_at = now; job.lease_expires_at = lease_expires_at; job.attempt_number += 1; return job; } } return None; }
    def claim_stage_job(document: CourseDocument, stage: DocumentProcessingStage, worker_id: str, now: str, lease_expires_at: str) -> DocumentProcessingJob | None { for job in self.queued_jobs(document) { if job.stage == stage and self.compare_and_transition(job, [ProcessingJobStatus.QUEUED], ProcessingJobStatus.RUNNING, now) { job.worker_id = worker_id; job.started_at = now; job.last_heartbeat_at = now; job.lease_expires_at = lease_expires_at; job.attempt_number += 1; return job; } } return None; }
    def heartbeat(job: DocumentProcessingJob, worker_id: str, now: str, lease_expires_at: str) -> bool { if job.status != ProcessingJobStatus.RUNNING or job.worker_id != worker_id or job.lease_expires_at is None or (job.lease_expires_at as str) < now { return False; } job.last_heartbeat_at = now; job.lease_expires_at = lease_expires_at; job.updated_at = now; return True; }
    def find_stale_jobs(document: CourseDocument, now: str) -> list[DocumentProcessingJob] { return [job for job in self.list_jobs_for_document(document) if job.status == ProcessingJobStatus.RUNNING and job.lease_expires_at is not None and (job.lease_expires_at as str) < now]; }
    def find_retry_due_jobs(document: CourseDocument, now: str) -> list[DocumentProcessingJob] { return [job for job in self.list_jobs_for_document(document) if job.status == ProcessingJobStatus.RETRY_WAIT and job.next_retry_at is not None and (job.next_retry_at as str) <= now]; }
}
