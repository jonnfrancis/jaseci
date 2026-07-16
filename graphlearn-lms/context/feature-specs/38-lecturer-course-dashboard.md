# 38 — Lecturer Course Dashboard

## Overview

Implement the lecturer-facing course dashboard for GraphLearn LMS.

The dashboard is the primary workspace where an authenticated lecturer can:

- view every course they own or are authorized to manage;
- understand each course's current lifecycle state;
- continue incomplete course setup;
- identify courses requiring review or repair;
- open a course workspace;
- create a new course;
- archive or restore eligible courses;
- see high-level learner and course activity summaries when those data become available.

The dashboard must be built as a read-optimized projection over the existing learning-track, authorization, version, document-processing, publication, enrollment, and learner-progress services.

It must not create a second source of truth for course state.

---

## Status

- **Feature type:** Lecturer workspace and operational dashboard
- **Priority:** High
- **Depends on:**
  - `29-learning-track-domain-model.md`
  - `32-learning-track-osp-schema.md`
  - `33-track-repositories-and-services.md`
  - `35-user-roles-and-lecturer-profile.md`
  - `36-lecturer-authorization-policies.md`
  - `37-create-and-manage-course-track.md`
- **Blocks:**
  - lecturer document upload flow;
  - course-processing status UI;
  - blueprint review entry points;
  - publication controls;
  - lecturer analytics.
- **Primary implementation:** Jac backend and Jac Client frontend
- **Breaking changes allowed:** No
- **New persistence required:** Minimal; dashboard data should primarily be projected from existing graph state

---

## Problem statement

After lecturer identity and course creation are introduced, lecturers need one trusted place to understand and manage their courses.

Without a dashboard, lecturers would need to navigate directly to individual course routes without knowing:

- which courses are drafts;
- which courses need documents;
- which courses are processing;
- which courses require blueprint review;
- which courses are published;
- which courses failed processing;
- whether enrollment is open;
- how many learners are enrolled;
- what the recommended next action is.

The dashboard must turn distributed graph state into a clear, secure, actionable course-management view.

---

## Goals

Implement a lecturer dashboard that:

1. Lists every course the lecturer is authorized to view or manage.
2. Groups and filters courses by lifecycle state.
3. Shows each course's readiness and next required action.
4. Displays processing and publication status without exposing internal implementation details.
5. Allows lecturers to resume course setup from the correct step.
6. Provides safe entry points for course creation, editing, document upload, review, publication, and archival.
7. Uses authorization-aware backend projections.
8. Supports pagination, search, sorting, and empty states.
9. Avoids N+1 graph traversals and repeated expensive calculations.
10. Remains useful before advanced learner analytics are implemented.
11. Supports future collaborator and institution-managed courses.
12. Provides stable contracts for the Jac Client.

---

## Non-goals

This specification does not implement:

- document upload itself;
- PDF or DOCX processing;
- course-blueprint generation;
- blueprint editing;
- course publication logic;
- learner enrollment logic;
- detailed learner analytics;
- grading review workflows;
- collaborator invitations;
- institution administration;
- real-time websocket updates;
- destructive permanent course deletion.

The dashboard may expose navigation and status placeholders for these features, but the underlying operations belong to later specifications.

---

# Design principles

## 1. Projection, not duplication

The dashboard must derive course state from authoritative domain records.

Do not create a second mutable dashboard record containing copied course state such as:

```text
course title
course status
active version
processing status
enrollment count
```

A cache or materialized projection may be introduced later for performance, but it must be rebuildable from authoritative graph data.

## 2. Action-oriented information

Every course card or row should answer:

```text
What is this course?
What state is it in?
What needs to happen next?
Can I perform that action?
When was it last updated?
```

## 3. Authorization before projection

The backend must determine which courses the actor can see before returning summaries.

The frontend must not receive unauthorized courses and then filter them locally.

## 4. Status and readiness are different

A course may have:

```text
status = DRAFT
```

while its actual readiness issue is:

```text
No source document uploaded
```

The dashboard must expose both lifecycle status and readiness/next-action state.

## 5. Graceful partial data

The dashboard must remain usable when:

- no document exists;
- processing has not started;
- a processing job failed;
- no learners are enrolled;
- learner analytics are not yet available;
- a newer draft version exists beside a published version.

## 6. Stable typed contracts

The Jac Client should consume typed dashboard projections rather than traverse raw graph nodes.

---

# User stories

## Lecturer course discovery

As a lecturer, I want to see all courses I manage so that I can quickly resume work.

## Draft continuation

As a lecturer, I want to know what a draft course is missing so that I can complete setup.

## Processing visibility

