# 29-learning-track-domain-model.md

## Overview

Implement a generic learning-track domain model that allows GraphLearn LMS to support multiple kinds of courses through the same adaptive-learning engine.

A learning track may represent:

* a built-in programming-language path;
* a lecturer-created academic course;
* a future institution-managed curriculum;
* a future imported or certification-based curriculum.

The current system is primarily organized around a programming-language selection:

```text
Learner
→ selects language
→ takes diagnostic assessment
→ receives roadmap
→ completes lessons and quizzes
→ mastery is updated
```

The new model must generalize this flow:

```text
Learner
→ selects learning track
→ takes diagnostic assessment
→ receives roadmap
→ completes lessons and activities
→ mastery is updated
```

The system must not create a separate assessment, roadmap, lesson, quiz, grading, mastery, or recommendation system for lecturer-created courses.

Both built-in programming tracks and lecturer-created courses must resolve to the same `LearningTrack` abstraction.

---

## Objectives

Implement the domain foundation required to:

1. Represent programming languages and lecturer-created courses as learning tracks.
2. Give each track a stable, immutable identifier.
3. Separate shared course curriculum from learner-specific progression.
4. Support track ownership and visibility.
5. Support draft, processing, review, publication, failure, and archival states.
6. Support immutable published course versions.
7. Preserve the current programming-language workflow.
8. Provide backward compatibility for existing `language` values.
9. Establish graph relationships for future document, skill, module, lesson, and enrollment features.
10. Prevent later specifications from creating duplicate course-flow implementations.

---

## Non-goals

This specification does not implement:

* lecturer registration;
* lecturer authentication;
* lecturer dashboard UI;
* document upload;
* PDF extraction;
* Word document extraction;
* content chunking;
* byLLM course-blueprint generation;
* lecturer course review;
* learner enrollment;
* course catalogue UI;
* track-aware assessment generation;
* track-aware roadmap generation;
* source-grounded lesson generation;
* generalized quiz grading;
* lecturer analytics.

Those features will depend on the domain model created here.

---

## Architectural principle

The system must have one adaptive-learning engine with multiple curriculum sources.

```text
Built-in programming curriculum ─┐
                                 ├── LearningTrack
Lecturer-created curriculum ─────┘        │
                                          ▼
                               Adaptive learning engine
                               ├── assessment
                               ├── roadmap
                               ├── lesson
                               ├── quiz
                               ├── grading
                               ├── mastery
                               ├── unlocking
                               └── recommendations
```

A track represents shared curriculum identity.

A track must not store learner-specific data such as:

* diagnostic answers;
* learner assessment score;
* personal roadmap;
* lesson completion;
* challenge submissions;
* mastery scores;
* grading feedback;
* recommendations.

These records must reference the relevant track and track version.

---

## Proposed project structure

Adapt the structure to the existing GraphLearn codebase:

---

# Domain enums

Use enums for controlled domain states instead of unrestricted strings.

## `LearningTrackType`

```jac
enum LearningTrackType {
    PROGRAMMING_LANGUAGE,
    LECTURER_COURSE
}
```

Meaning:

| Value                  | Meaning                                             |
| ---------------------- | --------------------------------------------------- |
| `PROGRAMMING_LANGUAGE` | A built-in or system-managed programming curriculum |
| `LECTURER_COURSE`      | A course created and managed by a lecturer          |

Future values may include:

```text
INSTITUTION_COURSE
CERTIFICATION_PATH
IMPORTED_CURRICULUM
```

Do not add these values until they are required.

---

## `LearningTrackStatus`

```jac
enum LearningTrackStatus {
    DRAFT,
    PROCESSING,
    REVIEW_REQUIRED,
    PUBLISHED,
    FAILED,
    ARCHIVED
}
```

| Status            | Meaning                                                       |
| ----------------- | ------------------------------------------------------------- |
| `DRAFT`           | The track exists but is not ready for learners                |
| `PROCESSING`      | Course material is being processed                            |
| `REVIEW_REQUIRED` | Generated or imported curriculum requires approval            |
| `PUBLISHED`       | The track has an approved active version                      |
| `FAILED`          | A blocking course-processing operation failed                 |
| `ARCHIVED`        | The track is retained historically but closed to new learners |

Built-in programming tracks may be seeded directly as published tracks.

