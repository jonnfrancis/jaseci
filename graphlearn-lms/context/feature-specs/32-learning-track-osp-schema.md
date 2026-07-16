# 32-learning-track-osp-schema.md

## Overview

Implement the Object-Spatial Programming schema that connects GraphLearn LMS learning tracks, track versions, curriculum structure, learners, assessments, roadmaps, lessons, activities, submissions, mastery, and recommendations in one coherent Jac graph.

This specification builds on:

- `29-learning-track-domain-model.md`
- `30-programming-track-migration.md`
- `31-track-aware-existing-models.md`

The purpose of this specification is to move beyond adding scalar `track_id` fields and define the actual graph structure that Jac walkers will traverse.

The schema must support:

- built-in programming tracks;
- lecturer-created courses;
- immutable published course versions;
- shared curriculum content;
- learner-specific progression;
- prerequisite traversal;
- mastery-based lesson unlocking;
- source-document traceability;
- multi-track learners;
- historical version isolation;
- graph integrity validation.

The core graph must make GraphLearn meaningfully graph-native rather than using nodes only as ordinary database records.

---

## Status

- **Feature type:** OSP graph-schema foundation
- **Priority:** Critical
- **Depends on:** `29-learning-track-domain-model.md`
- **Depends on:** `30-programming-track-migration.md`
- **Depends on:** `31-track-aware-existing-models.md`
- **Blocks:** Track repositories, track-aware walkers, document ingestion, course blueprint generation, enrollment, and adaptive-learning extensions
- **Breaking changes allowed:** No
- **Persistence migration required:** Yes
- **Primary implementation language:** Jac
- **Primary design paradigm:** Object-Spatial Programming

---

## Goals

Implement an OSP schema that:

1. Gives learning tracks a persistent shared catalogue location.
2. Connects each track to immutable curriculum versions.
3. Connects versions to modules, skills, lessons, activities, and source material.
4. Models prerequisite relationships as traversable edges.
5. Connects learners to track-specific enrollments.
6. Connects learner assessments, roadmaps, mastery, and submissions to the correct enrollment and version.
7. Allows walkers to reason over graph structure rather than repeatedly filtering unrelated records.
8. Prevents cross-track and cross-version contamination.
9. Supports old programming-language data during migration.
10. Establishes graph-integrity rules and validation walkers.

---

## Non-goals

This specification does not implement:

- lecturer authentication;
- course-document upload UI;
- PDF or DOCX extraction;
- byLLM blueprint generation;
- final repository implementation;
- final learner enrollment UI;
- final track-aware assessment walkers;
- final roadmap generation logic;
- final lesson or quiz generation;
- course publication workflows;
- lecturer analytics.

It defines the graph those features will use.

---

# OSP design principles

## 1. Graph edges are domain relationships

Do not rely only on scalar fields such as:

```jac
has learner_id: str;
has track_id: str;
has skill_id: str;
```

Those fields remain useful for:

- indexed lookup;
- serialization;
- migration;
- debugging;
- external API contracts.

However, authoritative domain relationships must also be represented by named graph edges.

Example:

```text
LearnerEnrollment
    └── FOR_TRACK_VERSION → TrackVersion
```

This enables walkers to traverse actual relationships and verify that IDs correspond to the connected graph.

## 2. Shared curriculum and learner state must be separated

Shared curriculum graph:

```text
LearningTrack
└── TrackVersion
    ├── CourseModule
    ├── Skill
    ├── LessonTemplate
    └── ActivityTemplate
```

Learner-specific graph:

```text
Learner
└── Enrollment
    ├── AssessmentAttempt
    ├── Roadmap
    ├── Mastery
    └── Submission
```

A learner must not own the shared course definition.

## 3. Track versions are graph boundaries

Curriculum content for version 1 must not be silently reused as mutable content for version 2.

Every version-specific curriculum node must be reachable from exactly one `TrackVersion`, unless a node is explicitly designed as immutable global reference data.

## 4. Persistence requires reachability

Nodes intended to persist must remain reachable through an approved persistent graph path.

Creating a node without connecting it into the correct graph must not be considered a successful save operation.

## 5. Traversals must remain bounded

Walkers must not perform unrestricted graph traversal across the full LMS graph.

Traversals must be scoped by:

- learner;
- enrollment;
- track;
- track version;
- roadmap;
- module;
- skill;
- activity.

## 6. Named edges must describe intent

Prefer:

```text
HAS_TRACK_VERSION
CONTAINS_MODULE
TEACHES_SKILL
PREREQUISITE
HAS_ROADMAP
TARGETS_SKILL
```

Avoid vague relationships such as:

```text
LINKED_TO
HAS_ITEM
RELATED
```

---

# High-level graph

```text
ApplicationRoot
└── HAS_CATALOGUE
    └── LearningCatalogue
        └── HAS_LEARNING_TRACK
            └── LearningTrack
                ├── HAS_TRACK_CONFIGURATION
                │   └── TrackConfiguration
                └── HAS_TRACK_VERSION
                    └── TrackVersion
                        ├── CONTAINS_MODULE
                        │   └── CourseModule
                        ├── CONTAINS_SKILL
                        │   └── Skill
                        ├── HAS_LESSON_TEMPLATE
                        │   └── LessonTemplate
                        ├── HAS_ACTIVITY_TEMPLATE
                        │   └── ActivityTemplate
                        ├── HAS_SOURCE_DOCUMENT
                        │   └── CourseDocument
                        └── HAS_BLUEPRINT
                            └── CourseBlueprint
```

