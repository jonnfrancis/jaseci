# 30-programming-track-migration.md

## Overview

Migrate GraphLearn LMS from programming-language strings to the generic `LearningTrack` and `TrackVersion` model introduced in `29-learning-track-domain-model.md`.

Each currently supported programming curriculum must become a deterministic, published, system-owned learning track.

The migration must preserve:

* existing learner accounts;
* assessment attempts and results;
* generated roadmaps;
* lesson progress;
* quizzes and challenges;
* submissions and grades;
* mastery records;
* dashboard data;
* skill-map data;
* recommendation history;
* existing language-based frontend behavior during the transition.

The migration must be:

* additive;
* idempotent;
* observable;
* testable;
* reversible during the compatibility period;
* safe for persisted Jac graph data.

---

## Status

* **Feature type:** Data and application migration
* **Priority:** Critical
* **Depends on:** `29-learning-track-domain-model.md`
* **Blocks:** `31-track-aware-existing-models.md`
* **Blocks:** `34-track-aware-walker-migration.md`
* **Breaking changes allowed:** No
* **Data migration required:** Yes
* **Rollback required:** Yes
* **Frontend impact:** Compatibility changes only
* **Primary implementation language:** Jac

---

## Problem statement

The existing LMS identifies a curriculum using programming-language values such as:

```text
python
Python
jaseci
Jac
javascript
```

These values may currently appear in:

* learner profile fields;
* assessment records;
* roadmap records;
* mastery records;
* walker inputs;
* repository filters;
* frontend state;
* local storage;
* URL parameters;
* generated prompts;
* seed data;
* cache keys;
* test fixtures.

This design assumes that every curriculum is a programming language.

It prevents lecturer-created courses such as:

```text
Database Management Systems
Introduction to Marketing
Business Statistics
Financial Accounting
```

from using the same adaptive-learning flow.

The target architecture replaces programming-language identity with:

```text
track_id
track_version_id
```

The programming-language name remains display metadata and temporary compatibility data, but it is no longer the primary curriculum identity.

---

## Goals

Implement a migration that:

1. Inventories all language-dependent code and persisted data.
2. Seeds deterministic programming learning tracks.
3. Creates a published version `1` for each supported track.
4. Creates a canonical legacy-language mapping.
5. Backfills track references into existing records.
6. Preserves legacy language fields temporarily.
7. Introduces track-first compatibility reads.
8. Supports temporary dual writes where necessary.
9. Keeps the current programming learner journey working.
10. Prevents duplicate tracks, versions, configurations, and edges.
11. Reports unresolved and conflicting historical values.
12. Supports dry-run, apply, verification, and rollback modes.

---

## Non-goals

This specification does not:

* remove all language fields;
* introduce lecturer accounts;
* introduce lecturer-created courses;
* redesign assessment generation;
* redesign roadmap generation;
* redesign lessons or quizzes;
* upload or process course documents;
* merge unrelated learner mastery records;
* automatically create tracks from unknown language strings;
* migrate all walkers to final track-only contracts;
* remove old frontend storage keys.

Those changes belong to later specifications.

---

# Migration principles

## 1. Add before removing

Track fields, seeded tracks, and compatibility resolvers must be available before legacy language-based behavior is removed.

## 2. Preserve learner data

The migration must not delete or recreate learner-owned records merely to add track references.

## 3. Use deterministic identities

Built-in programming tracks must use stable IDs across:

* development;
* testing;
* staging;
* production;
* redeployment;
* migration reruns;
* database restoration.

## 4. Make every operation idempotent

Rerunning the migration must not create duplicate:

* tracks;
* versions;
* configurations;
* catalogue edges;
* version edges;
* migration markers.

## 5. Avoid unsafe inference

Unknown or misspelled language values must be reported.

They must not be weakly matched to a programming track.

## 6. Preserve historical context

A historical assessment or roadmap must not be reassigned based only on the learner's current selected track.

## 7. Maintain rollback compatibility

Legacy language fields must remain available until track-based reads and writes are proven stable.

---

# Source-of-truth rules

During the migration period, read curriculum identity in this order:

```text
1. Valid track_id and track_version_id
2. Valid track_id with active-version resolution
3. Legacy language resolved through the canonical registry
4. Explicit migration or validation error
```

After migration cleanup:

```text
1. Valid track_id and track_version_id
2. Explicit validation error
```

