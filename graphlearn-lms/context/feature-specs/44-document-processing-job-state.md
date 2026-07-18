# 44-document-processing-job-state.md

## Overview

Implement a durable document-processing job-state subsystem that coordinates and observes the asynchronous processing pipeline for lecturer-uploaded course documents.

This specification manages the lifecycle across:

```text
upload
→ storage
→ security validation
→ text extraction
→ content chunking
→ later blueprint generation
```

It does not perform the actual validation, extraction, chunking, or byLLM work.

Instead, it provides:

- durable job state;
- stage progression;
- retry and recovery;
- cancellation;
- idempotency;
- worker ownership;
- stale-job detection;
- progress reporting;
- error aggregation;
- lecturer-facing status;
- restart-safe orchestration.

The core rule is:

```text
Walkers trigger and inspect processing.
Workers/services perform processing.
Job state coordinates the workflow.
```

No long-running document-processing operation should depend on one HTTP/walker request remaining open.

---

## Status

- **Feature type:** Processing orchestration / job state
- **Priority:** Critical
- **Depends on:** `39-course-document-upload.md`
- **Depends on:** `40-course-document-storage.md`
- **Depends on:** `41-document-security-and-validation.md`
- **Depends on:** `42-document-text-extraction.md`
- **Depends on:** `43-document-content-chunking.md`
- **Blocks:** `45-course-blueprint-byllm-contracts.md`
- **Blocks:** `46-course-blueprint-generation.md`
- **Breaking changes allowed:** No
- **Primary implementation:** Jac domain/job nodes + services + walkers + worker coordination

---

# Goals

Implement a job-state subsystem that:

1. Tracks each document-processing stage durably.
2. Survives backend/process restarts.
3. Prevents duplicate concurrent processing of the same stage.
4. Supports retryable and non-retryable failures.
5. Supports bounded automatic retry.
6. Supports explicit lecturer retry where appropriate.
7. Detects stale/incomplete jobs.
8. Recovers jobs left in running state after crashes.
9. Supports cancellation for obsolete/replaced draft documents.
10. Prevents cancelled/replaced documents from advancing the active course.
11. Provides consistent stage progress to the lecturer dashboard.
12. Separates current status from historical attempts.
13. Preserves audit history of failures and retries.
14. Coordinates validation, extraction, and chunking in order.
15. Supports future blueprint-generation stages.
16. Supports idempotent start requests.
17. Supports worker lease/heartbeat semantics.
18. Prevents one failed stage from corrupting later state.
19. Exposes stable error and progress contracts.
20. Integrates with observability and metrics.

---

# Non-goals

This specification does not implement:

- validation logic itself;
- PDF/DOCX parsing;
- text normalization;
- content chunking algorithms;
- byLLM blueprint generation;
- distributed message-broker deployment;
- Celery/RQ/Kafka-specific implementation;
- webhook callbacks;
- learner notifications;
- course publication.

The architecture should allow a queue/worker backend later without making the domain depend on one vendor.

---

# Processing pipeline

Current pipeline:

```text
UPLOADED
   ↓
STORED
   ↓
VALIDATION
   ↓
EXTRACTION
   ↓
CHUNKING
   ↓
READY_FOR_BLUEPRINT
```

Future extension:

```text
READY_FOR_BLUEPRINT
   ↓
BLUEPRINT_GENERATION
   ↓
BLUEPRINT_VALIDATION
   ↓
REVIEW_REQUIRED
```

The job system must be extensible so future stages can be appended without redesigning existing job history.

---

# Processing stages

Define:

```jac
enum DocumentProcessingStage {
    STORAGE,
    SECURITY_VALIDATION,
    TEXT_EXTRACTION,
    CONTENT_CHUNKING,
    BLUEPRINT_GENERATION,
    BLUEPRINT_VALIDATION
}
```

For this specification, the first four are active.

Future stages may exist in the enum but should not run until their specifications are implemented.

---

# Job status

```jac
enum ProcessingJobStatus {
    PENDING,
    QUEUED,
    RUNNING,
    RETRY_WAIT,
    SUCCEEDED,
    FAILED,
    CANCEL_REQUESTED,
    CANCELLED,
    STALE,
    BLOCKED
}
```

Meaning:

| Status | Meaning |
|---|---|
| `PENDING` | Job record created but not yet queued |
| `QUEUED` | Ready for worker execution |
| `RUNNING` | Worker currently owns the job |
| `RETRY_WAIT` | Retryable failure waiting for next attempt |
| `SUCCEEDED` | Stage completed successfully |
| `FAILED` | Terminal failure for current job |
| `CANCEL_REQUESTED` | Cancellation requested; worker must stop safely |
| `CANCELLED` | Job stopped and will not advance |
| `STALE` | Worker lease expired or job became abandoned |
| `BLOCKED` | Cannot run because prerequisite or domain condition is unmet |

---

# Overall document processing state

Create a separate aggregate state for lecturer/dashboard use.

