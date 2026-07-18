# 40-course-document-storage.md

## Overview

Implement a provider-agnostic storage subsystem for lecturer-uploaded course source documents.

This specification defines how GraphLearn stores, retrieves, validates, replaces, retains, and deletes course files after the upload boundary defined in `39-course-document-upload.md`.

The storage layer must use Jac's storage abstraction where available so the application can run with local filesystem storage in development and a configured production backend without changing walker or domain logic.

The storage subsystem must not:

- parse PDF or DOCX content;
- extract text;
- chunk documents;
- invoke byLLM;
- generate a course blueprint;
- publish a course.

Its responsibility is to safely persist the original uploaded file and expose a stable, authorized storage interface to later processing services.

---

## Status

- **Feature type:** Infrastructure / storage
- **Priority:** Critical
- **Depends on:** `39-course-document-upload.md`
- **Depends on:** `36-lecturer-authorization-policies.md`
- **Uses:** `CourseDocument`
- **Blocks:** `41-document-security-and-validation.md`
- **Blocks:** `42-document-text-extraction.md`
- **Breaking changes allowed:** No
- **Primary implementation:** Jac storage abstraction + service/repository layer

---

## Jac/Jaseci storage alignment

Current Jac provides a built-in `store()` abstraction for file/blob operations.

The core runtime can use local storage, while scale deployments can provide a configured backend through the same storage interface.

Use the storage abstraction rather than calling filesystem APIs directly from walkers.

Conceptual initialization:

```jac
glob course_store = store(
    base_path="./storage/course-documents",
    create_dirs=True
);
```

The storage implementation should remain replaceable through environment or runtime configuration.

Do not hard-code a cloud provider into:

- walkers;
- course-domain services;
- document nodes;
- extraction services;
- frontend code.

---

# Goals

Implement storage that:

1. Persists validated lecturer-uploaded PDF/DOCX files.
2. Uses stable internal storage keys rather than user filenames.
3. Works in local development and production environments.
4. Keeps storage-provider details out of the domain model.
5. Supports upload, download, delete, list, copy/move, and metadata operations where the active backend supports them.
6. Verifies file integrity using checksums and size metadata.
7. Prevents path traversal and unsafe key construction.
8. Supports one-active-document replacement semantics from the upload specification.
9. Supports idempotent retries.
10. Supports orphan-file detection and cleanup.
11. Prevents unauthorized direct document access.
12. Supports future extraction workers without exposing raw public URLs.
13. Provides retention and deletion rules.
14. Keeps published historical course versions reproducible.
15. Produces storage metrics and audit logs.

---

# Non-goals

This specification does not implement:

- browser-to-cloud presigned uploads unless later required;
- virus or malware scanning;
- MIME/signature validation beyond storage-layer consistency checks;
- PDF text extraction;
- DOCX parsing;
- OCR;
- document chunking;
- embedding generation;
- vector storage;
- blueprint generation;
- course publishing;
- learner access to raw lecturer notes by default.

These belong to later specifications.

---

# Storage architecture

```text
Jac Client
   │
   ▼
Private upload walker
   │
   ▼
CourseDocumentUploadService
   │
   ├── authorization
   ├── upload validation
   └── storage request
          │
          ▼
CourseDocumentStorageService
          │
          ▼
Jac store() abstraction
     ┌────┴───────────────┐
     │                    │
Development           Production
LocalStorage          configured backend
     │                    │
     └──── storage key ───┘
          │
          ▼
CourseDocument metadata node
```

The domain database stores metadata.

The storage backend stores file bytes.

Never store the full PDF/DOCX byte payload inside ordinary `CourseDocument` node fields.

---

# Storage abstraction boundary

Create one application-facing service:

```text
CourseDocumentStorageService
```

All course-document file operations must go through this service.

Walkers must not call:

```text
open()
os.remove()
pathlib.Path.write_bytes()
cloud SDK upload()
S3 SDK calls
Azure SDK calls
GCS SDK calls
```

directly.

The service is the boundary between application logic and storage infrastructure.

---

# Proposed module organization

Adapt to the current repository structure:

```text
server/
├── storage/
│   ├── course_document_storage.jac
│   ├── storage_key_builder.jac
│   ├── storage_types.jac
│   └── storage_errors.jac
├── services/
│   └── course_document_storage_service.jac
├── repositories/
│   └── course_document_repository.jac
├── jobs/
│   └── course_document_orphan_cleanup.jac
└── tests/
    └── course_document_storage_test.jac
```