A valid `track_id` must always take precedence over a legacy language value.

Example:

```json
{
  "track_id": "trk_builtin_python",
  "language": "jaseci"
}
```

This input contains a conflict.

The system must either:

* reject it as inconsistent; or
* use the track reference while reporting the mismatch.

It must never silently select Jaseci.

---

# Phase 1: Migration inventory

Before implementing the migration, audit all language-dependent code and data.

## Backend code inventory

Search for:

```text
language
selected_language
supported_languages
language_track
programming_language
course_language
```

Inspect:

* Jac node declarations;
* Jac object declarations;
* Jac walker declarations;
* walker reports;
* services;
* repositories;
* graph traversals;
* filters;
* byLLM prompts;
* seed operations;
* persistence code;
* serialization types;
* test fixtures;
* application constants.

## Frontend inventory

Inspect:

* React state;
* TypeScript interfaces;
* `localStorage`;
* URL parameters;
* course-selection components;
* assessment payloads;
* roadmap payloads;
* dashboard payloads;
* progress payloads;
* skill-map payloads;
* query-cache keys;
* labels and display text.

## Persistence inventory

Count distinct language values for every affected persisted model.

Example:

```json
{
  "learner_values": {
    "python": 34,
    "Python": 8,
    "jaseci": 19,
    "Jac": 4,
    "": 2,
    "pythn": 1
  },
  "assessment_values": {},
  "roadmap_values": {},
  "mastery_values": {}
}
```

Classify each value as:

```text
CANONICAL
ALIAS
BLANK
UNKNOWN
CONFLICTING
```

## Inventory deliverable

Produce a migration inventory containing:

```text
file or module
model or function
field or parameter
current purpose
migration action
risk level
test coverage
```

Example:

| Location          | Current field      | Migration action                 |
| ----------------- | ------------------ | -------------------------------- |
| Learner node      | `language`         | Add optional `track_id`          |
| Assessment walker | `language` input   | Add track compatibility resolver |
| Roadmap           | `language`         | Backfill track and version       |
| Local storage     | `selectedLanguage` | Add `selectedTrackId`            |
| Quiz cache        | language cache key | Move to track-version cache key  |

---

# Built-in programming-track registry

Create one canonical registry for supported built-in tracks.

Do not maintain separate language mappings in:

* walkers;
* repositories;
* frontend components;
* migration scripts;
* prompts;
* tests.

## Suggested registry

```jac
glob BUILTIN_PROGRAMMING_TRACKS: dict = {
    "python": {
        "track_id": "trk_builtin_python",
        "track_version_id": "trv_builtin_python_v1",
        "configuration_id": "cfg_builtin_python",
        "slug": "python-programming",
        "title": "Python Programming",
        "aliases": ["python", "python3", "py"],
        "subject_area": "Computer Science",
        "default_difficulty": "MIXED",
        "supports_code_challenge": True
    },
    "jaseci": {
        "track_id": "trk_builtin_jaseci",
        "track_version_id": "trv_builtin_jaseci_v1",
        "configuration_id": "cfg_builtin_jaseci",
        "slug": "jaseci-programming",
        "title": "Jaseci Programming",
        "aliases": ["jaseci", "jac", "jaclang"],
        "subject_area": "Computer Science",
        "default_difficulty": "MIXED",
        "supports_code_challenge": True
    }
};
```

Only include programming languages whose full flow currently works.

A language should be considered supported only when the application can complete:

```text
selection
→ assessment
→ assessment evaluation
→ roadmap
→ lesson
→ quiz or challenge
→ grading
→ mastery
→ next lesson
```

A language appearing only in a dropdown is not necessarily a supported track.

---

## Deterministic identifiers

Use deterministic IDs for built-in data.

Recommended examples:

```text
trk_builtin_python
trv_builtin_python_v1
cfg_builtin_python

trk_builtin_jaseci
trv_builtin_jaseci_v1
cfg_builtin_jaseci
```

Do not generate random built-in IDs during application startup.

Do not use titles as the only seed lookup.

Bad:

```text
find track where title == "Python Programming"
```

Correct:

```text
find track where track_id == "trk_builtin_python"
```

---

## Reserved identifier namespace

Reserve:

```text
trk_builtin_
trv_builtin_
cfg_builtin_
```

Lecturer-created tracks must not use these prefixes.

Validate this during track creation.

