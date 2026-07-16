# 37-create-and-manage-course-track.md

## Overview

Implement the lecturer-facing course-track management workflow for GraphLearn LMS.

This feature allows an authorized lecturer to:

- create a new lecturer-owned course track;
- save it as a private draft;
- create its initial draft version;
- edit course metadata;
- retrieve course details;
- list their courses;
- duplicate an existing draft or published course into a new draft;
- archive or restore eligible course tracks;
- validate whether a course is ready for document upload, curriculum review, or publication.

The feature must reuse the generic `LearningTrack`, `TrackVersion`, `TrackConfiguration`, repositories, services, and authorization policies introduced in specifications 29–36.

It must not create a second course model specifically for lecturers.

The core creation path is:

```text
Authenticated lecturer
    → resolve trusted actor context
    → authorize CREATE_COURSE_TRACK
    → validate course metadata
    → create lecturer-owned LearningTrack
    → create TrackVersion version 1 as DRAFT
    → create TrackConfiguration
    → connect graph edges
    → persist aggregate
    → return lecturer-safe course projection
```

A newly created course is not visible to learners and is not open for enrollment.

---

## Status

- **Feature type:** Lecturer course-management use case
- **Subsystem:** Lecturer identity and course management
- **Priority:** Critical
- **Depends on:**
  - `29-learning-track-domain-model.md`
  - `30-programming-track-migration.md`
  - `31-track-aware-existing-models.md`
  - `32-learning-track-osp-schema.md`
  - `33-track-repositories-and-services.md`
  - `34-track-aware-walker-migration.md`
  - `35-user-roles-and-lecturer-profile.md`
  - `36-lecturer-authorization-policies.md`
- **Blocks:**
  - lecturer course dashboard;
  - course-document upload;
  - document processing;
  - blueprint generation;
  - lecturer blueprint review;
  - course publication;
  - learner course catalogue.
- **Primary implementation language:** Jac
- **Frontend:** Jac Client / React
- **Breaking changes allowed:** No
- **Migration required:** No destructive migration
- **Security review required:** Yes

---

## Goals

Implement a safe course-management workflow that:

1. Creates lecturer courses using the shared `LearningTrack` aggregate.
2. Derives ownership from the authenticated lecturer profile.
3. Creates a private, non-enrollable draft by default.
4. Creates exactly one initial draft track version.
5. Creates a validated track configuration.
6. Persists the complete graph atomically or through compensating rollback.
7. Allows authorized metadata edits without mutating published curriculum.
8. Supports course listing and retrieval through typed projections.
9. Supports safe archival and controlled restoration.
10. Protects system-owned and other lecturers' tracks.
11. Prevents duplicate submissions through idempotency keys.
12. Provides stable error codes and observability.
13. Keeps walkers thin and delegates business rules to services.
14. Preserves version and graph integrity.
15. Prepares the course for later document-upload and publication specifications.

---

## Non-goals

This specification does not implement:

- PDF or DOCX upload;
- document storage;
- text extraction;
- document chunking;
- byLLM curriculum generation;
- course blueprint review;
- learner enrollment;
- learner course catalogue;
- course publication approval;
- multiple lecturer collaborators;
- institution tenancy;
- bulk course import;
- full course analytics;
- grading-review workflows;
- deletion of published or referenced courses.

The course may expose readiness information for those later operations, but it must not implement them here.

---

# Domain boundaries

## Course-track aggregate

The course-management feature operates on this aggregate:

```text
LearningTrack
├── HAS_TRACK_VERSION → TrackVersion
└── HAS_TRACK_CONFIGURATION → TrackConfiguration
```

The `LearningTrack` is the stable course identity.

The `TrackVersion` represents editable or published curriculum state.

The `TrackConfiguration` controls supported assessment and activity capabilities.

Course creation must not create:

- learner enrollment edges;
- assessment attempts;
- roadmaps;
- mastery nodes;
- source-document nodes;
- generated skill nodes;
- generated lessons;
- generated quizzes.

---

## Shared versus versioned fields

### Track-level fields

These describe the course identity across versions:

```text
track_id
slug
track_type
ownership_type
owner_id
institution_id
status
visibility
active_version_id
current_version_number
is_enrollment_open
created_at
updated_at
published_at
archived_at
```

### Version-snapshotted metadata

These fields may be displayed on the track for convenience but must be copied into each new `TrackVersion` when versioning begins:

```text
title
short_description
course_code
subject_area
academic_level
estimated_duration_weeks
learning outcomes when later introduced
```

The initial version must capture at least:

```text
title_snapshot
description_snapshot
```

Later specifications may expand the snapshot.

---

# Required user journeys

## Journey 1: Create a new course

```text
Lecturer opens “Create course”
    → enters metadata
    → submits form
    → backend derives lecturer identity
    → validates lecturer status and permission
    → validates metadata
    → creates track aggregate
    → returns draft course
    → frontend navigates to course workspace
```

Expected result:

```text
track_type = LECTURER_COURSE
ownership_type = LECTURER
status = DRAFT
visibility = PRIVATE
is_enrollment_open = false
current_version_number = 1
active_version_id = null
version 1 status = DRAFT
```