If the project already has a general storage package, extend it instead.

---

# Storage configuration

Define explicit configuration.

Example environment configuration:

```text
COURSE_DOCUMENT_STORAGE_BASE=./storage/course-documents
COURSE_DOCUMENT_MAX_BYTES=52428800
COURSE_DOCUMENT_RETENTION_DAYS=30
COURSE_DOCUMENT_ORPHAN_GRACE_MINUTES=60
COURSE_DOCUMENT_TMP_PREFIX=_tmp
COURSE_DOCUMENT_TRASH_PREFIX=_trash
```

When using Jac's configured storage backend, avoid duplicating backend credentials in application-specific settings.

Secrets such as cloud credentials must never be:

- committed to Git;
- stored in graph nodes;
- returned by walkers;
- exposed to Jac Client;
- written into logs.

---

# Storage key design

User-controlled filenames must never become storage paths directly.

Bad:

```text
uploads/{original_filename}
```

Unsafe examples:

```text
../../config.env
../other-course/notes.pdf
C:\Windows\...
```

Use a server-generated storage key.

Recommended format:

```text
course-documents/
{track_id}/
{track_version_id}/
{document_id}/
source.{canonical_extension}
```

Example:

```text
course-documents/
trk_abc123/
trv_abc123_v1/
doc_789xyz/
source.pdf
```

Flattened:

```text
course-documents/trk_abc123/trv_abc123_v1/doc_789xyz/source.pdf
```

---

# Storage key builder

Create:

```text
StorageKeyBuilder
```

Conceptual interface:

```jac
obj StorageKeyBuilder {
    def build_course_document_key(
        track_id: str,
        track_version_id: str,
        document_id: str,
        extension: str
    ) -> str;

    def build_temp_key(
        upload_id: str,
        extension: str
    ) -> str;

    def build_trash_key(
        document_id: str,
        timestamp: str,
        extension: str
    ) -> str;
}
```

The key builder must:

- accept only server-generated IDs;
- normalize the extension;
- reject path separators in IDs;
- reject `..`;
- reject absolute paths;
- reject null bytes;
- produce deterministic canonical paths;
- keep all course documents within the configured storage namespace.

---

# Canonical extensions

Initial supported extensions:

```text
.pdf
.docx
```

Storage should normalize:

```text
PDF → pdf
.PDF → pdf
DocX → docx
```

Do not infer extension solely from the original filename.

The validated document type from `39` / `41` determines the canonical extension.

---

# CourseDocument storage metadata

The `CourseDocument` node should contain storage metadata similar to:

```jac
node CourseDocument {
    has document_id: str;

    has track_id: str;
    has track_version_id: str;

    has original_filename: str;
    has canonical_extension: str;
    has mime_type: str;

    has storage_key: str;
    has storage_provider: str | None = None;

    has size_bytes: int;
    has checksum_sha256: str;

    has upload_status: str;
    has processing_status: str;

    has uploaded_by: str;
    has uploaded_at: str;

    has replaced_document_id: str | None = None;

    has deleted_at: str | None = None;
}
```

Provider-specific object IDs should not become primary domain identifiers.

`document_id` remains the application identity.

---

# Storage provider metadata

Avoid tightly coupling domain nodes to provider-specific concepts.

Acceptable metadata:

```text
storage_key
size_bytes
checksum_sha256
storage_provider
```

Avoid unless absolutely required:

```text
s3_bucket
s3_version_id
azure_blob_etag
gcs_generation
```

Provider-specific fields should live in:

- backend metadata;
- an infrastructure-specific metadata object;
- operational logs.

Not in ordinary domain behavior.

---

# Storage operations

The service must support the following application-level operations.

## `store_document`

```text
store_document(...)
→ StoredCourseDocument
```

Responsibilities:

1. Receive validated file bytes or stream.
2. Generate/accept a canonical storage key.
3. Calculate SHA-256 during transfer where practical.
4. Track byte count.
5. Write to a temporary key first where supported.
6. Verify metadata.
7. Promote/move to canonical key.
8. Return storage metadata.

Conceptual result:

```jac
obj StoredCourseDocument {
    has storage_key: str;
    has size_bytes: int;
    has checksum_sha256: str;
    has stored_at: str;
}
```

---

## `open_document`

Used internally by later extraction services.

```text
open_document(document_id, actor/context)
```

Must:

1. resolve `CourseDocument`;
2. authorize access;
3. validate that the document is active/available;
4. resolve the storage key;
5. retrieve bytes/stream;
6. optionally verify integrity;
7. return an internal stream/byte object.