As a lecturer, I want to see whether uploaded notes are processing, failed, or awaiting review.

## Published-course monitoring

As a lecturer, I want to see whether a published course is open for enrollment and how many learners are enrolled.

## Failure recovery

As a lecturer, I want failed courses to show a clear recovery action rather than appearing as generic errors.

## Course creation

As a lecturer, I want a clear “Create course” action from the dashboard.

## Search and filtering

As a lecturer with many courses, I want to search and filter by status, subject, or course code.

---

# Dashboard information architecture

The initial dashboard should contain:

```text
Lecturer dashboard
├── Header
│   ├── lecturer identity
│   ├── workspace title
│   └── create-course action
├── Summary cards
│   ├── total managed courses
│   ├── drafts/incomplete
│   ├── requiring review
│   ├── published
│   └── failed/attention required
├── Controls
│   ├── search
│   ├── lifecycle filter
│   ├── visibility filter
│   ├── subject filter
│   └── sort
├── Course list/grid
│   └── dashboard course summaries
└── Empty/error/loading states
```

Advanced learner analytics should be added later without changing the base course-summary contract unnecessarily.

---

# Dashboard summary model

## `LecturerDashboardSummary`

```jac
obj LecturerDashboardSummary {
    has lecturer_id: str;
    has display_name: str;

    has total_courses: int;
    has draft_courses: int;
    has processing_courses: int;
    has review_required_courses: int;
    has published_courses: int;
    has archived_courses: int;
    has failed_courses: int;

    has total_enrollments: int;
    has active_learners: int;

    has generated_at: str;
}
```

### Summary rules

- Counts must include only courses the actor is authorized to see.
- `total_courses` includes archived courses only when the dashboard query includes them or when explicitly documented.
- `total_enrollments` counts enrollment records, not unique users across all tracks, unless the field is renamed accordingly.
- `active_learners` must have a precise activity-window definition before it is populated.
- Until learner analytics exist, return explicit availability metadata rather than misleading zeroes.

Recommended optional availability fields:

```jac
has enrollment_metrics_available: bool = False;
has learner_activity_metrics_available: bool = False;
```

Do not represent “not implemented” as a factual zero.

---

# Course dashboard projection

## `LecturerCourseDashboardItem`

```jac
obj LecturerCourseDashboardItem {
    has track_id: str;
    has active_version_id: str | None;
    has draft_version_id: str | None;

    has title: str;
    has slug: str;
    has course_code: str | None;
    has subject_area: str | None;
    has academic_level: str | None;
    has short_description: str;

    has track_type: LearningTrackType;
    has status: LearningTrackStatus;
    has visibility: LearningTrackVisibility;
    has is_enrollment_open: bool;

    has active_version_number: int | None;
    has draft_version_number: int | None;

    has readiness_state: CourseReadinessState;
    has readiness_percent: int;
    has next_action: CourseDashboardAction;

    has source_document_count: int;
    has processing_state: CourseProcessingState | None;
    has processing_progress_percent: int | None;
    has processing_error_code: str | None;

    has enrollment_count: int | None;
    has active_learner_count: int | None;

    has created_at: str;
    has updated_at: str;
    has published_at: str | None;
    has archived_at: str | None;

    has actor_permissions: CourseDashboardPermissions;
}
```

The exact enum imports must match the prior domain specifications.

---

# Dashboard readiness model

Lifecycle status alone is insufficient for the dashboard.

Introduce a calculated readiness state.

## `CourseReadinessState`

```jac
enum CourseReadinessState {
    METADATA_INCOMPLETE,
    READY_FOR_DOCUMENT,
    DOCUMENT_UPLOADED,
    PROCESSING,
    PROCESSING_FAILED,
    REVIEW_REQUIRED,
    READY_TO_PUBLISH,
    PUBLISHED,
    PUBLISHED_WITH_DRAFT_UPDATE,
    ARCHIVED
}
```

### Meaning

| State | Meaning |
|---|---|
| `METADATA_INCOMPLETE` | Required course metadata is missing |
| `READY_FOR_DOCUMENT` | Metadata is valid and notes can be uploaded |
| `DOCUMENT_UPLOADED` | A source document exists but processing has not started or completed |
| `PROCESSING` | Extraction or blueprint processing is underway |
| `PROCESSING_FAILED` | The latest required processing operation failed |
| `REVIEW_REQUIRED` | A generated blueprint or course structure requires lecturer review |
| `READY_TO_PUBLISH` | Required review and validation are complete |
| `PUBLISHED` | The active version is published and no newer draft requires attention |
| `PUBLISHED_WITH_DRAFT_UPDATE` | A published version exists while a newer draft is being prepared |
| `ARCHIVED` | The track is archived |