---

## Journey 2: Edit draft metadata

```text
Lecturer opens owned draft
    → edits allowed metadata
    → submits update
    → backend checks ownership and revision token
    → validates values
    → updates track and draft snapshot
    → returns updated course
```

The operation must reject:

- another lecturer's course;
- system-owned tracks;
- published-version mutation;
- stale concurrent updates;
- invalid lifecycle state.

---

## Journey 3: View one owned course

```text
Lecturer requests course detail
    → resource resolved
    → authorization evaluated
    → aggregate and readiness state loaded
    → safe projection returned
```

Do not return raw graph internals or private data belonging to unrelated users.

---

## Journey 4: List lecturer courses

```text
Lecturer opens course dashboard
    → list walker resolves actor
    → repository filters by owner
    → optional status/search filters applied
    → stable paginated summaries returned
```

---

## Journey 5: Archive course

```text
Lecturer chooses archive
    → authorization and state validation
    → new enrollment disabled
    → track status set ARCHIVED
    → archive timestamp stored
    → historical references preserved
```

Archival is not destructive deletion.

---

## Journey 6: Restore archived draft

A lecturer may restore an archived course only when policy permits.

Initial restore policy:

- an archived course that was never published may return to `DRAFT`;
- a previously published course should require a later dedicated restore/publication policy;
- restoration never automatically reopens enrollment;
- active-version integrity must be revalidated.

---

# Course creation input

Define a typed input object.

```jac
obj CreateCourseTrackInput {
    has title: str;
    has short_description: str = "";
    has course_code: str | None = None;
    has subject_area: str | None = None;
    has academic_level: str | None = None;
    has estimated_duration_weeks: int | None = None;
    has default_difficulty: TrackDifficultyLevel = TrackDifficultyLevel.MIXED;
    has visibility: LearningTrackVisibility = LearningTrackVisibility.PRIVATE;
    has supports_diagnostic_assessment: bool = True;
    has supports_multiple_choice: bool = True;
    has supports_short_answer: bool = True;
    has supports_numeric_answer: bool = False;
    has supports_code_challenge: bool = False;
    has supports_essay: bool = False;
    has supports_project_activity: bool = False;
    has default_pass_score: float = 0.70;
    has mastery_threshold: float = 0.80;
    has max_assessment_questions: int = 20;
    has default_lesson_minutes: int = 30;
    has client_request_id: str | None = None;
}
```

Do not include these trusted fields in public client input:

```text
track_id
track_version_id
owner_id
lecturer_id
ownership_type
track_type
status
active_version_id
current_version_number
created_by
approved_by
published_at
is_enrollment_open
```

These values must be created or derived by the backend.

---

# Course update input

```jac
obj UpdateCourseTrackInput {
    has track_id: str;
    has title: str | None = None;
    has short_description: str | None = None;
    has course_code: str | None = None;
    has subject_area: str | None = None;
    has academic_level: str | None = None;
    has estimated_duration_weeks: int | None = None;
    has default_difficulty: TrackDifficultyLevel | None = None;
    has visibility: LearningTrackVisibility | None = None;
    has expected_revision: int;
    has client_request_id: str | None = None;
}
```

Use explicit patch semantics.

Omitted fields remain unchanged.

If a nullable field needs to be cleared, use one consistent strategy:

- an explicit `clear_fields` list; or
- a typed optional wrapper that distinguishes omitted from null.

Do not confuse “not supplied” with “clear this field.”

---

# Configuration update input

```jac
obj UpdateTrackConfigurationInput {
    has track_id: str;
    has supports_diagnostic_assessment: bool | None = None;
    has supports_multiple_choice: bool | None = None;
    has supports_short_answer: bool | None = None;
    has supports_numeric_answer: bool | None = None;
    has supports_code_challenge: bool | None = None;
    has supports_essay: bool | None = None;
    has supports_project_activity: bool | None = None;
    has default_pass_score: float | None = None;
    has mastery_threshold: float | None = None;
    has max_assessment_questions: int | None = None;
    has default_lesson_minutes: int | None = None;
    has expected_revision: int;
}
```

Configuration updates must be separate from general metadata updates if that improves validation and auditability.

---

# Additional model fields

Add optimistic-concurrency fields where they do not already exist.

## `LearningTrack`

```jac
has revision: int = 1;
has last_modified_by: str | None = None;
```

## `TrackVersion`

```jac
has revision: int = 1;
has last_modified_by: str | None = None;
```

## `TrackConfiguration`

```jac
has revision: int = 1;
has last_modified_by: str | None = None;
```

Every successful mutation increments the relevant revision.

A stale expected revision must return a conflict rather than silently overwriting a newer edit.

---

# Default course state

A newly created lecturer course must use these defaults:

```text
track_type = LECTURER_COURSE
ownership_type = LECTURER
owner_id = authenticated lecturer profile ID
status = DRAFT
visibility = PRIVATE
active_version_id = null
current_version_number = 1
is_enrollment_open = false
published_at = null
archived_at = null
```

Initial version:

```text
version_number = 1
status = DRAFT
source_kind = MANUAL
created_by = authenticated user ID
approved_by = null
published_at = null
```

When a source document is later uploaded, `source_kind` or source relationships may be updated according to the document-processing specification.

---

# Visibility rules

Initial course creation must allow only:

```text
PRIVATE
```

Optionally allow `INSTITUTION` only after institution access policies exist.

Do not allow a normal lecturer to create a `PUBLIC` course that appears to learners before publication.

Even when a future workflow allows a public visibility preference, discoverability must remain false until:

```text
status == PUBLISHED
active_version_id is valid
publication policy passes
```

---

# Metadata validation

Validation must occur in a central service.

## Title

Requirements:

- required;
- trimmed;
- not blank;
- minimum useful length;
- maximum length, for example 160 characters;
- reject control characters;
- reject title values containing only punctuation;
- preserve user-facing capitalization.

Recommended validation:

```text
3–160 characters after trimming
```

## Short description

Requirements:

- optional during creation;
- required before publication;
- maximum length, for example 1,000 characters;
- plain text initially;
- sanitized before display.

## Course code

Requirements:

- optional;
- trimmed;
- maximum length, for example 40 characters;
- allow letters, digits, spaces, hyphens, periods, underscores, and slashes;
- unique only if institution-level rules later require it.

Examples:

```text
CSC 220
MKT-101
BUS/STAT 201
```

## Subject area

Requirements:

- optional;
- trimmed;
- maximum length;
- not used as an authorization category.

## Academic level

Requirements:

- optional;
- trimmed;
- maximum length;
- stored as controlled text initially.

## Estimated duration

Requirements:

- optional;
- integer;
- greater than zero;
- no greater than a configured maximum such as 260 weeks.

## Scores

Requirements:

```text
0.0 <= default_pass_score <= 1.0
0.0 <= mastery_threshold <= 1.0
```

Recommended invariant:

```text
mastery_threshold >= default_pass_score
```

## Assessment question count

Requirements:

```text
1 <= max_assessment_questions <= configured maximum
```

## Lesson duration

Requirements:

```text
5 <= default_lesson_minutes <= configured maximum
```

## Activity support

At least one assessment or activity type must be enabled before publication.

Creation may allow all activity types to be false only when diagnostic assessment is disabled and the course is still a draft. Readiness validation must flag it.

---

# Slug generation

Generate the slug server-side from the title.

Process:

1. trim title;
2. lowercase;
3. safely normalize characters;
4. replace whitespace with hyphens;
5. remove unsupported characters;
6. collapse repeated hyphens;
7. remove leading/trailing hyphens;
8. check for conflicts;
9. add deterministic numeric suffix when needed.

Examples:

```text
Database Management Systems
→ database-management-systems

Database Management Systems
→ database-management-systems-2
```

A title update must not automatically change the slug unless an explicit slug-update feature is provided.

Stable links and identifiers must continue working after title edits.

---

# Idempotent creation

Course creation must accept an optional `client_request_id`.

Recommended idempotency scope:

```text
actor_id + operation + client_request_id
```

When the same lecturer retries the same request:

- return the existing successful result;
- do not create another track;
- do not create another version;
- do not create duplicate edges.

If the same idempotency key is reused with a materially different payload, return:

```text
IDEMPOTENCY_KEY_PAYLOAD_CONFLICT
```

Persist a request fingerprint and operation result reference.

---

# Duplicate-course behavior

Do not treat equal titles as duplicate identities.

A lecturer may legitimately create:

```text
Database Systems — Semester 1
Database Systems — Semester 2
```

The system should prevent only accidental repeated submission through idempotency.

Optionally warn when the lecturer owns another active course with the same normalized title and course code.

A warning must not automatically block creation unless a later institution policy requires uniqueness.

---

# Aggregate creation transaction

The complete operation must produce:

```text
LearningCatalogue
└── HAS_LEARNING_TRACK
    └── LearningTrack
        ├── HAS_TRACK_VERSION
        │   └── TrackVersion v1
        └── HAS_TRACK_CONFIGURATION
            └── TrackConfiguration
```

The operation is successful only when all required nodes and edges exist and pass integrity checks.

## Preferred atomic behavior

Perform creation in one transaction when supported by the persistence layer.

## Compensating behavior

When full atomic transactions are unavailable:

1. create a pending operation record;
2. create track;
3. connect catalogue edge;
4. create version;
5. connect version edge;
6. create configuration;
7. connect configuration edge;
8. validate aggregate;
9. mark operation complete.

On failure:

- disconnect or archive incomplete nodes where safe;
- record the failure;
- make retry idempotent;
- ensure partial aggregates do not appear in course lists.

Use an internal readiness marker if needed:

```text
aggregate_state = CREATING | READY | FAILED
```

Do not expose `CREATING` tracks as valid courses.

---

# Course lifecycle rules

## Create

Creates `DRAFT` only.

## Edit

Allowed when:

- actor owns the course or holds an authorized administrative permission;
- track is not system-owned;
- track is not archived unless restore/edit policy permits it;
- target version is editable;
- expected revision matches.

## Archive

Archival must:

- set `status = ARCHIVED`;
- set `is_enrollment_open = false`;
- set `archived_at`;
- increment revision;
- preserve all graph relationships and historical learner data.

## Restore

For an unpublished course:

```text
ARCHIVED → DRAFT
```

Restore must:

- clear or retain `archived_at` according to audit convention;
- never open enrollment automatically;
- revalidate graph integrity;
- increment revision;
- emit an audit event.

For a previously published course, restoration behavior is deferred to course publication/versioning specification.

## Delete

Hard deletion is not part of this specification.

A never-published, empty draft may be eligible for future purge by an administrative cleanup process, but normal lecturer operations use archival.

---

# Editing published courses

A published version is immutable.

When a lecturer wants to modify a published course, the system must eventually create a new draft version.

This specification should expose readiness for this future path but must not directly mutate published curriculum.

Allowed track-level edits on a published course should be conservative.

Recommended initial policy:

- descriptive catalogue metadata changes require a new draft or dedicated metadata policy;
- ownership and identity fields cannot be changed;
- enrollment may be closed through an explicit operation;
- published curriculum cannot be edited;
- archived published courses cannot be restored through the simple draft restore flow.

---

# Course duplication

Provide an optional duplicate operation for lecturer convenience.

```text
source course
    → validate read permission
    → create new lecturer-owned draft track
    → copy selected metadata and configuration
    → create new version 1
    → do not copy enrollments or learner data
```

Do not copy:

- learner enrollments;
- assessments;
- roadmaps;
- submissions;
- mastery;
- publication history;
- source documents unless later explicitly supported;
- generated grading decisions.

Suggested input:

```jac
obj DuplicateCourseTrackInput {
    has source_track_id: str;
    has new_title: str;
    has new_course_code: str | None = None;
    has copy_configuration: bool = True;
    has client_request_id: str | None = None;
}
```

The duplicate receives new IDs and starts as a private draft.

---

# Readiness model

Course management should return readiness information for later workflow steps.

```jac
obj CourseReadiness {
    has metadata_complete: bool;
    has configuration_valid: bool;
    has initial_version_valid: bool;
    has has_source_document: bool;
    has document_processing_complete: bool;
    has blueprint_available: bool;
    has blueprint_review_complete: bool;
    has publication_ready: bool;
    has blockers: list[str];
    has warnings: list[str];
}
```

In this specification, document and blueprint values may default to false based on graph inspection.

Example blockers:

```text
SHORT_DESCRIPTION_REQUIRED
NO_SOURCE_DOCUMENT
NO_CURRICULUM_BLUEPRINT
NO_SUPPORTED_ACTIVITY_TYPE
INVALID_ACTIVE_DRAFT
```

Do not treat readiness as authorization.

---

# Projections

## `LecturerCourseSummary`

```jac
obj LecturerCourseSummary {
    has track_id: str;
    has slug: str;
    has title: str;
    has short_description: str;
    has course_code: str | None;
    has subject_area: str | None;
    has academic_level: str | None;
    has status: LearningTrackStatus;
    has visibility: LearningTrackVisibility;
    has current_version_number: int;
    has active_version_id: str | None;
    has is_enrollment_open: bool;
    has readiness_stage: str;
    has created_at: str;
    has updated_at: str;
    has revision: int;
}
```

## `LecturerCourseDetail`

```jac
obj LecturerCourseDetail {
    has track: LecturerCourseSummary;
    has owner_id: str;
    has institution_id: str | None;
    has estimated_duration_weeks: int | None;
    has default_difficulty: TrackDifficultyLevel;
    has draft_version: TrackVersionSummary | None;
    has active_version: TrackVersionSummary | None;
    has configuration: TrackConfigurationView;
    has readiness: CourseReadiness;
    has available_actions: list[str];
}
```

## `TrackVersionSummary`

```jac
obj TrackVersionSummary {
    has track_version_id: str;
    has version_number: int;
    has status: TrackVersionStatus;
    has change_summary: str;
    has source_kind: TrackSourceKind;
    has created_at: str;
    has updated_at: str;
    has revision: int;
}
```

Do not return raw nodes and edges to the frontend.

---

# Available actions

Return server-calculated actions based on policy and state.

Examples:

```text
EDIT_METADATA
EDIT_CONFIGURATION
UPLOAD_DOCUMENT
VIEW_PROCESSING_STATUS
REVIEW_BLUEPRINT
ARCHIVE_COURSE
RESTORE_DRAFT
CREATE_NEW_VERSION
PUBLISH_COURSE
CLOSE_ENROLLMENT
```

The frontend may use these actions to render controls, but the backend must still reauthorize every request.

---

# Repository responsibilities

Extend or implement focused repository methods.

## `LearningTrackRepository`

```text
create_track
find_by_id
find_owned_by_id
find_by_slug
list_by_owner
list_by_owner_and_status
update_track_metadata
set_track_status
increment_revision
exists_slug
```

## `TrackVersionRepository`

```text
create_initial_version
find_draft_version
find_active_version
list_versions
update_draft_snapshot
set_version_status
increment_revision
```

## `TrackConfigurationRepository`