Do not return storage paths directly to ordinary frontend callers.

---

## `download_document`

Optional lecturer-facing operation.

Use only if lecturers need to download their uploaded source file.

Must enforce:

```text
authenticated
AND authorized for course
AND document belongs to requested track/version
AND document is not hard-deleted
```

Prefer application-mediated download over exposing public storage URLs.

---

## `delete_document`

Deletion must obey retention and version rules.

Logical deletion should occur before physical deletion.

Sequence:

```text
mark document DELETING
→ verify no protected references
→ move to trash / delete storage object
→ mark DELETED
→ retain metadata tombstone as required
```

For published historical course versions:

```text
physical deletion prohibited by default
```

unless an explicit retention/legal policy allows it.

---

## `get_document_metadata`

Returns safe metadata:

```json
{
  "document_id": "doc_123",
  "original_filename": "Database Systems Notes.pdf",
  "mime_type": "application/pdf",
  "size_bytes": 2481932,
  "checksum_sha256": "...",
  "upload_status": "STORED"
}
```

Do not return:

- cloud credentials;
- private absolute filesystem paths;
- internal signed secrets;
- backend connection configuration.

---

# Temporary storage workflow

Use staged storage where practical.

```text
incoming upload
   │
   ▼
temporary key
   │
   ├── upload interrupted → cleanup later
   │
   ▼
integrity verified
   │
   ▼
canonical storage key
   │
   ▼
CourseDocument marked STORED
```

Suggested temporary key:

```text
_tmp/{upload_id}/source.pdf
```

The temporary object must not be considered a valid stored course document.

Only the canonical key referenced by a committed `CourseDocument` record is valid.

---

# Atomicity model

Storage and graph persistence may not share one database transaction.

Use a recoverable state machine.

Example:

```text
PENDING
→ UPLOADING
→ STORED_PENDING_COMMIT
→ STORED
```

Failure variants:

```text
UPLOAD_FAILED
COMMIT_FAILED
ORPHANED
DELETING
DELETED
```

---

# Recommended upload transaction

```text
1. Validate actor and course/version.
2. Create document_id.
3. Create upload attempt/idempotency record.
4. Write file to temporary storage key.
5. Calculate size and checksum.
6. Promote temporary object to canonical key.
7. Create/update CourseDocument metadata.
8. Connect HAS_SOURCE_DOCUMENT edge.
9. Mark document STORED.
10. Emit storage event.
11. Schedule later validation/extraction.
```

If step 7 or 8 fails after storage succeeds:

```text
mark/record object as orphan candidate
```

Do not silently lose track of the stored object.

---

# Idempotency

Uploads may be retried because of:

- client timeout;
- network failure;
- browser retry;
- duplicated walker invocation;
- server restart.

Support an idempotency key.

Suggested tuple:

```text
actor_id
track_version_id
client_upload_id
```

A repeated successful request must return the existing document result rather than storing a second identical object.

---

# Content checksum

Use SHA-256.

```text
checksum_sha256
```

Uses:

- duplicate upload detection;
- integrity verification;
- retry reconciliation;
- corruption detection;
- storage audit;
- replacement comparison.

Do not use checksum as the sole security validator.

Two files with the same checksum are identical bytes, but authorization still applies.

---

# Duplicate handling

Duplicate scope should initially be:

```text
same track version
AND same SHA-256
```

Possible outcome:

```text
DUPLICATE_DOCUMENT
```

The system may return the already-stored document rather than creating another object.

Do not perform global cross-lecturer deduplication unless privacy and tenancy implications are explicitly designed.

---

# File-size verification

Record size from the actual storage transfer.

Do not trust only the browser-provided file size.

Verify:

```text
client claimed size
actual received size
stored object metadata size
```

When inconsistent:

```text
STORAGE_INTEGRITY_MISMATCH
```

and do not hand the file to extraction.

---

# Integrity verification

The storage service should support:

```text
verify_integrity(document_id)
```

Checks:

```text
metadata exists
storage key exists
stored size matches expected size
checksum matches where configured
document belongs to expected track/version
```

Result:

```jac
obj StorageIntegrityResult {
    has valid: bool;
    has object_exists: bool;
    has size_matches: bool;
    has checksum_matches: bool;
    has error_code: str | None;
}
```

Checksum re-reading may be expensive for large cloud files.

Support policies such as:

```text
ON_UPLOAD
ON_EXTRACTION
ON_DEMAND
SAMPLED
```

