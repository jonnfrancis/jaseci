# 39-course-document-upload.md

## Overview

Implement secure PDF and DOCX upload for lecturer-created course tracks.

This specification introduces the document-ingestion entry point for lecturer courses while keeping upload, extraction, chunking, AI analysis, blueprint generation, review, and publication as separate concerns.

The upload flow must:

1. allow an authorized lecturer to upload course notes to a draft course/version;
2. validate the file before accepting it;
3. persist document metadata and an upload/processing record;
4. store the file through the configured storage abstraction;
5. connect the document to the correct learning track and track version in the OSP graph;
6. return a stable document identifier and processing state;
7. support idempotency and duplicate detection;
8. support safe retry after failure;
9. prevent unauthorized access to another lecturer's course documents;
10. hand the accepted document to later extraction and chunking workflows without performing those operations inline.

This specification does **not** extract text or generate curriculum.

---

## Status

- **Feature type:** Lecturer document ingestion
- **Priority:** Critical
- **Depends on:**
  - `29-learning-track-domain-model.md`
  - `32-learning-track-osp-schema.md`
  - `33-track-repositories-and-services.md`
  - `35-user-roles-and-lecturer-profile.md`
  - `36-lecturer-authorization-policies.md`
  - `37-create-and-manage-course-track.md`
- **Blocks:**
  - `40-course-document-storage.md`
  - `41-document-security-and-validation.md`
  - `42-document-text-extraction.md`
  - `43-document-content-chunking.md`
  - `44-document-processing-job-state.md`
- **Breaking change allowed:** No
- **Supported initial formats:** PDF, DOCX
- **Primary implementation:** Jac walkers/services plus storage adapter

---

## Core design principle

The upload request must remain narrow.

```text
Lecturer selects file
    ↓
Validate request and authorization
    ↓
Validate basic file metadata/signature
    ↓
Store source document
    ↓
Create CourseDocument node
    ↓
Create/initialize processing state
    ↓
Return document_id + status
```

The upload request must **not** synchronously perform:

```text
PDF text extraction
DOCX text extraction
chunking
embedding
LLM analysis
course blueprint generation
skill graph generation
publication
learner roadmap generation
```

These later stages must consume the persisted document asynchronously or through explicit follow-up walkers/services.

---

# Goals

Implement a course-document upload subsystem that:

- accepts PDF and DOCX files;
- validates course ownership before accepting the upload;
- validates target track and track-version state;
- validates file type and size;
- computes or records a checksum;
- stores files using a storage abstraction rather than direct arbitrary filesystem paths;
- creates a persistent `CourseDocument` node;
- connects the document to the correct `TrackVersion`;
- supports duplicate detection;
- supports retry-safe upload behavior;
- supports single-document initial release while remaining extensible to multiple documents later;
- returns stable typed responses to Jac Client;
- exposes safe errors without leaking filesystem or storage internals;
- creates the clean handoff required for later processing stages.

---

# Non-goals

Do not implement in this specification:

- PDF text extraction;
- DOCX text extraction;
- OCR;
- PowerPoint upload;
- image-only notes;
- ZIP archives;
- Google Docs import;
- URL scraping;
- document chunking;
- embeddings/vector indexing;
- byLLM course analysis;
- course blueprint generation;
- lecturer blueprint review;
- course publication;
- multi-document merge logic;
- learner access to source files.

---

# Supported file types

Initial support:

```text
.pdf
.docx
```

Accepted MIME types:

```text
application/pdf
application/vnd.openxmlformats-officedocument.wordprocessingml.document
```

Do not accept legacy `.doc` in the first version.

Do not rely on filename extension alone.

Validation must consider:

- declared MIME type;
- extension;
- file signature/magic bytes where available;
- parser compatibility in later stages.

Detailed content-security validation belongs to `41-document-security-and-validation.md`, but this upload feature must provide the validation hooks and reject obviously unsupported files.

---

# Domain model

## `CourseDocument`

Create or finalize the document node introduced in the OSP schema.

