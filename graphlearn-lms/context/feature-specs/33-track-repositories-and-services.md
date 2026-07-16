# 33-track-repositories-and-services.md

## Overview

Implement the repository and service layer that sits between GraphLearn LMS walkers and the track-aware Object-Spatial Programming graph.

This specification builds on:

- `29-learning-track-domain-model.md`
- `30-programming-track-migration.md`
- `31-track-aware-existing-models.md`
- `32-learning-track-osp-schema.md`

The repository layer must provide focused, reusable graph-access operations. The service layer must coordinate domain rules and multi-step use cases. Walkers must remain thin entry points that validate transport-level input, resolve the authenticated actor, call a service, and report a typed response.

The architecture must prevent the following anti-patterns:

- duplicating graph traversals across walkers;
- performing raw persistence operations inside UI-facing walkers;
- mixing authorization, graph access, byLLM calls, and response formatting in one function;
- treating scalar IDs as sufficient proof of graph ownership;
- silently crossing track-version boundaries;
- creating separate repository stacks for programming and lecturer tracks;
- introducing generic repositories that expose unrestricted graph mutation.

The target flow is:

```text
Jac Client
    ↓ Spawn()
Walker
    ↓
Application service
    ↓
Domain service + repositories
    ↓
OSP graph and persistence
```

---

## Status

- **Feature type:** Architecture and application-layer foundation
- **Priority:** Critical
- **Depends on:** `32-learning-track-osp-schema.md`
- **Blocks:** Track-aware walkers, lecturer course management, document ingestion, course publication, enrollment, assessment, roadmap, lesson, grading, and analytics specifications
- **Breaking changes allowed:** No
- **Persistence migration required:** No new large migration beyond prior specifications, but repository adoption is required
- **Primary implementation language:** Jac
- **Primary architectural style:** Repository + domain service + application service

---

## Goals

Implement a repository and service layer that:

1. Centralizes graph traversal and persistence behavior.
2. Enforces track and version boundaries consistently.
3. Separates shared curriculum access from learner-specific progression access.
4. Reuses the same infrastructure for programming and lecturer-created tracks.
5. Keeps walkers thin and transport-focused.
6. Makes authorization checks explicit and reusable.
7. Supports idempotent creation and mutation operations.
8. Produces typed results and stable domain errors.
9. Supports migration-era fallback from legacy `language` values.
10. Enables unit, integration, graph-integrity, and regression testing.
11. Prevents cross-track and cross-version data leakage.
12. Supports observability, retries, and safe failure handling.

---

## Non-goals

This specification does not implement:

- lecturer authentication UI;
- PDF or DOCX parsing;
- document upload storage;
- byLLM course-blueprint generation;
- final course catalogue screens;
- final enrollment screens;
- final assessment generation logic;
- final roadmap generation logic;
- final lesson generation logic;
- final generalized grading logic;
- distributed transactions across external systems;
- a generic ORM-style abstraction over all Jac nodes.

This specification defines the architecture and contracts that later feature specifications will use.

---

# Architectural principles

## 1. Walkers are adapters

A walker should:

1. accept typed input;
2. resolve authentication context;
3. perform lightweight request validation;
4. call one application service;
5. map the result to a stable report;
6. avoid direct graph mutation where possible.

A walker should not:

- manually traverse the curriculum graph;
- construct repository queries inline;
- make multiple unrelated domain decisions;
- duplicate ownership checks;
- call byLLM and persistence directly in the same code path;
- return raw graph nodes to the client.

---

## 2. Repositories own graph access

Repositories are responsible for:

- locating nodes;
- validating expected graph relationships;
- performing bounded traversals;
- creating and connecting nodes through approved edges;
- reading and writing persistent graph state;
- detecting duplicate or inconsistent graph structures;
- returning domain nodes or typed projections.

Repositories must not decide business policy such as whether a track should be published or whether a learner deserves lesson access.

---

## 3. Domain services own invariants

Domain services are responsible for:

- enforcing lifecycle transitions;
- validating ownership combinations;
- validating version immutability;
- validating track-version alignment;
- validating enrollment eligibility;
- protecting published curriculum state;
- resolving safe domain mutations.

Domain services must not format frontend reports.

---

## 4. Application services coordinate use cases

Application services combine:

- authorization context;
- domain services;
- repositories;
- optional external services;
- idempotency;
- observability;
- result mapping.

Examples:

```text
CreateLearningTrackService
CreateTrackVersionService
PublishTrackVersionService
ListAvailableTracksService
ResolveTrackContextService
ArchiveLearningTrackService
```

---

## 5. Graph relationships are authoritative

A scalar field such as:

```text
track_id = trk_example
```

is useful for indexing and compatibility, but it does not prove graph ownership.