For the first release:

- checksum during upload;
- size verification after write;
- checksum verification before first extraction when practical.

---

# One-active-document policy

From `39-course-document-upload.md`, the first release may support one active source document per draft course version.

Storage behavior must support replacement without destructive overwrite.

Do not write a replacement into the old object's storage key.

Bad:

```text
same key overwritten
```

Correct:

```text
old document_id → old immutable key
new document_id → new immutable key
```

Then metadata determines which document is active.

This preserves:

- audit history;
- rollback;
- processing traceability;
- reproducibility.

---

# Replacement workflow

```text
Existing active document
        │
        ▼
Upload replacement
        │
        ├── store new immutable object
        ├── verify new object
        ├── create new CourseDocument
        ├── mark old document REPLACED
        └── point course version to new active document
```

Only after successful replacement should cleanup policy consider old draft objects.

For published versions, retain historical source documents by default.

---

# Immutability rules

Once a file is stored under its canonical key:

```text
do not modify bytes in place
```

Any changed file must receive:

```text
new document_id
new storage_key
new checksum
```

Immutability simplifies:

- versioning;
- caching;
- extraction reproducibility;
- auditing;
- rollback.

---

# Public access policy

Course source documents must be private by default.

Do not configure:

```text
public-read
anonymous download
guessable public URL
```

Raw lecturer notes may contain:

- copyrighted course material;
- unpublished material;
- internal institutional content;
- personally identifying annotations.

Access must flow through authorized application logic.

---

# Signed URLs

If the configured backend supports signed or temporary URLs, use them only when needed.

Requirements:

- short expiry;
- authorization before generation;
- read-only permission;
- exact object scope;
- no directory listing;
- no permanent public URL;
- audit generation.

Do not store temporary signed URLs in `CourseDocument`.

---

# Learner access

Learners should not automatically receive raw source-document access.

Learners consume:

```text
approved curriculum
generated lessons
quizzes
activities
source references when permitted
```

Raw source notes require a separate explicit course-resource feature.

Therefore:

```text
learner raw-document download = DENY by default
```

---

# Lecturer access

A lecturer may retrieve documents only when policy evaluation confirms access to the owning course/version.

Required context:

```text
actor_id
track_id
track_version_id
document_id
required_permission
```

The storage layer must not trust only `document_id`.

Validate relationship:

```text
document
→ belongs to requested version
→ belongs to requested track
→ actor authorized for track
```

---

# Service contracts

## `CourseDocumentStorageService`

Conceptual methods:

```jac
obj CourseDocumentStorageService {
    def store_document(
        request: StoreCourseDocumentRequest
    ) -> StoredCourseDocument;

    def get_metadata(
        document_id: str
    ) -> StoredDocumentMetadata;

    def open_for_processing(
        context: AuthorizedDocumentContext
    );

    def delete_document(
        context: AuthorizedDocumentContext
    ) -> StorageDeleteResult;

    def verify_integrity(
        document_id: str
    ) -> StorageIntegrityResult;

    def exists(
        storage_key: str
    ) -> bool;

    def cleanup_orphan(
        orphan_id: str
    ) -> StorageCleanupResult;
}
```

Exact syntax should match the current Jac version.

---

# Request type

```jac
obj StoreCourseDocumentRequest {
    has document_id: str;

    has track_id: str;
    has track_version_id: str;

    has original_filename: str;
    has canonical_extension: str;
    has mime_type: str;

    has client_upload_id: str;

    has uploaded_by: str;
}
```

Do not pass arbitrary `storage_key` from the client.

The service generates it.

---

# Repository responsibilities

`CourseDocumentRepository` owns metadata/graph access.

Suggested operations:

```text
find_by_id
find_active_for_version
find_by_checksum_for_version
list_for_version
save_document
mark_stored
mark_replaced
mark_deleting
mark_deleted
find_orphan_candidates
has_protected_references
```

Storage service owns bytes.

Repository owns document metadata and graph relationships.

Do not mix responsibilities.

---

# Storage adapter

Create a thin adapter around `store()` if useful.

```text
DocumentBlobStore
```

Methods:

```text
upload
download
delete
list
move
copy
get_metadata
exists
```

The adapter provides:

- normalized errors;
- tracing;
- metrics;
- storage-key validation;
- backend independence.

---

# Local development storage

Use Jac's local storage backend where no scale storage backend is configured.

Suggested local path:

```text
./storage/course-documents/
```

Add storage directories to `.gitignore`.