---

# Legacy language normalization

Implement one normalization function.

```jac
def normalize_legacy_language(
    value: str | None
) -> str | None;
```

The function must:

1. return `None` for null input;
2. trim whitespace;
3. convert to lowercase;
4. normalize agreed separators;
5. return `None` for a blank result.

Examples:

```text
" Python " → "python"
"PYTHON" → "python"
"JacLang" → "jaclang"
```

Normalization must not guess misspellings.

Unsafe automatic mappings:

```text
"pythn" → "python"
"java" → "javascript"
"jacob" → "jac"
```

These values must remain unresolved.

---

# Canonical legacy resolver

Create one resolver used by:

* migration scripts;
* compatibility walkers;
* repository adapters;
* frontend migration support;
* tests.

## Resolution result

```jac
obj LegacyTrackResolution {
    has resolved: bool;

    has canonical_language: str | None;
    has track_id: str | None;
    has track_version_id: str | None;

    has source_value: str | None;
    has resolution_type: str;

    has error_code: str | None;
    has message: str = "";
}
```

Resolution types:

```text
TRACK_ID
CANONICAL_LANGUAGE
ALIAS
MISSING
UNRESOLVED
CONFLICT
```

## Resolver contract

```jac
def resolve_legacy_programming_track(
    track_id: str | None,
    track_version_id: str | None,
    language: str | None
) -> LegacyTrackResolution;
```

## Resolution rules

1. Validate a supplied `track_id`.
2. Validate a supplied `track_version_id`.
3. Ensure the version belongs to the supplied track.
4. If the track is valid, use it.
5. If no track exists, normalize the language value.
6. Resolve canonical names and exact aliases.
7. Return `UNRESOLVED` for unknown values.
8. Return `MISSING` if all values are absent.
9. Return `CONFLICT` for mismatched valid inputs.
10. Never create a new track from a legacy value.

---

# Seed graph

Each built-in track must create:

```text
LearningCatalogue
└── HAS_LEARNING_TRACK
    └── LearningTrack
        ├── HAS_TRACK_CONFIGURATION
        │   └── TrackConfiguration
        └── HAS_TRACK_VERSION
            └── TrackVersion version 1
```

## Python example

```json
{
  "track": {
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
  },
  "version": {
    "track_version_id": "trv_builtin_python_v1",
    "track_id": "trk_builtin_python",
    "version_number": 1,
    "status": "PUBLISHED",
    "source_kind": "SEEDED"
  },
  "configuration": {
    "configuration_id": "cfg_builtin_python",
    "track_id": "trk_builtin_python",
    "supports_diagnostic_assessment": true,
    "supports_multiple_choice": true,
    "supports_short_answer": true,
    "supports_code_challenge": true
  }
}
```

---

# Seed service

Create:

```text
BuiltinProgrammingTrackSeedService
```

## Responsibilities

```text
ensure_catalogue
ensure_track
ensure_version_one
ensure_configuration
ensure_catalogue_edge
ensure_version_edge
ensure_configuration_edge
validate_seeded_track
produce_seed_report
```

## Seed algorithm

For every registry entry:

1. Resolve the persistent learning catalogue.
2. Look up the deterministic `track_id`.
3. Create the track when absent.
4. Validate the existing node when present.
5. Validate immutable identity fields.
6. Resolve deterministic version `1`.
7. Create version `1` when absent.
8. Verify that the version belongs to the correct track.
9. Resolve or create the configuration.
10. Ensure exactly one catalogue edge exists.
11. Ensure exactly one version edge exists.
12. Ensure exactly one configuration edge exists.
13. Validate the complete graph.
14. Set the active version.
15. Set track status to published.
16. Open enrollment.
17. Record the seed outcome.

Enrollment must only be enabled after every required node and edge is valid.

---

## Seed outcomes

Supported outcomes:

```text
CREATED
UNCHANGED
REPAIRED
SKIPPED
FAILED
```

### `CREATED`

The complete track graph was newly created.

### `UNCHANGED`

The complete graph already existed and passed validation.

### `REPAIRED`

A safe non-identity issue was repaired, such as a missing expected edge.

### `SKIPPED`

The registry entry was intentionally disabled or unsupported.

### `FAILED`

An unsafe conflict was detected.

---

## Seed conflicts

Fail safely when:

* a deterministic ID belongs to the wrong archetype;
* a deterministic track ID belongs to a lecturer course;
* a deterministic version belongs to another track;
* a slug is owned by a conflicting track;
* ownership type differs from the registry;
* track type differs from the registry;
* duplicate edges cannot be safely repaired;
* active-version references are inconsistent.

Do not silently overwrite identity conflicts.

---

# Seed idempotency

Running the seed repeatedly must produce:

```text
0 duplicate tracks
0 duplicate versions
0 duplicate configurations
0 duplicate catalogue edges
0 duplicate version edges
0 changed deterministic IDs
```

A valid second seed run should report:

```text
UNCHANGED
```

---

# Schema additions for migration

Add optional track references to affected models where needed:

```jac
has track_id: str | None = None;
has track_version_id: str | None = None;
```

Keep these fields optional during initial migration so older persisted objects remain loadable.

They may become required after:

* backfill completion;
* compatibility verification;
* walker migration;
* frontend migration;
* rollback-window closure.

---

# Backfill candidates

Inspect these models:

```text
Learner
Assessment
AssessmentAttempt
Roadmap
RoadmapItem
Lesson
Challenge
Submission
Mastery
Recommendation
SkillMap snapshot
```

Do not assume every model stores a direct language value.

Some records should inherit track context through graph relationships.

---

# Backfill resolution order

For each record, resolve track identity using:

```text
1. Existing valid track_id and track_version_id
2. Existing valid track_id
3. Direct legacy language field
4. Parent record's track context
5. Closely related historical record
6. Learner selection as a last safe fallback
7. Unresolved report entry
```

Historical context must take precedence over the learner's current selection.

Example:

```text
Learner currently studies Jaseci.
Old roadmap was generated for Python.
```

The old roadmap must remain associated with Python.

---

# Relationship-based inheritance

Use graph context when direct language fields are missing.

Example:

```text
Submission
→ Challenge
→ Lesson
→ RoadmapItem
→ Roadmap
```

When the entire chain resolves unambiguously to Python, the submission may inherit:

```text
track_id = trk_builtin_python
track_version_id = trv_builtin_python_v1
```

Do not infer from distant or ambiguous relationships.

---

# Conflict detection

A conflict exists when related records identify different tracks.

Example:

```text
Assessment.language = python
Roadmap.language = jaseci
Assessment and roadmap belong to the same journey
```

Required behavior:

1. Do not overwrite either record.
2. Mark the migration unit as `CONFLICT`.
3. Record every conflicting source.
4. Preserve existing values.
5. require a deterministic repair rule or manual review.

Conflict report example:

```json
{
  "status": "CONFLICT",
  "learner_id": "learner-1",
  "assessment_id": "assessment-1",
  "roadmap_id": "roadmap-1",
  "sources": [
    {
      "entity": "Assessment",
      "value": "python"
    },
    {
      "entity": "Roadmap",
      "value": "jaseci"
    }
  ]
}
```

---

# Missing-value rules

A missing field may inherit a track only when the relationship is unambiguous.

Safe:

```text
Submission has no language.
Its challenge belongs to a Python lesson.
Its lesson belongs to a Python roadmap.
```

Unsafe:

```text
A mastery record has no language.
The learner has completed both Python and Jaseci.
The mastery record has no linked skill or lesson.
```

The unsafe record must remain unresolved.

---

# Migration units

Migrate related records as logical learner-journey units where practical.

```text
Learner journey
├── assessment
├── assessment attempt
├── roadmap
├── roadmap items
├── lessons
├── challenges
├── submissions
└── mastery records
```

Before applying a unit:

1. resolve the expected track;
2. collect all related records;
3. detect conflicts;
4. prepare proposed updates;
5. validate track and version;
6. apply updates;
7. verify graph integrity;
8. record migration results.

When full graph transactions are unavailable, use checkpointed, idempotent updates.

---

# Migration records

Create a migration record structure.

```jac
obj ProgrammingTrackMigrationRecord {
    has migration_id: str;
    has migration_version: int;

    has entity_type: str;
    has entity_id: str;

    has status: str;

    has previous_language: str | None;
    has previous_track_id: str | None;
    has previous_track_version_id: str | None;

    has assigned_track_id: str | None;
    has assigned_track_version_id: str | None;

    has message: str;

    has migrated_at: str | None;
}
```

Statuses:

```text
PENDING
MIGRATED
UNCHANGED
SKIPPED
UNRESOLVED
CONFLICT
FAILED
ROLLED_BACK
```

Migration records should be stored outside ordinary learner-facing graph traversal.

---

# Migration version

Assign an explicit migration version:

```text
programming_track_migration_version = 1
```

A record migrated by version `1` must not be repeatedly modified by version `1` unless validation detects an incomplete operation.

Future corrective migrations must use a new version.

---

# Dry-run mode

The migration must support dry-run execution.

Dry-run mode:

* scans records;
* normalizes values;
* resolves proposed mappings;
* detects conflicts;
* detects seed collisions;
* computes expected updates;
* performs no domain mutation;
* produces a report.

Example:

```json
{
  "mode": "dry_run",
  "migration_version": 1,
  "tracks": {
    "create": 2,
    "reuse": 0,
    "repair": 0,
    "fail": 0
  },
  "records": {
    "scanned": 184,
    "migratable": 176,
    "unchanged": 4,
    "unresolved": 2,
    "conflicts": 2,
    "failed": 0
  }
}
```

Production apply mode must not proceed automatically when conflicts exceed a configured threshold.

---

# Apply mode

Apply mode must:

1. verify migration version;
2. verify persistence availability;
3. verify or create the catalogue;
4. seed built-in tracks;
5. validate all built-in track graphs;
6. create a pre-migration report;
7. process records in bounded batches;
8. write migration markers;
9. validate each batch;
10. produce a final report;
11. retain rollback data.

Batch size must be configurable.

Example:

```text
MIGRATION_BATCH_SIZE=100
```

---

# Compatibility track context

Create a temporary track-context adapter.

```jac
obj TrackContext {
    has track_id: str;
    has track_version_id: str;

    has title: str;
    has legacy_language: str | None;

    has resolution_source: str;
}
```

Resolver:

```jac
def resolve_track_context(
    track_id: str | None,
    track_version_id: str | None,
    language: str | None
) -> TrackContext;
```

The resolver must:

* validate track identity;
* validate version ownership;
* use the active version when appropriate;
* use legacy language only when a track is absent;
* report how the context was resolved;
* reject mismatched track and version values.

---

# Dual-write period

During the compatibility period, migrated operations may write:

```text
track_id
track_version_id
language
```

Rules:

1. Track references are authoritative.
2. Legacy language is derived from the built-in registry.
3. Lecturer-created tracks receive no fake programming language.
4. Legacy fields are retained only for compatibility.
5. All dual-write locations must be documented.
6. Dual writes must be removed in a later cleanup migration.

Programming example:

```json
{
  "track_id": "trk_builtin_python",
  "track_version_id": "trv_builtin_python_v1",
  "language": "python"
}
```

Future lecturer-course example:

```json
{
  "track_id": "trk_course_database_systems",
  "track_version_id": "trv_course_database_systems_v1",
  "language": null
}
```

---

# Supported-language response migration

The current supported-language operation must become track-backed.

Legacy response:

```json
{
  "languages": [
    "python",
    "jaseci"
  ]
}
```

Temporary combined response:

```json
{
  "languages": [
    "python",
    "jaseci"
  ],
  "tracks": [
    {
      "track_id": "trk_builtin_python",
      "track_version_id": "trv_builtin_python_v1",
      "slug": "python-programming",
      "title": "Python Programming",
      "track_type": "PROGRAMMING_LANGUAGE",
      "legacy_language": "python"
    },
    {
      "track_id": "trk_builtin_jaseci",
      "track_version_id": "trv_builtin_jaseci_v1",
      "slug": "jaseci-programming",
      "title": "Jaseci Programming",
      "track_type": "PROGRAMMING_LANGUAGE",
      "legacy_language": "jaseci"
    }
  ]
}
```

Both arrays must be generated from the same source of truth.

Do not maintain a separate hardcoded frontend language list.

---

# Frontend migration

## Local storage

Current keys may include:

```text
selectedLanguage
language
languageTrack
```

Add:

```text
selectedTrackId
selectedTrackVersionId
```

Read order:

```text
selectedTrackId
→ resolve track
→ otherwise resolve selectedLanguage
```

After successful local migration:

* save the track ID;
* save the version ID;
* retain the old language key during compatibility;
* reject unsupported values safely.

## TypeScript model