```jac
enum DocumentProcessingState {
    UPLOADED,
    STORED,
    VALIDATION_PENDING,
    VALIDATING,
    VALIDATION_FAILED,
    VALIDATED,
    EXTRACTION_PENDING,
    EXTRACTING,
    OCR_REQUIRED,
    NO_EXTRACTABLE_TEXT,
    EXTRACTION_FAILED,
    EXTRACTED,
    CHUNKING_PENDING,
    CHUNKING,
    CHUNKING_FAILED,
    CHUNKED,
    READY_FOR_BLUEPRINT,
    CANCELLED,
    BLOCKED
}
```

This state is a projection of stage/job state.

It must not replace stage attempt history.

---

# Why separate job status and document processing state

Example:

```text
Job:
SECURITY_VALIDATION
status = FAILED
attempt = 2

Document:
processing_state = VALIDATION_FAILED
```

Later:

```text
new validation job
status = RUNNING
attempt = 3

Document:
processing_state = VALIDATING
```

Historical attempts remain preserved.

---

# Core processing job node

Create:

```jac
node DocumentProcessingJob {
    has job_id: str;

    has document_id: str;
    has track_id: str;
    has track_version_id: str;

    has stage: DocumentProcessingStage;
    has status: ProcessingJobStatus;

    has job_generation: int = 1;

    has attempt_number: int = 0;
    has max_attempts: int = 3;

    has idempotency_key: str;

    has priority: int = 100;

    has queued_at: str | None = None;
    has started_at: str | None = None;
    has completed_at: str | None = None;

    has next_retry_at: str | None = None;

    has worker_id: str | None = None;
    has lease_expires_at: str | None = None;
    has last_heartbeat_at: str | None = None;

    has progress_percent: int = 0;
    has progress_message: str | None = None;

    has error_code: str | None = None;
    has error_message: str | None = None;
    has retryable: bool | None = None;

    has cancel_requested_at: str | None = None;
    has cancelled_at: str | None = None;
    has cancellation_reason: str | None = None;

    has created_at: str;
    has updated_at: str;
}
```

---

# Job identity

Recommended:

```text
job_<uuid>
```

Do not derive job identity solely from stage.

Multiple attempts/generations may exist historically.

---

# Job generation

Use:

```text
job_generation
```

when the same stage must be executed again because upstream content changed.

Example:

```text
Document A validation generation 1
→ source replaced
Document B starts its own jobs
```

For reprocessing same immutable source:

```text
same document
new extraction schema
→ extraction generation 2
```

Do not overwrite historical jobs.

---

# Idempotency key

Create deterministic idempotency keys.

Suggested:

```text
document_id
stage
source checksum
stage schema version
configuration fingerprint
```

Example:

```text
sha256(
  doc_123 |
  TEXT_EXTRACTION |
  checksum_abc |
  extraction_schema_v1
)
```

Equivalent start requests reuse the existing active/successful job.

---

# Job attempt node

Keep individual attempts separately where detailed history is needed.

```jac
node ProcessingJobAttempt {
    has attempt_id: str;
    has job_id: str;

    has attempt_number: int;

    has status: str;

    has worker_id: str | None;

    has started_at: str;
    has completed_at: str | None = None;

    has error_code: str | None = None;
    has error_message: str | None = None;

    has retryable: bool | None = None;

    has duration_ms: int | None = None;

    has metadata_json: str | None = None;
}
```

Graph:

```text
DocumentProcessingJob
└── HAS_JOB_ATTEMPT
    ├── Attempt 1
    ├── Attempt 2
    └── Attempt N
```

This is recommended for auditability.

---

# Processing graph

```text
CourseDocument
└── HAS_PROCESSING_JOB
    ├── STORAGE job
    ├── SECURITY_VALIDATION job
    ├── TEXT_EXTRACTION job
    └── CONTENT_CHUNKING job
```

Edges:

```jac
edge HAS_PROCESSING_JOB {
    has stage: str;
    has created_at: str;
}

edge HAS_JOB_ATTEMPT {
    has attempt_number: int;
}
```

---

# Active-job invariant

For one document and one stage/config identity:

```text
at most one job may be active in:
PENDING
QUEUED
RUNNING
RETRY_WAIT
CANCEL_REQUESTED
STALE
```

A second equivalent start request must reuse or reconcile the existing job.

---

# Stage dependencies

Define explicit prerequisites.

```text
STORAGE
requires:
upload accepted

SECURITY_VALIDATION
requires:
storage succeeded

TEXT_EXTRACTION
requires:
validation succeeded

CONTENT_CHUNKING
requires:
extraction succeeded

BLUEPRINT_GENERATION
requires:
chunking succeeded

BLUEPRINT_VALIDATION
requires:
blueprint generation succeeded
```

Do not rely only on stage ordering numbers.

Use a dependency resolver.

---

# Dependency service

Create:

```text
DocumentProcessingDependencyService
```

Responsibilities:

```text
can_start_stage
required_previous_stage
resolve_blocking_condition
assert_stage_prerequisites
```

Example result:

```jac
obj StageEligibility {
    has eligible: bool;
    has stage: DocumentProcessingStage;
    has blocking_stage: DocumentProcessingStage | None;
    has error_code: str | None;
    has message: str | None;
}
```

---

# Job orchestration service

Create:

```text
DocumentProcessingOrchestrator
```

Responsibilities:

```text
start_pipeline
start_stage
enqueue_stage
claim_job
heartbeat
report_progress
complete_job
fail_job
schedule_retry
request_cancel
cancel_job
recover_stale_jobs
advance_pipeline
reconcile_document_state
```

Walkers call the orchestrator.

Stage-specific workers call their corresponding services.

---

# Separation of concerns

## Orchestrator

Owns:

```text
state transitions
dependencies
job ownership
retry
progress
cancellation
recovery
pipeline advancement
```

## Stage services

Own:

```text
validation
extraction
chunking
```

## Repositories

Own:

```text
graph reads/writes
job queries
attempt persistence
```

## Walkers

Own:

```text
auth
input validation
service invocation
typed report
```

---

# Pipeline start

After storage succeeds:

```text
start_pipeline(document_id)
```

Behavior:

1. resolve document;
2. verify active/current source;
3. resolve existing jobs;
4. create validation job if missing;
5. queue validation;
6. update document processing projection;
7. return current processing summary.

Do not create all future jobs upfront unless needed.

Prefer creating each next-stage job only after previous success.

---

# Automatic pipeline advancement

On successful stage completion:

```text
complete_job(job)
→ reconcile domain artifact
→ determine next stage
→ check document still active/current
→ create/reuse next job
→ enqueue
```

Example:

```text
validation SUCCEEDED
→ document VALIDATED
→ create extraction job
→ EXTRACTION_PENDING
```

---

# Advancement safety check

Before starting next stage, re-read:

```text
CourseDocument
track version
active document reference
cancellation state
replacement state
course version state
```

Do not advance obsolete documents.

---

# Replacement behavior

If document A is replaced by B while A is processing:

```text
A:
cancel pending/running jobs
no new stages
historical outputs may remain

B:
start independent pipeline
```

A completed stale stage must not update the active course version to use A.

---

# Cancellation

Cancellation is cooperative.

Flow:

```text
request_cancel(job)
→ CANCEL_REQUESTED
→ worker sees request
→ stops at safe boundary
→ cleanup partial stage artifacts
→ CANCELLED
```

If no worker owns job:

```text
QUEUED/PENDING
→ CANCELLED directly
```

---

# Cancellation reasons

Examples:

```text
DOCUMENT_REPLACED
COURSE_ARCHIVED
LECTURER_CANCELLED
ADMIN_CANCELLED
UPSTREAM_INVALIDATED
NEW_PROCESSING_GENERATION
```

Persist reason.

---

# Non-cancellable stages

If a stage cannot be safely interrupted:

```text
mark CANCEL_REQUESTED
allow operation to finish
discard/ignore result during commit if obsolete
```

Never forcefully corrupt a parser/storage operation.

---

# Worker claim model

Workers claim queued jobs using a lease.

Fields:

```text
worker_id
lease_expires_at
last_heartbeat_at
```

Claim must be atomic or protected by compare-and-set semantics.

---

# Claim algorithm

```text
1. query eligible QUEUED job
2. verify not already leased
3. set RUNNING
4. set worker_id
5. set lease expiry
6. increment attempt
7. create ProcessingJobAttempt
```

If another worker wins claim:

```text
losing worker does not execute job
```

---

# Worker lease

Config:

```text
PROCESSING_JOB_LEASE_SECONDS
```

Example:

```text
120
```

Workers heartbeat periodically.

Example:

```text
every 30 seconds
```

---

# Heartbeat

```text
heartbeat(job_id, worker_id)
```

Must:

- verify current worker owns lease;
- extend lease;
- update timestamp;
- optionally update progress.

A worker with expired lease must not commit stage success without reacquiring/revalidating ownership.

---

# Stale-job detection

A running job becomes stale when:

```text
status == RUNNING
AND lease_expires_at < now
```

Stale reconciliation:

```text
RUNNING
→ STALE
→ determine retryability
→ QUEUED or FAILED
```

---

# Crash recovery

On application/worker restart:

1. scan expired running jobs;
2. mark stale;
3. inspect stage side effects;
4. reconcile whether operation actually completed;
5. reuse completed artifact when valid;
6. retry only if needed.

Example:

```text
extraction artifact persisted
but job completion update failed
```

Recovery should detect matching valid extraction and mark job succeeded instead of rerunning.

---

# Stage reconciliation

Create stage-specific reconciliation hooks:

```text
reconcile_validation_job
reconcile_extraction_job
reconcile_chunking_job
```

Check durable outputs.

Example:

```text
TEXT_EXTRACTION:
matching DocumentExtraction exists
source checksum matches
status EXTRACTED
→ reconcile job as SUCCEEDED
```

---

# Retry policy

Each job has:

```text
max_attempts
attempt_number
retryable
next_retry_at
```