Example:

```gitignore
/storage/
/uploads/
```

Never commit uploaded course files to Git.

---

# Container/deployment considerations

Local filesystem storage inside an ephemeral container is not durable unless backed by persistent storage.

Therefore:

```text
development:
local filesystem acceptable

single-server production:
persistent mounted volume may be acceptable

scaled/multi-pod production:
use configured shared durable object/blob storage
or a storage backend shared across replicas
```

Do not assume a file uploaded to one pod's local filesystem is visible to another pod.

This is especially important because later extraction work may run in a different process or pod.

---

# Storage startup validation

On application startup or health diagnostics, validate:

```text
storage backend can initialize
base path/container exists or can be created
write operation works when required
read operation works
delete test object works
```

Do not write permanent user content during a health check.

Use a temporary probe object.

Health states:

```text
HEALTHY
DEGRADED
UNAVAILABLE
```

If storage is unavailable:

- course uploads must fail safely;
- existing learning functionality should remain available where possible.

---

# Storage errors

Define stable error codes:

```text
STORAGE_UNAVAILABLE
STORAGE_WRITE_FAILED
STORAGE_READ_FAILED
STORAGE_DELETE_FAILED
STORAGE_MOVE_FAILED
STORAGE_METADATA_FAILED
STORAGE_KEY_INVALID
STORAGE_OBJECT_NOT_FOUND
STORAGE_INTEGRITY_MISMATCH
STORAGE_SIZE_MISMATCH
STORAGE_CHECKSUM_MISMATCH
STORAGE_DUPLICATE_DOCUMENT
STORAGE_DOCUMENT_PROTECTED
STORAGE_DOCUMENT_NOT_AVAILABLE
STORAGE_ORPHAN_CLEANUP_FAILED
STORAGE_CONFIGURATION_INVALID
```

Example safe response:

```json
{
  "ok": false,
  "error": {
    "code": "STORAGE_WRITE_FAILED",
    "message": "The course document could not be stored.",
    "retryable": true
  }
}
```

Do not return backend exception strings directly to users.

---

# Retry policy

Classify errors.

## Retryable

Examples:

```text
temporary storage service outage
network timeout
rate limit
transient backend error
```

## Non-retryable

Examples:

```text
invalid storage key
authorization denial
unsupported document type
protected published document deletion
```

Use bounded retries.

Conceptual:

```text
attempt 1
→ short backoff
attempt 2
→ longer backoff
attempt 3
→ fail and record retryable error
```

Do not retry indefinitely inside a request walker.

---

# Orphan detection

An orphan is a storage object that:

- exists in storage;
- is not referenced by a valid committed `CourseDocument`;
- has exceeded a safe grace period.

Possible causes:

```text
server crash after upload
database commit failure
network interruption
replacement transaction failure
manual backend operation
```

---

# Orphan registry

Optionally record pending objects:

```jac
node StorageOrphanCandidate {
    has orphan_id: str;
    has storage_key: str;
    has upload_id: str | None;
    has document_id: str | None;

    has reason: str;

    has detected_at: str;
    has eligible_for_cleanup_at: str;

    has cleanup_status: str;
}
```

Alternatively, maintain operational records outside the main curriculum graph.

Do not expose orphan records to learners.

---

# Orphan cleanup job

The cleanup job must:

1. find eligible orphan candidates;
2. recheck metadata references;
3. recheck active processing jobs;
4. enforce grace period;
5. delete only confirmed orphan objects;
6. record outcome;
7. emit metrics.

Never delete solely because an object is old.

---

# Temporary-file cleanup

Temporary objects older than the configured grace period may be removed when:

```text
no active upload attempt references them
AND no CourseDocument references them
AND no extraction process references them
```

Use a separate prefix:

```text
_tmp/
```

to make temporary cleanup bounded.

---

# Soft deletion and trash

Where practical:

```text
canonical object
→ _trash/{document_id}/{timestamp}/source.pdf
→ retention period
→ permanent deletion
```

Benefits:

- accidental deletion recovery;
- auditability;
- safer replacement behavior.

If the backend does not support atomic move, implement equivalent safe behavior using copy + verification + delete.

---

# Retention rules

Suggested initial policy:

## Draft documents

Old replaced draft source:

```text
retain for configurable grace period
then eligible for cleanup
```

## Published version documents

```text
retain indefinitely by default
```

because generated curriculum may need to remain reproducible.

## Archived course documents

Retention depends on:

- learner records;
- institutional policy;
- legal/copyright requirements;
- backup policy.

Archival must not automatically delete source files.

---

# Hard deletion guard

Before permanent deletion, verify:

```text
not active source document
not referenced by published version
not referenced by active extraction
not referenced by blueprint provenance
not under retention hold
authorization granted
```

If any condition fails:

```text
STORAGE_DOCUMENT_PROTECTED
```

---

# Backup policy

Production storage must have a documented recovery strategy.

At minimum define:

```text
durability expectations
backup/versioning behavior
restore procedure
retention
disaster recovery owner
```

Application logic must not assume backups exist unless the deployed storage configuration actually provides them.

---

# Disaster recovery

Recovery sequence:

```text
1. restore graph/database metadata
2. restore storage objects
3. run storage-reference audit
4. detect missing objects
5. detect unreferenced objects
6. verify checksums for critical published sources
7. mark unrecoverable documents appropriately
```

A restored database referencing a missing file must not silently proceed to extraction.

---

# Storage-reference audit

Create an operational audit function:

```text
audit_course_document_storage
```

Checks:

```text
every active CourseDocument has storage_key
every storage_key exists
stored size matches metadata
published source files exist
no active document points to trash/temp key
no duplicate active source per version
orphan candidates reported
```

Output:

```json
{
  "documents_checked": 124,
  "healthy": 122,
  "missing": 1,
  "integrity_mismatch": 1,
  "orphans": 3
}
```

---

# Concurrency

Two uploads may arrive simultaneously for the same version.

Prevent both from becoming active.

Use:

- revision/optimistic concurrency;
- upload lock;
- unique active-document invariant;
- serialized course-document service operation.

The storage backend alone cannot enforce domain uniqueness.

---

# Race example

```text
Upload A stores object
Upload B stores object
Upload A attempts activation
Upload B attempts activation
```

Expected:

```text
one document becomes active
the other becomes non-active/replaced/orphan candidate
no bytes are overwritten
no duplicate active source edge exists
```

---

# Storage key immutability

After a `CourseDocument` reaches `STORED`:

```text
storage_key must be immutable
```

Moving objects for trash/retention may update infrastructure metadata through a controlled deletion workflow, but normal business logic must never silently change a document's key.

---

# Storage metadata synchronization

Do not assume object-store metadata is always the same as graph metadata.

Treat:

```text
CourseDocument
```

as application metadata source of truth, and storage metadata as integrity evidence.

When they disagree:

```text
do not silently overwrite either
→ report integrity mismatch
```

---

# Extraction handoff contract

Later `42-document-text-extraction.md` must request the document through the storage service.

Expected flow:

```text
ExtractionService
→ resolve CourseDocument
→ authorize internal processing context
→ storage.verify_integrity()
→ storage.open_for_processing()
→ extract
```

The extraction service must not construct filesystem paths from `document_id`.

---

# Internal processing authorization

Background/internal processing should use a trusted service context.

Example:

```jac
obj DocumentProcessingContext {
    has job_id: str;
    has document_id: str;
    has track_id: str;
    has track_version_id: str;
    has operation: str;
}
```

Still verify:

```text
document belongs to track/version
job is active
document status allows processing
```

Trusted internal execution does not remove integrity checks.

---

# Frontend responsibilities

The frontend must not know:

- storage key;
- absolute path;
- bucket/container name;
- cloud credentials.

Frontend receives:

```text
document_id
original_filename
size_bytes
upload status
processing status
```

Example:

```json
{
  "document_id": "doc_123",
  "filename": "Database Systems Notes.pdf",
  "size_bytes": 2481932,
  "status": "STORED"
}
```

---

# Direct upload future option

A later optimization may use direct-to-object-storage uploads for very large files.

Possible flow:

```text
client
→ request authorized upload session
→ temporary signed upload target
→ storage
→ finalize walker
→ verify object
→ create CourseDocument
```

Do not implement this unless upload size/performance requires it.

The current abstraction should make this future change possible without changing the `CourseDocument` domain identity.

---

# Observability

Emit events:

```text
course_document.storage_started
course_document.storage_completed
course_document.storage_failed
course_document.storage_duplicate
course_document.integrity_checked
course_document.integrity_failed
course_document.downloaded
course_document.delete_started
course_document.deleted
course_document.delete_failed
course_document.orphan_detected
course_document.orphan_deleted
storage.backend_unavailable
```

Fields:

```text
document_id
track_id
track_version_id
actor_id
storage_operation
size_bytes
duration_ms
retry_count
error_code
request_id
```