```ts
export interface LearningTrackOption {
  trackId: string;
  trackVersionId: string;
  slug: string;
  title: string;
  trackType: "PROGRAMMING_LANGUAGE" | "LECTURER_COURSE";
  legacyLanguage?: string | null;
}
```

## Temporary walker payload

```json
{
  "learner_id": "learner-1",
  "track_id": "trk_builtin_python",
  "track_version_id": "trv_builtin_python_v1",
  "language": "python"
}
```

The backend must prefer `track_id`.

---

# Cache-key migration

Inventory all language-based cache keys.

Before:

```text
quiz:python:lesson-1
roadmap:learner-1:python
lesson:python:variables:beginner
```

After:

```text
quiz:trv_builtin_python_v1:lesson-1
roadmap:learner-1:trv_builtin_python_v1
lesson:trv_builtin_python_v1:variables:beginner
```

Rules:

* use `track_version_id` for curriculum-sensitive generated content;
* use `track_id` for version-independent metadata;
* do not mix content from different versions;
* version the cache namespace;
* invalidate or expire old language-keyed entries.

Suggested namespace:

```text
graphlearn:v2:<resource>:<track-version>:...
```

---

# Prompt compatibility

Existing byLLM prompts may currently use:

```text
Generate a Python lesson.
```

Temporary track-aware context:

```text
Track ID: trk_builtin_python
Track version: trv_builtin_python_v1
Track title: Python Programming
Legacy language: python
```

This migration must not substantially redesign prompt behavior.

It only changes curriculum identity and context resolution.

---

# Rollback strategy

Rollback must remain possible while language fields are retained.

## Rollback may

* switch reads back to language-first mode;
* disable track-first compatibility behavior;
* restore previous track fields where recorded;
* close seeded-track enrollment;
* mark migration records as rolled back.

## Rollback must not

* delete learners;
* delete assessments;
* delete roadmaps;
* delete submissions;
* delete mastery records;
* delete shared tracks already referenced by new data;
* reuse version identifiers for different content.

## Rollback record

Store:

```text
entity type
entity ID
old language
old track ID
old track-version ID
new track ID
new track-version ID
migration version
migration timestamp
```

Once lecturer-created data exists, prefer forward fixes instead of dismantling the track model.

---

# Failure handling

## Seed failure

When built-in seed validation fails:

1. stop the record backfill;
2. keep legacy reads enabled;
3. emit a critical migration event;
4. do not advertise incomplete tracks;
5. preserve existing data.

## Batch failure

When a batch fails:

* mark it failed;
* retain successful prior batches;
* preserve restart position;
* avoid duplicate updates on retry;
* produce a failure report.

## Unknown values

Unknown values enter a repair queue.

They must not create tracks automatically.

## Serialization or schema failures

Records that cannot be safely deserialized or migrated must be reported or quarantined according to the configured persistence backend.

They must never be silently discarded.

---

# Observability

Emit structured events:

```text
programming_track_migration.started
programming_track_migration.dry_run_completed
programming_track_migration.batch_started
programming_track_migration.batch_completed
programming_track_migration.record_migrated
programming_track_migration.record_unresolved
programming_track_migration.conflict_detected
programming_track_migration.failed
programming_track_migration.completed
programming_track_migration.rolled_back

builtin_programming_track.created
builtin_programming_track.reused
builtin_programming_track.repaired
builtin_programming_track.conflict
```

Metrics:

```text
migration_records_scanned_total
migration_records_changed_total
migration_records_unresolved_total
migration_conflicts_total
migration_failures_total
migration_batch_duration_ms
builtin_tracks_valid_total
builtin_tracks_invalid_total
legacy_resolver_fallback_total
```

Do not log:

* learner answers;
* passwords;
* access tokens;
* document contents;
* generated lesson bodies.

---

# Migration report

Produce both machine-readable and human-readable reports.

Example:

```json
{
  "migration": "programming-track-migration",
  "version": 1,
  "mode": "apply",
  "status": "completed_with_warnings",
  "started_at": "2026-07-15T08:00:00Z",
  "completed_at": "2026-07-15T08:02:12Z",
  "tracks": {
    "created": 2,
    "reused": 0,
    "repaired": 0,
    "failed": 0
  },
  "entities": {
    "scanned": 184,
    "migrated": 176,
    "unchanged": 4,
    "unresolved": 2,
    "conflicts": 2,
    "failed": 0
  },
  "unresolved_values": [
    "pythn"
  ],
  "conflict_ids": [
    "roadmap-123",
    "assessment-456"
  ]
}
```