Default:

```text
max_attempts = 3
```

Stage-specific overrides allowed.

---

# Retry categories

## Retryable

Examples:

```text
storage timeout
malware scanner unavailable
temporary parser error
temporary persistence failure
worker crash
transient DB error
```

## Non-retryable

Examples:

```text
unsupported file
malware detected
encrypted PDF
OCR required
no extractable text
invalid chunk config
source-content policy rejection
```

---

# Backoff

Recommended bounded exponential backoff:

```text
attempt 1 → 30 seconds
attempt 2 → 2 minutes
attempt 3 → 10 minutes
```

Configurable.

Do not retry infinitely.

---

# Retry jitter

Add small jitter where multiple jobs may fail simultaneously.

Avoid retry storms.

---

# Manual retry

Lecturer may retry only when:

```text
job failed
error is retryable or approved manual retry class
document still active
track version editable
authorization passes
```

A manual retry may:

- reuse same job with new attempt; or
- create new job generation.

Prefer same job for transient retry.

Use new generation when configuration/source/schema changed.

---

# Retry after corrected upload

If source itself is invalid:

```text
do not retry same job endlessly
```

Lecturer must upload replacement.

New document gets new pipeline.

---

# Progress model

Progress must be coarse and trustworthy.

Avoid fake precision.

Per stage ranges:

```text
STORAGE:             0–15
SECURITY_VALIDATION: 15–35
TEXT_EXTRACTION:     35–65
CONTENT_CHUNKING:    65–85
BLUEPRINT_GENERATION:85–95
BLUEPRINT_VALIDATION:95–100
```

These percentages are user-facing projection only.

Stage workers may report local progress.

---

# Progress projection

Example:

```text
overall_percent =
stage_base +
(stage_local_percent * stage_weight)
```

Do not claim exact ETA.

---

# Progress messages

Examples:

```text
Uploading course notes…
Validating document security…
Reading course content…
Organizing course sections…
Preparing course structure…
```

Errors:

```text
Document validation failed.
Text extraction failed.
Course section preparation failed.
```

Avoid exposing low-level implementation jargon unless in admin diagnostics.

---

# Processing summary type

```jac
obj DocumentProcessingSummary {
    has document_id: str;

    has state: DocumentProcessingState;

    has current_stage: DocumentProcessingStage | None;

    has overall_progress_percent: int;

    has progress_message: str | None;

    has retry_available: bool;
    has cancel_available: bool;

    has error_code: str | None;
    has user_message: str | None;

    has started_at: str | None;
    has updated_at: str;
    has completed_at: str | None;
}
```

---

# Lecturer-facing processing timeline

Optional typed projection:

```jac
obj ProcessingStageSummary {
    has stage: DocumentProcessingStage;
    has status: str;
    has attempt_count: int;
    has started_at: str | None;
    has completed_at: str | None;
    has error_code: str | None;
}
```

Example:

```json
{
  "state": "EXTRACTING",
  "overall_progress_percent": 48,
  "stages": [
    {"stage": "STORAGE", "status": "SUCCEEDED"},
    {"stage": "SECURITY_VALIDATION", "status": "SUCCEEDED"},
    {"stage": "TEXT_EXTRACTION", "status": "RUNNING"},
    {"stage": "CONTENT_CHUNKING", "status": "PENDING"}
  ]
}
```

---

# Repository contracts

## `DocumentProcessingJobRepository`

Suggested methods:

```text
find_by_id
find_active_by_stage
find_matching_idempotency_key
list_jobs_for_document
list_stage_attempts
save_job
claim_next_job
heartbeat
mark_succeeded
mark_failed
mark_retry_wait
mark_cancel_requested
mark_cancelled
mark_stale
find_stale_jobs
find_retry_due_jobs
```

---

# Atomic state transition helper

Centralize:

```text
compare_and_transition(
  job_id,
  expected_statuses,
  new_status
)
```

Do not allow arbitrary status mutation.

---

# Valid job transitions

```text
PENDING
→ QUEUED
→ CANCELLED

QUEUED
→ RUNNING
→ CANCELLED
→ BLOCKED

RUNNING
→ SUCCEEDED
→ FAILED
→ RETRY_WAIT
→ CANCEL_REQUESTED
→ STALE

RETRY_WAIT
→ QUEUED
→ CANCELLED
→ FAILED

CANCEL_REQUESTED
→ CANCELLED
→ SUCCEEDED (only if safe operation completed but result ignored/reconciled)

STALE
→ QUEUED
→ FAILED
→ SUCCEEDED (through reconciliation)

BLOCKED
→ QUEUED
→ CANCELLED
```

Invalid transitions must fail explicitly.

---

# Document-state projection

Do not let every stage service mutate `CourseDocument.processing_state` independently.

Centralize in:

```text
DocumentProcessingProjectionService
```

It derives:

```text
current state
current stage
progress
retry availability
error
```

from jobs + durable artifacts.

---

# Projection reconciliation

Run when:

- job created;
- job state changes;
- artifact committed;
- document replaced;
- course archived;
- backend restarts.

This avoids stale dashboard states.

---

# Job creation rules

A job may be created only when:

```text
document exists
document active/eligible
track/version relationship valid
stage prerequisites satisfied or job intentionally BLOCKED
matching successful job does not already satisfy request
```

---

# Blocked jobs

Use `BLOCKED` for domain dependency issues, not technical failures.

Examples:

```text
waiting for validation
waiting for lecturer to replace OCR-only document
course archived
document superseded
```

Do not automatically retry blocked jobs.

---

# Terminal document states

These stop automatic progression:

```text
OCR_REQUIRED
NO_EXTRACTABLE_TEXT
VALIDATION_FAILED when non-retryable
CANCELLED
BLOCKED requiring user action
```

---

# Stage worker interface

Create generic contract:

```jac
obj ProcessingStageWorker {
    def stage() -> DocumentProcessingStage;

    def execute(
        job: DocumentProcessingJob,
        context: ProcessingWorkerContext
    ) -> StageExecutionResult;

    def reconcile(
        job: DocumentProcessingJob
    ) -> StageReconciliationResult;
}
```

Implement adapters:

```text
SecurityValidationWorker
TextExtractionWorker
ContentChunkingWorker
```

Future:

```text
BlueprintGenerationWorker
BlueprintValidationWorker
```

---

# Worker context

```jac
obj ProcessingWorkerContext {
    has worker_id: str;
    has job_id: str;
    has attempt_id: str;

    has request_id: str;

    has cancellation_check_interval: int;
}
```

---

# Stage execution result

```jac
obj StageExecutionResult {
    has succeeded: bool;

    has retryable: bool;

    has error_code: str | None;
    has error_message: str | None;

    has artifact_id: str | None;

    has warnings: list[str];
}
```

---

# Job scheduling implementation

The domain must not depend on one queue technology.

Possible implementations:

```text
development:
in-process durable polling loop

production:
worker process + persistent job repository

future:
message queue/broker
```

The job records remain the source of truth.

A queue message is only a delivery mechanism.

---

# No in-memory-only job state

Do not store authoritative processing state only in:

```text
Python dict
global variable
browser state
React state
in-memory queue
```

A restart must not lose:

```text
which stage ran
attempt count
failure reason
next retry
```

---

# Polling worker

If no message queue is used initially:

```text
worker periodically:
1. find QUEUED jobs
2. claim atomically
3. execute
4. heartbeat
5. commit result
```

Polling interval configurable.

---

# Recovery scheduler

Run periodically:

```text
recover_stale_jobs
queue_due_retries
reconcile_inconsistent_jobs
```

Highest frequency should be appropriate to deployment.

---

# Processing consistency audit

Create:

```text
audit_document_processing_state
```

Checks:

```text
no two active equivalent jobs
RUNNING jobs have valid lease
SUCCEEDED validation has validated artifact/state
SUCCEEDED extraction has extraction artifact
SUCCEEDED chunking has chunk set
document projection matches jobs
active document not cancelled
replaced document not progressing
```

---

# Error propagation

Stage service errors become job errors.

Do not expose raw exceptions.

Map:

```text
domain/service error
→ stable job error code
→ safe lecturer message
```

---

# Error history

A later successful retry must not erase previous attempt errors.

Current job may clear active error fields after success, while `ProcessingJobAttempt` preserves history.

---

# Audit events

Emit:

```text
document_job.created
document_job.queued
document_job.claimed
document_job.started
document_job.progress
document_job.heartbeat
document_job.succeeded
document_job.failed
document_job.retry_scheduled
document_job.retry_started
document_job.cancel_requested
document_job.cancelled
document_job.stale
document_job.recovered
document_job.reconciled
pipeline.advanced
pipeline.blocked
pipeline.completed
```

Fields:

```text
job_id
document_id
track_id
track_version_id
stage
status
attempt
worker_id
duration_ms
error_code
retryable
request_id
```

Do not log document content.

---

# Metrics

Track:

```text
document_processing_jobs_total
document_processing_jobs_running
document_processing_jobs_failed_total
document_processing_jobs_retry_total
document_processing_jobs_stale_total
document_processing_jobs_cancelled_total

document_processing_stage_duration_ms
document_processing_queue_wait_ms
document_processing_attempts_per_job
document_processing_pipeline_duration_ms

document_processing_recovery_total
document_processing_reconciliation_total
```

Dimensions:

```text
stage
status
result
retryable
```

Avoid high-cardinality IDs.

---

# Authorization

Lecturer-facing operations:

```text
get processing status
retry failed processing
cancel processing
```

must enforce ownership/course authorization.

Workers use trusted internal context.

Internal trust does not bypass:

```text
document-track-version relationship validation
job ownership
lease validation
artifact consistency
```

---

# Private walkers

Suggested:

```text
get_course_document_processing_status
retry_course_document_processing
cancel_course_document_processing
```

Internal/admin:

```text
reconcile_document_processing
audit_document_processing
```