Learner graph:

```text
UserRoot
└── HAS_LEARNER_PROFILE
    └── Learner
        └── HAS_ENROLLMENT
            └── Enrollment
                ├── FOR_TRACK
                │   └── LearningTrack
                ├── FOR_TRACK_VERSION
                │   └── TrackVersion
                ├── HAS_ASSESSMENT_ATTEMPT
                ├── HAS_ROADMAP
                ├── HAS_MASTERY
                ├── HAS_LESSON_PROGRESS
                ├── HAS_SUBMISSION
                └── HAS_RECOMMENDATION
```

---

# Core shared nodes

## `LearningCatalogue`

```jac
node LearningCatalogue {
    has catalogue_id: str = "global";
    has name: str = "GraphLearn Catalogue";
    has created_at: str;
    has updated_at: str;
}
```

Rules:

- exactly one default catalogue initially;
- reachable from the approved application-level persistent root;
- contains every discoverable track;
- does not bypass authorization;
- does not directly contain learner records.

## `LearningTrack`

Use the model introduced in specification 29.

The track is the stable identity across versions.

It must not directly own mutable curriculum nodes such as individual skills or modules.

Those belong to a `TrackVersion`.

## `TrackVersion`

Use the model introduced in specification 29.

A version is the root of an immutable published curriculum snapshot.

Once published:

- its module structure is immutable;
- its prerequisite relationships are immutable;
- its source references are immutable;
- its lesson and activity templates are immutable, except through a controlled correction/versioning policy.

## `TrackConfiguration`

Use the configuration model introduced in specification 29.

It may be connected to:

```text
LearningTrack
```

when configuration applies across versions.

Version-sensitive configuration should instead be snapshot onto `TrackVersion` or a version-specific configuration node.

---

# Curriculum nodes

## `CourseModule`

Represents an ordered curriculum unit.

```jac
node CourseModule {
    has module_id: str;
    has track_id: str;
    has track_version_id: str;

    has title: str;
    has description: str = "";
    has order_index: int;

    has estimated_minutes: int | None = None;
    has learning_outcomes_json: str = "[]";

    has created_at: str;
    has updated_at: str;
}
```

Rules:

- belongs to exactly one track version;
- `order_index` is unique within its direct module collection unless nested modules are later introduced;
- title is required;
- published modules are immutable;
- modules do not store learner completion state.

## `Skill`

Represents a concept, competency, or learning objective measured through mastery.

```jac
node Skill {
    has skill_id: str;
    has track_id: str;
    has track_version_id: str;

    has title: str;
    has description: str = "";
    has skill_type: str = "CONCEPT";
    has difficulty: str = "MIXED";

    has mastery_threshold: float = 0.80;
    has order_hint: int | None = None;

    has created_at: str;
    has updated_at: str;
}
```

Possible skill types:

```text
CONCEPT
PROCEDURE
CODE
ANALYSIS
APPLICATION
COMMUNICATION
PROJECT
```

Rules:

- belongs to one track version;
- prerequisite edges must remain inside that track version;
- mastery threshold uses the project-wide normalized score scale;
- learner mastery is stored separately.

## `LessonTemplate`

Represents shared lesson structure or reusable generated content.

```jac
node LessonTemplate {
    has lesson_template_id: str;
    has track_id: str;
    has track_version_id: str;

    has title: str;
    has summary: str = "";
    has content: str = "";
    has content_format: str = "MARKDOWN";

    has difficulty: str = "MIXED";
    has estimated_minutes: int = 30;

    has generation_status: str = "READY";
    has source_references_json: str = "[]";
    has generation_metadata_json: str = "{}";

    has created_at: str;
    has updated_at: str;
}
```

Rules:

- belongs to exactly one track version;
- may teach one or more skills;
- may be linked to one module;
- must not contain learner completion state;
- generated lesson variants personalized for one learner should use a separate learner-specific node.

## `ActivityTemplate`

Generalizes quizzes and challenges.

```jac
node ActivityTemplate {
    has activity_template_id: str;
    has track_id: str;
    has track_version_id: str;

    has title: str;
    has instructions: str;
    has activity_type: str;

    has max_score: float = 100.0;
    has pass_score: float = 70.0;
    has difficulty: str = "MIXED";

    has answer_key_json: str | None = None;
    has rubric_json: str | None = None;
    has test_cases_json: str | None = None;
    has source_references_json: str = "[]";

    has created_at: str;
    has updated_at: str;
}
```

Supported activity types may include:

```text
MULTIPLE_CHOICE
SHORT_ANSWER
NUMERIC
ESSAY
CODE
SCENARIO
PROJECT
```

Sensitive answer keys and rubrics must not be exposed through learner-facing walkers.

---

# Document and blueprint nodes

These nodes may be fully implemented in later specifications, but the OSP schema reserves their graph position now.

## `CourseDocument`

```jac
node CourseDocument {
    has document_id: str;
    has track_id: str;
    has track_version_id: str;

    has filename: str;
    has mime_type: str;
    has storage_key: str;
    has checksum: str;

    has processing_status: str;
    has uploaded_by: str;
    has uploaded_at: str;
}
```

## `CourseContentChunk`

```jac
node CourseContentChunk {
    has chunk_id: str;
    has document_id: str;
    has track_id: str;
    has track_version_id: str;

    has order_index: int;
    has heading: str | None = None;
    has content: str;

    has page_start: int | None = None;
    has page_end: int | None = None;
    has token_count: int = 0;
}
```