The readiness state is a projection, not a stored lifecycle field.

---

## Readiness calculation

Create a service method:

```jac
def calculate_course_readiness(
    track: LearningTrack,
    versions: list[TrackVersion],
    document_summary: CourseDocumentSummary | None,
    processing_summary: CourseProcessingSummary | None,
    review_summary: CourseReviewSummary | None
) -> CourseReadinessProjection;
```

Suggested precedence:

```text
1. If track is ARCHIVED → ARCHIVED
2. If a blocking processing failure exists → PROCESSING_FAILED
3. If required metadata is incomplete → METADATA_INCOMPLETE
4. If processing is active → PROCESSING
5. If review is required → REVIEW_REQUIRED
6. If publication requirements pass → READY_TO_PUBLISH
7. If published and a newer draft exists → PUBLISHED_WITH_DRAFT_UPDATE
8. If published → PUBLISHED
9. If a source document exists → DOCUMENT_UPLOADED
10. Otherwise → READY_FOR_DOCUMENT
```

The precise order must be covered by tests because multiple conditions may be true at once.

---

# Readiness percentage

The dashboard may show a progress percentage for unpublished courses.

This value must be deterministic, transparent, and based on completed setup stages.

Suggested weighted stages:

| Stage | Weight |
|---|---:|
| Required metadata valid | 15 |
| Initial version valid | 10 |
| Track configuration valid | 10 |
| Source document uploaded | 15 |
| Text extraction completed | 10 |
| Course blueprint generated | 15 |
| Lecturer review completed | 15 |
| Publication validation passed | 10 |

Total:

```text
100
```

Published courses always report `100`.

Archived courses may retain their previous percentage or report `100` only when they were published before archival. Choose one behavior and document it consistently.

Do not let the frontend calculate readiness independently.

---

# Course next-action model

## `CourseDashboardAction`

```jac
enum CourseDashboardAction {
    COMPLETE_METADATA,
    UPLOAD_DOCUMENT,
    START_PROCESSING,
    VIEW_PROCESSING,
    RETRY_PROCESSING,
    REVIEW_BLUEPRINT,
    COMPLETE_PUBLICATION_CHECKS,
    PUBLISH_COURSE,
    VIEW_COURSE,
    VIEW_LEARNERS,
    CONTINUE_DRAFT_UPDATE,
    RESTORE_COURSE,
    NONE
}
```

The backend must derive the recommended action using:

- readiness state;
- course status;
- actor permissions;
- active and draft versions;
- processing state;
- publication readiness.

Example:

```text
readiness = REVIEW_REQUIRED
permission.can_review = true
next_action = REVIEW_BLUEPRINT
```

If the actor lacks the required permission:

```text
next_action = VIEW_COURSE
```

or `NONE`, depending on the actor's allowed access.

---

# Dashboard permissions projection

The frontend needs to know which controls may be shown, but the backend must still reauthorize every action.

## `CourseDashboardPermissions`

```jac
obj CourseDashboardPermissions {
    has can_view: bool;
    has can_edit_metadata: bool;
    has can_upload_document: bool;
    has can_start_processing: bool;
    has can_retry_processing: bool;
    has can_review_blueprint: bool;
    has can_publish: bool;
    has can_open_enrollment: bool;
    has can_close_enrollment: bool;
    has can_view_learners: bool;
    has can_archive: bool;
    has can_restore: bool;
}
```

These flags are display hints only.

A stale permission projection must never authorize a mutation.

---

# Processing-state projection

Later document specifications will define detailed processing jobs.

The dashboard should consume a stable summary contract.

## `CourseProcessingState`

```jac
enum CourseProcessingState {
    NOT_STARTED,
    QUEUED,
    EXTRACTING,
    CHUNKING,
    ANALYZING,
    GENERATING_BLUEPRINT,
    VALIDATING,
    COMPLETED,
    FAILED,
    CANCELLED
}
```

## `CourseProcessingSummary`

```jac
obj CourseProcessingSummary {
    has track_id: str;
    has track_version_id: str;
    has state: CourseProcessingState;
    has progress_percent: int | None;
    has current_stage_label: str | None;
    has error_code: str | None;
    has recoverable: bool;
    has started_at: str | None;
    has updated_at: str;
    has completed_at: str | None;
}
```

Dashboard rules:

- expose a safe error code, not a stack trace;
- expose whether retry is possible;
- use the latest relevant processing job for the draft version;
- ignore superseded jobs unless viewing history;
- do not combine jobs from different track versions.

---

# Dashboard query contract

## `LecturerDashboardQuery`