```text
create_default_configuration
find_by_track
update_configuration
increment_revision
```

## `LearningCatalogueRepository`

```text
get_default_catalogue
connect_track
contains_track
```

## `IdempotencyRepository`

```text
find_operation
begin_operation
complete_operation
fail_operation
```

Repository methods must:

- perform bounded OSP traversals;
- validate expected node and edge types;
- avoid authorization decisions except ownership-scoped lookup helpers;
- return typed domain results or nodes to services;
- not produce frontend reports directly.

---

# Service responsibilities

## `CourseTrackManagementService`

Suggested operations:

```text
create_course
get_course_detail
list_owned_courses
update_course_metadata
update_course_configuration
archive_course
restore_draft_course
duplicate_course
compute_course_readiness
```

The service coordinates:

- actor context;
- authorization policy;
- validation;
- repositories;
- graph integrity;
- idempotency;
- audit events;
- typed projections.

The service must not:

- parse HTTP details;
- trust client role fields;
- directly invoke document extraction;
- perform LLM blueprint generation;
- return raw persistence exceptions.

---

# Authorization requirements

Use policies from `36-lecturer-authorization-policies.md`.

Required actions:

```text
CREATE_COURSE_TRACK
VIEW_OWNED_COURSE
LIST_OWNED_COURSES
EDIT_COURSE_METADATA
EDIT_COURSE_CONFIGURATION
ARCHIVE_COURSE
RESTORE_DRAFT_COURSE
DUPLICATE_COURSE
```

## Creation

Actor must:

- be authenticated;
- have an active lecturer role assignment;
- have an active/approved lecturer profile;
- not be suspended;
- satisfy any future course quota policy.

## Editing

Actor must:

- own the course or hold explicit administrative permission;
- target a lecturer-owned track;
- target an editable lifecycle state;
- satisfy version immutability rules.

## Listing

List only resources the actor may view.

Do not load all tracks and filter only on the frontend.

## Not-found behavior

For a private course not owned by the actor, return a safe resource error according to the authorization policy.

Do not disclose:

- title;
- owner;
- version count;
- processing status;
- enrollment count.

---

# Walkers

Use private walkers for lecturer operations.

Suggested contracts:

```text
create_course_track
get_lecturer_course
list_lecturer_courses
update_course_track
update_course_track_configuration
archive_course_track
restore_course_track
 duplicate_course_track
```

Correct the accidental leading space in implementation; walker name must be `duplicate_course_track`.

---

## `create_course_track`

Conceptual Jac declaration:

```jac
walker:priv create_course_track {
    has input: CreateCourseTrackInput;

    can enter with entry {
        # Resolve actor from trusted auth session.
        # Call CourseTrackManagementService.create_course.
        # Report typed success or safe error.
    }
}
```

Success response:

```json
{
  "ok": true,
  "course": {
    "track_id": "trk_...",
    "slug": "database-management-systems",
    "title": "Database Management Systems",
    "status": "DRAFT",
    "visibility": "PRIVATE",
    "current_version_number": 1,
    "is_enrollment_open": false,
    "revision": 1
  },
  "next_action": "UPLOAD_DOCUMENT"
}
```

---

## `get_lecturer_course`

Input:

```jac
walker:priv get_lecturer_course {
    has track_id: str;
}
```

Returns:

- course detail;
- current draft version;
- configuration;
- readiness;
- available actions.

---

## `list_lecturer_courses`

Input:

```jac
walker:priv list_lecturer_courses {
    has status: LearningTrackStatus | None = None;
    has search: str | None = None;
    has subject_area: str | None = None;
    has page_size: int = 20;
    has cursor: str | None = None;
    has sort: str = "updated_desc";
}
```

Response:

```json
{
  "ok": true,
  "items": [],
  "next_cursor": null,
  "total_estimate": 0
}
```

Supported sort values should be allowlisted:

```text
updated_desc
created_desc
title_asc
title_desc
```

Do not accept arbitrary sort expressions.

---

## `update_course_track`

Input uses `UpdateCourseTrackInput`.

Required behavior:

1. resolve actor;
2. load course;
3. authorize edit;
4. check expected revision;
5. validate patch;
6. update track metadata;
7. update editable draft snapshot where required;
8. increment revisions;
9. audit changes;
10. return updated detail.

---

## `update_course_track_configuration`

Must validate capability combinations and revision.

Do not update published immutable version data.

---

## `archive_course_track`

Input:

```jac
walker:priv archive_course_track {
    has track_id: str;
    has expected_revision: int;
    has reason: str | None = None;
}
```

Archival reason must be length-limited and audit-safe.

---

## `restore_course_track`

Input:

```jac
walker:priv restore_course_track {
    has track_id: str;
    has expected_revision: int;
}
```

Restore only when allowed by state and publication history.

---

## `duplicate_course_track`

Creates a new draft aggregate with new IDs.

The service must use idempotency protection.

---

# Thin-walker flow

Every walker must follow:

```text
validate basic transport shape
    → resolve authenticated actor
    → call application service
    → convert service result to report
```

Walkers must not contain:

- duplicated ownership logic;
- graph traversal chains;
- slug collision loops;
- lifecycle transition rules;
- direct field mutation;
- LLM calls;
- raw persistence exception handling.

---

# Concurrency control

Use optimistic concurrency for all mutations.

Input includes:

```text
expected_revision
```

Update succeeds only when:

```text
stored_revision == expected_revision
```

On success:

```text
revision = revision + 1
```

On mismatch return:

```text
COURSE_REVISION_CONFLICT
```

Response should include the current server revision when safe:

```json
{
  "ok": false,
  "error": {
    "code": "COURSE_REVISION_CONFLICT",
    "message": "The course was updated by another operation.",
    "details": {
      "current_revision": 4
    }
  }
}
```

The frontend should reload before resubmitting.

---

# Error codes

Required stable errors:

```text
LECTURER_PROFILE_REQUIRED
LECTURER_PROFILE_INACTIVE
COURSE_CREATE_FORBIDDEN
COURSE_NOT_FOUND
COURSE_ACCESS_DENIED
COURSE_TITLE_REQUIRED
COURSE_TITLE_INVALID
COURSE_CODE_INVALID
COURSE_DURATION_INVALID
COURSE_CONFIGURATION_INVALID
COURSE_SLUG_CONFLICT
COURSE_ALREADY_ARCHIVED
COURSE_NOT_ARCHIVED
COURSE_RESTORE_NOT_ALLOWED
COURSE_EDIT_NOT_ALLOWED
COURSE_VERSION_IMMUTABLE
COURSE_REVISION_CONFLICT
COURSE_AGGREGATE_CREATION_FAILED
COURSE_AGGREGATE_INVALID
IDEMPOTENCY_KEY_PAYLOAD_CONFLICT
COURSE_LIST_FILTER_INVALID
COURSE_DUPLICATION_FAILED
```

Error responses must be safe and typed.

Do not expose:

- database IDs not intended for clients;
- stack traces;
- filesystem paths;
- internal graph traversal details;
- another lecturer's identity.

---

# Audit events

Emit structured events:

```text
course_track.create_started
course_track.created
course_track.create_failed
course_track.metadata_updated
course_track.configuration_updated
course_track.archived
course_track.restored
course_track.duplicated
course_track.readiness_changed
course_track.authorization_denied
course_track.revision_conflict
```

Recommended fields:

```text
request_id
client_request_id
actor_user_id
lecturer_profile_id
track_id
track_version_id
old_status
new_status
old_revision
new_revision
changed_fields
timestamp
```

Do not log full course descriptions when unnecessary.

For update events, log changed field names, not sensitive full values by default.

---

# Metrics

Recommended metrics:

```text
course_track_create_total
course_track_create_failure_total
course_track_update_total
course_track_archive_total
course_track_restore_total
course_track_duplicate_total
course_track_revision_conflict_total
course_track_authorization_denial_total
course_track_create_duration_ms
course_track_list_duration_ms
course_track_incomplete_aggregate_total
```

Label cardinality must remain controlled.

Do not use `track_id` as a high-cardinality metric label unless the observability platform explicitly supports it.

---

# Frontend requirements

## Create-course page

Suggested route:

```text
/lecturer/courses/new
```

Sections:

1. Course identity
   - title;
   - course code;
   - subject area;
   - academic level.

2. Course overview
   - short description;
   - expected duration;
   - default difficulty.

3. Learning and assessment capabilities
   - diagnostic assessment;
   - multiple choice;
   - short answer;
   - numeric answer;
   - code challenge;
   - essay;
   - project activity.

4. Scoring defaults
   - pass score;
   - mastery threshold;
   - maximum assessment questions;
   - expected lesson duration.

Keep the initial experience manageable. Advanced configuration may be collapsed or deferred to a second step.

---

## Course workspace route

Suggested route:

```text
/lecturer/courses/:trackId
```

Initial tabs or sections:

```text
Overview
Course setup
Source material
Curriculum
Publishing
```

Only `Overview` and `Course setup` are fully implemented by this specification.

Later sections may show locked or pending states.

---

## Draft state banner

Display:

```text
This course is a private draft. Learners cannot see or enroll in it.
```

Do not represent a saved draft as published.

---

## Save behavior

- disable repeated submit while a request is pending;
- send a stable client request ID for creation;
- show field-level validation errors;
- preserve entered data after recoverable failure;
- update local revision after successful save;
- handle revision conflicts by reloading or showing a comparison message.

---

## Archive behavior

Require a clear confirmation explaining:

```text
Archiving closes the course to new learner activity but preserves historical data.
```

Do not use destructive language such as “permanently delete” unless a real delete operation exists.

---

# Pagination and search

Course listing must support bounded pagination.

Cursor pagination is preferred over unbounded lists.

Search should initially match safe indexed or normalized fields:

```text
title
course_code
subject_area
```

Authorization and owner filtering must be applied before returning results.

Search input must be:

- trimmed;
- length-limited;
- safely handled by the repository;
- protected against injection into raw persistence queries.

---

# Graph integrity checks

After creation, verify:

1. track is connected to the catalogue;
2. track type is `LECTURER_COURSE`;
3. ownership type is `LECTURER`;
4. owner ID matches authenticated lecturer profile;
5. exactly one initial version edge exists;
6. version number is `1`;
7. version status is `DRAFT`;
8. exactly one configuration edge exists;
9. active version is null;
10. enrollment is closed;
11. track status is `DRAFT`;
12. no learner enrollment edge exists.

After updates, verify:

- graph relationships remain intact;
- version ownership remains consistent;
- no published version was mutated;
- revisions increment correctly.

---

# Security requirements

## Trusted ownership

Set ownership from:

```text
authenticated actor
→ active lecturer profile
→ lecturer_profile_id
```

Never use a client-supplied owner ID.

## Mass-assignment prevention

Explicitly allowlist editable fields.

Ignore or reject requests attempting to set:

```text
status
owner_id
track_type
ownership_type
active_version_id
published_at
is_enrollment_open
current_version_number
```

Prefer rejection with a validation error for unexpected privileged fields.

## Cross-course protection

Every update must validate:

```text
requested track
→ actual owner
→ actor authorization
```

## Published-version protection

No metadata update path may accidentally mutate a published version snapshot.

## Input limits

Apply limits to:

- title;
- description;
- course code;
- search query;
- archive reason;
- page size;
- client request ID.

## Rate limiting

Course creation and duplication should be rate-limited per authenticated lecturer when infrastructure supports it.

Rate limiting supplements authorization; it does not replace it.

---

# Persistence and recovery

## Incomplete aggregate recovery

Provide an internal repair operation or startup integrity check that identifies:

```text
track without catalogue edge
track without version
track without configuration
version with wrong parent
configuration with wrong track
creating operation that never completed
```

Incomplete tracks must not appear in normal lecturer lists unless a safe recovery state is deliberately shown.

## Retry

A retry with the same idempotency key must resume or return the prior operation where possible.

Do not create a second track after a timeout if the first operation succeeded but the response was lost.

---

# Testing strategy

Use Jac test blocks and service-level tests.

## Creation tests

- active lecturer can create a course;
- learner-only user cannot create a course;
- pending lecturer cannot create a course;
- suspended lecturer cannot create a course;
- owner is derived from session;
- client owner ID cannot override ownership;
- new course is private;
- new course is draft;
- enrollment is closed;
- version 1 is created;
- configuration is created;
- all required edges exist;
- aggregate integrity passes.

## Validation tests

- blank title is rejected;
- too-long title is rejected;
- invalid course code is rejected;
- duration zero is rejected;
- negative duration is rejected;
- score outside range is rejected;
- mastery below pass score is rejected if invariant enabled;
- invalid assessment-question count is rejected;
- unsafe privileged fields are rejected.

## Slug tests

- normal title produces expected slug;
- repeated spaces collapse;
- punctuation is normalized;
- duplicate slug receives suffix;
- editing title does not silently change slug.

## Idempotency tests

- repeated request ID returns same course;
- repeated request creates one version only;
- repeated request creates one configuration only;
- changed payload with same request ID is rejected;
- retry after simulated response loss returns existing result.

## Authorization tests

- owner can view course;
- owner can edit draft;
- another lecturer cannot view private course details;
- another lecturer cannot update course;
- normal lecturer cannot edit system track;
- administrator behavior follows explicit policy;
- private-resource errors do not leak metadata.

## Revision tests

- correct revision updates successfully;
- stale revision returns conflict;
- successful edit increments revision;
- failed validation does not increment revision;
- concurrent edits do not silently overwrite each other.

## Lifecycle tests

- draft can be archived;
- archived course closes enrollment;
- archived unpublished course may be restored to draft;
- restoration does not open enrollment;
- already archived operation is idempotent or returns stable error;
- published-course restore uses restricted path;
- hard deletion is unavailable.

## Duplication tests

- owner can duplicate owned course;
- duplicate receives new IDs;
- duplicate starts as private draft;
- duplicate copies allowed configuration;
- duplicate does not copy enrollments;
- duplicate does not copy learner records;
- duplicate is idempotent.

## Listing tests

- lecturer sees only owned courses;
- status filter works;
- subject filter works;
- search is bounded;
- pagination is stable;
- invalid sort is rejected;
- archived courses can be filtered;
- system tracks do not appear as lecturer-owned courses.

## Failure-injection tests

Simulate failure after:

- track creation;
- catalogue connection;
- version creation;
- version connection;
- configuration creation;
- configuration connection;
- audit event emission.

Verify:

- partial aggregate is not listed as ready;
- retry does not duplicate data;
- failure is observable;
- compensation or recovery succeeds.

## Persistence tests

- course survives backend restart;
- graph edges survive restart;
- idempotency record survives restart;
- revisions remain correct;
- archived course remains available historically.

---

# Example Jac test outlines