## `CourseBlueprint`

```jac
node CourseBlueprint {
    has blueprint_id: str;
    has track_id: str;
    has track_version_id: str;

    has status: str;
    has summary: str = "";
    has learning_outcomes_json: str = "[]";
    has warnings_json: str = "[]";

    has generated_at: str;
    has approved_by: str | None = None;
    has approved_at: str | None = None;
}
```

---

# Learner-specific nodes

## `Enrollment`

Enrollment is the learner's stable relationship to a track version.

```jac
node Enrollment {
    has enrollment_id: str;
    has learner_id: str;
    has track_id: str;
    has track_version_id: str;

    has status: str = "ACTIVE";
    has source: str = "SELF_ENROLLED";

    has enrolled_at: str;
    has started_at: str | None = None;
    has completed_at: str | None = None;
    has archived_at: str | None = None;

    has current_roadmap_id: str | None = None;
    has overall_mastery: float = 0.0;
}
```

Possible statuses:

```text
PENDING_ASSESSMENT
ACTIVE
PAUSED
COMPLETED
WITHDRAWN
ARCHIVED
```

Rules:

- belongs to exactly one learner;
- points to exactly one track;
- points to exactly one version of that same track;
- may not silently switch versions;
- a new version migration must be explicit;
- one learner may have multiple enrollments across different tracks;
- duplicate active enrollment in the same track version should be rejected unless explicitly supported.

## `AssessmentAttempt`

```jac
node AssessmentAttempt {
    has assessment_id: str;
    has learner_id: str;
    has enrollment_id: str;
    has track_id: str;
    has track_version_id: str;

    has assessment_type: str = "DIAGNOSTIC";
    has status: str = "IN_PROGRESS";

    has score: float | None = None;
    has level_result: str | None = None;
    has responses_json: str = "[]";
    has result_json: str = "{}";

    has started_at: str;
    has completed_at: str | None = None;
}
```

## `Roadmap`

```jac
node Roadmap {
    has roadmap_id: str;
    has learner_id: str;
    has enrollment_id: str;
    has track_id: str;
    has track_version_id: str;

    has title: str;
    has status: str = "ACTIVE";
    has generation_version: int = 1;

    has created_at: str;
    has updated_at: str;
    has completed_at: str | None = None;
}
```

## `RoadmapItem`

```jac
node RoadmapItem {
    has roadmap_item_id: str;
    has roadmap_id: str;
    has track_id: str;
    has track_version_id: str;

    has order_index: int;
    has week_number: int | None = None;
    has status: str = "LOCKED";

    has target_skill_id: str;
    has lesson_template_id: str | None = None;

    has unlocked_at: str | None = None;
    has started_at: str | None = None;
    has completed_at: str | None = None;
}
```

## `LessonProgress`

```jac
node LessonProgress {
    has lesson_progress_id: str;
    has learner_id: str;
    has enrollment_id: str;
    has roadmap_item_id: str;
    has track_id: str;
    has track_version_id: str;
    has lesson_template_id: str;

    has status: str = "NOT_STARTED";
    has progress_percent: float = 0.0;

    has started_at: str | None = None;
    has completed_at: str | None = None;
    has last_viewed_at: str | None = None;
}
```

## `Submission`

```jac
node Submission {
    has submission_id: str;
    has learner_id: str;
    has enrollment_id: str;
    has track_id: str;
    has track_version_id: str;
    has activity_template_id: str;

    has answer_text: str | None = None;
    has answer_payload_json: str | None = None;

    has status: str = "SUBMITTED";
    has score: float | None = None;
    has passed: bool | None = None;
    has feedback: str | None = None;
    has grading_metadata_json: str = "{}";

    has submitted_at: str;
    has graded_at: str | None = None;
}
```

## `Mastery`

```jac
node Mastery {
    has mastery_id: str;
    has learner_id: str;
    has enrollment_id: str;
    has track_id: str;
    has track_version_id: str;
    has skill_id: str;

    has score: float = 0.0;
    has confidence: float = 0.0;
    has evidence_count: int = 0;

    has status: str = "NOT_STARTED";
    has last_evidence_at: str | None = None;
    has updated_at: str;
}
```

## `Recommendation`

```jac
node Recommendation {
    has recommendation_id: str;
    has learner_id: str;
    has enrollment_id: str;
    has track_id: str;
    has track_version_id: str;

    has recommendation_type: str;
    has target_id: str | None = None;
    has reason: str;
    has priority: float = 0.0;

    has status: str = "ACTIVE";
    has generated_at: str;
    has acted_at: str | None = None;
}
```

---

# Edge declarations

## Catalogue edges

### `HAS_CATALOGUE`

```jac
edge HAS_CATALOGUE {}
```

Direction:

```text
ApplicationRoot → LearningCatalogue
```

### `HAS_LEARNING_TRACK`

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

## Track edges

### `HAS_TRACK_VERSION`

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

### `HAS_TRACK_CONFIGURATION`

```jac
edge HAS_TRACK_CONFIGURATION {}
```

Direction:

```text
LearningTrack → TrackConfiguration
```

### `OWNS_TRACK`

```jac
edge OWNS_TRACK {
    has granted_at: str;
}
```

Direction:

```text
LecturerProfile → LearningTrack
```

This edge becomes authoritative after lecturer-profile implementation.

---

## Curriculum edges