A repository must verify relationships such as:

```text
LearningTrack
    └── HAS_TRACK_VERSION
          └── TrackVersion
```

before accepting that the version belongs to the track.

---

## 6. Track-version boundaries are mandatory

Curriculum-sensitive operations must use both:

```text
track_id
track_version_id
```

A service must reject:

- a version belonging to another track;
- an archived or invalid active version;
- mutable writes to published curriculum;
- learner records connected to a mismatched enrollment version.

---

## 7. Narrow repositories over generic repositories

Prefer:

```text
LearningTrackRepository
TrackVersionRepository
CurriculumRepository
EnrollmentRepository
AssessmentRepository
RoadmapRepository
LessonRepository
ActivityRepository
SubmissionRepository
MasteryRepository
RecommendationRepository
```

Avoid one unrestricted repository such as:

```text
GraphRepository.create_any_node()
GraphRepository.connect_any_nodes()
GraphRepository.delete_any_edge()
```

A low-level graph utility may exist internally, but feature code must use focused repository contracts.

---

# Proposed module organization

Adapt to the existing codebase instead of duplicating equivalent modules.

```text
server/
├── repositories/
│   ├── learning_track_repository.jac
│   ├── track_version_repository.jac
│   ├── curriculum_repository.jac
│   ├── enrollment_repository.jac
│   ├── assessment_repository.jac
│   ├── roadmap_repository.jac
│   ├── lesson_repository.jac
│   ├── activity_repository.jac
│   ├── submission_repository.jac
│   ├── mastery_repository.jac
│   ├── recommendation_repository.jac
│   └── migration_repository.jac
├── services/
│   ├── track_context_service.jac
│   ├── learning_track_domain_service.jac
│   ├── learning_track_application_service.jac
│   ├── track_version_service.jac
│   ├── track_publication_service.jac
│   ├── enrollment_service.jac
│   ├── curriculum_query_service.jac
│   ├── learner_progress_service.jac
│   └── repository_transaction_service.jac
├── types/
│   ├── repository_results.jac
│   ├── service_results.jac
│   ├── pagination.jac
│   └── authorization_context.jac
└── tests/
    ├── repositories/
    ├── services/
    └── integration/
```

---

# Shared repository types

## `RepositoryError`

```jac
obj RepositoryError {
    has code: str;
    has message: str;
    has details: dict = {};
}
```

## `RepositoryResult`

Use a consistent result structure if the current codebase does not use exceptions for domain flow.

```jac
obj RepositoryResult {
    has ok: bool;
    has value: any | None = None;
    has error: RepositoryError | None = None;
}
```

Do not mix several incompatible error styles across repositories.

---

## `PageRequest`

```jac
obj PageRequest {
    has limit: int = 20;
    has cursor: str | None = None;
}
```

Validation:

- `limit` must be positive;
- enforce a maximum page size;
- cursors must be opaque to clients;
- do not expose internal node identifiers as cursors unless already safe and stable.

---

## `PageResult`

```jac
obj PageResult {
    has items: list;
    has next_cursor: str | None = None;
    has has_more: bool = False;
}
```

---

## `ActorContext`

```jac
obj ActorContext {
    has user_id: str;
    has learner_id: str | None = None;
    has lecturer_id: str | None = None;
    has roles: list[str] = [];
    has institution_ids: list[str] = [];
    has request_id: str;
}
```

Requirements:

- created from trusted authentication/session state;
- never accepted directly from frontend input;
- passed into application services;
- not persisted as ordinary domain state.

---

# Repository responsibilities

# `LearningTrackRepository`

Responsible for stable track identity and catalogue membership.

Suggested contract:

```jac
obj LearningTrackRepository {
    def get_catalogue() -> LearningCatalogue | None;

    def find_by_id(
        track_id: str
    ) -> LearningTrack | None;

    def find_by_slug(
        slug: str
    ) -> LearningTrack | None;

    def list_all(
        page: PageRequest
    ) -> PageResult;

    def list_visible(
        actor: ActorContext,
        filters: LearningTrackFilters,
        page: PageRequest
    ) -> PageResult;

    def list_owned_by(
        owner_id: str,
        page: PageRequest
    ) -> PageResult;

    def create_and_attach(
        catalogue: LearningCatalogue,
        track: LearningTrack
    ) -> LearningTrack;

    def update_metadata(
        track: LearningTrack,
        patch: LearningTrackMetadataPatch
    ) -> LearningTrack;

    def save(
        track: LearningTrack
    ) -> None;

    def has_catalogue_membership(
        track: LearningTrack
    ) -> bool;
}
```

### Required behavior