```jac
test "active lecturer creates a private draft course" {
    # Arrange authenticated lecturer and catalogue.
    # Invoke create-course service.
    # Assert track type, ownership, draft status, private visibility.
    # Assert version 1 and configuration exist.
    # Assert enrollment is closed.
}

test "course creation derives owner from session" {
    # Supply a malicious owner field if transport permits unknown values.
    # Assert stored owner equals authenticated lecturer profile.
}

test "course creation is idempotent" {
    # Submit same client_request_id twice.
    # Assert same track ID is returned.
    # Assert one aggregate exists.
}

test "stale metadata update is rejected" {
    # Load revision 1.
    # Apply first update to revision 2.
    # Attempt update using expected revision 1.
    # Assert COURSE_REVISION_CONFLICT.
}

test "another lecturer cannot edit private course" {
    # Create course owned by lecturer A.
    # Attempt update as lecturer B.
    # Assert safe authorization denial.
}
```

---

# Implementation sequence

## Step 1: Confirm domain fields

Verify that `LearningTrack`, `TrackVersion`, and `TrackConfiguration` contain all required creation, ownership, status, and revision fields.

## Step 2: Add typed contracts

Implement:

- creation input;
- metadata update input;
- configuration update input;
- summaries;
- detail projection;
- readiness object;
- stable error result.

## Step 3: Extend repositories

Add bounded create, read, list, update, archive, and revision-aware methods.

## Step 4: Implement aggregate creation

Create track, version, configuration, and required edges through a transaction or compensating workflow.

## Step 5: Implement idempotency

Protect creation and duplication from repeated requests.

## Step 6: Implement management service

Add creation, retrieval, listing, metadata update, configuration update, archive, restore, duplicate, and readiness operations.

## Step 7: Apply authorization policies

Use the central policy service for every operation.

## Step 8: Implement thin walkers

Expose private walker contracts and safe reports.

## Step 9: Implement lecturer UI

Add create-course form and course workspace overview/setup pages.

## Step 10: Add tests

Cover validation, authorization, idempotency, graph integrity, failure recovery, persistence, and concurrency.

## Step 11: Run regression suite

Verify that built-in programming tracks and learner flows remain unchanged.

---

# Acceptance criteria

## Course creation

- [ ] An active lecturer can create a lecturer-owned course.
- [ ] Ownership is derived from trusted session context.
- [ ] New course is `DRAFT`.
- [ ] New course is `PRIVATE`.
- [ ] New course is not enrollable.
- [ ] Version `1` is created as `DRAFT`.
- [ ] Track configuration is created.
- [ ] Required graph edges are created.
- [ ] Aggregate integrity validation passes.
- [ ] Creation is idempotent.

## Course management

- [ ] Owner can retrieve course detail.
- [ ] Owner can list owned courses.
- [ ] Owner can update editable metadata.
- [ ] Owner can update configuration.
- [ ] Owner can archive eligible course.
- [ ] Owner can restore eligible unpublished draft.
- [ ] Owner can duplicate a course into a new draft.
- [ ] Hard deletion is not exposed.

## Authorization

- [ ] Learner-only account cannot create courses.
- [ ] Pending or suspended lecturer cannot create courses.
- [ ] Lecturer cannot edit another lecturer's course.
- [ ] Lecturer cannot edit system-owned programming tracks.
- [ ] Unauthorized private-course access does not leak metadata.
- [ ] Published version immutability is preserved.

## Validation and concurrency

- [ ] Invalid metadata is rejected.
- [ ] Privileged field mass assignment is rejected.
- [ ] Slugs are unique and stable.
- [ ] Revision conflicts are detected.
- [ ] Failed updates do not increment revisions.
- [ ] Duplicate request IDs do not create duplicates.

## Quality

- [ ] Jac type checking passes.
- [ ] Jac linting passes or documented warnings are resolved.
- [ ] Jac tests pass.
- [ ] Graph integrity tests pass.
- [ ] Persistence tests pass.
- [ ] Failure-injection tests pass.
- [ ] Existing programming-track regression tests pass.

---

# Check when done

Run the commands supported by the installed Jac version:

```bash
jac check <entry-file>
jac check --lint <entry-file>
jac test
```

Manually verify:

```text
1. Log in as an approved lecturer.
2. Open the create-course page.
3. Create “Database Management Systems”.
4. Confirm the course is private and draft.
5. Confirm learners cannot see the course.
6. Confirm version 1 exists.
7. Confirm configuration exists.
8. Edit title, description, code, level, and duration.
9. Refresh and verify persistence.
10. Open the same course as another lecturer and verify denial.
11. Submit a stale edit and verify revision conflict.
12. Archive the course.
13. Confirm it remains stored but is not active.
14. Restore the unpublished draft.
15. Confirm enrollment remains closed.
16. Duplicate the course and verify new IDs.
17. Restart the backend and verify both courses persist.
18. Verify existing Python and Jaseci learner flows still work.
```

---

# Expected result

After implementing this specification:

- approved lecturers can create and manage private draft course tracks;
- lecturer courses use the same `LearningTrack` aggregate as programming tracks;
- ownership is derived securely from authenticated lecturer identity;
- every new course has an initial draft version and validated configuration;
- course creation is idempotent and graph-safe;
- metadata edits are revision-aware;
- published curriculum remains protected;
- archival preserves historical data;
- course details expose readiness for later document and blueprint workflows;
- the lecturer course dashboard and document-upload subsystem have a stable domain foundation.