```jac
obj LecturerDashboardQuery {
    has search: str | None = None;
    has statuses: list[LearningTrackStatus] = [];
    has readiness_states: list[CourseReadinessState] = [];
    has visibilities: list[LearningTrackVisibility] = [];
    has subject_areas: list[str] = [];

    has include_archived: bool = False;

    has sort_by: LecturerCourseSort = LecturerCourseSort.UPDATED_AT;
    has sort_direction: SortDirection = SortDirection.DESC;

    has page: int = 1;
    has page_size: int = 20;
}
```

## `LecturerCourseSort`

```jac
enum LecturerCourseSort {
    UPDATED_AT,
    CREATED_AT,
    TITLE,
    STATUS,
    PUBLISHED_AT,
    ENROLLMENT_COUNT
}
```

## `SortDirection`

```jac
enum SortDirection {
    ASC,
    DESC
}
```

### Query rules

- Search must be trimmed.
- Search should match title, course code, slug, and subject area where supported.
- Page must be at least `1`.
- Page size must have a safe maximum, such as `100`.
- Unsupported sort fields must fail validation.
- Archived courses are excluded by default.
- Filters are applied after authorization scope is established.

---

# Dashboard response contract

## `LecturerDashboardResponse`

```jac
obj LecturerDashboardResponse {
    has summary: LecturerDashboardSummary;
    has courses: list[LecturerCourseDashboardItem];

    has page: int;
    has page_size: int;
    has total_items: int;
    has total_pages: int;

    has available_filters: LecturerDashboardFilterOptions;
    has generated_at: str;
}
```

## `LecturerDashboardFilterOptions`

```jac
obj LecturerDashboardFilterOptions {
    has statuses: list[LearningTrackStatus];
    has readiness_states: list[CourseReadinessState];
    has visibilities: list[LearningTrackVisibility];
    has subject_areas: list[str];
}
```

Available filters must be scoped to the actor's accessible courses.

Do not leak subject areas or statuses from unauthorized private courses.

---

# Repository contracts

## `LecturerDashboardRepository`

Create a read-focused repository or projection repository.

```jac
obj LecturerDashboardRepository {
    def list_authorized_course_refs(
        actor: ActorContext,
        query: LecturerDashboardQuery
    ) -> list[AuthorizedCourseRef];

    def count_authorized_courses_by_status(
        actor: ActorContext,
        include_archived: bool
    ) -> dict;

    def get_course_projection_data(
        track_id: str
    ) -> CourseProjectionData | None;

    def get_course_projection_batch(
        track_ids: list[str]
    ) -> list[CourseProjectionData];

    def get_filter_options(
        actor: ActorContext
    ) -> LecturerDashboardFilterOptions;
}
```

The repository may delegate to existing track, version, document, processing, enrollment, and authorization repositories.

Do not duplicate write operations in the dashboard repository.

---

## Batch projection requirement

Avoid this pattern:

```text
list 20 tracks
→ query version 20 times
→ query documents 20 times
→ query processing 20 times
→ query enrollments 20 times
```

Use bounded or batched traversals where possible.

The target should be a predictable number of repository operations per page.

Example:

```text
1. Resolve actor and authorization scope.
2. Query paginated course IDs.
3. Batch-load versions.
4. Batch-load document/process summaries.
5. Batch-load enrollment counts.
6. Build projections.
```

---

# Dashboard service

## `LecturerCourseDashboardService`

Suggested responsibilities:

```text
get_dashboard
get_dashboard_summary
list_course_items
calculate_course_readiness
calculate_readiness_percent
resolve_next_action
resolve_dashboard_permissions
resolve_filter_options
```

Conceptual contract:

```jac
obj LecturerCourseDashboardService {
    def get_dashboard(
        actor: ActorContext,
        query: LecturerDashboardQuery
    ) -> LecturerDashboardResponse;
}
```

### Service flow

```text
1. Validate actor authentication.
2. Verify lecturer workspace eligibility.
3. Validate query.
4. Resolve authorized course scope.
5. Load paginated course projection data.
6. Calculate readiness for each course.
7. Resolve actor-specific permissions.
8. Resolve next actions.
9. Calculate summary counts.
10. Return typed dashboard response.
```

The service must not trust a lecturer ID supplied by the client.

It must derive the lecturer identity from the authenticated actor context.

---

# Authorization behavior

The dashboard may include:

- courses owned by the lecturer;
- courses they are later invited to collaborate on;
- institution-managed courses they are authorized to manage;
- administrator-visible courses when using an administrative dashboard mode.

Initial implementation should return lecturer-owned tracks only unless collaborator policies already exist.

Required checks:

```text
actor is authenticated
actor has active lecturer role
lecturer profile is active/approved
actor can view each returned track
```

Pending or suspended lecturers:

- may receive a restricted workspace state;
- must not receive ordinary course-management actions;
- must not be treated as unauthenticated if a clearer status response is available.

---

# Private walker contracts

Use private authenticated walkers.

## `get_lecturer_course_dashboard`

```jac
walker get_lecturer_course_dashboard {
    has query: LecturerDashboardQuery;
}
```

Conceptual response:

```json
{
  "ok": true,
  "dashboard": {
    "summary": {},
    "courses": [],
    "page": 1,
    "page_size": 20,
    "total_items": 0,
    "total_pages": 0,
    "available_filters": {},
    "generated_at": "2026-07-16T08:00:00Z"
  }
}
```

## Optional `get_lecturer_dashboard_summary`

Only add a separate summary walker when the frontend genuinely needs independent refresh behavior.

Avoid unnecessary endpoint proliferation.

## Optional `get_course_dashboard_item`

May support refreshing one course card after a mutation:

```jac
walker get_course_dashboard_item {
    has track_id: str;
}
```

The walker must reauthorize access.

---

# Thin-walker requirements

The walker should:

1. obtain the authenticated actor;
2. parse the query;
3. call the dashboard service;
4. report the typed result;
5. map known errors safely.

The walker must not:

- manually traverse every course graph;
- calculate readiness itself;
- trust a client-provided lecturer ID;
- duplicate authorization policy;
- directly update course state.

---

# Dashboard route and frontend entry point

Suggested route:

```text
/lecturer/courses
```

Alternative:

```text
/lecturer/dashboard
```

Choose one route convention and use it consistently.

Course workspace route:

```text
/lecturer/courses/:trackId
```

Creation route:

```text
/lecturer/courses/new
```

---

# Frontend component structure

Suggested Jac Client/React structure:

```text
LecturerCourseDashboardPage
├── LecturerDashboardHeader
├── CourseSummaryCards
├── LecturerCourseToolbar
│   ├── CourseSearchInput
│   ├── CourseStatusFilter
│   ├── CourseReadinessFilter
│   ├── SubjectFilter
│   └── CourseSortControl
├── LecturerCourseCollection
│   ├── LecturerCourseCard
│   └── LecturerCourseRow
├── DashboardPagination
├── LecturerDashboardEmptyState
├── LecturerDashboardErrorState
└── CreateCourseButton
```

Use either cards or a table as the primary view initially.

Do not maintain two fully separate interaction models unless there is a strong usability requirement.

---

# Course card requirements

Each course card should show:

```text
course title
course code, when present
subject area
lifecycle badge
readiness label
readiness percentage
processing stage, when active
published/draft version information
last updated time
learner count, when available
recommended action
secondary menu
```

Example:

```text
Database Management Systems
CSC 220 · Computer Science

Review required                       70%
Version 1 draft
Updated 2 hours ago

[Review course]
```

Published course with a newer draft:

```text
Python Programming
Published · Enrollment open

Active: Version 1
Draft update: Version 2
120 enrollments

[Continue update]
```

---

# Status badges

Use separate visual labels for lifecycle and operational state where necessary.

Examples:

```text
Draft
Processing
Review required
Published
Archived
Failed
```

Do not rely on color alone.

Every badge must include readable text and accessible semantics.

---

# Dashboard actions

Primary action examples:

| Readiness state | Primary action |
|---|---|
| `METADATA_INCOMPLETE` | Complete details |
| `READY_FOR_DOCUMENT` | Upload notes |
| `DOCUMENT_UPLOADED` | Process notes |
| `PROCESSING` | View progress |
| `PROCESSING_FAILED` | Review error / Retry |
| `REVIEW_REQUIRED` | Review course |
| `READY_TO_PUBLISH` | Publish course |
| `PUBLISHED` | View course |
| `PUBLISHED_WITH_DRAFT_UPDATE` | Continue update |
| `ARCHIVED` | View archive / Restore |

Secondary menu actions may include:

- edit metadata;
- duplicate course;
- archive course;
- restore course;
- close enrollment;
- open enrollment;
- view learner list.

Only show actions permitted by the projection, and reauthorize when invoked.

---

# Summary cards

Initial summary cards:

```text
Total courses
Drafts
Needs review
Published
Needs attention
```

`Needs attention` may include:

- failed processing;
- invalid active-version state;
- missing required metadata;
- publication validation failures.

Do not count normal incomplete drafts as failures unless the product wording clearly distinguishes them.

---

# Search behavior

Search should support:

- course title;
- course code;
- subject area;
- slug where useful.

Requirements:

- debounce frontend input;
- enforce server-side limits;
- escape or safely process search values;
- use case-insensitive matching where supported;
- avoid searching raw uploaded document text from the dashboard.

---

# Sorting behavior

Default sorting:

```text
updated_at DESC
```

Supported sorts:

- recently updated;
- oldest updated;
- title A–Z;
- title Z–A;
- newest created;
- newest published;
- highest enrollment count when metrics are available.

Unavailable sorts must not appear in the frontend.

---

# Pagination

Use server-side pagination.

Initial defaults:

```text
page = 1
page_size = 20
maximum page_size = 100
```

The response must include total count and total pages.

Cursor pagination may replace page-based pagination later if performance requires it.

---

# Empty states

## No courses

Message:

```text
You have not created any courses yet.
Create your first course to upload notes and build an adaptive learning track.
```

Primary action:

```text
Create course
```

## No search results

Message:

```text
No courses match the current search and filters.
```

Action:

```text
Clear filters
```

## Only archived courses excluded

When useful, show:

```text
No active courses found. Archived courses are hidden.
```

Action:

```text
Show archived
```

---

# Loading states

Use skeleton placeholders for:

- summary cards;
- course list rows/cards;
- filter controls where options are server-derived.

Do not show fake zero counts while loading.

Preserve the previous result during background refresh when possible.

---

# Error states

Dashboard errors should distinguish:

```text
AUTHENTICATION_REQUIRED
LECTURER_ROLE_REQUIRED
LECTURER_PROFILE_PENDING
LECTURER_PROFILE_SUSPENDED
DASHBOARD_QUERY_INVALID
DASHBOARD_LOAD_FAILED
COURSE_PROJECTION_INVALID
```

Do not expose stack traces.

When one course projection fails, prefer returning the rest of the dashboard plus a safe warning when integrity permits.

Example partial warning:

```json
{
  "code": "COURSE_PROJECTION_SKIPPED",
  "track_id": "trk_...",
  "message": "One course could not be loaded."
}
```

Do not expose a private course ID to an actor who is not authorized to know it exists.

---

# Refresh behavior

The initial implementation may use:

- refresh on page entry;
- manual refresh;
- query invalidation after course mutations;
- optional polling only for courses in active processing states.

Suggested processing polling interval:

```text
5–15 seconds
```

Stop polling when processing reaches a terminal state.

Do not poll the entire dashboard rapidly when only one course is processing.

Prefer refreshing a single course card where supported.

---

# Caching

The dashboard is read-heavy and may use short-lived caching.

Suggested cache key inputs:

```text
actor_id
lecturer_profile_id
query filters
page
page size
sort
permission revision
```

Do not use only `lecturer_id` if collaborators or administrators can see overlapping course sets later.

Suggested TTL:

```text
15–60 seconds
```

Invalidate after:

- course creation;
- metadata update;
- document upload;
- processing state change;
- blueprint review completion;
- publication;
- enrollment-state change;
- archival or restoration;
- authorization change.

Permissions should be revalidated for sensitive mutations even when dashboard data is cached.

---

# Performance requirements

Target initial response performance in a normal deployment:

```text
p95 dashboard response under 1 second for 20 course items,
excluding cold infrastructure startup.
```

This is a target, not a guarantee.

Avoid:

- unbounded graph traversal;
- loading full document content;
- loading complete blueprints;
- loading full learner lists;
- calculating learner-level analytics synchronously per course;
- N+1 repository calls.

Only load summary projections.

---

# Data consistency rules

The dashboard must detect and safely represent inconsistent graph states.

Examples:

- track marked published without a valid active version;
- active version belonging to another track;
- multiple active draft versions where only one is permitted;
- processing job attached to a superseded version;
- enrollment open on an archived track.

Represent these as `needs attention` and emit integrity events.

Do not silently correct graph state in a read-only dashboard request.

Repairs must occur through dedicated services.

---

# Audit and observability

Emit structured events:

```text
lecturer_dashboard.requested
lecturer_dashboard.loaded
lecturer_dashboard.failed
lecturer_dashboard.partial_projection
lecturer_dashboard.course_action_selected
lecturer_dashboard.processing_poll_started
lecturer_dashboard.processing_poll_stopped
```

Recommended fields:

```text
actor_id
lecturer_profile_id
course_count
page
page_size
filters
sort
response_duration_ms
cache_hit
request_id
timestamp
```

Do not log:

- raw course notes;
- learner answers;
- private profile details not needed for debugging;
- access tokens.

Metrics:

```text
lecturer_dashboard_requests_total
lecturer_dashboard_failures_total
lecturer_dashboard_partial_results_total
lecturer_dashboard_response_duration_ms
lecturer_dashboard_cache_hits_total
lecturer_dashboard_courses_returned_total
```