Never log:

- file bytes;
- extracted text;
- signed URL secrets;
- credentials;
- absolute sensitive host paths.

---

# Metrics

Track:

```text
course_document_storage_upload_total
course_document_storage_upload_failed_total
course_document_storage_bytes_total
course_document_storage_read_total
course_document_storage_delete_total
course_document_storage_integrity_failure_total
course_document_storage_orphan_total
course_document_storage_cleanup_total
course_document_storage_operation_duration_ms
```

Useful dimensions:

```text
operation
result
mime_type
track_type
backend_type
```

Avoid high-cardinality labels such as `document_id`.

---

# Testing strategy

## Storage-key tests

Verify:

- valid key generation;
- no original filename in key;
- stable namespace;
- path traversal rejected;
- absolute paths rejected;
- `..` rejected;
- invalid extension rejected;
- IDs containing separators rejected.

## Local storage tests

Verify:

- write;
- read;
- metadata;
- delete;
- move/copy if used;
- object existence;
- nested directory creation.

Use temporary test directories.

---

# Upload persistence tests

```text
store valid PDF
→ metadata created
→ bytes exist
→ size matches
→ checksum matches
```

Repeat for DOCX.

---

# Integrity tests

Test:

- valid checksum;
- wrong checksum;
- wrong size;
- missing storage object;
- corrupted object;
- wrong storage key;
- document/version mismatch.

---

# Idempotency tests

Same:

```text
actor
track_version
client_upload_id
```

must not create duplicate storage objects.

---

# Duplicate-content tests

Upload identical bytes twice to same version.

Expected:

```text
duplicate detected according to policy
```

Upload identical bytes to different lecturer/course.

Do not expose the existence of another lecturer's document.

---

# Replacement tests

```text
upload A
activate A
upload B replacement
activate B
```

Verify:

- A remains immutable;
- B has new key;
- only B active;
- A retained according to policy.

---

# Concurrent upload tests

Simulate two simultaneous replacements.

Verify:

- exactly one active document;
- no overwrite;
- losing operation handled safely;
- orphan/non-active object tracked.

---

# Authorization tests

Verify:

```text
owner lecturer → allowed
other lecturer → denied
learner → denied raw access
admin with explicit permission → allowed
suspended lecturer → denied
```

---

# Published-document tests

Verify:

- cannot overwrite;
- cannot replace source in place;
- cannot hard-delete while protected;
- retrieval for internal processing remains possible.

---

# Orphan tests

Create:

```text
stored object with no CourseDocument
```

Verify:

- not deleted before grace period;
- detected;
- rechecked;
- deleted after eligibility;
- active object never deleted.

---

# Failure injection tests

Simulate:

```text
storage write fails
metadata commit fails
edge connection fails
move fails
delete fails
backend unavailable
server restart mid-upload
```

Verify recoverable states.

---

# Multi-instance tests

Where production can run multiple instances/pods:

- upload from instance A;
- read from instance B;
- verify storage is shared or deployment fails readiness policy;
- ensure local ephemeral storage is not incorrectly treated as shared.

---

# Security tests

Attempt:

```text
../../secret
absolute path
encoded traversal
null byte
fake extension
unauthorized document ID
other lecturer's track ID
direct guessed storage key
```

All must fail safely.

---

# Example Jac test outlines

```jac
test "course document keys are safe and deterministic" {
    # Build a key from trusted IDs.
    # Assert it remains inside course-documents namespace.
    # Assert original filename is not embedded.
}

test "stores immutable course document" {
    # Store validated bytes.
    # Verify storage metadata.
    # Verify checksum.
    # Attempt in-place overwrite through domain API.
    # Assert operation is rejected.
}

test "idempotent retry does not duplicate storage object" {
    # Call storage workflow twice with same client_upload_id.
    # Assert one CourseDocument and one canonical object.
}

test "published source document cannot be hard deleted" {
    # Create published version with source.
    # Attempt delete.
    # Assert STORAGE_DOCUMENT_PROTECTED.
}

test "orphan cleanup preserves referenced objects" {
    # Create an old object that is still referenced.
    # Run cleanup.
    # Assert it remains.
}
```

---

# Implementation sequence

## Step 1 — Audit current upload implementation

Identify whether `39` currently:

- writes files directly;
- uses temporary paths;
- uses Jac `store()`;
- stores bytes in metadata;
- exposes filesystem paths.

Remove direct backend coupling behind the new storage service.