---

## `LearningTrackVisibility`

```jac
enum LearningTrackVisibility {
    PUBLIC,
    INSTITUTION,
    PRIVATE
}
```

Initial rules:

* `PUBLIC` tracks can be discovered by authenticated learners.
* `PRIVATE` tracks are visible only to authorized owners or assigned users.
* `INSTITUTION` tracks must remain unavailable to general learners until institution membership is implemented.

Visibility alone must not make a track discoverable.

A track must also be published and have a valid active version.

---

## `TrackOwnershipType`

```jac
enum TrackOwnershipType {
    SYSTEM,
    LECTURER,
    INSTITUTION
}
```

Initial valid combinations:

| Track type             | Ownership type |
| ---------------------- | -------------- |
| `PROGRAMMING_LANGUAGE` | `SYSTEM`       |
| `LECTURER_COURSE`      | `LECTURER`     |

The following combinations must be rejected unless a later administrative feature explicitly supports them:

```text
PROGRAMMING_LANGUAGE + LECTURER
LECTURER_COURSE + SYSTEM
```

---

## `TrackVersionStatus`

```jac
enum TrackVersionStatus {
    DRAFT,
    REVIEW_REQUIRED,
    APPROVED,
    PUBLISHED,
    SUPERSEDED,
    FAILED,
    ARCHIVED
}
```

---

## `TrackDifficultyLevel`

```jac
enum TrackDifficultyLevel {
    BEGINNER,
    INTERMEDIATE,
    ADVANCED,
    MIXED
}
```

Use `MIXED` when a learner's starting level will be determined through a diagnostic assessment.

---

## `TrackSourceKind`

```jac
enum TrackSourceKind {
    SEEDED,
    LECTURER_DOCUMENT,
    MANUAL
}
```

This value describes the curriculum source.

It must not contain provider-specific details such as the name of an LLM model.

---

# Core graph nodes

## `LearningTrack`

Create a stable learning-track identity node.

```jac
node LearningTrack {
    has track_id: str;
    has slug: str;
    has title: str;
    has short_description: str = "";

    has track_type: LearningTrackType;
    has status: LearningTrackStatus = LearningTrackStatus.DRAFT;
    has visibility: LearningTrackVisibility = LearningTrackVisibility.PRIVATE;

    has ownership_type: TrackOwnershipType;
    has owner_id: str | None = None;
    has institution_id: str | None = None;

    has course_code: str | None = None;
    has subject_area: str | None = None;
    has academic_level: str | None = None;
    has default_difficulty: TrackDifficultyLevel =
        TrackDifficultyLevel.MIXED;

    has estimated_duration_weeks: int | None = None;

    has active_version_id: str | None = None;
    has current_version_number: int = 0;

    has is_enrollment_open: bool = False;

    has created_at: str;
    has updated_at: str;
    has published_at: str | None = None;
    has archived_at: str | None = None;
}
```

---

## `track_id`

Requirements:

* required;
* generated by the backend;
* globally unique;
* immutable;
* not derived exclusively from the title;
* used as the primary curriculum reference.

Recommended format:

```text
trk_<uuid>
```

Example:

```text
trk_f97cb719c5194f0b95d964ef14ea4799
```

Titles, language names, slugs, and course codes must not be used as primary references.

Bad references:

```text
Python
Database Systems
CSC 220
```

Correct reference:

```text
trk_f97cb719c5194f0b95d964ef14ea4799
```

---

## `slug`

Requirements:

* required;
* lowercase;
* hyphen-separated;
* unique within the catalogue namespace;
* editable without changing `track_id`;
* not used as the domain primary key.

Examples:

```text
python-programming
jaseci-programming
database-management-systems
introduction-to-marketing
```

Slug collisions must be handled consistently:

```text
database-management-systems
database-management-systems-2
```

---

## `title`

Requirements:

* required;
* trimmed;
* non-empty;
* validated against a maximum length;
* editable without changing the track identity.

---

## `short_description`

Requirements:

* optional when a draft is created;
* required before a lecturer course is published;
* treated as plain text during this specification;
* sanitized before frontend rendering.

---

## `track_type`

The track type describes the curriculum category or origin.

It must not control which adaptive-learning system is used.

Both track types must use the existing shared:

* assessment flow;
* roadmap flow;
* lesson flow;
* challenge flow;
* mastery flow;
* recommendation flow.

---

## `owner_id`

Requirements:

* required for lecturer-owned tracks;
* normally absent for system-owned tracks;
* must eventually be derived from the authenticated lecturer session;
* must not be trusted directly from frontend input.

A later specification may add a direct `OWNS_TRACK` graph edge. The scalar `owner_id` may remain for indexed lookups and authorization checks.

---

## `institution_id`

This value is optional until institutional accounts are introduced.

A non-null institution ID must not automatically grant access.

---

## `course_code`

Examples:

```text
CSC 220
MKT 101
ACC 204
```

Requirements:

* optional;
* trimmed;
* length-limited;
* not globally unique;
* may only be unique within a specific institution.

---

## `subject_area`

Initial examples:

```text
Computer Science
Marketing
Accounting
Mathematics
Business Management
```

Use controlled text initially.

Create a dedicated `SubjectArea` node only when subject hierarchies, relationships, or analytics require one.

---

## `academic_level`

Examples:

```text
Beginner
Year 1
Undergraduate
Level 5
Postgraduate
```

Keep this as a string initially because institutions use different academic-level systems.

---

## `estimated_duration_weeks`

Requirements:

* optional;
* positive integer;
* within a configurable maximum;
* represents the expected course duration;
* does not represent a learner-specific schedule.

---

## `active_version_id`

Requirements:

* null before the first version is published;
* references a version belonging to the same track;
* references a version with `PUBLISHED` status;
* modified only by the publication service;
* never set directly by an ordinary walker.

---

## `current_version_number`

Requirements:

* starts at `0`;
* increments when a new version is created;
* never decreases;
* never reuses a previous number.

---

## `is_enrollment_open`

Publication and enrollment must remain separate controls.

A track is enrollable only when:

```text
track.status == PUBLISHED
AND track.active_version_id is not null
AND track.is_enrollment_open == true
AND track.visibility permits the learner
```

---

# Track version node

## `TrackVersion`

A version represents a specific curriculum snapshot.

```jac
node TrackVersion {
    has track_version_id: str;
    has track_id: str;
    has version_number: int;

    has status: TrackVersionStatus =
        TrackVersionStatus.DRAFT;

    has title_snapshot: str;
    has description_snapshot: str = "";
    has change_summary: str = "";

    has source_kind: TrackSourceKind;
    has curriculum_schema_version: int = 1;

    has created_by: str;
    has approved_by: str | None = None;

    has created_at: str;
    has updated_at: str;
    has approved_at: str | None = None;
    has published_at: str | None = None;
    has superseded_at: str | None = None;
}
```

---

## Track-version rules

1. Every version belongs to exactly one track.
2. Version numbers are unique within a track.
3. Version numbers increase monotonically.
4. Published versions are immutable.
5. A published version must not be deleted while learner data references it.
6. Only one version may be active at a time.
7. Creating a new draft must not mutate the active published version.
8. A new version should copy required curriculum state into a separate version graph.
9. Learner roadmaps must record the version from which they were generated.
10. Archiving a track must not delete its historical versions.

The first implementation should allow only one active draft version per track.

---

# Track configuration

## `TrackConfiguration`

Create a separate configuration node to avoid overloading `LearningTrack`.

```jac
node TrackConfiguration {
    has configuration_id: str;
    has track_id: str;

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

    has created_at: str;
    has updated_at: str;
}
```

Configuration rules:

* programming tracks may enable code challenges;
* lecturer courses must not automatically enable coding;
* scores must consistently use the range `0.0` to `1.0`;
* assessment-question limits must be positive;
* configuration must be validated before persistence;
* learner-specific accommodations must not modify the shared track configuration.

---

# Catalogue model

## `LearningCatalogue`

Tracks must be stored in a shared graph location that supports authorised discovery.

```jac
node LearningCatalogue {
    has catalogue_id: str = "global";
    has name: str = "GraphLearn Catalogue";
    has created_at: str;
    has updated_at: str;
}
```

Suggested graph:

```text
Application/global persistent root
└── LearningCatalogue
    ├── LearningTrack: Python Programming
    ├── LearningTrack: Jaseci Programming
    └── LearningTrack: Database Management Systems
```

Requirements:

* exactly one default catalogue initially;
* track creation connects the track to the catalogue;
* track creation and connection occur as one logical operation;
* detached tracks must not appear in learner searches;
* catalogue traversal must still apply authorization rules;
* multi-institution catalogues are deferred.

Do not create a new catalogue root if the application already has an appropriate global persistent graph.

---

# Graph edges

## `HAS_LEARNING_TRACK`

```jac
edge HAS_LEARNING_TRACK {
    has created_at: str;
}
```

Direction:

```text
LearningCatalogue → LearningTrack
```

---

## `HAS_TRACK_VERSION`

```jac
edge HAS_TRACK_VERSION {
    has version_number: int;
    has created_at: str;
}
```

Direction:

```text
LearningTrack → TrackVersion
```

The edge version number must match the connected version node.

---

## `HAS_TRACK_CONFIGURATION`

```jac
edge HAS_TRACK_CONFIGURATION {}
```

Direction:

```text
LearningTrack → TrackConfiguration
```

---

## Reserved future edges

Reserve compatible naming for:

```text
OWNS_TRACK
ENROLLED_IN
HAS_SOURCE_DOCUMENT
HAS_BLUEPRINT
HAS_CURRICULUM_MODULE
CONTAINS_SKILL
PREREQUISITE
DERIVED_FROM
```

Do not fully implement these relationships in this specification unless required for basic domain validation.

---

# Domain graph

```text
LearningCatalogue
└── HAS_LEARNING_TRACK
    └── LearningTrack
        ├── HAS_TRACK_CONFIGURATION
        │   └── TrackConfiguration
        │
        └── HAS_TRACK_VERSION
            ├── TrackVersion 1
            └── TrackVersion 2
```

Later curriculum graph:

```text
TrackVersion
├── HAS_SOURCE_DOCUMENT
├── HAS_BLUEPRINT
├── HAS_CURRICULUM_MODULE
└── CONTAINS_SKILL
```

Learner-specific graph:

```text
Learner
├── ENROLLED_IN → LearningTrack / TrackVersion
├── HAS_ASSESSMENT → Assessment
├── HAS_ROADMAP → Roadmap
├── HAS_MASTERY → Mastery
└── HAS_SUBMISSION → Submission
```

---

# Domain invariants

## Identity invariants

* `track_id` is globally unique.
* `track_version_id` is globally unique.
* `(track_id, version_number)` is unique.
* `slug` is unique within the catalogue.
* IDs are immutable.
* Titles may change without changing IDs.

## Ownership invariants

* `LECTURER_COURSE` requires `LECTURER` ownership.
* Lecturer ownership requires a valid `owner_id`.
* System tracks cannot be modified by lecturer operations.
* Ownership changes require a dedicated administrative operation.
* Client-provided ownership values are not authoritative.

## Lifecycle invariants

* lecturer tracks begin as `DRAFT`;
* drafts are not learner-discoverable;
* a track cannot become published without a published active version;
* enrollment cannot open before publication;
* archived tracks cannot receive new enrollments;
* lifecycle changes occur through a domain service;
* arbitrary walkers must not directly mutate lifecycle fields.

## Version invariants

* published versions are immutable;
* the active version belongs to the same track;
* the active version has `PUBLISHED` status;
* publishing a new version supersedes the previous active version;
* historical versions remain available while referenced;
* version numbers never decrease;
* mutable curriculum nodes cannot be shared across different versions.

## Graph invariants

* every saved track is connected through the approved catalogue path;
* every track version has exactly one parent track;
* every configuration belongs to exactly one track;
* no active-version reference points to another track;
* tracks referenced by learner records are archived rather than deleted.

---

# Track state transitions

## Valid track transitions

```text
DRAFT
├── PROCESSING
├── REVIEW_REQUIRED
├── FAILED
└── ARCHIVED

PROCESSING
├── REVIEW_REQUIRED
├── FAILED
└── DRAFT

REVIEW_REQUIRED
├── DRAFT
├── PUBLISHED
├── FAILED
└── ARCHIVED

PUBLISHED
└── ARCHIVED

FAILED
├── DRAFT
├── PROCESSING
└── ARCHIVED
```

Restoring an archived track must require a dedicated policy and operation.

Built-in tracks may be seeded directly as published if they also receive a valid published version.