---

# Security requirements

- The dashboard walker must be private/authenticated.
- Lecturer identity must come from the session.
- Every returned course must pass authorization.
- Filters must not expand authorization scope.
- Search must not reveal private course existence.
- Permission flags are non-authoritative UI hints.
- Mutation actions must reauthorize independently.
- Suspended lecturers must not receive management actions.
- Course errors must not expose source-document paths or internal stack traces.
- Pagination metadata must count only authorized results.

---

# Accessibility requirements

- Course status must not rely on color alone.
- Summary cards require accessible labels.
- Search input requires a label.
- Filter controls must be keyboard accessible.
- Course-card actions must have descriptive names.
- Processing progress must expose `aria-valuenow` where appropriate.
- Loading states must avoid excessive announcements.
- Error messages must be associated with the relevant region.
- Mobile course cards must preserve logical reading order.

---

# Responsive behavior

## Desktop

- summary cards in a horizontal grid;
- search and filters on one or two rows;
- table or multi-column card grid;
- visible key status and action controls.

## Tablet

- reduced summary-card columns;
- horizontally wrapping controls;
- course cards preferred over a dense table if needed.

## Mobile

- stacked summary cards or horizontally scrollable summary strip;
- full-width search;
- filters in a drawer or collapsible section;
- single-column course cards;
- primary action visible without opening a menu.

---

# Testing strategy

Use Jac tests for backend projections and frontend tests for rendering and interaction.

## Authorization tests

- active lecturer sees owned courses;
- learner-only user is rejected;
- pending lecturer receives the correct restricted state;
- suspended lecturer cannot manage courses;
- lecturer cannot see another lecturer's private course;
- administrator scope works only when explicitly enabled;
- pagination counts include authorized courses only.

## Summary tests

- counts each lifecycle state correctly;
- excludes archived tracks by default;
- includes archived tracks when requested;
- does not report unavailable learner metrics as factual zeroes;
- handles an empty course set.

## Projection tests

- returns correct course metadata;
- returns active and draft version numbers;
- returns enrollment state;
- returns safe processing summaries;
- never returns full source content;
- returns actor-specific permission hints.

## Readiness tests

- incomplete metadata maps to `METADATA_INCOMPLETE`;
- valid metadata without document maps to `READY_FOR_DOCUMENT`;
- active processing maps to `PROCESSING`;
- failed processing maps to `PROCESSING_FAILED`;
- generated blueprint maps to `REVIEW_REQUIRED`;
- approved valid draft maps to `READY_TO_PUBLISH`;
- published course maps to `PUBLISHED`;
- published course with newer draft maps to `PUBLISHED_WITH_DRAFT_UPDATE`;
- archived course maps to `ARCHIVED`;
- state precedence is deterministic.

## Next-action tests

- missing metadata recommends completion;
- missing document recommends upload;
- failed processing recommends retry only when permitted and recoverable;
- review state recommends blueprint review;
- ready course recommends publication only when actor may publish;
- published course recommends view course;
- archived course recommends restoration only when allowed.

## Query tests

- search matches title;
- search matches course code;
- status filter works;
- readiness filter works;
- subject filter works;
- sort direction works;
- invalid page values fail validation;
- page-size maximum is enforced;
- archived courses are hidden by default.

## Performance tests

- a page of 20 courses does not produce unbounded repository calls;
- batch projection is used;
- full document content is never loaded;
- dashboard remains bounded with many learners;
- cache invalidation occurs after relevant mutations.

## Integrity tests

- invalid active version produces a safe attention state;
- cross-track version mismatch is detected;
- duplicate drafts are reported;
- archived course with open enrollment is reported;
- read requests do not silently mutate invalid state.

## Frontend tests

- loading skeleton renders;
- empty state renders;
- search and filters update the query;
- course cards display correct status;
- disabled or hidden actions match permission projections;
- error state is accessible;
- mobile layout preserves the primary action;
- background refresh does not erase current content unnecessarily.

---

# Example Jac test outlines

```jac
test "lecturer dashboard returns only owned courses" {
    # Create two lecturers.
    # Create one private course for each lecturer.
    # Request the dashboard as lecturer A.
    # Assert only lecturer A's course is returned.
}

test "dashboard readiness detects review required" {
    # Create a lecturer course and valid draft version.
    # Attach completed processing and an unapproved blueprint.
    # Build the dashboard projection.
    # Assert readiness_state == REVIEW_REQUIRED.
    # Assert next_action == REVIEW_BLUEPRINT.
}

test "dashboard uses batched projection reads" {
    # Create multiple courses.
    # Execute the dashboard query.
    # Assert repository instrumentation remains within the expected bound.
}

test "archived courses are excluded by default" {
    # Create an active course and an archived course.
    # Query without include_archived.
    # Assert only the active course appears.
}
```