- query by stable ID first;
- validate catalogue membership;
- exclude detached tracks from normal listing;
- apply bounded filters;
- avoid loading full curriculum graphs for catalogue summaries;
- never delete a referenced track through a general repository method;
- keep publication and archival policy in services.

---

# `TrackVersionRepository`

Responsible for track-version lookup and graph ownership.

Suggested contract:

```jac
obj TrackVersionRepository {
    def find_by_id(
        track_version_id: str
    ) -> TrackVersion | None;

    def find_by_number(
        track_id: str,
        version_number: int
    ) -> TrackVersion | None;

    def list_for_track(
        track_id: str
    ) -> list[TrackVersion];

    def get_active_for_track(
        track: LearningTrack
    ) -> TrackVersion | None;

    def belongs_to_track(
        track: LearningTrack,
        version: TrackVersion
    ) -> bool;

    def create_and_attach(
        track: LearningTrack,
        version: TrackVersion
    ) -> TrackVersion;

    def save_draft(
        version: TrackVersion
    ) -> None;
}
```

### Required behavior

- verify `HAS_TRACK_VERSION` edge;
- reject scalar-only ownership mismatches;
- return versions in ascending or descending version order consistently;
- prevent repository APIs from modifying a published version;
- never activate a version directly; activation belongs to the publication service.

---

# `CurriculumRepository`

Responsible for shared curriculum graph traversal.

It may manage:

- curriculum modules;
- skills;
- prerequisites;
- lessons;
- activities;
- source references;
- track-version curriculum summaries.

Suggested contract:

```jac
obj CurriculumRepository {
    def list_modules(
        track_version_id: str
    ) -> list[CurriculumModule];

    def list_skills(
        track_version_id: str
    ) -> list[Skill];

    def find_skill(
        track_version_id: str,
        skill_id: str
    ) -> Skill | None;

    def list_prerequisites(
        track_version_id: str,
        skill_id: str
    ) -> list[Skill];

    def list_dependents(
        track_version_id: str,
        skill_id: str
    ) -> list[Skill];

    def topological_skill_order(
        track_version_id: str
    ) -> list[Skill];

    def detect_prerequisite_cycle(
        track_version_id: str
    ) -> list[str];

    def list_lessons_for_skill(
        track_version_id: str,
        skill_id: str
    ) -> list[Lesson];

    def list_activities_for_lesson(
        track_version_id: str,
        lesson_id: str
    ) -> list[LearningActivity];
}
```

### Required behavior

- every traversal is constrained by `track_version_id`;
- no cross-version prerequisite traversal;
- bounded traversal depth for recursive queries;
- deterministic ordering using edge or node order fields;
- cycle detection available before publication;
- summary methods must not pull source-document content unless requested.

---

# `EnrollmentRepository`

Responsible for learner-to-track relationships.

Suggested contract:

```jac
obj EnrollmentRepository {
    def find_active(
        learner_id: str,
        track_id: str
    ) -> Enrollment | None;

    def find_by_id(
        enrollment_id: str
    ) -> Enrollment | None;

    def list_for_learner(
        learner_id: str,
        page: PageRequest
    ) -> PageResult;

    def list_for_track_version(
        track_version_id: str,
        page: PageRequest
    ) -> PageResult;

    def create_and_attach(
        learner: Learner,
        track: LearningTrack,
        version: TrackVersion,
        enrollment: Enrollment
    ) -> Enrollment;

    def save(
        enrollment: Enrollment
    ) -> None;
}
```

### Required behavior

- validate learner, track, and version relationships;
- prevent duplicate active enrollment for the same learner and track unless explicitly allowed;
- preserve historical enrollments;
- avoid silently migrating an active enrollment to a newer version;
- ensure child learner records inherit the enrollment context.

---

# `AssessmentRepository`

Responsible for assessment records and attempts.

Suggested contract:

```jac
obj AssessmentRepository {
    def find_by_id(
        assessment_id: str
    ) -> Assessment | None;

    def find_active_for_enrollment(
        enrollment_id: str
    ) -> Assessment | None;

    def list_attempts(
        assessment_id: str
    ) -> list[AssessmentAttempt];

    def create_for_enrollment(
        enrollment: Enrollment,
        assessment: Assessment
    ) -> Assessment;

    def create_attempt(
        assessment: Assessment,
        attempt: AssessmentAttempt
    ) -> AssessmentAttempt;

    def save_result(
        attempt: AssessmentAttempt
    ) -> None;
}
```

### Required behavior

- assessment context derives from enrollment;
- attempts cannot cross assessment or version boundaries;
- completed attempts remain immutable except for explicit correction workflows;
- repository methods do not generate questions or score answers.

---

# `RoadmapRepository`

Responsible for learner roadmaps and roadmap items.

Suggested contract:

```jac
obj RoadmapRepository {
    def find_by_id(
        roadmap_id: str
    ) -> Roadmap | None;

    def find_active_for_enrollment(
        enrollment_id: str
    ) -> Roadmap | None;

    def list_items(
        roadmap_id: str
    ) -> list[RoadmapItem];

    def create_for_enrollment(
        enrollment: Enrollment,
        roadmap: Roadmap,
        items: list[RoadmapItem]
    ) -> Roadmap;

    def update_item_status(
        item: RoadmapItem,
        new_status: str
    ) -> None;

    def save(
        roadmap: Roadmap
    ) -> None;
}
```

### Required behavior

- one active roadmap per enrollment unless versioned roadmap history explicitly permits more;
- roadmap and items share the same track version;
- item order is deterministic;
- active roadmap replacement is explicit;
- repository does not decide roadmap personalization.

---

# `LessonRepository`

Responsible for shared base lessons and learner-specific lesson instances where both exist.

Suggested contract:

```jac
obj LessonRepository {
    def find_shared_lesson(
        track_version_id: str,
        lesson_id: str
    ) -> Lesson | None;

    def find_by_skill(
        track_version_id: str,
        skill_id: str
    ) -> list[Lesson];

    def find_learner_instance(
        enrollment_id: str,
        lesson_id: str
    ) -> LearnerLesson | None;

    def create_shared_lesson(
        track_version: TrackVersion,
        skill: Skill,
        lesson: Lesson
    ) -> Lesson;

    def create_learner_instance(
        enrollment: Enrollment,
        lesson: Lesson,
        instance: LearnerLesson
    ) -> LearnerLesson;

    def save_learner_progress(
        instance: LearnerLesson
    ) -> None;
}
```

### Required behavior

- distinguish shared lesson content from learner progress;
- shared published lessons are immutable;
- learner lesson state references the correct enrollment and track version;
- generated lesson caching uses track version and skill context.

---

# `ActivityRepository`

Responsible for quizzes, challenges, and generalized activities.

Suggested contract:

```jac
obj ActivityRepository {
    def find_by_id(
        activity_id: str
    ) -> LearningActivity | None;

    def list_for_lesson(
        track_version_id: str,
        lesson_id: str
    ) -> list[LearningActivity];

    def create_for_lesson(
        lesson: Lesson,
        activity: LearningActivity
    ) -> LearningActivity;

    def save(
        activity: LearningActivity
    ) -> None;
}
```

The repository must not grade learner responses.

---

# `SubmissionRepository`

Responsible for learner submissions and grading state.

Suggested contract:

```jac
obj SubmissionRepository {
    def find_by_id(
        submission_id: str
    ) -> Submission | None;

    def list_for_activity(
        enrollment_id: str,
        activity_id: str
    ) -> list[Submission];

    def create(
        enrollment: Enrollment,
        activity: LearningActivity,
        submission: Submission
    ) -> Submission;

    def save_grade(
        submission: Submission
    ) -> None;

    def list_pending_review(
        track_id: str,
        page: PageRequest
    ) -> PageResult;
}
```

### Required behavior

- submission track context must match enrollment and activity;
- grading updates are auditable;
- raw submitted content is not included in broad list queries;
- pending-review queries apply lecturer authorization later.

---

# `MasteryRepository`

Responsible for learner-skill mastery records.

Suggested contract:

```jac
obj MasteryRepository {
    def find_for_skill(
        enrollment_id: str,
        skill_id: str
    ) -> Mastery | None;

    def list_for_enrollment(
        enrollment_id: str
    ) -> list[Mastery];

    def upsert_for_skill(
        enrollment: Enrollment,
        skill: Skill,
        mastery: Mastery
    ) -> Mastery;

    def list_below_threshold(
        enrollment_id: str,
        threshold: float
    ) -> list[Mastery];
}
```

### Required behavior

- uniqueness by learner enrollment and skill;
- mastery records cannot move silently across versions;
- score normalization is consistent;
- repository stores values but does not decide mastery policy.

---

# `RecommendationRepository`

Responsible for persisted recommendation history where required.

Suggested contract:

```jac
obj RecommendationRepository {
    def find_latest(
        enrollment_id: str
    ) -> Recommendation | None;

    def list_recent(
        enrollment_id: str,
        limit: int
    ) -> list[Recommendation];

    def create(
        enrollment: Enrollment,
        recommendation: Recommendation
    ) -> Recommendation;
}
```

Repository methods must not calculate the recommendation.

---

# `MigrationRepository`

Responsible for migration checkpoints and reports.

Suggested contract:

```jac
obj MigrationRepository {
    def find_record(
        migration_name: str,
        migration_version: int,
        entity_type: str,
        entity_id: str
    ) -> MigrationRecord | None;

    def save_record(
        record: MigrationRecord
    ) -> None;

    def list_failures(
        migration_name: str,
        migration_version: int,
        page: PageRequest
    ) -> PageResult;
}
```

Migration records must remain outside learner-facing traversals.

---

# Service layers

# Track context service

Create one track-context resolver used by all track-aware application services.

```jac
obj TrackContext {
    has track: LearningTrack;
    has version: TrackVersion;
    has legacy_language: str | None = None;
    has resolution_source: str;
}
```

Suggested service:

```jac
obj TrackContextService {
    def resolve(
        track_id: str | None,
        track_version_id: str | None,
        language: str | None
    ) -> TrackContext;
}
```

Resolution order:

1. validate provided track ID;
2. validate provided version ID;
3. verify graph ownership;
4. resolve active version when allowed;
5. use legacy programming-language mapping only when no track is supplied;
6. reject conflicts;
7. return the source of resolution.

Every later track-aware service should use this component rather than implementing its own fallback logic.

---

# Learning-track domain service

Responsibilities:

```text
validate creation input
validate ownership
validate metadata
validate lifecycle transitions
validate enrollment eligibility
validate discoverability
validate archival
protect system tracks
protect published versions
```

It must not perform broad catalogue queries or UI report formatting.

---

# Learning-track application service

Suggested operations:

```text
create_track
get_track
list_available_tracks
list_owned_tracks
update_track_metadata
archive_track
restore_track
```

Example creation flow:

```text
Walker
  → resolve actor
  → application service
      → authorization policy
      → domain validation
      → repository create and attach
      → version repository create initial draft
      → configuration repository create
      → audit event
      → typed result
```

---

# Track-version service

Responsibilities:

```text
create initial version
create next draft version
copy published curriculum into draft
validate one-active-draft rule
submit version for review
approve version
supersede version
archive version
```

The service must reject direct edits to published versions.

---

# Track-publication service

Publishing is a multi-repository use case.

Required checks:

1. actor authorization;
2. track exists;
3. version belongs to track;
4. version is approved;
5. curriculum graph passes integrity validation;
6. prerequisite graph is acyclic;
7. required metadata exists;
8. configuration is valid;
9. source references satisfy later grounding requirements;
10. no blocking processing errors exist.

Publication flow:

```text
validate
→ mark previous active version superseded
→ mark target version published
→ update track active_version_id
→ update track status
→ optionally open enrollment
→ emit audit event
```

If a failure occurs mid-operation, the service must either:

- restore the previous consistent state; or
- mark a recoverable incomplete-publication state and block discovery.

---

# Curriculum query service

Provides read-oriented curriculum projections without exposing raw graph internals.

Suggested operations:

```text
get_track_curriculum_summary
get_module_outline
get_skill_graph
get_skill_prerequisites
get_lesson_outline
validate_curriculum_graph
```

This service may compose several repository calls and return typed DTOs.

---

# Enrollment service

Later enrollment walkers must call this service.

Responsibilities:

1. validate track discoverability;
2. validate enrollment is open;
3. validate active version;
4. detect duplicate enrollment;
5. create enrollment;
6. connect learner, track, and version;
7. initialize learner-track state;
8. emit event.

The service must not initialize an assessment unless the enrollment use case explicitly includes that operation.

---

# Learner-progress service

Coordinates read operations across:

- enrollment;
- roadmap;
- lesson progress;
- submissions;
- mastery;
- recommendations.

Suggested operations:

```text
get_track_progress
get_dashboard_summary
get_skill_map_projection
get_current_roadmap_item
get_next_available_lesson
```

This service must scope every query to one enrollment or explicitly aggregate across selected enrollments.

---

# Transaction and consistency strategy

Jac graph operations may span several node and edge mutations. Use one project-wide consistency strategy.

## Required logical transaction boundaries

Treat these as atomic use cases:

```text
create track + attach catalogue + create configuration
create version + attach to track
create enrollment + attach learner, track, and version
create roadmap + create and attach roadmap items
publish version + update active version + supersede previous version
```

## When native transactions are available

Use them through one transaction abstraction.

## When native transactions are unavailable

Use:

- idempotency keys;
- deterministic IDs where appropriate;
- ordered mutation steps;
- validation after each stage;
- compensating actions;
- incomplete-operation markers;
- retry-safe repository methods.

Never hide partial failure.

---

# Idempotency

Every mutating application service must define its idempotency strategy.

## `IdempotencyContext`

```jac
obj IdempotencyContext {
    has key: str;
    has operation: str;
    has actor_id: str;
    has request_id: str;
}
```

Example keys:

```text
create-track:<actor-id>:<client-request-id>
seed-track:trk_builtin_python
create-enrollment:<learner-id>:<track-id>
publish-version:<track-version-id>
```

Requirements:

- repeated successful calls return the original logical result;
- repeated failed calls do not duplicate partial nodes;
- idempotency keys are scoped by operation;
- secrets are not embedded in keys;
- retention policy is documented.

---

# Authorization handoff

Repositories do not decide high-level authorization, but they must support authorization-safe queries.

## Application service responsibilities

- resolve trusted actor context;
- invoke authorization policy;
- prevent arbitrary `owner_id` claims;
- choose authorized repository method;
- prevent existence leaks for private tracks.

## Repository responsibilities

- filter by graph ownership where required;
- support owner-scoped queries;
- avoid unrestricted broad reads;
- validate requested nodes belong to expected graph parents.

Example:

```text
Unauthorized get private track
→ return not found or access denied according to project policy
→ do not include private title or owner metadata
```

---

# Query and traversal rules

## Always scope curriculum traversal

Every curriculum query must include:

```text
track_version_id
```

## Always scope learner progress

Every learner-progress query must include:

```text
enrollment_id
```

or an equivalent validated learner-track context.

## Bounded traversal

- set explicit traversal depth;
- use explicit node and edge types;
- avoid traversing from a global root without filters;
- avoid loading full lesson bodies for catalogue cards;
- avoid loading raw submissions for dashboard counts.

## Deterministic ordering

Use explicit ordering fields for:

- modules;
- skills within modules;
- roadmap items;
- lessons;
- activities;
- version history.

Never rely on incidental graph traversal order.

---

# Read models and projections

Do not return graph nodes directly to Jac Client when a purpose-built projection is safer.

Examples:

```jac
obj TrackCatalogueItem {
    has track_id: str;
    has track_version_id: str;
    has slug: str;
    has title: str;
    has short_description: str;
    has track_type: str;
    has subject_area: str | None;
    has academic_level: str | None;
    has estimated_duration_weeks: int | None;
}
```

```jac
obj TrackProgressSummary {
    has enrollment_id: str;
    has track_id: str;
    has track_version_id: str;
    has completion_percent: float;
    has mastered_skill_count: int;
    has total_skill_count: int;
    has current_lesson_id: str | None;
}
```

Projection creation belongs in application/query services, not low-level repositories.

---

# Caching

Caching must preserve version isolation.

## Safe cache keys

```text
track-summary:<track-id>
curriculum-outline:<track-version-id>
skill-graph:<track-version-id>
lesson:<track-version-id>:<lesson-id>
learner-progress:<enrollment-id>
```

## Invalidation events

Invalidate on:

```text
track metadata updated
track version published
track archived
curriculum draft changed
learner progress changed
mastery changed
submission graded
```

Published curriculum may be cached longer than drafts because published versions are immutable.

Do not cache private track results without actor or authorization scope.

---

# External-service boundaries

Later specifications may add:

- file storage;
- PDF/DOCX extraction;
- byLLM generation;
- grading providers;
- vector retrieval.

Wrap these behind service interfaces.

Repositories must not call LLMs or document parsers.

Suggested interfaces:

```text
DocumentStorageService
DocumentExtractionService
CourseBlueprintGenerationService
LessonGenerationService
GradingService
EmbeddingService
```

Application services coordinate them with repositories.

---

# Errors

## Repository error codes

```text
REPOSITORY_NODE_NOT_FOUND
REPOSITORY_DUPLICATE_NODE
REPOSITORY_DUPLICATE_EDGE
REPOSITORY_GRAPH_RELATIONSHIP_MISSING
REPOSITORY_GRAPH_RELATIONSHIP_CONFLICT
REPOSITORY_VERSION_MISMATCH
REPOSITORY_PERSISTENCE_FAILED
REPOSITORY_QUERY_LIMIT_EXCEEDED
```

## Service error codes

```text
TRACK_NOT_FOUND
TRACK_NOT_VISIBLE
TRACK_NOT_ENROLLABLE
TRACK_VERSION_NOT_FOUND
TRACK_VERSION_MISMATCH
TRACK_VERSION_IMMUTABLE
TRACK_ALREADY_HAS_DRAFT
INVALID_TRACK_STATUS_TRANSITION
CURRICULUM_GRAPH_INVALID
PREREQUISITE_CYCLE_DETECTED
ENROLLMENT_ALREADY_EXISTS
ENROLLMENT_NOT_FOUND
UNAUTHORIZED_TRACK_OPERATION
IDEMPOTENCY_CONFLICT
APPLICATION_OPERATION_INCOMPLETE
```

## Error mapping

Walkers should map internal errors to stable client reports.

Do not expose:

- stack traces;
- raw graph IDs not intended for users;
- database driver messages;
- internal storage paths;
- prompt contents.

---

# Observability

Every application-service operation should create structured telemetry.

## Events

```text
repository.query_failed
repository.graph_conflict
repository.persistence_failed

learning_track_service.create_started
learning_track_service.create_completed
learning_track_service.create_failed

track_version_service.created
track_publication_service.started
track_publication_service.completed
track_publication_service.failed

enrollment_service.created
learner_progress_service.loaded
```

## Common fields

```text
operation
repository
service
track_id
track_version_id
enrollment_id
actor_id
request_id
idempotency_key
duration_ms
status
error_code
```

Do not log full document content, learner answers, or private lesson bodies.

---

# Testing strategy

Use Jac test blocks and the project's integration-test conventions.

# Repository unit tests

## Learning-track repository

- finds a track by stable ID;
- finds a track by slug;
- excludes detached tracks from catalogue listing;
- lists only visible tracks;
- owner-scoped query returns only owned tracks;
- duplicate catalogue edges are detected;
- missing catalogue edge is detected.

## Track-version repository

- finds version by ID;
- lists versions in deterministic order;
- verifies version ownership through graph edge;
- rejects version from another track;
- finds active version;
- prevents published-version mutation.

## Curriculum repository

- lists modules for one version;
- lists skills for one version;
- does not return another version's skills;
- returns prerequisites in deterministic order;
- detects cycles;
- respects traversal bounds.

## Enrollment repository

- creates one enrollment;
- prevents duplicate active enrollment;
- preserves historical enrollment;
- rejects version mismatch;
- lists learner enrollments.

## Assessment and roadmap repositories

- create records under the correct enrollment;
- reject cross-enrollment attachment;
- preserve track and version context;
- return active records only when requested.

## Mastery repository

- creates one mastery record per enrollment and skill;
- updates existing mastery safely;
- rejects cross-version skill references;
- lists weak skills by threshold.

---

# Service unit tests

## Track context service

- resolves valid track and version;
- resolves active version when permitted;
- resolves legacy Python language;
- rejects mismatched track and version;
- rejects conflicting language and track;
- reports resolution source.

## Track domain service

- validates ownership combinations;
- validates lifecycle transitions;
- blocks enrollment before publication;
- protects system tracks;
- protects published versions.

## Publication service

- publishes an approved valid version;
- supersedes previous active version;
- rejects curriculum cycles;
- rejects missing required metadata;
- leaves consistent state after failure;
- repeated publish call is idempotent.

## Enrollment service

- enrolls learner in active version;
- rejects archived track;
- rejects closed enrollment;
- rejects duplicate enrollment;
- repeated request returns same logical enrollment.

---

# Integration tests

## Create-track graph

```text
create track
→ attach catalogue
→ create configuration
→ create initial version
→ reload through repository
→ validate graph integrity
```

## Publish-version graph

```text
create draft
→ attach curriculum
→ validate graph
→ approve
→ publish
→ resolve active version
→ list in catalogue
```

## Learner progression graph

```text
enroll learner
→ initialize assessment
→ create roadmap
→ load lesson
→ create submission
→ grade submission
→ update mastery
→ retrieve progress projection
```

Every record must retain the same track and version context.

## Multi-track isolation

Create one learner enrolled in Python and Jaseci.

Verify:

- Python mastery does not appear in Jaseci progress;
- Python roadmap items do not appear in Jaseci roadmap;
- recommendations are scoped by enrollment;
- cache keys remain isolated;
- repository queries require explicit context.

---

# Failure-injection tests

Inject failures after:

- track node creation but before catalogue edge;
- version node creation but before track edge;
- publication status update but before active-version update;
- enrollment node creation but before learner edge;
- roadmap creation but before item attachment.

Verify:

- the operation is retry-safe;
- partial state is detectable;
- duplicate nodes are not created;
- compensating action or repair path exists;
- invalid incomplete state is not exposed to learners.

---

# Performance tests

Measure:

- catalogue listing with many tracks;
- version lookup with many historical versions;
- prerequisite traversal on large skill graphs;
- progress projection with many mastery records;
- lecturer pending-review pagination;
- repeated repository calls with cache enabled.

Set practical limits for:

```text
page size
traversal depth
maximum returned nodes
query duration warnings
```

---

# Migration and adoption plan

## Phase 1: Introduce contracts

1. Add repository interfaces.
2. Add shared result and error types.
3. Add actor context.
4. Add track context service.
5. Add tests with current graph models.

## Phase 2: Wrap existing access

1. Move track lookup into `LearningTrackRepository`.
2. Move version lookup into `TrackVersionRepository`.
3. Move roadmap lookup into `RoadmapRepository`.
4. Move mastery lookup into `MasteryRepository`.
5. Preserve old walker behavior.