### `CONTAINS_MODULE`

```jac
edge CONTAINS_MODULE {
    has order_index: int;
}
```

Direction:

```text
TrackVersion → CourseModule
```

### `CONTAINS_SKILL`

```jac
edge CONTAINS_SKILL {
    has order_index: int | None = None;
}
```

Direction:

```text
TrackVersion → Skill
```

### `MODULE_CONTAINS_SKILL`

```jac
edge MODULE_CONTAINS_SKILL {
    has order_index: int;
}
```

Direction:

```text
CourseModule → Skill
```

### `PREREQUISITE`

```jac
edge PREREQUISITE {
    has strength: float = 1.0;
    has required_mastery: float = 0.80;
    has relation_type: str = "REQUIRED";
}
```

Direction:

```text
Prerequisite Skill → Dependent Skill
```

Interpretation:

```text
A ──PREREQUISITE──> B
```

means skill A should be mastered before skill B.

Supported relation types:

```text
REQUIRED
RECOMMENDED
REINFORCES
```

Only `REQUIRED` edges must block unlocking.

### `HAS_LESSON_TEMPLATE`

```jac
edge HAS_LESSON_TEMPLATE {
    has order_index: int | None = None;
}
```

Direction:

```text
TrackVersion → LessonTemplate
```

### `MODULE_HAS_LESSON`

```jac
edge MODULE_HAS_LESSON {
    has order_index: int;
}
```

Direction:

```text
CourseModule → LessonTemplate
```

### `TEACHES_SKILL`

```jac
edge TEACHES_SKILL {
    has coverage_weight: float = 1.0;
    has role: str = "PRIMARY";
}
```

Direction:

```text
LessonTemplate → Skill
```

Roles:

```text
PRIMARY
SECONDARY
REVIEW
```

### `HAS_ACTIVITY_TEMPLATE`

```jac
edge HAS_ACTIVITY_TEMPLATE {
    has order_index: int | None = None;
}
```

Direction:

```text
TrackVersion → ActivityTemplate
```

### `LESSON_HAS_ACTIVITY`

```jac
edge LESSON_HAS_ACTIVITY {
    has order_index: int;
    has required: bool = True;
}
```

Direction:

```text
LessonTemplate → ActivityTemplate
```

### `ASSESSES_SKILL`

```jac
edge ASSESSES_SKILL {
    has assessment_weight: float = 1.0;
}
```

Direction:

```text
ActivityTemplate → Skill
```

---

## Source and blueprint edges

### `HAS_SOURCE_DOCUMENT`

```jac
edge HAS_SOURCE_DOCUMENT {
    has order_index: int;
}
```

Direction:

```text
TrackVersion → CourseDocument
```

### `HAS_CONTENT_CHUNK`

```jac
edge HAS_CONTENT_CHUNK {
    has order_index: int;
}
```

Direction:

```text
CourseDocument → CourseContentChunk
```

### `HAS_BLUEPRINT`

```jac
edge HAS_BLUEPRINT {}
```

Direction:

```text
TrackVersion → CourseBlueprint
```

### `DERIVED_FROM`

```jac
edge DERIVED_FROM {
    has page_start: int | None = None;
    has page_end: int | None = None;
    has confidence: float = 1.0;
}
```

Allowed directions:

```text
CourseModule → CourseContentChunk
Skill → CourseContentChunk
LessonTemplate → CourseContentChunk
ActivityTemplate → CourseContentChunk
```

Do not use one `DERIVED_FROM` edge to connect learner submissions to source notes.

---

## Learner and enrollment edges

### `HAS_ENROLLMENT`

```jac
edge HAS_ENROLLMENT {
    has enrolled_at: str;
}
```

Direction:

```text
Learner → Enrollment
```

### `FOR_TRACK`

```jac
edge FOR_TRACK {}
```

Direction:

```text
Enrollment → LearningTrack
```

### `FOR_TRACK_VERSION`

```jac
edge FOR_TRACK_VERSION {}
```

Direction:

```text
Enrollment → TrackVersion
```

### `HAS_ASSESSMENT_ATTEMPT`

```jac
edge HAS_ASSESSMENT_ATTEMPT {
    has created_at: str;
}
```

Direction:

```text
Enrollment → AssessmentAttempt
```

### `HAS_ROADMAP`

```jac
edge HAS_ROADMAP {
    has active: bool = True;
}
```

Direction:

```text
Enrollment → Roadmap
```

### `HAS_MASTERY`

```jac
edge HAS_MASTERY {}
```

Direction:

```text
Enrollment → Mastery
```

### `HAS_LESSON_PROGRESS`

```jac
edge HAS_LESSON_PROGRESS {}
```

Direction:

```text
Enrollment → LessonProgress
```

### `HAS_SUBMISSION`

```jac
edge HAS_SUBMISSION {}
```

Direction:

```text
Enrollment → Submission
```

### `HAS_RECOMMENDATION`

```jac
edge HAS_RECOMMENDATION {}
```

Direction:

```text
Enrollment → Recommendation
```

---

## Roadmap edges

### `HAS_ROADMAP_ITEM`

```jac
edge HAS_ROADMAP_ITEM {
    has order_index: int;
}
```

Direction:

```text
Roadmap → RoadmapItem
```

### `TARGETS_SKILL`

```jac
edge TARGETS_SKILL {}
```

Direction:

```text
RoadmapItem → Skill
```

### `USES_LESSON_TEMPLATE`

