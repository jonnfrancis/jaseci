# 31-track-aware-existing-models.md

## Overview

Update GraphLearn LMS's existing learner, assessment, roadmap, lesson, challenge, submission, mastery, dashboard, skill-map, and recommendation models so every curriculum-dependent record can identify the exact `LearningTrack` and `TrackVersion` that produced it.

This specification builds on:

- `29-learning-track-domain-model.md`
- `30-programming-track-migration.md`

The change must remain backward compatible while existing persisted records still contain legacy programming-language fields.

The target model is:

```text
LearningTrack
└── TrackVersion
    ├── Assessment
    ├── Roadmap
    ├── Lesson
    ├── Challenge
    ├── Submission
    ├── Mastery
    ├── Recommendation
    └── SkillMap
```

Learner-owned records remain connected to the learner graph, but they must also carry enough curriculum context to remain historically correct when:

- a learner studies multiple tracks;
- a course publishes a new version;
- a learner changes tracks;
- a lesson is regenerated;
- a roadmap is rebuilt;
- a lecturer edits future course content;
- legacy language fields are later removed.

---

## Status

- **Feature type:** Domain-model migration
- **Priority:** Critical
- **Depends on:** `29-learning-track-domain-model.md`
- **Depends on:** `30-programming-track-migration.md`
- **Blocks:** `34-track-aware-walker-migration.md`
- **Blocks:** lecturer-course assessment, roadmap, lesson, quiz, and grading work
- **Breaking changes allowed:** No
- **Persistence migration required:** Yes
- **Frontend impact:** Response types and local state must tolerate new fields
- **Primary implementation language:** Jac

---

## Problem statement

The current LMS may identify curriculum context through one or more of the following:

```text
language
selected_language
programming_language
learner.language
roadmap.language
lesson.language
```

This is insufficient once the platform supports:

- multiple programming tracks;
- lecturer-created courses;
- multiple versions of the same course;
- learners enrolled in more than one course;
- historical roadmaps tied to earlier course versions.

A learner's current selected track must not become the source of truth for older records.

Example:

```text
Learner currently studies Jaseci.
An older assessment was completed for Python.
```

The old assessment must remain linked to Python even if the learner's current track changes.

The exact curriculum identity must therefore be persisted directly on curriculum-dependent records.

---

## Goals

Implement model updates that:

1. Add `track_id` and `track_version_id` to every curriculum-dependent record.
2. Preserve legacy language fields during the compatibility period.
3. Keep historical records tied to the version used when they were created.
4. Distinguish shared curriculum entities from learner-generated instances.
5. Prevent records from referencing mismatched tracks and versions.
6. Support learners enrolled in multiple tracks.
7. Support published course-version isolation.
8. Preserve current programming-track behavior.
9. Provide safe defaults for older persisted Jac objects.
10. Establish validation and migration rules for later walker updates.

---

## Non-goals

This specification does not:

- migrate every walker to track-only input contracts;
- create lecturer accounts;
- implement course uploads;
- generate course blueprints;
- create enrollment UI;
- redesign lesson content generation;
- redesign quiz grading;
- remove legacy language fields;
- automatically migrate mastery between course versions;
- merge duplicate historical records;
- publish or archive course versions.

---

# Core modeling rule

Every curriculum-dependent record must include:

```jac
has track_id: str | None = None;
has track_version_id: str | None = None;
```

These fields are initially optional for persisted-data compatibility.

After migration and validation, new records created through updated walkers must always include both values.

## Meaning

### `track_id`

Identifies the stable curriculum identity.

Example:

```text
trk_builtin_python
```

### `track_version_id`

Identifies the exact curriculum snapshot.

Example:

```text
trv_builtin_python_v1
```

The version reference is required because generated content and learner progression must not silently move when a course changes.

---

# Model classification

Existing models must be classified into three groups.

## 1. Shared curriculum models

These represent reusable curriculum content or structure.

Examples:

```text
Skill
Topic
LessonTemplate
ChallengeTemplate
QuizTemplate
Rubric
```

These should normally belong to a `TrackVersion`.

## 2. Learner-specific models

These represent learner state.

Examples:

```text
AssessmentAttempt
Roadmap
RoadmapItem
LessonProgress
Submission
Mastery
Recommendation
```

These must identify the track and version used for that learner state.

## 3. Generated learner content