---

## Valid version transitions

```text
DRAFT
├── REVIEW_REQUIRED
├── FAILED
└── ARCHIVED

REVIEW_REQUIRED
├── DRAFT
├── APPROVED
├── FAILED
└── ARCHIVED

APPROVED
├── PUBLISHED
└── ARCHIVED

PUBLISHED
├── SUPERSEDED
└── ARCHIVED

FAILED
├── DRAFT
└── ARCHIVED
```

All transitions must be validated centrally.

---

# Typed domain contracts

## `CreateLearningTrackInput`

```jac
obj CreateLearningTrackInput {
    has title: str;
    has short_description: str = "";

    has track_type: LearningTrackType;
    has visibility: LearningTrackVisibility =
        LearningTrackVisibility.PRIVATE;

    has ownership_type: TrackOwnershipType;
    has owner_id: str | None = None;
    has institution_id: str | None = None;

    has course_code: str | None = None;
    has subject_area: str | None = None;
    has academic_level: str | None = None;

    has default_difficulty: TrackDifficultyLevel =
        TrackDifficultyLevel.MIXED;

    has estimated_duration_weeks: int | None = None;
}
```

---

## `LearningTrackSummary`

```jac
obj LearningTrackSummary {
    has track_id: str;
    has slug: str;
    has title: str;
    has short_description: str;

    has track_type: LearningTrackType;
    has status: LearningTrackStatus;
    has visibility: LearningTrackVisibility;

    has course_code: str | None;
    has subject_area: str | None;

    has active_version_id: str | None;
    has is_enrollment_open: bool;
}
```

---

## `LearningTrackDetail`

```jac
obj LearningTrackDetail {
    has track: LearningTrackSummary;

    has ownership_type: TrackOwnershipType;
    has owner_id: str | None;
    has institution_id: str | None;

    has academic_level: str | None;
    has default_difficulty: TrackDifficultyLevel;
    has estimated_duration_weeks: int | None;

    has current_version_number: int;

    has created_at: str;
    has updated_at: str;
    has published_at: str | None;
}
```

Do not expose internal graph objects directly to the frontend where typed response objects are sufficient.

---

# Domain errors

Support consistent error codes:

```text
LEARNING_TRACK_NOT_FOUND
LEARNING_TRACK_ID_CONFLICT
LEARNING_TRACK_SLUG_CONFLICT
INVALID_TRACK_TYPE
INVALID_TRACK_OWNER
INVALID_TRACK_STATUS_TRANSITION
TRACK_NOT_PUBLISHED
TRACK_NOT_ENROLLABLE
TRACK_ARCHIVED
TRACK_VERSION_NOT_FOUND
TRACK_VERSION_MISMATCH
TRACK_VERSION_IMMUTABLE
TRACK_ACTIVE_VERSION_INVALID
TRACK_ALREADY_HAS_DRAFT
TRACK_REFERENCED_BY_LEARNERS
TRACK_VALIDATION_FAILED
```

Error structure:

```json
{
  "ok": false,
  "error": {
    "code": "TRACK_NOT_ENROLLABLE",
    "message": "This learning track is not open for enrollment.",
    "details": {
      "track_id": "trk_example"
    }
  }
}
```

Do not expose stack traces or internal database details through walker reports.

---

# Domain service

Create a focused learning-track domain service.

Suggested responsibilities:

```text
create_track
validate_track
create_initial_version
create_next_draft_version
transition_track_status
transition_version_status
activate_published_version
archive_track
restore_track
can_discover
can_enroll
validate_active_version
```

## `create_track`

Must:

1. validate the input;
2. generate a stable `track_id`;
3. generate a unique slug;
4. apply initial lifecycle state;
5. create the track node;
6. connect it to the catalogue;
7. create its default configuration;
8. persist the connected graph;
9. return a typed result.

Lecturer-created defaults:

```text
status = DRAFT
visibility = PRIVATE
is_enrollment_open = false
active_version_id = null
current_version_number = 0
```

## `create_initial_version`

Must:

1. verify that the track exists;
2. verify authorization;
3. ensure version `1` does not exist;
4. create a draft version;
5. snapshot title and description;
6. connect it with `HAS_TRACK_VERSION`;
7. set `current_version_number` to `1`;
8. update timestamps.