## Phase 3: Introduce application services

1. Route track creation through service.
2. Route version creation through service.
3. Route catalogue reads through query service.
4. Route enrollment later through enrollment service.
5. Add observability and idempotency.

## Phase 4: Remove direct graph access from walkers

Audit all walkers and remove duplicated:

- track lookup;
- version validation;
- catalogue traversal;
- enrollment lookup;
- roadmap lookup;
- mastery traversal.

## Phase 5: Enforce architecture

Add code-review and test requirements:

- new walkers may not bypass repositories;
- published curriculum writes must pass domain service;
- track context must come from the shared resolver;
- learner progress queries must be enrollment-scoped.

---

# Implementation checklist

## Shared types

- [ ] `ActorContext` implemented.
- [ ] Repository result/error convention implemented.
- [ ] Service result/error convention implemented.
- [ ] Pagination types implemented.
- [ ] Track-context type implemented.

## Repositories

- [ ] Learning-track repository implemented.
- [ ] Track-version repository implemented.
- [ ] Curriculum repository implemented.
- [ ] Enrollment repository implemented or contract stubbed.
- [ ] Assessment repository updated.
- [ ] Roadmap repository updated.
- [ ] Lesson repository updated.
- [ ] Activity repository updated.
- [ ] Submission repository updated.
- [ ] Mastery repository updated.
- [ ] Recommendation repository updated.
- [ ] Migration repository implemented.

## Services

- [ ] Track-context service implemented.
- [ ] Learning-track domain service implemented.
- [ ] Learning-track application service implemented.
- [ ] Track-version service implemented.
- [ ] Publication service contract implemented.
- [ ] Curriculum query service implemented.
- [ ] Enrollment service contract implemented.
- [ ] Learner-progress query service implemented.

## Consistency

- [ ] Logical transaction boundaries documented.
- [ ] Idempotency strategy documented per mutation.
- [ ] Partial-failure repair behavior implemented.
- [ ] Published-version immutability enforced.
- [ ] Cross-version graph access rejected.

## Security

- [ ] Actor context comes from trusted session state.
- [ ] Owner ID is not accepted as authoritative input.
- [ ] Private track queries avoid information leakage.
- [ ] Repository queries are authorization-safe.
- [ ] System tracks are protected.

## Observability

- [ ] Repository failures emit structured events.
- [ ] Service operations emit duration and status.
- [ ] Request IDs are propagated.
- [ ] Idempotency keys are logged safely.
- [ ] Sensitive content is excluded from logs.

## Testing

- [ ] Repository unit tests pass.
- [ ] Service unit tests pass.
- [ ] Graph-integrity tests pass.
- [ ] Multi-track isolation tests pass.
- [ ] Failure-injection tests pass.
- [ ] Existing programming-flow regression tests pass.

---

# Acceptance criteria

This specification is complete when:

1. Walkers no longer implement repeated learning-track graph queries.
2. Track and version ownership are verified through graph relationships.
3. Curriculum repository operations are version-scoped.
4. Learner-progress operations are enrollment-scoped.
5. Publishing is coordinated through one service.
6. Published curriculum cannot be mutated through repository methods.
7. All mutating use cases have an idempotency strategy.
8. Partial failures are detectable and retry-safe.
9. Programming and lecturer tracks use the same repository contracts.
10. Legacy language resolution exists only in the shared track-context service.
11. Repository and service errors map to stable walker reports.
12. Authorization uses trusted actor context.
13. Cache keys preserve track-version isolation.
14. Graph-integrity and multi-track isolation tests pass.
15. Existing programming-language flows continue to work.

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
1. Built-in tracks load through LearningTrackRepository.
2. Active versions load through TrackVersionRepository.
3. A mismatched version is rejected.
4. Catalogue listing excludes private drafts.
5. Existing Python assessment flow still works.
6. Existing Jaseci roadmap flow still works.
7. Learner progress is scoped to one enrollment.
8. Multi-track learner data remains isolated.
9. Publishing a version updates one active version only.
10. Repeating a create or publish request does not duplicate nodes.
11. A simulated partial failure can be detected and repaired.
12. Restarting the backend preserves repository-visible graph state.
```

---

# Expected result

After implementation:

- GraphLearn walkers are thin application adapters;
- graph traversal is centralized in focused repositories;
- domain invariants are centralized in services;
- programming and lecturer tracks share one architecture;
- curriculum queries cannot silently cross version boundaries;
- learner progression cannot silently cross enrollment boundaries;
- publication and enrollment operations are consistent and retry-safe;
- later document, blueprint, course catalogue, assessment, lesson, grading, and analytics features can build on stable contracts.