These are generated or personalized artifacts.

Examples:

```text
GeneratedLesson
GeneratedQuiz
GeneratedChallenge
GeneratedFeedback
```

These must carry both track context and generation metadata.

---

# Required model changes

## Learner model

The learner model must no longer use one language field as the complete curriculum state.

Current conceptual shape:

```jac
node Learner {
    has learner_id: str;
    has language: str | None;
}
```

Transitional shape:

```jac
node Learner {
    has learner_id: str;

    has active_track_id: str | None = None;
    has active_track_version_id: str | None = None;

    has language: str | None = None;

    has created_at: str;
    has updated_at: str;
}
```

### Rules

- `active_track_id` represents the currently selected learner context.
- It is not the authoritative source for historical records.
- `active_track_version_id` must belong to `active_track_id`.
- The learner may eventually have several enrollments.
- Legacy `language` remains temporarily for compatibility.
- Changing the active track must not rewrite previous assessments, roadmaps, submissions, or mastery records.

The future enrollment model will become the main representation of learner-track participation.

---

## Assessment model

The assessment definition or assessment session must include track context.

```jac
node Assessment {
    has assessment_id: str;
    has learner_id: str;

    has track_id: str | None = None;
    has track_version_id: str | None = None;

    has assessment_type: str;
    has status: str;
    has difficulty: str | None = None;

    has language: str | None = None;

    has created_at: str;
    has updated_at: str;
}
```

### Rules

- The assessment's track must be fixed at creation.
- Assessment evaluation must use the same track version.
- An assessment cannot be submitted under another track.
- A regenerated assessment is a new assessment record unless explicitly modeled as another attempt.
- Legacy language must agree with the track registry when present.

---

## Assessment attempt model

```jac
node AssessmentAttempt {
    has attempt_id: str;
    has assessment_id: str;
    has learner_id: str;

    has track_id: str | None = None;
    has track_version_id: str | None = None;

    has answers_json: str;
    has score: float | None = None;
    has status: str;

    has started_at: str;
    has submitted_at: str | None = None;
}
```

### Rules

- Attempt track references must match the parent assessment.
- Attempts cannot be moved between assessments.
- Track context must be copied from the assessment, not from current learner state.
- Evaluation must reject mismatches.

---

## Roadmap model

```jac
node Roadmap {
    has roadmap_id: str;
    has learner_id: str;

    has track_id: str | None = None;
    has track_version_id: str | None = None;

    has source_assessment_id: str | None = None;
    has status: str;
    has title: str;

    has language: str | None = None;

    has generated_at: str;
    has updated_at: str;
}
```

### Rules

- The roadmap track must match its source assessment.
- The roadmap version is immutable after creation.
- Regenerating a roadmap should create a replacement or incremented roadmap revision.
- A course-version update must not silently mutate an active roadmap.
- Roadmap items must inherit the roadmap track context.
- Only one roadmap may be marked active per learner and enrollment unless the product explicitly supports alternatives.

---

## Roadmap item model

```jac
node RoadmapItem {
    has roadmap_item_id: str;
    has roadmap_id: str;
    has learner_id: str;

    has track_id: str | None = None;
    has track_version_id: str | None = None;

    has skill_id: str | None = None;
    has lesson_id: str | None = None;

    has sequence_index: int;
    has status: str;
    has unlock_state: str;

    has created_at: str;
    has updated_at: str;
}
```

### Rules

- Track context must match the parent roadmap.
- Linked skills and lessons must belong to the same track version.
- Sequence indices must be unique within a roadmap.
- Unlocking must not traverse into another track.
- A roadmap item cannot reference content from a superseded version unless the roadmap itself uses that version.

---

## Lesson model

The project must distinguish shared lesson content from learner progress.

### Shared lesson

```jac
node Lesson {
    has lesson_id: str;

    has track_id: str | None = None;
    has track_version_id: str | None = None;

    has skill_id: str | None = None;
    has title: str;
    has content: str;
    has difficulty: str;

    has generation_key: str | None = None;
    has generation_version: int = 1;
    has source_references_json: str | None = None;

    has language: str | None = None;

    has created_at: str;
    has updated_at: str;
}
```

### Lesson progress