## `can_discover`

Return true only when:

```text
status == PUBLISHED
AND active_version_id is not null
AND visibility rules pass
```

## `can_enroll`

Return true only when:

```text
can_discover(track, learner) == true
AND is_enrollment_open == true
AND active version is valid
AND status != ARCHIVED
```

---

# Minimal internal walkers

The following walkers may be added for domain verification:

```text
create_learning_track
get_learning_track
list_learning_tracks
create_track_version
archive_learning_track
```

These are not yet the complete lecturer-facing API.

## `create_learning_track`

Conceptual contract:

```jac
walker create_learning_track {
    has input: CreateLearningTrackInput;
}
```

Example report:

```json
{
  "ok": true,
  "track": {
    "track_id": "trk_example",
    "slug": "database-management-systems",
    "title": "Database Management Systems",
    "status": "DRAFT"
  }
}
```

The walker must not allow an unauthenticated caller to assign arbitrary ownership.

Until lecturer roles are implemented, restrict course-creation walkers to a development or administrative path.

---

# Built-in programming tracks

Convert the currently supported programming languages into deterministic seeded tracks.

Example tracks:

```text
Python Programming
Jaseci Programming
```

Only seed tracks that the application currently supports.

Each built-in track must have:

* one `LearningTrack`;
* one version `1`;
* one `TrackConfiguration`;
* one catalogue relationship;
* one valid published active-version reference.

Example:

```json
{
  "track_id": "trk_builtin_python",
  "slug": "python-programming",
  "title": "Python Programming",
  "track_type": "PROGRAMMING_LANGUAGE",
  "status": "PUBLISHED",
  "visibility": "PUBLIC",
  "ownership_type": "SYSTEM",
  "owner_id": null,
  "active_version_id": "trv_builtin_python_v1",
  "current_version_number": 1,
  "is_enrollment_open": true
}
```

Use deterministic IDs so seeding can be safely rerun.

Do not look up built-in tracks only by title.

---

# Backward compatibility

The existing system may use:

```text
language
selected_language
language_track
```

Do not remove these fields immediately.

Create a resolver:

```jac
def resolve_learning_track(
    track_id: str | None,
    language: str | None
) -> LearningTrack;
```

Resolution order:

1. Resolve by `track_id` when supplied.
2. Otherwise resolve the legacy language through a built-in mapping.
3. Return a validation error when neither value is supplied.

Example mapping:

```text
python → trk_builtin_python
jaseci → trk_builtin_jaseci
jac → trk_builtin_jaseci
```

Normalize legacy values:

* trim whitespace;
* compare case-insensitively;
* support agreed aliases;
* reject unknown languages.

Do not create a new track automatically for an unknown language string.

## Migration stages

### Stage 1

```text
Frontend sends language.
Backend resolves language to track_id.
```

### Stage 2

```text
Frontend sends track_id and optional legacy language.
Backend uses track_id.
```

### Stage 3

```text
Frontend and backend use track_id only.
Language remains optional display metadata.
```

---

# Existing model references

The following models must eventually include:

```jac
has track_id: str;
has track_version_id: str;
```

Affected models:

```text
Assessment
AssessmentAttempt
Roadmap
RoadmapItem
Lesson
Challenge
Submission
Mastery
Recommendation
SkillMap
```

Rules:

* `track_id` identifies the curriculum.
* `track_version_id` identifies the exact curriculum snapshot.
* roadmaps must not silently change versions;
* learner submissions must remain linked to the version used;
* mastery migration between course versions must be handled explicitly.

The full model migration will be covered in a later specification.

---

# Persistence and migration

The implementation must preserve existing persisted graph data.

Migration requirements:

1. New optional fields have safe defaults.
2. Existing learner records remain readable.
3. Existing records are not deleted.
4. Built-in track seeding is idempotent.
5. Legacy language values map to deterministic track IDs.
6. Running the migration twice creates no duplicate nodes.
7. Running the migration twice creates no duplicate edges.
8. The migration produces a report.

Migration report fields:

```text
tracks_created
tracks_existing
versions_created
records_mapped
records_skipped
records_failed
```

Suggested migration order:

```text
1. Add enums and node definitions.
2. Create or resolve the catalogue.
3. Seed built-in programming tracks.
4. Create the legacy language mapping.
5. Backfill track references where safe.
6. Preserve legacy language fields.
7. Validate graph relationships.
8. Enable track-aware reads.
```