```jac
edge USES_LESSON_TEMPLATE {}
```

Direction:

```text
RoadmapItem → LessonTemplate
```

### `DEPENDS_ON_ROADMAP_ITEM`

```jac
edge DEPENDS_ON_ROADMAP_ITEM {
    has required: bool = True;
}
```

Direction:

```text
Earlier RoadmapItem → Later RoadmapItem
```

This relationship may mirror skill prerequisites but should capture personalized roadmap ordering.

---

## Learner evidence edges

### `PROGRESS_FOR_LESSON`

```jac
edge PROGRESS_FOR_LESSON {}
```

Direction:

```text
LessonProgress → LessonTemplate
```

### `SUBMISSION_FOR_ACTIVITY`

```jac
edge SUBMISSION_FOR_ACTIVITY {}
```

Direction:

```text
Submission → ActivityTemplate
```

### `MASTERY_OF_SKILL`

```jac
edge MASTERY_OF_SKILL {}
```

Direction:

```text
Mastery → Skill
```

### `EVIDENCE_FOR_MASTERY`

```jac
edge EVIDENCE_FOR_MASTERY {
    has contribution_weight: float = 1.0;
}
```

Direction:

```text
Submission → Mastery
AssessmentAttempt → Mastery
LessonProgress → Mastery
```

### `RECOMMENDS_SKILL`

```jac
edge RECOMMENDS_SKILL {}
```

Direction:

```text
Recommendation → Skill
```

### `RECOMMENDS_ROADMAP_ITEM`

```jac
edge RECOMMENDS_ROADMAP_ITEM {}
```

Direction:

```text
Recommendation → RoadmapItem
```

---

# Cardinality rules

## Catalogue and tracks

- application root → exactly one default catalogue;
- catalogue → zero or more tracks;
- track → exactly one configuration in the initial design;
- track → one or more versions after first version creation;
- track → at most one active published version.

## Track-version curriculum

- version → zero or more modules while draft;
- published version → at least one skill;
- module → one or more skills before publication;
- lesson template → at least one taught skill;
- activity template → at least one assessed skill unless it is a non-graded orientation activity;
- prerequisite edge → connects two different skills in the same version.

## Learner graph

- learner → zero or more enrollments;
- enrollment → exactly one track;
- enrollment → exactly one track version;
- enrollment version must belong to the enrollment track;
- enrollment → zero or more assessments;
- enrollment → at most one active roadmap;
- enrollment → at most one mastery node per skill;
- roadmap → one or more roadmap items after generation;
- roadmap item → exactly one target skill;
- submission → exactly one activity template.

---

# Cross-version isolation

The following edges must never cross track-version boundaries:

```text
CONTAINS_MODULE
CONTAINS_SKILL
MODULE_CONTAINS_SKILL
PREREQUISITE
HAS_LESSON_TEMPLATE
MODULE_HAS_LESSON
TEACHES_SKILL
HAS_ACTIVITY_TEMPLATE
LESSON_HAS_ACTIVITY
ASSESSES_SKILL
HAS_SOURCE_DOCUMENT
HAS_BLUEPRINT
DERIVED_FROM
TARGETS_SKILL
USES_LESSON_TEMPLATE
PROGRESS_FOR_LESSON
SUBMISSION_FOR_ACTIVITY
MASTERY_OF_SKILL
```

Validation rule:

```text
source.track_version_id == target.track_version_id
```

where both nodes contain a version field.

Exceptions require explicit future documentation.

---

# Cross-track isolation

The following must remain in one track:

- enrollment and its version;
- assessment and enrollment;
- roadmap and enrollment;
- roadmap items and roadmap;
- target skills and roadmap items;
- mastery and skill;
- submission and activity;
- lesson progress and lesson template;
- recommendation targets.

Any mismatch must produce:

```text
TRACK_GRAPH_MISMATCH
```

and prevent mutation.

---

# Prerequisite graph rules

## Direction

```text
Prerequisite → Dependent
```

Example:

```text
Variables ──PREREQUISITE──> Functions
```

## Required rules

1. Both skills belong to the same track version.
2. A skill cannot be its own prerequisite.
3. Duplicate prerequisite edges are prohibited.
4. Required prerequisite cycles are prohibited.
5. Recommended or reinforces relationships should also avoid cycles where they would confuse traversal.
6. Edge `required_mastery` must be between `0.0` and `1.0`.
7. Edge strength must be non-negative.

## Cycle detection

Before publishing a version, run a bounded depth-first traversal or equivalent graph algorithm.

The validator must return the detected cycle path.

Example:

```json
{
  "code": "PREREQUISITE_CYCLE",
  "path": [
    "skill-a",
    "skill-b",
    "skill-c",
    "skill-a"
  ]
}
```

---

# Mastery traversal rules

To determine whether a skill is unlockable:

1. Start from the target skill.
2. Traverse incoming required `PREREQUISITE` relationships.
3. Resolve the learner's mastery node for each prerequisite skill within the same enrollment.
4. Compare mastery score with the edge's `required_mastery`.
5. Return blockers and satisfied prerequisites.

Conceptual result:

```jac
obj SkillUnlockEvaluation {
    has skill_id: str;
    has unlockable: bool;
    has blocker_skill_ids: list[str];
    has satisfied_skill_ids: list[str];
}
```

Do not use mastery from another enrollment, track, or version.

---

# Recommended traversal patterns

## List catalogue tracks