---

# `get_course_document_processing_status`

Input:

```text
document_id
track_id
```

Output:

```text
DocumentProcessingSummary
stage summaries
warnings
safe error
```

Do not expose:

```text
worker_id
lease internals
stack traces
raw exception details
```

to normal lecturers unless needed.

---

# `retry_course_document_processing`

Behavior:

1. authenticate;
2. authorize course ownership;
3. resolve active failed stage;
4. verify retry policy;
5. clear/advance retry state;
6. queue job;
7. return updated summary.

Do not restart from storage unless required.

Retry should resume from the failed stage.

---

# `cancel_course_document_processing`

Behavior:

1. authorize;
2. verify draft/editable version;
3. identify active jobs;
4. request cancellation;
5. prevent future advancement;
6. return updated summary.

Published-version processing maintenance should require admin/internal control.

---

# Pipeline resume

After failure recovery:

```text
validation succeeded
extraction failed
```

Retry:

```text
extraction only
```

Do not rerun validation unless:

```text
policy version changed
source integrity changed
explicit revalidation required
```

---

# Upstream invalidation

When an upstream artifact changes:

```text
new validation policy
new extraction schema
new chunk config
```

downstream jobs/artifacts may become stale.

Create invalidation chain:

```text
validation invalidated
→ extraction stale
→ chunks stale
→ blueprint stale
```

Do not delete historical artifacts.

Mark active generation obsolete and create new job generation.

---

# Stale artifact status

Recommended metadata:

```text
is_current
superseded_by_id
invalidated_at
invalidation_reason
```

Do not confuse:

```text
job STALE
```

with:

```text
artifact stale due to new upstream generation
```

Use distinct concepts.

---

# Job priority

Initial priority:

```text
100
```

Possible future:

```text
interactive retry = 50
new upload = 100
background reprocessing = 200
```

Lower number may mean higher priority if chosen.

Document convention explicitly.

Do not implement complex scheduling unless needed.

---

# Fairness

A lecturer uploading many files must not permanently starve others.

If worker scheduler grows beyond simple polling, support:

```text
bounded concurrency
fair queue order
per-user/course limits
```

Initial release may use FIFO with bounded worker concurrency.

---

# Per-course concurrency

Initial policy:

```text
one active processing pipeline per track version
```

This aligns with one-active-document policy.

Do not process two competing source documents for the same draft version as active pipelines.

---

# Global worker concurrency

Config:

```text
DOCUMENT_PROCESSING_MAX_CONCURRENT_JOBS
```

Tune based on:

- CPU;
- memory;
- malware scanner capacity;
- parser cost.

---

# Stage-specific concurrency

Optional:

```text
validation workers = N
extraction workers = M
chunking workers = K
```

Useful if extraction is more resource-heavy.

---

# Timeouts

Each stage should define:

```text
execution timeout
lease duration
heartbeat interval
retry policy
```

Do not use one universal timeout for all stages.

---

# Example configuration

```text
DOCUMENT_JOB_LEASE_SECONDS=120
DOCUMENT_JOB_HEARTBEAT_SECONDS=30
DOCUMENT_JOB_MAX_ATTEMPTS=3

DOCUMENT_VALIDATION_JOB_TIMEOUT_SECONDS=120
DOCUMENT_EXTRACTION_JOB_TIMEOUT_SECONDS=300
DOCUMENT_CHUNKING_JOB_TIMEOUT_SECONDS=180
```

---

# Job timeout behavior

A timeout should:

```text
fail attempt
classify retryability
release/expire lease
schedule retry when appropriate
```

Do not leave job `RUNNING`.

---

# Lecturer dashboard integration

`38-lecturer-course-dashboard.md` should consume processing summary.

Examples:

```text
Draft
Uploading
Validating
Reading notes
Organizing sections
Ready for course generation
Needs attention
Failed
```

Dashboard should not independently infer state from raw nodes.

Use projection service.

---

# Course readiness integration

Examples:

```text
document absent
→ SOURCE_REQUIRED

stored, validation pending
→ PROCESSING

validation rejected
→ SOURCE_REJECTED

OCR required
→ SOURCE_REPLACEMENT_REQUIRED

chunked
→ READY_FOR_BLUEPRINT
```

---

# User actions by state

## Validation failure, retryable

```text
Retry
Replace document
```

## Encrypted/malware/macro/non-retryable

```text
Replace document
```

## Extraction transient failure

```text
Retry
Replace document
```

## OCR required

```text
Replace with text-based PDF/DOCX
```

## Chunking transient failure

```text
Retry
```

---

# Processing completion

Current subsystem completion:

```text
CONTENT_CHUNKING SUCCEEDED
AND valid active chunk set exists
```

Projection:

```text
READY_FOR_BLUEPRINT
```

Do not mark course itself:

```text
PUBLISHED
```

or:

```text
REVIEW_REQUIRED
```

yet.

---

# Failure recovery examples

## Crash during extraction before artifact