Migration reports must not be exposed through ordinary learner graph traversal.

---

# Testing strategy

Use Jac test blocks for service, repository, graph, and migration testing.

## Registry tests

* every supported language exists;
* deterministic IDs are unique;
* slugs are unique;
* aliases do not collide;
* every track has a version `1`;
* published tracks have valid configurations.

## Normalization tests

* whitespace is trimmed;
* casing is normalized;
* canonical names resolve;
* exact aliases resolve;
* blank values return missing;
* unknown values remain unresolved;
* Java is not mapped to JavaScript;
* misspellings are not fuzzy-matched.

## Seed tests

* creates a missing catalogue;
* creates the Python track;
* creates the Jaseci track;
* creates one version per track;
* creates one configuration per track;
* creates required edges;
* activates version `1`;
* opens enrollment after validation;
* a second run creates no duplicates;
* identity conflicts fail safely.

## Backfill tests

* direct language values are migrated;
* child records inherit unambiguous parent context;
* valid existing track references remain unchanged;
* track-version mismatches are rejected;
* unknown values remain unresolved;
* conflicting related records are reported;
* current learner selection does not overwrite historical context;
* repeated migration runs remain safe.

## Dry-run tests

* no graph state changes;
* proposed counts are correct;
* unknown values are reported;
* conflicts are reported;
* no applied migration markers are created.

## Rollback tests

* old values can be restored;
* legacy language remains available;
* rollback state is recorded;
* referenced tracks are not deleted;
* repeated rollback remains safe.

## Frontend compatibility tests

* language-only requests work;
* track-aware requests work;
* track references take precedence;
* old local selections migrate;
* unsupported values produce recoverable errors;
* track and language options come from one source.

## End-to-end regression tests

For every supported programming track:

1. list tracks;
2. select a track;
3. initialize assessment;
4. submit assessment;
5. evaluate assessment;
6. generate roadmap;
7. retrieve roadmap;
8. generate or load lesson;
9. generate quiz or challenge;
10. evaluate submission;
11. update mastery;
12. unlock next lesson;
13. retrieve dashboard;
14. retrieve skill map;
15. retrieve next-action recommendation;
16. restart the backend;
17. verify persisted state.

---

# Example Jac test outlines

```jac
test "seeds programming tracks idempotently" {
    # Run the seed service twice.
    # Assert one Python track exists.
    # Assert one Jaseci track exists.
    # Assert one version-1 relationship per track.
    # Assert no duplicate catalogue edges exist.
}

test "resolves exact legacy aliases" {
    # Assert Python, python, and py resolve to Python.
    # Assert jac and jaclang resolve to Jaseci.
    # Assert unknown values remain unresolved.
}

test "preserves existing valid track references" {
    # Create a record with a valid track and version.
    # Include a matching legacy language.
    # Run migration.
    # Assert the track references remain unchanged.
}

test "detects historical conflicts" {
    # Create a Python assessment.
    # Connect a Jaseci roadmap to the same journey.
    # Run migration dry run.
    # Assert conflict is reported.
    # Assert neither record is changed.
}
```

---

# Deployment sequence

## Phase 1: Prepare additive code

1. Add optional track fields.
2. Add the built-in registry.
3. Add normalization.
4. Add the compatibility resolver.
5. Add the seed service.
6. Add dry-run support.
7. Add migration markers.
8. Add compatibility reads.
9. Add temporary dual writes.
10. Add tests.

## Phase 2: Staging migration

1. Restore representative persisted data.
2. Run schema compatibility checks.
3. Run seed dry run.
4. Run backfill dry run.
5. inspect unknown values.
6. inspect conflicts.
7. resolve deterministic issues.
8. apply the migration.
9. run regression tests.
10. restart the backend.
11. verify persistence.

## Phase 3: Production migration

1. Back up the persistence store.
2. Deploy additive schema changes.
3. retain legacy reads.
4. run dry run.
5. review migration thresholds.
6. seed built-in tracks.
7. backfill in bounded batches.
8. verify each batch.
9. enable track-first reads.
10. monitor fallback metrics.

## Phase 4: Observation period

Monitor:

```text
legacy resolver fallback usage
missing track references
track-version mismatches
unknown language values
walker failures
learner-flow failures
cache behavior
```