```text
ApplicationRoot
→ HAS_CATALOGUE
→ LearningCatalogue
→ HAS_LEARNING_TRACK
→ LearningTrack
```

Then apply:

- status filter;
- visibility filter;
- authorization filter;
- enrollment-open filter where required.

## Load a track curriculum

```text
LearningTrack
→ HAS_TRACK_VERSION
→ matching TrackVersion
→ CONTAINS_MODULE / CONTAINS_SKILL
```

## Load learner enrollments

```text
Learner
→ HAS_ENROLLMENT
→ Enrollment
→ FOR_TRACK
→ LearningTrack
```

## Load learner roadmap

```text
Learner
→ HAS_ENROLLMENT
→ matching Enrollment
→ HAS_ROADMAP(active=true)
→ Roadmap
→ HAS_ROADMAP_ITEM
→ RoadmapItem
```

## Load skill mastery

```text
Enrollment
→ HAS_MASTERY
→ Mastery
→ MASTERY_OF_SKILL
→ Skill
```

## Find next unlockable skill

```text
Enrollment
→ active Roadmap
→ incomplete RoadmapItems
→ TARGETS_SKILL
→ Skill
→ incoming PREREQUISITE edges
→ prerequisite Skills
→ learner Mastery nodes
```

---

# Traversal safety

Walkers must:

- begin from an authorized root or validated starting node;
- restrict traversal to expected edge types;
- restrict results by track and version;
- cap traversal depth;
- cap returned node counts;
- detect duplicate graph paths;
- avoid serializing entire connected graphs;
- return typed DTOs rather than raw node graphs.

Do not provide a generic learner-facing walker that can traverse arbitrary node and edge types.

---

# Graph creation services

Node and edge creation should be coordinated by services rather than duplicated across walkers.

Suggested services:

```text
LearningCatalogueGraphService
TrackVersionGraphService
CurriculumGraphService
EnrollmentGraphService
RoadmapGraphService
MasteryGraphService
GraphIntegrityService
```

## `TrackVersionGraphService`

Responsibilities:

```text
attach_version_to_track
attach_configuration
validate_version_ownership
resolve_active_version
clone_version_graph
```

## `CurriculumGraphService`

Responsibilities:

```text
create_module
create_skill
connect_module_skill
connect_prerequisite
create_lesson_template
connect_lesson_skill
create_activity_template
connect_activity_skill
validate_curriculum_graph
```

## `EnrollmentGraphService`

Responsibilities:

```text
create_enrollment
attach_track
attach_track_version
validate_enrollment_context
archive_enrollment
```

---

# Graph integrity service

Create a reusable integrity validator.

Suggested result:

```jac
obj GraphIntegrityIssue {
    has code: str;
    has severity: str;
    has node_id: str | None = None;
    has edge_type: str | None = None;
    has message: str;
    has details_json: str = "{}";
}

obj GraphIntegrityReport {
    has valid: bool;
    has issues: list[GraphIntegrityIssue];
    has checked_nodes: int;
    has checked_edges: int;
}
```

Required checks:

```text
CATALOGUE_MISSING
TRACK_DETACHED
TRACK_CONFIGURATION_MISSING
TRACK_VERSION_DETACHED
ACTIVE_VERSION_INVALID
VERSION_TRACK_MISMATCH
CURRICULUM_NODE_VERSION_MISMATCH
PREREQUISITE_CYCLE
DUPLICATE_EDGE
DUPLICATE_ACTIVE_ROADMAP
ENROLLMENT_TRACK_MISMATCH
ENROLLMENT_VERSION_MISMATCH
MASTERY_SKILL_MISMATCH
SUBMISSION_ACTIVITY_MISMATCH
ROADMAP_ITEM_SKILL_MISMATCH
ORPHANED_LEARNER_RECORD
```

---

# Duplicate-edge policy

Before adding an edge, query for an existing equivalent edge.

Uniqueness examples:

```text
Catalogue + Track + HAS_LEARNING_TRACK
Track + Version + HAS_TRACK_VERSION
Module + Skill + MODULE_CONTAINS_SKILL
Skill A + Skill B + PREREQUISITE + relation_type
Enrollment + Roadmap + HAS_ROADMAP(active=true)
Mastery + Skill + MASTERY_OF_SKILL
```

When duplicates exist:

- safe duplicates may be consolidated during migration;
- conflicting edge attributes must be reported;
- learner history must not be deleted automatically.

---

# Deletion and archival rules

## Shared curriculum

Do not hard-delete:

- published tracks;
- published versions;
- curriculum referenced by learner records;
- source documents referenced by published curriculum.

Use archival or superseding states.

## Learner records

Do not delete learner history when:

- a track is archived;
- a version is superseded;
- enrollment is withdrawn;
- roadmap is replaced.

Mark old records inactive or archived.

## Detaching edges

Removing an edge that would orphan persisted domain data must require explicit validation.

---

# Migration from scalar-only relationships

Existing records may contain IDs but no graph edges.

Migration sequence:

1. Load the record.
2. Resolve its track and version.
3. Resolve the expected parent node.
4. Validate scalar IDs.
5. Create the named edge if absent.
6. Verify edge uniqueness.
7. Preserve scalar fields.
8. record migration status.

Example:

```text
Roadmap.enrollment_id exists
but Enrollment ─HAS_ROADMAP→ Roadmap is missing
```

The migration may create the edge only when:

- the enrollment exists;
- the learner IDs match;
- track IDs match;
- version IDs match;
- no conflicting active roadmap exists.