```jac
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

    has checksum_algorithm: str = "sha256";
    has checksum: str;

    has upload_status: CourseDocumentUploadStatus;
    has processing_status: CourseDocumentProcessingStatus;

    has uploaded_by: str;
    has uploaded_at: str;
    has updated_at: str;

    has processing_error_code: str | None = None;
    has processing_error_message: str | None = None;

    has is_active: bool = True;
    has deleted_at: str | None = None;
}
```

---

# Upload status enum

```jac
enum CourseDocumentUploadStatus {
    PENDING,
    UPLOADING,
    STORED,
    FAILED,
    DELETED
}
```

Meaning:

| Status | Meaning |
|---|---|
| `PENDING` | Metadata exists but storage write has not completed |
| `UPLOADING` | Upload/storage operation is in progress |
| `STORED` | File is durably stored and metadata is valid |
| `FAILED` | Upload/storage failed |
| `DELETED` | File has been logically deleted |

---

# Processing status enum

```jac
enum CourseDocumentProcessingStatus {
    NOT_STARTED,
    QUEUED,
    EXTRACTING,
    CHUNKING,
    ANALYZING,
    REVIEW_REQUIRED,
    COMPLETED,
    FAILED
}
```

This spec only initializes the processing state.

Typical successful upload result:

```text
upload_status = STORED
processing_status = NOT_STARTED
```

or, if processing is automatically queued:

```text
upload_status = STORED
processing_status = QUEUED
```

Choose one project-wide behavior and apply it consistently.

Recommended initial behavior:

```text
STORED + NOT_STARTED
```

Then trigger processing explicitly through the processing workflow in later specs.

---

# Graph relationships

## `HAS_SOURCE_DOCUMENT`

```jac
edge HAS_SOURCE_DOCUMENT {
    has attached_at: str;
    has attached_by: str;
}
```

Direction:

```text
TrackVersion → CourseDocument
```

The document must belong to a specific `TrackVersion`, not only the stable `LearningTrack`.

Reason:

- source notes can change between versions;
- learner roadmaps must remain version-isolated;
- published historical versions must remain auditable;
- a new upload for version 2 must not mutate version 1.

---

# Upload ownership model

A document is valid only when all are true:

```text
CourseDocument.track_id == LearningTrack.track_id
CourseDocument.track_version_id == TrackVersion.track_version_id
TrackVersion belongs to LearningTrack
Authenticated lecturer may edit that track/version
```

Do not trust scalar IDs alone.

Validate the graph relationship:

```text
LearningTrack
    └── HAS_TRACK_VERSION
          └── TrackVersion
```

before attaching:

```text
TrackVersion
    └── HAS_SOURCE_DOCUMENT
          └── CourseDocument
```

---

# Upload eligibility

A lecturer may upload a document only when:

- authenticated;
- lecturer role is active;
- lecturer owns the track or has explicit future collaborator permission;
- target track exists;
- target version belongs to the track;
- target version is editable;
- target version is not `PUBLISHED`, `SUPERSEDED`, or `ARCHIVED`;
- track is not archived;
- course has not exceeded configured document limits;
- file passes upload validation.

Recommended editable version statuses:

```text
DRAFT
REVIEW_REQUIRED
FAILED
```

`PROCESSING` may reject replacement uploads unless the current processing job is cancelled first.

---

# Published-version immutability

Never attach, replace, or remove source documents on a published version.

Invalid:

```text
Published TrackVersion v1
    + upload replacement notes
```

Correct:

```text
Published v1
    ↓ create new draft
Draft v2
    ↓ upload revised notes
```

If a lecturer tries to upload to a published version, return:

```text
TRACK_VERSION_IMMUTABLE
```

or a document-specific equivalent.

---

# Initial document-count policy

For the first release, support:

```text
1 active source document per draft track version
```

This keeps extraction and blueprint generation deterministic.

The schema must still support multiple documents later.

If an active document already exists, the lecturer must explicitly choose a replacement action.

Do not silently overwrite it.

---

# Replacement behavior

A replacement upload must:

1. verify the target version is editable;
2. verify ownership;
3. upload and validate the new file first;
4. persist the new document safely;
5. mark the previous document inactive only after the new document succeeds;
6. cancel or invalidate processing derived from the old document;
7. update track/version readiness state;
8. retain audit history.

Never delete the old document before the replacement succeeds.

Recommended behavior:

```text
old_document.is_active = false
new_document.is_active = true
```

Physical deletion may occur later through retention policy.

---

# Typed request contracts

## `UploadCourseDocumentInput`

```jac
obj UploadCourseDocumentInput {
    has track_id: str;
    has track_version_id: str;
    has original_filename: str;
    has mime_type: str;
    has file_size_bytes: int;
    has idempotency_key: str;
    has replace_existing: bool = False;
}
```

The actual connector/file object should be passed using the mechanism supported by the deployed Jac/Jac Client upload path rather than embedding file bytes in JSON.

---

# Typed response

## `CourseDocumentUploadResult`

```jac
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

    has error: ErrorResult | None = None;
}
```

Example success:

```json
{
  "ok": true,
  "document_id": "doc_a82f...",
  "track_id": "trk_course_dbms",
  "track_version_id": "trv_course_dbms_v1",
  "filename": "database-notes.pdf",
  "mime_type": "application/pdf",
  "file_size_bytes": 2412834,
  "upload_status": "STORED",
  "processing_status": "NOT_STARTED",
  "duplicate": false
}
```

---

# Walker contract

Create a private walker:

```text
upload_course_document
```

Conceptual form:

```jac
walker upload_course_document {
    has input: UploadCourseDocumentInput;
    # file payload handled through supported upload transport
}
```

The walker must remain thin.

Responsibilities:

```text
resolve authenticated actor
validate request shape
call authorization policy
call upload application service
report typed result
```

The walker must not:

- manually traverse the entire graph;
- write directly to arbitrary filesystem paths;
- parse PDF content;
- invoke byLLM;
- generate course modules;
- publish the track.

---

# Upload application service

Create:

```text
CourseDocumentUploadService
```

Responsibilities:

```text
validate_actor
resolve_track_context
validate_track_version_editability
validate_document_limit
validate_upload_metadata
normalize_filename
validate_basic_file_type
calculate_or_verify_checksum
check_duplicate
reserve_document_id
store_file
persist_document_node
attach_document_edge
handle_replacement
initialize_processing_state
emit_events
return_result
```

---

# Repository contracts

## `CourseDocumentRepository`

Suggested contract:

```jac
obj CourseDocumentRepository {
    def find_by_id(document_id: str) -> CourseDocument | None;

    def list_for_version(
        track_version_id: str,
        include_inactive: bool = False
    ) -> list[CourseDocument];

    def find_active_for_version(
        track_version_id: str
    ) -> CourseDocument | None;

    def find_by_checksum(
        track_version_id: str,
        checksum: str
    ) -> CourseDocument | None;

    def save(document: CourseDocument) -> None;

    def attach_to_version(
        version: TrackVersion,
        document: CourseDocument,
        actor_id: str
    ) -> None;

    def mark_inactive(document_id: str) -> None;
}
```

Repository methods must validate graph relationships where relevant.

---

# Storage adapter boundary

Do not couple the upload walker directly to local disk or a cloud provider.

Define an abstraction:

```text
CourseDocumentStorage
```

Suggested operations:

```text
put
exists
get_metadata
open/read
move
copy
delete
```

Detailed provider selection belongs to `40-course-document-storage.md`.

The upload service should only depend on this abstraction.

---

# Storage key design

Never use the raw filename as the storage key.

Recommended logical structure:

```text
course-documents/
  <track_id>/
    <track_version_id>/
      <document_id>/
        source.<ext>
```

Example:

```text
course-documents/
  trk_course_dbms/
    trv_course_dbms_v1/
      doc_f82d91/
        source.pdf
```

Benefits:

- avoids filename collision;
- prevents path traversal;
- supports version isolation;
- supports predictable cleanup;
- allows original filenames to remain metadata only.

---

# Filename handling

Store both:

```text
original_filename
normalized_filename
```

Example:

```text
Original: "DBMS Notes FINAL (2).pdf"
Normalized: "dbms-notes-final-2.pdf"
```

Rules:

- strip path components;
- reject null bytes;
- trim whitespace;
- restrict maximum length;
- preserve extension only after validation;
- never use user filenames as filesystem paths;
- sanitize for display separately from storage identity.

---

# File-size limits

Define configuration values:

```text
COURSE_DOCUMENT_MAX_BYTES
COURSE_DOCUMENT_MIN_BYTES
```

Suggested initial maximum:

```text
25 MB
```

The exact value should be configurable.

Reject files larger than the configured maximum before expensive processing.

Reject zero-byte files.

Return:

```text
DOCUMENT_TOO_LARGE
DOCUMENT_EMPTY
```

---

# Duplicate detection

Calculate a strong checksum, preferably:

```text
SHA-256
```

Use it to detect exact duplicate uploads.

## Same version duplicate

When the active document has the same checksum:

- do not create a second source document;
- return the existing document;
- mark `duplicate = true`;
- preserve idempotent behavior.

## Different version duplicate

The same file may legitimately be attached to a new draft version.

Do not automatically share mutable document nodes across versions.

Either:

- create a separate document metadata node pointing to deduplicated storage; or
- copy/reference the immutable stored object through the storage layer.

Keep graph ownership version-specific.

---

# Idempotency

Every upload request must include or derive an idempotency key.

Recommended scope:

```text
actor_id + track_version_id + idempotency_key
```

Repeated requests with the same key must not create duplicate document nodes.

Possible outcomes:

```text
first request → STORED
network retry → returns same document_id
```

If the same idempotency key is reused with a different file checksum, return:

```text
IDEMPOTENCY_CONFLICT
```

---

# Upload transaction pattern

Use a staged operation.

```text
1. Authorize
2. Validate metadata
3. Reserve document ID
4. Create PENDING metadata if needed
5. Write file to temporary/staging key
6. Verify size/checksum
7. Move/commit to durable storage key
8. Persist STORED metadata
9. Attach graph edge
10. Initialize processing status
11. Commit replacement state if applicable
12. Emit success event
```

Failure after step 5 must trigger cleanup or orphan reconciliation.

Never expose a document as `STORED` until durable storage succeeds.

---

# Failure recovery

## Storage write fails

Result:

```text
upload_status = FAILED
processing_status = NOT_STARTED
```

Store safe failure metadata.

Do not attach an invalid active source document.

## Metadata persistence fails after storage succeeds

Record an orphan-storage cleanup task or reconciliation marker.

Do not rely on manual cleanup.

## Graph edge creation fails

The document must not become active for the version.

Reconciliation should either:

- attach the valid stored document; or
- safely remove the orphaned file.

## Client disconnects

Idempotency must allow the client to retry and recover the existing result.

---

# Error codes

Required errors:

```text
COURSE_DOCUMENT_NOT_FOUND
COURSE_DOCUMENT_UPLOAD_FAILED
COURSE_DOCUMENT_UNSUPPORTED_TYPE
COURSE_DOCUMENT_TOO_LARGE
COURSE_DOCUMENT_EMPTY
COURSE_DOCUMENT_INVALID_FILENAME
COURSE_DOCUMENT_MIME_MISMATCH
COURSE_DOCUMENT_SIGNATURE_INVALID
COURSE_DOCUMENT_ALREADY_EXISTS
COURSE_DOCUMENT_LIMIT_REACHED
COURSE_DOCUMENT_REPLACEMENT_REQUIRED
COURSE_DOCUMENT_STORAGE_FAILED
COURSE_DOCUMENT_CHECKSUM_FAILED
COURSE_DOCUMENT_IDEMPOTENCY_CONFLICT
TRACK_NOT_FOUND
TRACK_VERSION_NOT_FOUND
TRACK_VERSION_MISMATCH
TRACK_VERSION_IMMUTABLE
TRACK_ARCHIVED
LECTURER_NOT_AUTHORIZED
```

Error response:

```json
{
  "ok": false,
  "error": {
    "code": "COURSE_DOCUMENT_UNSUPPORTED_TYPE",
    "message": "Only PDF and DOCX course documents are supported.",
    "details": {
      "allowed_extensions": ["pdf", "docx"]
    }
  }
}
```

Do not expose:

- filesystem paths;
- bucket credentials;
- cloud-provider internal errors;
- stack traces;
- malware-scan internals.

---

# Authorization policy

The upload service must call the authorization layer defined in `36-lecturer-authorization-policies.md`.

Required capability:

```text
COURSE_DOCUMENT_UPLOAD
```

Context should include:

```text
actor_id
lecturer_profile_id
track_id
track_version_id
track_owner_id
track_status
version_status
```

Authorization rules:

- owner lecturer: allowed on editable draft;
- unrelated lecturer: denied;
- learner-only user: denied;
- suspended lecturer: denied;
- administrator: only if explicit policy allows;
- published version: denied regardless of ownership.

---

# Processing handoff

After successful upload, return enough information for later processing:

```text
document_id
track_id
track_version_id
storage_key
mime_type
checksum
processing_status
```

The extraction service should consume `document_id`, not arbitrary client paths.

Correct:

```text
process_course_document(document_id)
```

Incorrect:

```text
process_course_document("C:\\Users\\...\\notes.pdf")
```

---

# Course readiness impact

Uploading a valid document changes course readiness.

Example readiness progression:

```text
NO_SOURCE_DOCUMENT
    ↓ upload succeeds
SOURCE_DOCUMENT_READY
    ↓ extraction begins later
PROCESSING
```

The track itself should remain:

```text
DRAFT
```

unless a later processing-state policy changes it explicitly.

Do not mark the course `PUBLISHED` after upload.

---

# Lecturer dashboard integration

The dashboard should surface upload state using backend projections.

Example card states:

```text
No notes uploaded
Upload in progress
Notes uploaded
Upload failed
Replacement required
Processing not started
```

Suggested next actions:

```text
UPLOAD_DOCUMENT
RETRY_UPLOAD
REPLACE_DOCUMENT
START_PROCESSING
VIEW_DOCUMENT
```

Do not compute permissions only in the frontend.

---

# Jac Client upload UI

Course workspace flow:

```text
Course Workspace
    ↓
Source Material section
    ↓
Choose PDF/DOCX
    ↓
Client-side preliminary validation
    ↓
Upload
    ↓
Progress indication
    ↓
Server validation
    ↓
Success / recoverable error
```

UI must display:

- supported types;
- max file size;
- selected filename;
- selected size;
- upload progress where transport supports it;
- validation errors;
- upload success;
- current active source document;
- replacement confirmation when applicable.

---

# Client-side validation

Client validation is only a usability feature.

It may check:

- extension;
- reported MIME type;
- file size;
- empty file.

The backend must repeat all security-relevant validation.

Never trust browser validation alone.

---

# Replacement UX

When a source document already exists:

```text
Current source:
Database Systems Notes.pdf
Uploaded: ...
Status: Ready
```

Selecting another file should show:

```text
Replace current source document?

Replacing the document will invalidate any unapproved generated curriculum
created from the current source.
```

Do not allow one-click silent replacement.

---

# Delete behavior

Physical deletion is not part of normal edit flow.

Implement logical deletion/inactivation first.

When allowed:

```text
is_active = false
upload_status = DELETED
```

Do not allow deletion when:

- version is published;
- active blueprint/curriculum is approved without an explicit invalidation flow;
- policy forbids it.

Detailed retention belongs to storage policy.

---

# Concurrency control

Prevent two simultaneous uploads from producing two active source documents.

Use one or more of:

- version revision checks;
- conditional persistence;
- per-version upload lock;
- idempotency key;
- unique active-document invariant.

Required invariant:

```text
At most one active source document per track version
```

for the initial release.

If concurrent uploads race, exactly one should become active.

The other should return a conflict or become inactive according to deterministic policy.

---

# Security controls

At minimum:

- private authenticated walker;
- lecturer role check;
- resource ownership check;
- draft-version check;
- extension allowlist;
- MIME allowlist;
- signature validation hook;
- size limits;
- filename sanitization;
- checksum verification;
- storage key generation server-side;
- no arbitrary path access;
- no executable file support;
- no macro-enabled Word formats;
- no archive extraction;
- no automatic rendering of uploaded HTML.

Further hardening belongs to `41-document-security-and-validation.md`.

---

# Observability

Emit structured events:

```text
course_document.upload_started
course_document.upload_completed
course_document.upload_failed
course_document.duplicate_detected
course_document.replaced
course_document.marked_inactive
course_document.storage_orphan_detected
course_document.reconciliation_completed
```

Recommended fields:

```text
document_id
track_id
track_version_id
actor_id
mime_type
file_size_bytes
checksum_prefix
upload_status
processing_status
duration_ms
request_id
```

Do not log:

- raw file contents;
- full extracted text;
- storage credentials;
- signed download URLs;
- access tokens.

---

# Metrics

Track:

```text
course_document_upload_attempts_total
course_document_upload_success_total
course_document_upload_failures_total
course_document_upload_bytes_total
course_document_duplicate_total
course_document_replacement_total
course_document_storage_failures_total
course_document_upload_duration_ms
```

Dimensions should remain bounded.

Useful labels:

```text
mime_type
result
storage_provider
```

Avoid high-cardinality labels such as `document_id` in metric dimensions.

---

# Testing strategy

## Upload validation tests

- accepts valid PDF;
- accepts valid DOCX;
- rejects `.exe`;
- rejects `.zip`;
- rejects legacy `.doc`;
- rejects zero-byte file;
- rejects oversized file;
- rejects MIME mismatch;
- rejects invalid filename;
- rejects unsupported signature.

## Authorization tests

- owner lecturer can upload to draft;
- unrelated lecturer cannot upload;
- learner cannot upload;
- suspended lecturer cannot upload;
- published version rejects upload;
- archived track rejects upload.

## Graph tests

- document attaches to correct track version;
- document cannot attach to version in another track;
- exactly one active document exists per version;
- detached document is not treated as valid source material;
- replacement keeps graph integrity.

## Idempotency tests

- same request retry returns same `document_id`;
- same idempotency key plus different checksum fails;
- duplicate checksum does not create duplicate active document;
- network retry after success is safe.

## Replacement tests

- replacement requires explicit flag;
- old file remains active if new upload fails;
- old document becomes inactive after successful replacement;
- unapproved processing state is invalidated;
- published source cannot be replaced.

## Storage-failure tests

- storage write failure produces safe error;
- metadata is not marked `STORED` prematurely;
- orphan storage is detected;
- failed upload can be retried;
- duplicate retry does not create multiple nodes.

## Persistence tests

- metadata survives restart;
- active-document relation survives restart;
- checksum survives restart;
- upload status survives restart.

## Frontend tests

- file picker accepts only expected types;
- size validation message appears;
- upload button disables during request;
- progress state displays;
- success displays document metadata;
- replacement confirmation appears;
- backend errors render safely.

---

# Example Jac test outlines

```jac
test "lecturer uploads a valid PDF to a draft course" {
    # Arrange authenticated lecturer and owned draft version.
    # Upload valid PDF metadata/payload through test adapter.
    # Assert CourseDocument exists.
    # Assert upload_status == STORED.
    # Assert processing_status == NOT_STARTED.
    # Assert version HAS_SOURCE_DOCUMENT document.
}

test "cannot upload to published track version" {
    # Arrange published version.
    # Attempt upload.
    # Assert TRACK_VERSION_IMMUTABLE.
    # Assert no document edge created.
}

test "duplicate retry is idempotent" {
    # Upload once with idempotency key.
    # Repeat same request.
    # Assert same document_id.
    # Assert one active CourseDocument.
}

test "failed replacement preserves original document" {
    # Arrange active source document.
    # Simulate replacement storage failure.
    # Assert old document remains active.
    # Assert no invalid replacement becomes active.
}
```

---

# Implementation sequence