## Step 2 — Introduce storage configuration

Configure:

```text
base path/backend
size limits
temp prefix
trash prefix
retention
orphan grace
```

## Step 3 — Add key builder

Centralize canonical key generation.

## Step 4 — Add storage adapter

Wrap `store()` operations with normalized errors and metrics.

## Step 5 — Add `CourseDocumentStorageService`

Implement:

```text
store
open
metadata
integrity
delete
cleanup
```

## Step 6 — Integrate with upload service

`39-course-document-upload.md` must delegate byte persistence to this service.

## Step 7 — Add recoverable upload states

Implement staged storage and commit recovery.

## Step 8 — Add checksum and size verification

Compute and persist authoritative storage metadata.

## Step 9 — Add replacement-safe immutable keys

Never overwrite existing source objects.

## Step 10 — Add orphan cleanup

Implement bounded cleanup with grace periods.

## Step 11 — Add storage audit

Verify metadata ↔ object consistency.

## Step 12 — Add tests

Run local storage, failure, integrity, concurrency, and authorization tests.

---

# Acceptance criteria

## Storage abstraction

- [ ] Course-document storage uses a dedicated service.
- [ ] Walkers do not call filesystem/cloud SDKs directly.
- [ ] Storage uses Jac `store()` or an approved equivalent adapter.
- [ ] Provider configuration is externalized.
- [ ] Local development storage works.

## Keys and immutability

- [ ] Storage keys are generated server-side.
- [ ] User filenames are not used as paths.
- [ ] Path traversal is impossible through key inputs.
- [ ] Stored source bytes are immutable.
- [ ] Replacements create new document IDs and keys.

## Integrity

- [ ] SHA-256 is stored.
- [ ] Actual byte size is stored.
- [ ] Integrity checks detect missing/corrupt objects.
- [ ] Extraction cannot start from an invalid storage object.

## Security

- [ ] Source documents are private by default.
- [ ] Raw storage paths are not exposed to clients.
- [ ] Learners cannot access lecturer source documents by default.
- [ ] Lecturer access requires course authorization.
- [ ] Signed URLs, if used, are temporary and scoped.

## Reliability

- [ ] Upload retries are idempotent.
- [ ] Metadata commit failures create recoverable orphan state.
- [ ] Temporary objects are cleaned safely.
- [ ] Orphan cleanup uses a grace period and reference recheck.
- [ ] Concurrent replacements result in one active document.

## Retention

- [ ] Published source files are protected.
- [ ] Archived tracks do not automatically lose source documents.
- [ ] Deletion has explicit retention guards.
- [ ] Replacement history remains auditable.

## Deployment

- [ ] Multi-instance deployments use shared durable storage.
- [ ] Ephemeral local pod storage is not treated as production durable storage.
- [ ] Backend health can be checked safely.
- [ ] Storage failure does not corrupt course metadata.

## Quality

- [ ] `jac check` passes.
- [ ] `jac check --lint` passes.
- [ ] `jac test` passes.
- [ ] Storage security tests pass.
- [ ] Failure-injection tests pass.
- [ ] Storage-reference audit passes.

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
1. Lecturer uploads a PDF.
2. CourseDocument stores metadata only, not file bytes.
3. Storage key is server-generated.
4. File exists in configured backend.
5. SHA-256 and byte size match.
6. Lecturer can retrieve their document through authorized flow.
7. Another lecturer cannot retrieve it.
8. Learner cannot retrieve raw notes by default.
9. Retrying upload does not duplicate the object.
10. Replacing the file creates a new immutable storage object.
11. Previous file is not overwritten.
12. Published source cannot be hard-deleted.
13. Temporary failed uploads become cleanup candidates.
14. Orphan cleanup does not delete referenced files.
15. Backend restart preserves document availability.
16. In a multi-instance deployment, another instance can access the same object.
17. Storage audit reports no missing or mismatched active documents.
```

---

# Expected result

After this specification is implemented:

- GraphLearn has a stable provider-agnostic course-document storage boundary.
- Lecturer files are persisted outside ordinary graph-node fields.
- Development can use local storage while production can use a shared configured backend.
- Walkers and domain services do not depend on a particular cloud provider.
- Uploaded documents use immutable server-generated storage keys.
- Checksums, sizes, retries, and orphan recovery make storage reliable.
- Published historical course versions retain reproducible source material.
- Raw lecturer notes remain private and authorization-controlled.
- The next document-security, extraction, chunking, and blueprint-generation specifications can consume files through one trusted storage service.