---

# Backward compatibility

During migration, walkers may resolve graph context using:

```text
1. Existing graph edges
2. Valid track and version scalar IDs
3. Legacy language resolver
4. Explicit error
```

Graph edges become authoritative after migration verification.

Do not immediately remove scalar IDs because they remain useful for:

- external contracts;
- indexing;
- debugging;
- migration;
- integrity checks.

---

# Serialization rules

Do not return raw connected nodes and edges to the frontend.

Return typed summaries.

Example:

```jac
obj SkillGraphItem {
    has skill_id: str;
    has title: str;
    has mastery_score: float;
    has status: str;
    has prerequisite_ids: list[str];
    has unlockable: bool;
}
```

Limit learner graph responses to the requested track and enrollment.

Do not expose:

- answer keys;
- hidden rubrics;
- private source-document storage keys;
- internal ownership metadata;
- unrelated learner nodes.

---

# Authorization boundaries

## Catalogue reads

Learners may traverse only tracks that pass visibility and publication rules.

## Lecturer reads

Lecturers may traverse:

- tracks they own;
- their draft versions;
- curriculum within those versions;
- authorized aggregate learner analytics.

They must not traverse unrelated private tracks or learner data.

## Learner reads

Learners may traverse:

- their own profile;
- their own enrollments;
- published curriculum for those enrollments;
- their own assessments, roadmaps, mastery, submissions, and recommendations.

## Administrative validation

Graph-integrity walkers must be private or administrative.

---

# Suggested internal walkers

These walkers support development and verification.

```text
validate_learning_catalogue_graph
validate_track_graph
validate_track_version_graph
validate_enrollment_graph
find_prerequisite_cycle
repair_safe_duplicate_edges
inspect_orphaned_track_nodes
inspect_orphaned_learner_records
```

Do not expose repair walkers publicly.

---

# Example validation walker contract

```jac
walker validate_track_version_graph {
    has track_version_id: str;
    has include_warnings: bool = True;
}
```

Example report:

```json
{
  "ok": false,
  "track_version_id": "trv_course_db_v1",
  "valid": false,
  "issues": [
    {
      "code": "PREREQUISITE_CYCLE",
      "severity": "ERROR",
      "message": "A required prerequisite cycle was detected.",
      "details": {
        "path": ["skill-a", "skill-b", "skill-a"]
      }
    }
  ]
}
```

---

# Testing strategy

Use Jac test blocks with isolated graph contexts.

## Catalogue tests

- creates one default catalogue;
- connects a track once;
- prevents duplicate catalogue edges;
- excludes detached tracks from discovery;
- persists catalogue-connected tracks.

## Track-version tests

- connects a version to exactly one track;
- prevents a version from belonging to two tracks;
- validates active-version ownership;
- rejects cross-track active versions;
- preserves superseded versions.

## Curriculum tests

- attaches modules to one version;
- attaches skills to one version;
- preserves module ordering;
- connects lessons to skills;
- connects activities to skills;
- rejects cross-version curriculum edges;
- rejects duplicate prerequisite edges;
- rejects self-prerequisites;
- detects required cycles.

## Enrollment tests

- connects learner to enrollment;
- connects enrollment to one track and version;
- rejects mismatched track and version;
- permits multiple tracks per learner;
- rejects duplicate active enrollment where prohibited;
- preserves archived enrollment history.

## Roadmap tests

- connects one active roadmap;
- rejects two active roadmap edges;
- orders roadmap items;
- connects each item to one target skill;
- rejects skill references from another version.

## Mastery tests

- creates one mastery node per enrollment and skill;
- rejects mastery from another version;
- records evidence edges;
- evaluates prerequisite mastery correctly;
- ignores mastery from other enrollments.

## Submission tests

- connects submission to one activity;
- rejects cross-track activity links;
- preserves grading history;
- prevents learner access to answer keys.

## Migration tests

- creates missing named edges from valid scalar IDs;
- does not duplicate existing edges;
- reports conflicting relationships;
- leaves ambiguous records unresolved;
- remains idempotent.

## Authorization tests

- learner cannot traverse another learner's enrollment;
- learner cannot read a private draft track;
- lecturer cannot mutate system tracks;
- public catalogue queries return only published authorized tracks;
- graph repair walkers are not publicly callable.

---

# Example Jac test outlines

```jac
test "track version cannot belong to two tracks" {
    # Create two tracks and one version.
    # Attach version to first track.
    # Attempt attachment to second track.
    # Assert VERSION_TRACK_MISMATCH.
}

test "prerequisite cycle is rejected" {
    # Create skills A, B, and C in one version.
    # Add A -> B and B -> C.
    # Attempt C -> A.
    # Assert PREREQUISITE_CYCLE.
}

test "learner mastery is enrollment scoped" {
    # Create two enrollments with similar skill titles.
    # Add mastery in enrollment one.
    # Evaluate unlock in enrollment two.
    # Assert mastery from enrollment one is ignored.
}

test "cross-version roadmap skill is rejected" {
    # Create roadmap for version 1.
    # Attempt to connect roadmap item to version-2 skill.
    # Assert ROADMAP_ITEM_SKILL_MISMATCH.
}
```

---

# Observability

Emit structured events:

```text
graph.catalogue.created
graph.track.attached
graph.track_version.attached
graph.curriculum.module_created
graph.curriculum.skill_created
graph.curriculum.prerequisite_created
graph.enrollment.created
graph.roadmap.attached
graph.mastery.created
graph.integrity.validation_completed
graph.integrity.issue_detected
graph.integrity.repair_completed
```