```text
job RUNNING
worker dies
lease expires
→ STALE
→ no extraction artifact found
→ retry extraction
```

## Crash after extraction artifact but before job success

```text
lease expires
→ STALE
→ reconciliation finds valid extraction
→ job SUCCEEDED
→ advance to chunking
```

## Document replaced during validation

```text
old job CANCEL_REQUESTED
validation may complete
commit sees document no longer active
→ no pipeline advance
→ job CANCELLED or completed-obsolete according to implementation
```

---

# Data retention

Keep job history while:

```text
course/version exists
audit policy requires
learner/published provenance depends on processing history
```

Old draft job attempts may be pruned later according to retention policy.

Do not delete active/current processing records.

---

# Job-history pruning

Future cleanup may archive:

```text
old succeeded attempts
old cancelled draft jobs
old retry metadata
```

while retaining:

```text
final job result
artifact references
important security failures
published-version processing history
```

Out of scope for first implementation beyond defining retention hooks.

---

# Repository query performance

Avoid:

```text
one query per stage
one query per attempt
one query per dashboard card
```

Provide batched methods:

```text
list_latest_jobs_by_document
list_pipeline_summary_for_tracks
find_active_jobs_for_documents
```

Dashboard queries must avoid N+1 traversal.

---

# Testing strategy

## State-transition tests

Test every allowed transition.

Test invalid transitions fail.

Examples:

```text
QUEUED → RUNNING valid
RUNNING → SUCCEEDED valid
SUCCEEDED → RUNNING invalid
CANCELLED → QUEUED invalid without new job/generation
```

---

# Dependency tests

Verify:

```text
extraction cannot start before validation success
chunking cannot start before extraction success
```

---

# Idempotency tests

Call pipeline start repeatedly.

Expected:

```text
one equivalent active validation job
```

---

# Claim/lease tests

Two workers claim same job simultaneously.

Expected:

```text
one winner
one loser
```

---

# Heartbeat tests

Verify:

```text
valid worker extends lease
wrong worker rejected
expired lease handled safely
```

---

# Stale recovery tests

Simulate:

```text
RUNNING job
expired lease
```

Verify stale recovery.

---

# Artifact reconciliation tests

Create successful extraction artifact but leave job RUNNING/stale.

Expected:

```text
reconcile to SUCCEEDED
no duplicate extraction
```

---

# Retry tests

Test:

```text
retryable failure
→ RETRY_WAIT
→ QUEUED
→ RUNNING
```

Non-retryable:

```text
FAILED terminal
```

---

# Max-attempt tests

After max attempts:

```text
FAILED
retry_available false unless manual/admin override policy
```

---

# Cancellation tests

Test:

```text
queued cancellation
running cancellation
replacement-triggered cancellation
```

Ensure no downstream stage starts.

---

# Replacement race tests

Simulate replacement while old job completes.

Expected:

```text
old result does not advance active pipeline
```

---

# Restart tests

Persist jobs.

Restart application.

Verify:

```text
queued jobs remain
running expired jobs recovered
retry_wait jobs remain scheduled
completed jobs preserved
```

---

# Progress tests

Verify:

```text
progress 0..100
monotonic within one generation
stage messages correct
no completed state below 100
```

Do not require exact wall-clock ETA.

---

# Dashboard projection tests

Ensure projection matches:

```text
jobs
artifacts
document state
```

Conflicting state should trigger reconciliation warning.

---

# Failure-injection tests

Simulate:

```text
repository failure during job completion
worker crash
heartbeat failure
artifact commit before job state commit
job state commit before artifact commit
retry scheduler crash
```

Verify recoverability.

---

# Security tests

Attempt:

```text
lecturer retries another lecturer's job
learner cancels job
client supplies fake worker_id
client marks job succeeded
client manipulates progress
```

All denied.

Only trusted workers may mutate execution state.

---

# Example Jac test outlines

```jac
test "pipeline advances validation to extraction" {
    # Create stored active document.
    # Complete validation successfully.
    # Assert extraction job queued.
}

test "duplicate pipeline start is idempotent" {
    # Start same document twice.
    # Assert one active equivalent job.
}

test "stale extraction reconciles from durable artifact" {
    # Create extraction artifact.
    # Leave job RUNNING with expired lease.
    # Run recovery.
    # Assert job SUCCEEDED.
    # Assert no duplicate extraction.
}

test "replaced document cannot advance pipeline" {
    # Start validation on document A.
    # Replace with document B.
    # Finish A validation.
    # Assert no extraction job for A.
}

test "worker lease prevents duplicate execution" {
    # Two workers try to claim same job.
    # Assert one succeeds.
}
```

---

# Implementation sequence

## Step 1 — Add job enums and nodes

Implement:

```text
DocumentProcessingJob
ProcessingJobAttempt
HAS_PROCESSING_JOB
HAS_JOB_ATTEMPT
```

## Step 2 — Add job repository

Implement atomic state transitions and queries.

## Step 3 — Add dependency service

Encode stage prerequisites centrally.

## Step 4 — Add orchestrator