---

# Validation

## Title

* trim whitespace;
* reject empty values;
* reject control characters;
* enforce maximum length.

## Slug

* lowercase;
* replace spaces with hyphens;
* remove unsafe characters;
* collapse repeated hyphens;
* reject an empty result;
* resolve collisions.

## Course code

* trim whitespace;
* enforce maximum length;
* permit common letters, digits, spaces, hyphens, and slashes;
* do not assume global uniqueness.

## Duration

* optional;
* positive integer;
* limited by configuration;
* does not define an individual learner schedule.

## Threshold scores

* use a consistent `0.0` to `1.0` scale;
* reject values outside that range.

---

# Security requirements

* System tracks are editable only through trusted system or administrative operations.
* Lecturer tracks require a lecturer owner.
* Ownership must eventually come from the authenticated session.
* Private tracks must not be exposed to ordinary learners.
* Unpublished tracks must not be discoverable.
* Enrollment cannot be enabled before publication.
* Published versions are immutable.
* Unauthorized requests should not reveal unnecessary private-track metadata.

---

# Observability

Emit structured events:

```text
learning_track.created
learning_track.updated
learning_track.status_changed
learning_track.archived
track_version.created
track_version.status_changed
track_version.activated
builtin_track.seeded
builtin_track.seed_skipped
learning_track.migration_failed
```

Include:

```text
track_id
track_version_id
version_number
track_type
old_status
new_status
actor_id
request_id
timestamp
```

Do not log:

* raw course notes;
* learner answers;
* private document content;
* authentication secrets.

---

# Testing

Use Jac test blocks and the project's established test organization.

## Track creation tests

* creates a lecturer track as `DRAFT`;
* generates a stable ID;
* generates a valid slug;
* connects the track to the catalogue;
* closes enrollment by default;
* rejects an empty title;
* rejects invalid ownership combinations;
* rejects invalid duration.

## Identity tests

* duplicate track ID is rejected;
* duplicate slug behavior is consistent;
* editing a title does not change `track_id`;
* IDs cannot be changed.

## Lifecycle tests

* a draft cannot open enrollment;
* a draft cannot publish without an active version;
* a published track can be archived;
* an archived track cannot accept new enrollment;
* invalid transitions return the correct error.

## Version tests

* the first version is `1`;
* later versions increment;
* duplicate version numbers are rejected;
* a version belongs to one track;
* a published version cannot be mutated;
* an active version must belong to the track;
* an active version must be published.

## Catalogue tests

* unpublished tracks are excluded from learner discovery;
* private tracks are excluded for unauthorized learners;
* published public tracks are included;
* archived tracks are excluded from enrollment results.

## Seed tests

* each built-in track is created once;
* rerunning the seed creates no duplicate tracks;
* rerunning the seed creates no duplicate version edges;
* deterministic IDs remain unchanged.

## Legacy resolver tests

* `python` resolves correctly;
* `Python` resolves correctly;
* surrounding whitespace is normalized;
* `track_id` takes precedence over `language`;
* unknown languages are rejected;
* missing track and language values are rejected.

## Graph integrity tests

* every track is reachable through the catalogue;
* every version has exactly one parent track;
* active-version references remain inside the track;
* configuration nodes are not detached;
* migration creates no duplicate edges.

## Regression tests

Verify the existing programming flow:

1. list supported programming tracks;
2. initialize assessment;
3. evaluate assessment;
4. generate roadmap;
5. load lesson;
6. generate quiz or challenge;
7. evaluate submission;
8. update mastery;
9. unlock next lesson;
10. load dashboard;
11. load skill map;
12. recommend next action.

The flow may resolve a seeded track internally, but existing learner behavior must remain functional.

---

# Example Jac test outline

```jac
test "creates a draft lecturer track" {
    # Create valid input.
    # Call the domain service.
    # Assert the track type is LECTURER_COURSE.
    # Assert the status is DRAFT.
    # Assert enrollment is closed.
    # Assert the track is connected to the catalogue.
}

test "built-in seeding is idempotent" {
    # Run the seed twice.
    # Assert exactly one Python track exists.
    # Assert exactly one Python version-1 relationship exists.
}

test "published versions are immutable" {
    # Create and publish a version.
    # Attempt a prohibited update.
    # Assert TRACK_VERSION_IMMUTABLE.
}

test "legacy language resolves to a built-in track" {
    # Resolve language='python'.
    # Assert track_id == 'trk_builtin_python'.
}
```