Recommended fields:

```text
track_id
track_version_id
learner_id
enrollment_id
node_id
edge_type
operation
actor_id
request_id
timestamp
```

Do not log raw learner answers or source-document text.

---

# Performance considerations

## Indexable scalar mirrors

Retain scalar IDs on nodes for efficient indexed lookup where supported:

```text
track_id
track_version_id
learner_id
enrollment_id
skill_id
roadmap_id
```

Graph relationships remain authoritative for relationship validation.

## Bounded queries

Catalogue queries must support pagination.

Large curriculum traversals must support:

- module filtering;
- page size;
- maximum node count;
- selective relationship loading.

## Avoid N+1 traversal

Repository methods should load related graph data in bounded batches where the Jac runtime and persistence backend permit it.

## Cache boundaries

Cache curriculum graph summaries by:

```text
track_version_id
```

Cache learner graph summaries by:

```text
learner_id + enrollment_id + revision marker
```

Never cache one learner's mastery for another learner.

---

# Implementation sequence

## Step 1 — Audit current graph schema

Document all existing nodes and edges for:

- learner;
- topics or skills;
- lessons;
- quizzes;
- roadmaps;
- mastery;
- submissions.

Identify relationships that already match this schema and reuse them where safe.

## Step 2 — Add missing node declarations

Add or update:

```text
LearningCatalogue
CourseModule
Skill
LessonTemplate
ActivityTemplate
Enrollment
LessonProgress
```

Reuse existing equivalent nodes rather than creating duplicates.

## Step 3 — Add named edge declarations

Create explicit edges defined in this specification.

## Step 4 — Add graph services

Centralize node attachment and invariant validation.

## Step 5 — Connect built-in tracks

Ensure seeded programming tracks and versions use the new graph structure.

## Step 6 — Migrate existing scalar relationships

Create safe named edges where existing IDs and graph context agree.

## Step 7 — Add integrity validation

Implement track, version, curriculum, and enrollment validators.

## Step 8 — Update repository traversal

Make repositories use bounded named-edge traversals.

## Step 9 — Add tests

Cover cardinality, version isolation, cycles, authorization, persistence, and migration.

## Step 10 — Run full regression flow

Confirm the existing programming journey still works.

---

# Acceptance criteria

## Shared graph

- [ ] One default learning catalogue exists.
- [ ] Every saved track is connected to the catalogue.
- [ ] Every track version belongs to exactly one track.
- [ ] Every active version belongs to its track and is published.
- [ ] Track configurations are connected correctly.

## Curriculum graph

- [ ] Modules belong to one track version.
- [ ] Skills belong to one track version.
- [ ] Lessons teach explicit skills.
- [ ] Activities assess explicit skills.
- [ ] Required prerequisite cycles are rejected.
- [ ] Cross-version curriculum edges are rejected.
- [ ] Duplicate domain edges are prevented.

## Learner graph

- [ ] Learners can have multiple enrollments.
- [ ] Every enrollment points to one track and one matching version.
- [ ] Assessments belong to enrollments.
- [ ] Roadmaps belong to enrollments.
- [ ] Roadmap items target version-correct skills.
- [ ] Lesson progress references version-correct lessons.
- [ ] Submissions reference version-correct activities.
- [ ] Mastery references version-correct skills.
- [ ] Recommendations remain enrollment scoped.

## Integrity

- [ ] Integrity validators return typed reports.
- [ ] Detached tracks are detected.
- [ ] Orphaned learner records are detected.
- [ ] Cross-track mismatches are detected.
- [ ] Cross-version mismatches are detected.
- [ ] Duplicate active roadmaps are detected.
- [ ] Safe migration repairs are idempotent.

## Security

- [ ] Learners cannot traverse other learners' private graphs.
- [ ] Draft tracks are not learner-discoverable.
- [ ] Answer keys and hidden rubrics are not learner-visible.
- [ ] Repair walkers are private or administrative.
- [ ] Traversals are bounded and edge-restricted.

## Quality

- [ ] `jac check` succeeds.
- [ ] Lint checks succeed.
- [ ] `jac test` passes.
- [ ] Persistence tests pass.
- [ ] Programming-track regression tests pass.

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
1. The global catalogue persists after restart.
2. Python and Jaseci tracks remain connected once each.
3. Each active version belongs to the correct track.
4. A learner can enroll in more than one track.
5. An enrollment cannot point to a version from another track.
6. Roadmap items cannot target skills from another version.
7. Mastery from one enrollment cannot unlock another enrollment.
8. Required prerequisite cycles are rejected.
9. Duplicate edges are not created on retry.
10. Existing assessment, roadmap, lesson, quiz, grading, mastery, dashboard, and skill-map flows still work.
```

---

# Expected result

After this specification is implemented:

- GraphLearn has a coherent OSP curriculum graph;
- learning tracks are persistently discoverable through a shared catalogue;
- published versions form isolated curriculum boundaries;
- modules, skills, lessons, activities, and source material have explicit relationships;
- learners progress through enrollment-scoped graphs;
- roadmaps and mastery can traverse prerequisites safely;
- cross-track and cross-version contamination is prevented;
- graph integrity can be tested and audited;
- existing programming tracks continue to work;
- lecturer-uploaded course content can later attach to the same graph without creating a second LMS architecture.