## Step 1 — Finalize document domain types

Implement:

- `CourseDocument`;
- upload status enum;
- processing status enum;
- `HAS_SOURCE_DOCUMENT` edge;
- typed request/response objects;
- document error codes.

## Step 2 — Add repository

Implement:

- document lookup;
- active-document lookup;
- checksum lookup;
- save;
- attach;
- mark inactive.

## Step 3 — Add storage abstraction

Introduce interface only.

Provider implementation details follow in spec 40.

## Step 4 — Implement upload service

Include:

- actor resolution;
- authorization;
- version validation;
- metadata validation;
- idempotency;
- checksum;
- storage write;
- graph persistence;
- failure recovery.

## Step 5 — Add private walker

Implement `upload_course_document` as a thin adapter.

## Step 6 — Add replacement flow

Require explicit replacement intent.

## Step 7 — Integrate lecturer workspace

Show source-document state and upload actions.

## Step 8 — Add observability

Add logs, metrics, and audit events.

## Step 9 — Add tests

Cover authorization, graph integrity, failure, idempotency, replacement, and persistence.

---

# Acceptance criteria

## Domain

- [ ] `CourseDocument` is implemented.
- [ ] Upload and processing statuses are typed.
- [ ] Documents reference both `track_id` and `track_version_id`.
- [ ] `HAS_SOURCE_DOCUMENT` connects document to the correct version.

## Upload

- [ ] PDF upload works.
- [ ] DOCX upload works.
- [ ] Unsupported formats are rejected.
- [ ] Empty files are rejected.
- [ ] Size limit is enforced.
- [ ] Stable `document_id` is returned.
- [ ] Storage key is generated server-side.
- [ ] Checksum is recorded.

## Security

- [ ] Walker is private/authenticated.
- [ ] Only authorized lecturers may upload.
- [ ] Cross-course uploads are denied.
- [ ] Published versions cannot be modified.
- [ ] Filenames cannot control storage paths.

## Idempotency

- [ ] Retries do not duplicate documents.
- [ ] Duplicate checksum detection works.
- [ ] Idempotency conflicts are detected.

## Replacement

- [ ] Existing documents are not silently overwritten.
- [ ] Replacement requires explicit intent.
- [ ] Failed replacement preserves the old source.
- [ ] Successful replacement leaves only one active source.

## Failure handling

- [ ] Storage failure is recoverable.
- [ ] Metadata is not marked stored before durable write succeeds.
- [ ] Orphaned storage can be reconciled.
- [ ] Safe error responses are returned.

## UI

- [ ] Lecturer can select a PDF/DOCX.
- [ ] Validation feedback appears.
- [ ] Upload progress/loading state appears.
- [ ] Success state shows active document.
- [ ] Replacement confirmation works.

## Quality

- [ ] Jac checks pass.
- [ ] Jac tests pass.
- [ ] Graph integrity tests pass.
- [ ] Persistence tests pass.
- [ ] Authorization tests pass.

---

# Check when done

Run the project-appropriate commands:

```bash
jac check <entry-file>
jac check --lint <entry-file>
jac test
```

Then manually verify:

```text
1. Lecturer logs in.
2. Lecturer opens an owned draft course.
3. Lecturer selects a valid PDF.
4. Upload succeeds.
5. Stable document ID is returned.
6. Document metadata appears in course workspace.
7. Backend restart preserves the document relationship.
8. Uploading the same file again does not duplicate it.
9. Unrelated lecturer cannot upload to the course.
10. Published version rejects upload.
11. DOCX upload works.
12. Unsupported file types fail safely.
13. Failed replacement does not remove the previous source.
```

---

# Expected result

After this specification is complete:

- lecturers can securely attach course-note documents to editable course versions;
- uploaded files are version-isolated and graph-connected;
- document metadata is persistent and traceable;
- duplicate and retry behavior is safe;
- replacement does not corrupt existing course state;
- unauthorized users cannot upload to another lecturer's course;
- published versions remain immutable;
- source documents are ready for the storage, validation, extraction, chunking, and AI-processing specifications that follow.