```jac
node LessonProgress {
    has lesson_progress_id: str;
    has learner_id: str;
    has lesson_id: str;

    has track_id: str | None = None;
    has track_version_id: str | None = None;

    has status: str;
    has progress_ratio: float = 0.0;
    has attempts: int = 0;

    has started_at: str | None = None;
    has completed_at: str | None = None;
    has updated_at: str;
}
```

### Rules

- Shared lesson content belongs to one track version.
- Lesson progress belongs to one learner.
- Lesson progress track context must match the lesson.
- A lesson generated for one course version must not be reused for another version without explicit validation.
- Cache keys must include `track_version_id`.
- Legacy language is optional compatibility metadata.

---

## Challenge model

```jac
node Challenge {
    has challenge_id: str;
    has lesson_id: str;

    has track_id: str | None = None;
    has track_version_id: str | None = None;

    has activity_type: str;
    has title: str;
    has instructions: str;
    has difficulty: str;
    has expected_answer: str | None = None;
    has rubric_json: str | None = None;
    has max_score: float = 100.0;

    has language: str | None = None;

    has created_at: str;
    has updated_at: str;
}
```

### Rules

- Challenge track context must match the lesson.
- Code challenges are allowed only when track configuration enables them.
- Rubrics belong to the same track version as the challenge.
- A challenge cannot be submitted under another track.

---

## Quiz model

If quizzes are separate from challenges, update them similarly.

```jac
node Quiz {
    has quiz_id: str;
    has lesson_id: str;

    has track_id: str | None = None;
    has track_version_id: str | None = None;

    has title: str;
    has question_count: int;
    has difficulty: str;
    has generation_version: int = 1;

    has language: str | None = None;

    has created_at: str;
    has updated_at: str;
}
```

Each quiz question should either:

- inherit track context through its parent quiz; or
- include direct track references if questions are independently reusable.

Do not duplicate fields unnecessarily when parent ownership is guaranteed by graph traversal.

---

## Submission model

```jac
node Submission {
    has submission_id: str;
    has learner_id: str;
    has challenge_id: str;

    has track_id: str | None = None;
    has track_version_id: str | None = None;

    has response_text: str | None = None;
    has response_json: str | None = None;
    has code: str | None = None;

    has score: float | None = None;
    has passed: bool | None = None;
    has grading_status: str;
    has grading_confidence: float | None = None;
    has feedback: str | None = None;

    has submitted_at: str;
    has graded_at: str | None = None;
}
```

### Rules

- Submission context must be copied from the challenge.
- Submission evaluation must reject track mismatches.
- A submission must never use the learner's current track as fallback when the challenge identifies another track.
- Grading artifacts must remain associated with the same track version.
- Historical submissions remain valid after a course publishes a new version.

---

## Mastery model

Mastery must become track-scoped.

```jac
node Mastery {
    has mastery_id: str;
    has learner_id: str;
    has skill_id: str;

    has track_id: str | None = None;
    has track_version_id: str | None = None;

    has score: float;
    has confidence: float | None = None;
    has evidence_count: int = 0;
    has status: str;

    has created_at: str;
    has updated_at: str;
}
```

### Required uniqueness

The logical uniqueness key is initially:

```text
learner_id + track_version_id + skill_id
```

Not:

```text
learner_id + skill title
```

### Rules

- Mastery for Python variables must not affect a similarly named skill in another course.
- Mastery from version `1` must not automatically overwrite version `2` mastery.
- Cross-version mastery migration requires a separate skill-mapping policy.
- Every mastery update must reference evidence from the same track version.
- Mastery thresholds come from the relevant track configuration.

---

## Recommendation model

```jac
node Recommendation {
    has recommendation_id: str;
    has learner_id: str;

    has track_id: str | None = None;
    has track_version_id: str | None = None;

    has roadmap_id: str | None = None;
    has target_skill_id: str | None = None;
    has target_lesson_id: str | None = None;

    has recommendation_type: str;
    has rationale: str;
    has status: str;

    has generated_at: str;
    has consumed_at: str | None = None;
}
```

### Rules

- Recommendations must remain within one track version.
- A recommendation must not select lessons from another course.
- Recommendations become stale when their roadmap is replaced or archived.
- The recommendation walker must later use the learner's active enrollment rather than a global language field.

---

## Skill-map model

If skill-map data is computed dynamically, no persisted snapshot may be required.

If persisted, use:

```jac
node SkillMapSnapshot {
    has skill_map_id: str;
    has learner_id: str;

    has track_id: str | None = None;
    has track_version_id: str | None = None;

    has roadmap_id: str | None = None;
    has snapshot_json: str;

    has generated_at: str;
}
```

### Rules

- Skill maps are track-specific.
- A learner with multiple tracks must receive separate skill maps.
- Skill-node IDs must belong to the same track version.
- Dashboard requests must identify or resolve the intended track.

---

## Dashboard summary model

If dashboard summaries are cached or persisted:

```jac
node DashboardSnapshot {
    has dashboard_snapshot_id: str;
    has learner_id: str;

    has track_id: str | None = None;
    has track_version_id: str | None = None;

    has roadmap_id: str | None = None;
    has summary_json: str;

    has generated_at: str;
    has expires_at: str | None = None;
}
```

Dashboard cache keys must include track context.

---

# Track-aware graph edges

Existing graph relationships should remain, but track validation must be added.

Recommended relationships:

```text
Learner
├── HAS_ASSESSMENT → Assessment
├── HAS_ROADMAP → Roadmap
├── HAS_LESSON_PROGRESS → LessonProgress
├── HAS_SUBMISSION → Submission
├── HAS_MASTERY → Mastery
└── HAS_RECOMMENDATION → Recommendation

Roadmap
└── HAS_ROADMAP_ITEM → RoadmapItem

RoadmapItem
├── TARGETS_SKILL → Skill
└── USES_LESSON → Lesson

Lesson
├── HAS_CHALLENGE → Challenge
└── HAS_QUIZ → Quiz
```

The graph may also include explicit track/version relationships later:

```text
TrackVersion
├── CONTAINS_SKILL → Skill
├── HAS_LESSON → Lesson
├── HAS_CHALLENGE → Challenge
└── HAS_QUIZ → Quiz
```

Scalar `track_id` fields remain useful for validation, indexing, serialization, and migration, but graph connectivity must also remain correct.

---

# Required invariants

## General invariants

Every new curriculum-dependent record must satisfy:

```text
track_id is not null
track_version_id is not null
track version belongs to track
```

## Parent-child invariants

```text
AssessmentAttempt.track == Assessment.track
Roadmap.track == source Assessment.track
RoadmapItem.track == Roadmap.track
LessonProgress.track == Lesson.track
Challenge.track == Lesson.track
Quiz.track == Lesson.track
Submission.track == Challenge.track
Mastery.track == Skill.track
Recommendation.track == Roadmap.track
SkillMap.track == Roadmap.track
```

## Historical invariants

- Existing records do not change track because learner preferences change.
- Published-version references are immutable on completed records.
- A course-version update creates future curriculum state rather than rewriting history.
- Completed submissions and grades remain linked to their original version.

## Data integrity invariants

- `track_version_id` cannot belong to another `track_id`.
- curriculum nodes cannot be attached to unrelated track versions;
- learner-specific records cannot inherit ambiguous track context;
- duplicate mastery records for the same logical key must be prevented or reconciled;
- archive operations must not delete referenced historical data.

---

# Shared validation service

Create or extend a track-context validation service.

Suggested functions:

```text
validate_track_exists
validate_track_version_exists
validate_version_belongs_to_track
validate_parent_child_track_match
validate_curriculum_entity_track
validate_learner_record_track
resolve_record_track_context
copy_track_context_from_parent
```

Suggested result:

```jac
obj TrackValidationResult {
    has valid: bool;
    has track_id: str | None;
    has track_version_id: str | None;
    has error_code: str | None;
    has message: str;
}
```

Do not duplicate track/version validation independently across walkers.

---

# Track-context copying rules

New child records must copy context from their authoritative parent.

Examples:

```text
AssessmentAttempt ← Assessment
Roadmap ← Assessment
RoadmapItem ← Roadmap
LessonProgress ← Lesson
Challenge ← Lesson
Submission ← Challenge
Recommendation ← Roadmap
```

Do not copy context from:

- the learner's current active track;
- frontend local storage;
- a free-form language string;
- unrelated recent records.

---

# Legacy compatibility fields

Legacy fields such as:

```text
language
selected_language
programming_language
```

remain temporarily.

Rules:

1. Track fields are authoritative when valid.
2. Legacy values must agree with built-in track mappings when present.
3. Lecturer-created courses may have `language = null`.
4. New code must not require language for non-programming tracks.
5. Legacy fields must be marked deprecated in comments or documentation.
6. A later cleanup specification will remove obsolete reads and writes.

---

# Model migration strategy

## Phase 1: Add optional fields

Add:

```jac
has track_id: str | None = None;
has track_version_id: str | None = None;
```

Use safe defaults so existing persisted nodes remain loadable.

## Phase 2: Backfill known records

Use the migration registry and resolver from `30-programming-track-migration.md`.

## Phase 3: Add validation on new writes

New records must include valid track references.

## Phase 4: Add track-first reads

Reads prefer track fields and fall back to legacy language only when needed.

## Phase 5: Make fields required

Only after:

- backfill completion;
- walker migration;
- frontend migration;
- rollback-window completion;
- unresolved-record repair.

---

# Backfill rules by model

## Learner

Resolve active track from:

1. existing valid active track;
2. current legacy language;
3. most recent active roadmap;
4. unresolved.

Do not use active learner track to rewrite history.

## Assessment

Resolve from:

1. existing track fields;
2. direct assessment language;
3. assessment journey context;
4. unresolved.

## Assessment attempt

Resolve from parent assessment.

## Roadmap

Resolve from:

1. source assessment;
2. direct roadmap language;
3. explicit journey relationship;
4. unresolved.

## Roadmap item

Resolve from parent roadmap.

## Lesson

Resolve from:

1. direct track fields;
2. owning roadmap item;
3. skill relationship;
4. direct legacy language;
5. unresolved.

## Challenge or quiz

Resolve from parent lesson.

## Submission

Resolve from parent challenge or quiz.

## Mastery

Resolve from:

1. skill ownership;
2. evidence records;
3. direct language;
4. unambiguous roadmap context;
5. unresolved.

Mastery requires extra caution because learners may have similarly named skills across tracks.

## Recommendation

Resolve from parent roadmap or target lesson.

## Skill-map snapshot

Resolve from the roadmap used to generate it.

---

# Unresolved records

A record remains unresolved when:

- no curriculum context exists;
- parent relationships are missing;
- related records disagree;
- legacy language is unknown;
- the track version cannot be determined;
- the referenced curriculum node belongs to multiple tracks.

Unresolved records must:

- remain unchanged;
- be reported;
- not be silently assigned to the learner's current track;
- not block unrelated valid records unless configured.

---

# Conflict handling

Examples:

```text
Roadmap.track_id = Python
RoadmapItem.track_id = Jaseci
```

```text
Submission.track_version_id = Python v1
Challenge.track_version_id = Python v2
```

Required behavior:

1. Stop mutation of the affected logical unit.
2. Preserve current data.
3. Emit a structured conflict record.
4. Include all conflicting IDs.
5. Require deterministic repair or manual review.
6. Do not choose the most recent value automatically.

---

# Domain errors

Add or reuse errors:

```text
TRACK_CONTEXT_MISSING
TRACK_CONTEXT_CONFLICT
TRACK_VERSION_MISMATCH
PARENT_TRACK_MISMATCH
CURRICULUM_ENTITY_TRACK_MISMATCH
LEARNER_RECORD_TRACK_MISMATCH
LEGACY_LANGUAGE_TRACK_MISMATCH
MASTERY_TRACK_AMBIGUOUS
ROADMAP_TRACK_IMMUTABLE
SUBMISSION_TRACK_IMMUTABLE
```

Example:

```json
{
  "ok": false,
  "error": {
    "code": "PARENT_TRACK_MISMATCH",
    "message": "The roadmap item does not belong to the roadmap's learning track.",
    "details": {
      "roadmap_id": "roadmap-1",
      "roadmap_track_id": "trk_builtin_python",
      "roadmap_item_id": "item-1",
      "roadmap_item_track_id": "trk_builtin_jaseci"
    }
  }
}
```

---

# Repository updates

Repositories must become track-aware.

Examples:

```text
get_assessment(assessment_id, track_id?)
list_assessments(learner_id, track_id?)
get_active_roadmap(learner_id, track_id)
list_roadmaps(learner_id, track_id?)
get_lesson(lesson_id, track_version_id?)
list_mastery(learner_id, track_id, track_version_id?)
get_recommendations(learner_id, track_id)
```

Rules:

- queries must filter by learner and track when both are required;
- `get_active_roadmap(learner_id)` without track becomes deprecated;
- repositories must not return another track's data because IDs collide or filters are omitted;
- graph relationship validation must accompany scalar filtering where practical.

---

# Serialization and frontend contracts

Every relevant response should include:

```json
{
  "track_id": "trk_builtin_python",
  "track_version_id": "trv_builtin_python_v1"
}
```

Temporary programming responses may also include:

```json
{
  "language": "python"
}
```

TypeScript interfaces must add optional track fields first, then make them required after migration.

Example:

```ts
export interface TrackContext {
  trackId: string;
  trackVersionId: string;
}

export interface RoadmapResponse extends TrackContext {
  roadmapId: string;
  learnerId: string;
  title: string;
  status: string;
  language?: string | null;
}
```

---

# Cache-key changes

Any cache containing curriculum-dependent data must include `track_version_id`.

Before:

```text
lesson:python:variables:beginner
quiz:python:lesson-1
mastery:learner-1
```

After:

```text
lesson:trv_builtin_python_v1:variables:beginner
quiz:trv_builtin_python_v1:lesson-1
mastery:learner-1:trv_builtin_python_v1
```

Track-independent metadata may use `track_id`.

Do not share generated content between versions unless a validation process confirms equivalence.

---

# Version-change behavior

When a new track version is published:

- existing roadmaps remain on their original version;
- existing lessons remain historically linked;
- completed submissions remain unchanged;
- mastery remains version-scoped;
- new enrollments use the active published version;
- learner migration requires an explicit future workflow;
- recommendations remain within the learner's roadmap version.

Never update every learner record merely because `active_version_id` changes.

---

# Deletion and archival behavior

Records referenced by historical learner data must not be hard deleted.

Prefer:

```text
ARCHIVED
SUPERSEDED
INACTIVE
```

Hard deletion is allowed only when:

- the record is an unreferenced draft;
- authorization permits deletion;
- graph-integrity checks pass;
- no learner progress depends on it.

---

# Observability

Emit structured events:

```text
track_context.backfilled
track_context.validation_failed
track_context.conflict_detected
track_context.legacy_fallback_used
track_context.parent_mismatch
track_context.version_mismatch
track_context.model_migration_completed
```

Recommended fields:

```text
entity_type
entity_id
learner_id
track_id
track_version_id
parent_entity_type
parent_entity_id
resolution_source
migration_version
request_id
timestamp
```

Metrics:

```text
track_context_missing_total
track_context_conflict_total
legacy_track_fallback_total
parent_track_mismatch_total
version_mismatch_total
model_records_backfilled_total
model_records_unresolved_total
```

---

# Testing strategy

Use Jac test blocks and representative persisted graph fixtures.

## Model loading tests

- older nodes without track fields still load;
- new defaults remain safe;
- enum and optional-field serialization succeeds;
- no existing records are deleted.

## Parent-child validation tests

- assessment attempt matches assessment;
- roadmap matches source assessment;
- roadmap item matches roadmap;
- challenge matches lesson;
- submission matches challenge;
- mastery matches skill ownership;
- mismatches fail with correct errors.

## Historical integrity tests

- changing learner active track does not change old assessment;
- publishing version `2` does not change version `1` roadmap;
- completed submissions retain original version;
- old recommendations remain tied to old roadmap;
- old mastery is not overwritten by a new version.

## Multi-track tests

- one learner can have Python and Jaseci records;
- roadmap queries return the requested track only;
- mastery is separated by track version;
- skill maps are separated by track;
- dashboard caches do not mix tracks.

## Backfill tests

- direct language backfills correctly;
- parent inheritance works;
- unknown values remain unresolved;
- conflicting values remain unchanged;
- repeated migration runs are idempotent.

## Cache tests

- Python v1 and Python v2 cache entries differ;
- Python and Jaseci entries differ;
- legacy keys are ignored or expired;
- no cross-track lesson reuse occurs.

## Regression tests

Verify the existing programming flow still works:

1. learner selects Python;
2. assessment is created with track context;
3. assessment attempt inherits context;
4. roadmap inherits context;
5. roadmap items inherit context;
6. lessons and challenges match context;
7. submissions inherit context;
8. mastery updates the correct track;
9. dashboard filters by track;
10. skill map filters by track;
11. next-action recommendation stays within track.

---