Implement start, advance, retry, cancel, recover.

## Step 5 — Add worker claim/lease

Support atomic claim and heartbeat.

## Step 6 — Integrate validation

Validation worker uses `41`.

## Step 7 — Integrate extraction

Extraction worker uses `42`.

## Step 8 — Integrate chunking

Chunking worker uses `43`.

## Step 9 — Add projection service

Provide stable lecturer/dashboard state.

## Step 10 — Add stale recovery

Reconcile expired jobs and durable artifacts.

## Step 11 — Add retry scheduler

Queue due retries safely.

## Step 12 — Add replacement cancellation

Prevent obsolete document progression.

## Step 13 — Add walkers

Status, retry, cancel.

## Step 14 — Add observability

Logs, events, metrics.

## Step 15 — Add tests

State machine, concurrency, recovery, security, restart.

---

# Acceptance criteria

## Durable job state

- [ ] Processing jobs are persisted.
- [ ] Restarts do not lose queued/running/retry state.
- [ ] Stage attempt history is retained.
- [ ] Job status is not stored only in memory.

## Pipeline ordering

- [ ] Validation requires storage success.
- [ ] Extraction requires validation success.
- [ ] Chunking requires extraction success.
- [ ] Future stages can be added cleanly.
- [ ] Invalid stage jumps are rejected.

## Idempotency

- [ ] Duplicate start requests reuse equivalent jobs.
- [ ] Equivalent successful jobs/artifacts are reused.
- [ ] Duplicate workers cannot execute the same leased job concurrently.

## Retry

- [ ] Retryable errors schedule bounded retry.
- [ ] Non-retryable errors fail terminally.
- [ ] Attempt counts are persisted.
- [ ] Max attempts are enforced.
- [ ] Manual retry obeys authorization/policy.

## Recovery

- [ ] Expired leases become stale.
- [ ] Stale jobs are reconciled.
- [ ] Durable completed artifacts prevent unnecessary reruns.
- [ ] Server restart recovery works.
- [ ] Partial state inconsistencies can be audited.

## Cancellation

- [ ] Queued jobs can be cancelled.
- [ ] Running jobs support cooperative cancellation.
- [ ] Replaced documents stop progressing.
- [ ] Cancelled jobs do not start downstream stages.
- [ ] Obsolete completed results do not reactivate old documents.

## Progress

- [ ] Lecturer gets stable processing state.
- [ ] Current stage is available.
- [ ] Progress percentage is bounded and trustworthy.
- [ ] Safe error messages are exposed.
- [ ] Retry/cancel availability is projected by backend.

## Security

- [ ] Only trusted workers mutate execution state.
- [ ] Lecturers can only inspect/retry/cancel their authorized course jobs.
- [ ] Learners cannot control processing jobs.
- [ ] Fake worker claims are rejected.

## Observability

- [ ] Job lifecycle events are emitted.
- [ ] Stage durations are measured.
- [ ] Retry/stale/cancel metrics exist.
- [ ] No document content is logged.

## Quality

- [ ] `jac check` passes.
- [ ] `jac check --lint` passes.
- [ ] `jac test` passes.
- [ ] State-transition tests pass.
- [ ] Concurrency/lease tests pass.
- [ ] Restart recovery tests pass.
- [ ] Failure-injection tests pass.
- [ ] Security tests pass.

---

# Check when done

Run:

```bash
jac check <entry-file>
jac check --lint <entry-file>
jac test
```

Then manually verify:

```text
1. Upload valid course notes.
2. Storage succeeds.
3. Validation job is created and queued.
4. Worker claims job.
5. Dashboard shows VALIDATING.
6. Validation succeeds.
7. Extraction job is automatically queued.
8. Dashboard shows EXTRACTING.
9. Extraction succeeds.
10. Chunking job is queued.
11. Chunking succeeds.
12. Document becomes READY_FOR_BLUEPRINT.

13. Simulate validation scanner outage.
14. Job enters retry flow.
15. Retry succeeds after recovery.

16. Simulate worker crash during extraction.
17. Lease expires.
18. Job becomes stale.
19. Recovery reconciles or retries correctly.

20. Replace a document while old processing is running.
21. Old pipeline stops advancing.
22. New document starts its own pipeline.

23. Restart backend with queued jobs.
24. Jobs remain recoverable.
25. No duplicate processing occurs.

26. Verify lecturer can view status and retry authorized jobs.
27. Verify another lecturer cannot access the job.
28. Verify learner cannot mutate job state.
```

---

# Expected result

After this specification is implemented:

- document processing is durable and restart-safe;
- validation, extraction, and chunking run as coordinated stages rather than one long request;
- duplicate work is prevented through idempotency and worker leases;
- failures can retry safely without restarting the whole pipeline;
- stale jobs recover after crashes;
- replaced documents cannot continue into active curriculum generation;
- lecturer dashboards receive one consistent processing projection;
- historical attempts remain auditable;
- future blueprint-generation stages can plug into the same orchestration model without redesigning the pipeline.