Do not remove legacy fields until fallback use is sufficiently low and all critical workflows pass.

## Phase 5: Future cleanup

A later specification may:

* make track fields required;
* remove dual writes;
* remove language-first reads;
* remove obsolete cache keys;
* remove deprecated local-storage keys;
* retain language only as track metadata.

---

# Implementation checklist

## Audit

* [ ] Backend language references inventoried.
* [ ] Frontend language references inventoried.
* [ ] Persisted values counted.
* [ ] Unknown values identified.
* [ ] Conflicting values identified.
* [ ] Language-based cache keys identified.

## Registry

* [ ] Canonical registry created.
* [ ] Deterministic IDs assigned.
* [ ] Reserved prefixes enforced.
* [ ] Alias collisions checked.
* [ ] Only fully supported languages are published.

## Seed operation

* [ ] Catalogue resolution implemented.
* [ ] Track seeding implemented.
* [ ] Version seeding implemented.
* [ ] Configuration seeding implemented.
* [ ] Edge validation implemented.
* [ ] Active-version validation implemented.
* [ ] Idempotency tested.
* [ ] Conflict handling tested.

## Compatibility

* [ ] Normalizer implemented.
* [ ] Resolver implemented.
* [ ] Track context implemented.
* [ ] Track-first reads implemented.
* [ ] Temporary dual writes documented.
* [ ] Supported-language response is track-backed.
* [ ] Frontend local-storage migration added.

## Backfill

* [ ] Dry-run mode implemented.
* [ ] Apply mode implemented.
* [ ] Bounded batches implemented.
* [ ] Migration markers implemented.
* [ ] Parent-context inheritance implemented.
* [ ] Unknown values remain unresolved.
* [ ] Conflict handling implemented.
* [ ] Repeated runs are safe.

## Rollback

* [ ] Backup procedure documented.
* [ ] Previous values recorded.
* [ ] Rollback behavior tested.
* [ ] Rollback preserves learner data.
* [ ] Forward-fix policy documented.

## Verification

* [ ] Graph integrity passes.
* [ ] Tracks persist after restart.
* [ ] Python flow passes.
* [ ] Jaseci flow passes.
* [ ] No duplicate seed data exists.
* [ ] No unexpected resolver fallback remains.

---

# Acceptance criteria

This specification is complete when:

1. Every fully supported programming curriculum has one deterministic learning track.
2. Every built-in track has a valid published version `1`.
3. Seed reruns create no duplicate graph objects.
4. Legacy values resolve through one canonical registry.
5. Existing persisted records can be safely backfilled.
6. Unknown values are reported rather than guessed.
7. Historical conflicts are preserved for review.
8. Language fields remain during the rollback window.
9. Track-first compatibility reads work.
10. Existing language-only requests still work.
11. The learner experience does not regress.
12. Data remains available after a backend restart.
13. Dry-run, apply, report, and rollback paths are tested.
14. Jac checks and tests pass.

---

# Check when done

Run the commands supported by the installed Jac version:

```bash
jac check <entry-file>
jac check --lint <entry-file>
jac test
```

Run dry-run mode and verify:

```text
no duplicate deterministic IDs
no alias collisions
no unexpected unsupported values
no unsafe historical inference
expected record counts
expected conflict counts
```

Run apply mode and verify:

```text
1. Each built-in track exists once.
2. Each built-in track has version 1.
3. Each track has one valid configuration.
4. Existing learners retain their data.
5. Language-only requests still work.
6. Track-aware requests work.
7. Python assessment works.
8. Jaseci assessment works.
9. Roadmap generation works.
10. Lessons and quizzes work.
11. Grading and mastery work.
12. Dashboard and skill map work.
13. Backend restart preserves the graph.
14. A second migration run makes no unexpected changes.
15. Rollback preserves learner data.
```

---

# Expected result

After implementation:

* language strings are no longer the primary curriculum identity;
* Python, Jaseci, and other verified programming curricula are system-owned learning tracks;
* existing learner data references stable tracks and versions;
* legacy language-only clients remain temporarily compatible;
* migration behavior is measurable and repeatable;
* migration failures do not silently destroy graph data;
* rollback remains available during the transition;
* the LMS is ready for track-aware model and walker changes;
* lecturer-created courses can later reuse the same adaptive-learning engine.