---

# Implementation sequence

## Step 1 — Confirm domain dependencies

Verify the current implementation of:

- lecturer actor context;
- track ownership;
- course status;
- track versions;
- course configuration;
- archive state.

## Step 2 — Define projection contracts

Add:

- dashboard query;
- dashboard summary;
- dashboard course item;
- readiness state;
- next action;
- permission projection;
- pagination metadata.

## Step 3 — Implement read repository

Create bounded and batched course-summary retrieval.

## Step 4 — Implement readiness calculator

Centralize readiness state and percentage calculation.

## Step 5 — Implement dashboard service

Coordinate authorization, queries, projections, summary counts, permissions, and next actions.

## Step 6 — Add private dashboard walker

Expose the typed dashboard response to Jac Client.

## Step 7 — Build the frontend page

Implement summary cards, controls, course collection, empty states, and loading/error behavior.

## Step 8 — Add refresh and invalidation

Refresh after course mutations and poll only relevant processing courses.

## Step 9 — Add observability

Track response duration, failures, partial projections, and cache behavior.

## Step 10 — Add tests

Cover authorization, readiness, filtering, pagination, performance, accessibility, and graph inconsistencies.

---

# Acceptance criteria

## Backend

- [ ] A private authenticated dashboard walker exists.
- [ ] Lecturer identity is derived from the authenticated session.
- [ ] Only authorized courses are returned.
- [ ] The response uses typed dashboard projections.
- [ ] Lifecycle status and readiness state are both returned.
- [ ] Readiness is calculated centrally.
- [ ] Next action is calculated centrally.
- [ ] Permission hints are actor-specific.
- [ ] Pagination, filters, search, and sorting work.
- [ ] Archived courses are excluded by default.
- [ ] Processing errors are safely summarized.
- [ ] Batch projection prevents N+1 graph access.

## Frontend

- [ ] Lecturer dashboard route exists.
- [ ] Create-course action is visible to authorized lecturers.
- [ ] Summary cards render accurate counts.
- [ ] Course cards or rows display required metadata.
- [ ] Search and filters work.
- [ ] Empty, loading, and error states are implemented.
- [ ] Primary action reflects backend `next_action`.
- [ ] Processing courses show progress safely.
- [ ] Archived courses can be shown explicitly.
- [ ] Responsive and accessible behavior is verified.

## Security

- [ ] Learner-only users cannot access the dashboard.
- [ ] Lecturers cannot see unauthorized private courses.
- [ ] Pagination totals do not leak unauthorized counts.
- [ ] Search does not reveal unauthorized course existence.
- [ ] Dashboard permissions do not replace mutation authorization.
- [ ] No source documents or stack traces are returned.

## Quality

- [ ] Jac type checking succeeds.
- [ ] Jac tests pass.
- [ ] Frontend tests pass.
- [ ] Performance tests confirm bounded projection queries.
- [ ] Graph-integrity edge cases produce safe states.
- [ ] Existing learner flows remain unaffected.

---

# Check when done

Run the commands supported by the installed project version:

```bash
jac check <entry-file>
jac check --lint <entry-file>
jac test
```

Run frontend checks:

```bash
npm run typecheck
npm run lint
npm run test
npm run build
```

Use the project's actual package manager and script names.

Manually verify:

```text
1. An active lecturer can open the dashboard.
2. A learner-only account cannot open it.
3. A lecturer sees only their authorized courses.
4. A new draft course appears immediately after creation.
5. The draft recommends completing metadata or uploading notes.
6. A processing course shows its current stage.
7. A failed course shows a safe recovery action.
8. A review-ready course links to the review workflow.
9. A published course shows enrollment state.
10. A published course with a new draft shows both versions.
11. Search and filters return correct results.
12. Archived courses are hidden until requested.
13. Empty, loading, and error states are usable.
14. Mobile layout preserves the primary course action.
15. Refreshing the backend preserves dashboard state.
```

---

# Expected result

After this specification is implemented:

- lecturers have one secure workspace for every course they manage;
- each course clearly communicates its lifecycle, readiness, and next action;
- incomplete and failed courses are easy to resume or repair;
- published courses can be monitored without loading learner-level detail;
- future document upload, processing, review, publication, enrollment, and analytics features have stable dashboard entry points;
- the dashboard remains a read projection over the authoritative Jac OSP graph rather than becoming a second source of truth.