# Example Jac test outlines

```jac
test "roadmap inherits track context from assessment" {
    # Create a Python assessment.
    # Generate a roadmap from it.
    # Assert matching track and version IDs.
}

test "submission cannot cross track boundaries" {
    # Create a Python challenge.
    # Attempt a Jaseci submission context.
    # Assert PARENT_TRACK_MISMATCH.
}

test "learner active track does not rewrite history" {
    # Create Python assessment and roadmap.
    # Change learner active track to Jaseci.
    # Assert old records remain Python.
}

test "mastery is unique per learner track version and skill" {
    # Create mastery for the same learner and similarly named skills
    # in two tracks.
    # Assert records remain separate.
}
```

---

# Implementation sequence

## Step 1: Audit existing models

Document:

- current fields;
- current graph edges;
- persistence assumptions;
- language usage;
- parent-child relationships;
- cache dependencies.

## Step 2: Add optional track fields

Add safe optional fields to persisted models.

## Step 3: Add shared validation

Implement track/version and parent-child validation helpers.

## Step 4: Update repositories

Add track-aware query filters and deprecate ambiguous methods.

## Step 5: Implement backfill

Use deterministic registry and parent inheritance.

## Step 6: Add serialization fields

Expose track context in backend responses and frontend types.

## Step 7: Update cache namespaces

Include track versions in curriculum-sensitive cache keys.

## Step 8: Add write-time enforcement

Require track context for all newly created records.

## Step 9: Run regression tests

Verify the entire programming flow.

## Step 10: Monitor legacy fallback

Track remaining records and requests that still depend on language-only context.

---

# Acceptance criteria

## Model updates

- [ ] Learner active-track fields exist.
- [ ] Assessment track fields exist.
- [ ] Assessment-attempt track fields exist.
- [ ] Roadmap and roadmap-item track fields exist.
- [ ] Lesson and lesson-progress track fields exist.
- [ ] Challenge and quiz track fields exist.
- [ ] Submission track fields exist.
- [ ] Mastery track fields exist.
- [ ] Recommendation track fields exist.
- [ ] Skill-map and dashboard snapshots are track-aware where persisted.

## Integrity

- [ ] Every new curriculum record has valid track context.
- [ ] Parent-child track mismatches are rejected.
- [ ] Track versions belong to their track.
- [ ] Historical records remain immutable.
- [ ] Version publication does not rewrite old data.
- [ ] Multi-track learners do not receive mixed records.

## Migration

- [ ] Older persisted records still load.
- [ ] Known records are backfilled.
- [ ] Unknown records remain unresolved.
- [ ] Conflicts are reported.
- [ ] Migration is idempotent.
- [ ] Legacy language fields remain temporarily.

## Repositories and APIs

- [ ] Track-aware queries are available.
- [ ] Ambiguous learner-only queries are deprecated.
- [ ] API responses expose track context.
- [ ] Frontend types accept track context.
- [ ] Cache keys include track-version identity.

## Quality

- [ ] `jac check` succeeds.
- [ ] Lint checks succeed.
- [ ] `jac test` passes.
- [ ] Persistence tests pass.
- [ ] Multi-track tests pass.
- [ ] Existing programming-flow regression tests pass.

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
1. Existing records without track fields still load.
2. New Python assessments include Python track and version IDs.
3. New Jaseci assessments include Jaseci track and version IDs.
4. Roadmaps inherit context from assessments.
5. Roadmap items inherit context from roadmaps.
6. Lessons and challenges stay inside one track version.
7. Submissions cannot cross track boundaries.
8. Mastery is separated by track and version.
9. Changing the learner's active track does not alter history.
10. Publishing a new version does not mutate old roadmaps.
11. Dashboard and skill-map responses are track-specific.
12. Cache entries do not mix tracks or versions.
13. Legacy language-only records still resolve during compatibility.
14. Restarting the backend preserves all migrated references.
```

---

# Expected result

After implementation:

- all curriculum-dependent records can identify their learning track;
- all historical records can identify the curriculum version used;
- one learner can safely participate in multiple courses;
- course-version changes do not corrupt existing progress;
- mastery, recommendations, dashboards, and skill maps remain track-specific;
- programming-language compatibility remains intact;
- later walker migrations can rely on consistent model-level track context;
- lecturer-created courses can reuse the existing adaptive-learning data model.