---

# Implementation sequence

## Step 1: Audit current language coupling

Find every place where language is:

* stored;
* passed to a walker;
* saved in local storage;
* used in route parameters;
* used as a cache key;
* used in assessment generation;
* used in roadmap generation;
* displayed in learner UI.

## Step 2: Add domain declarations

Implement:

* enums;
* nodes;
* edges;
* typed request objects;
* typed response objects;
* domain errors.

## Step 3: Add the catalogue

Create or reuse the application-wide persistent catalogue graph.

## Step 4: Add repository operations

Implement ID, slug, ownership, version, and catalogue queries.

## Step 5: Add the domain service

Centralize validation, state transitions, version activation, and enrollment eligibility.

## Step 6: Seed built-in tracks

Convert existing programming languages into deterministic published tracks.

## Step 7: Add the legacy resolver

Resolve existing language input to a built-in track.

## Step 8: Add migration safety

Preserve existing records and make seeding rerunnable.

## Step 9: Add tests

Implement unit, graph-integrity, migration, and regression tests.

## Step 10: Verify the existing learner journey

Run the programming-language flow from track selection through mastery update.

---

# Acceptance criteria

## Domain model

* [ ] `LearningTrack` exists.
* [ ] `TrackVersion` exists.
* [ ] `TrackConfiguration` exists or an equivalent configuration model is documented.
* [ ] Controlled states use enums.
* [ ] Stable IDs are generated.
* [ ] Named graph edges are implemented.
* [ ] A shared catalogue persistence path exists.
* [ ] Domain invariants are enforced centrally.

## Built-in programming tracks

* [ ] Every currently supported language has one deterministic track.
* [ ] Every built-in track has a published version `1`.
* [ ] Built-in seeding is idempotent.
* [ ] Built-in tracks are discoverable and enrollable only when valid.

## Compatibility

* [ ] Legacy `language` input resolves to a track.
* [ ] Unknown languages fail safely.
* [ ] Existing learner records are preserved.
* [ ] Existing programming flows remain functional.
* [ ] Legacy language fields are not removed prematurely.

## Versioning

* [ ] Versions increment monotonically.
* [ ] Published versions are immutable.
* [ ] Active versions belong to their tracks.
* [ ] Active versions are published.
* [ ] Historical versions are retained.

## Security

* [ ] Lecturer tracks require ownership.
* [ ] System tracks cannot be edited by lecturer operations.
* [ ] Private tracks are not exposed.
* [ ] Unpublished tracks are not exposed.
* [ ] Enrollment cannot open before publication.

## Testing

* [ ] Jac type checking succeeds.
* [ ] Lint checks succeed.
* [ ] Jac tests pass.
* [ ] Graph-integrity tests pass.
* [ ] Migration tests pass.
* [ ] Existing programming-flow regression tests pass.

---

# Check when done

Run the appropriate commands for the installed project version:

```bash
jac check <entry-file>
jac check --lint <entry-file>
jac test
```

Manually verify:

```text
1. The application starts successfully.
2. Existing programming tracks appear.
3. Python resolves to its deterministic track ID.
4. Jaseci resolves to its deterministic track ID.
5. Assessment initialization still works.
6. Assessment evaluation still works.
7. Roadmap generation still works.
8. Lessons and quizzes still work.
9. Mastery updates still work.
10. Seed operations create no duplicates.
11. Tracks remain available after backend restart.
12. A draft lecturer course is not visible to learners.
13. A draft lecturer course cannot accept enrollment.
```

---

# Expected result

After this specification is complete:

* the LMS no longer depends on a language string as its primary curriculum identity;
* programming languages are represented as built-in learning tracks;
* lecturer-created courses can later use the same model;
* assessments and roadmaps can reference stable track IDs;
* published curriculum versions can remain immutable;
* learner-specific progression remains separate from shared course data;
* later document upload, blueprint, catalogue, enrollment, lesson, quiz, grading, and analytics features can reuse the existing adaptive-learning engine.
