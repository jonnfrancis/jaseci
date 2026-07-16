# 34-track-aware-walker-migration.md

## Overview

Migrate GraphLearn LMS walkers from programming-language-specific inputs and behavior to the generic learning-track architecture introduced in:

- `29-learning-track-domain-model.md`
- `30-programming-track-migration.md`
- `31-track-aware-existing-models.md`
- `32-learning-track-osp-schema.md`
- `33-track-repositories-and-services.md`

Every learner-facing walker that currently depends on a `language`, `selected_language`, or equivalent value must become track-aware.

The migration must preserve the complete existing programming-language journey while enabling future lecturer-created courses to use the same walkers.

The target request flow is:

```text
Jac Client
    ↓ Spawn()
Track-aware walker
    ↓
Authenticated actor resolution
    ↓
TrackContextResolver
    ↓
Application service
    ↓
Repositories + domain services
    ↓
Track-version-isolated OSP graph
```

The migration must not create separate versions of the existing walkers for lecturer courses.

Bad design:

```text
generate_programming_roadmap
generate_lecturer_course_roadmap
```

Required design:

```text
generate_roadmap(track_id, track_version_id, learner_id, assessment_id)
```

---

## Status

- **Feature type:** Walker contract and orchestration migration
- **Priority:** Critical
- **Depends on:** `33-track-repositories-and-services.md`
- **Blocks:** Lecturer course catalogue, enrollment, assessment, roadmap, lesson, quiz, grading, and analytics specifications
- **Breaking changes allowed:** No during the compatibility period
- **Walker renaming required:** No unless an existing name is misleading or unsafe
- **Frontend migration required:** Yes, incrementally
- **Persistence migration required:** Existing backfill from prior specifications must be available
- **Primary implementation language:** Jac
- **Client invocation:** Jac Client `spawn()`

---

## Goals

Implement a migration that:

1. Adds `track_id` and `track_version_id` to all curriculum-dependent walker contracts.
2. Centralizes track-context resolution.
3. Preserves temporary support for legacy `language` inputs.
4. Validates track, version, learner, enrollment, and graph relationships before use.
5. Keeps walkers thin and delegates domain behavior to services.
6. Reuses the same walkers for programming and lecturer-created tracks.
7. Prevents cross-track and cross-version data access.
8. Preserves existing reports during a controlled response transition.
9. Supports idempotent retry behavior.
10. Adds stable error codes and observability.
11. Enables staged frontend rollout.
12. Provides rollback without deleting migrated data.
13. Verifies the complete existing programming workflow.

---

## Non-goals

This specification does not:

- implement lecturer authentication;
- implement course-document upload;
- generate course blueprints;
- publish lecturer courses;
- implement the final course catalogue;
- implement the final enrollment UI;
- redesign assessment pedagogy;
- redesign roadmap personalization;
- redesign lesson or quiz content;
- introduce new LLM providers;
- remove legacy language fields immediately;
- remove legacy response properties immediately;
- expose raw OSP nodes through walker reports.

---

# Current walker inventory

Audit the current codebase before changing contracts.

The known adaptive-learning walkers include:

```text
initialize_assessment
evaluate_assessment
generate_roadmap
generate_lesson
generate_challenge
evaluate_submission
update_mastery
unlock_next_lesson
get_dashboard
get_skill_map
recommend_next_action
```

The application may also contain supporting walkers such as:

```text
supported_language_tracks
load_assessment_journey
persist_journey
get_roadmap
get_lesson
get_challenge
get_progress
list_lessons
save_submission
current_auth_session
```

The migration audit must identify for each walker:

| Field | Description |
|---|---|
| Walker name | Current public or private walker name |
| Current inputs | Including implicit state from root or session |
| Current outputs | Report shape consumed by the frontend |
| Language dependency | Direct, indirect, prompt-only, cache-only, or none |
| Graph reads | Nodes and edges traversed |
| Graph writes | Nodes and edges created or updated |
| Service dependency | Existing service or inline logic |
| Authorization | Current checks |
| Idempotency | Current protection, if any |
| Migration action | Additive contract, internal-only change, or deprecation |
| Regression tests | Existing coverage |

Do not assume a walker is track-independent merely because it does not accept `language` directly. It may derive language from:

- learner profile;
- roadmap;
- lesson;
- local persistence;
- a graph traversal;
- a hard-coded prompt;
- a cache key.

---

# Core migration rule

Every curriculum-dependent walker must resolve exactly one authoritative `TrackContext` before accessing curriculum or learner progression.

```jac
obj TrackContext {
    has track_id: str;
    has track_version_id: str;

    has track_type: LearningTrackType;
    has track_title: str;
    has version_number: int;

    has legacy_language: str | None = None;
    has resolution_source: str;

    has is_published: bool;
    has is_enrollment_open: bool;
}
```

Valid resolution sources:

```text
EXPLICIT_TRACK_AND_VERSION
EXPLICIT_TRACK_ACTIVE_VERSION
PARENT_ENTITY
ENROLLMENT
LEGACY_LANGUAGE
SYSTEM_DEFAULT
```

`SYSTEM_DEFAULT` must be avoided for learner operations unless an existing legacy flow genuinely requires it and the choice is deterministic.

---

# Track-context resolver

Create one resolver used by all migrated walkers.

```jac
obj ResolveTrackContextInput {
    has track_id: str | None = None;
    has track_version_id: str | None = None;
    has language: str | None = None;

    has learner_id: str | None = None;
    has enrollment_id: str | None = None;

    has assessment_id: str | None = None;
    has roadmap_id: str | None = None;
    has roadmap_item_id: str | None = None;
    has lesson_id: str | None = None;
    has activity_id: str | None = None;
    has submission_id: str | None = None;
}
```

Suggested service contract:

```jac
obj TrackContextResolver {
    def resolve(
        input: ResolveTrackContextInput,
        actor: AuthenticatedActor,
        operation: str
    ) -> Result[TrackContext];
}
```

## Resolution order

Resolve in the following order:

1. Explicit valid `track_id` and `track_version_id`.
2. Parent entity's track and version.
3. Valid enrollment's pinned track and version.
4. Explicit valid `track_id` with permitted active-version resolution.
5. Legacy programming language mapping.
6. Return a stable error.

Parent entity context must take precedence for operations on existing entities.

Example:

```text
A submission belongs to a Python activity.
The learner's current selected track is Jaseci.
```

`evaluate_submission` must use the Python activity's track context.

It must not use the learner's current selection.

---

## Context consistency rules

When multiple context sources are supplied, validate consistency.

Example request:

```json
{
  "track_id": "trk_builtin_python",
  "track_version_id": "trv_builtin_python_v1",
  "language": "jaseci"
}
```

Required result:

```text
TRACK_CONTEXT_CONFLICT
```

Do not silently resolve conflicting values.

Other conflicts include:

- assessment belongs to Python but supplied track is Jaseci;
- roadmap belongs to version 1 but supplied version is 2;
- lesson belongs to another learner's roadmap;
- activity belongs to another track;
- enrollment belongs to another learner;
- active version differs from an entity's pinned version.

---

# Common walker input envelope

Use a consistent additive input pattern.

```jac
obj TrackAwareRequestContext {
    has learner_id: str | None = None;

    has track_id: str | None = None;
    has track_version_id: str | None = None;

    has enrollment_id: str | None = None;

    # Temporary compatibility field.
    has language: str | None = None;

    has request_id: str | None = None;
    has idempotency_key: str | None = None;
}
```

Individual walkers may flatten these fields if nested objects are inconvenient for Jac Client serialization, but naming and behavior must remain consistent.

---

# Common response metadata

During migration, successful curriculum-dependent reports should include normalized track metadata.

```jac
obj TrackResponseMeta {
    has track_id: str;
    has track_version_id: str;
    has track_title: str;
    has track_type: LearningTrackType;
    has version_number: int;
    has legacy_language: str | None = None;
}
```

Example:

```json
{
  "ok": true,
  "track": {
    "track_id": "trk_builtin_python",
    "track_version_id": "trv_builtin_python_v1",
    "track_title": "Python Programming",
    "track_type": "PROGRAMMING_LANGUAGE",
    "version_number": 1,
    "legacy_language": "python"
  },
  "data": {}
}
```

Legacy top-level fields may remain temporarily when required by the frontend.

---

# Standard walker execution template

Every migrated public walker should follow this order:

```text
1. Parse and validate transport input.
2. Resolve authenticated actor.
3. Resolve learner identity.
4. Resolve authoritative TrackContext.
5. Validate actor authorization.
6. Validate learner/track enrollment when required.
7. Validate referenced entity relationships.
8. Call one application service.
9. Map typed service result to a stable report.
10. Emit structured execution metrics.
```

Conceptual Jac outline:

```jac
walker example_track_aware_walker {
    has learner_id: str;
    has track_id: str | None = None;
    has track_version_id: str | None = None;
    has language: str | None = None;

    can enter with entry {
        actor = auth_service.require_actor();

        context_result = track_context_resolver.resolve(
            ResolveTrackContextInput(
                learner_id=self.learner_id,
                track_id=self.track_id,
                track_version_id=self.track_version_id,
                language=self.language
            ),
            actor,
            "example_operation"
        );

        if !context_result.ok {
            report error_mapper.to_report(context_result.error);
            disengage;
        }

        result = example_service.execute(
            actor=actor,
            learner_id=self.learner_id,
            track_context=context_result.value
        );

        report response_mapper.example(result, context_result.value);
    }
}
```

Adapt syntax to the installed Jac version and established project style.

---

# Walker-by-walker migration

## 1. `supported_language_tracks`

### Current responsibility

Returns programming-language options.

### Migration decision

Keep temporarily for backward compatibility, but source its output from published built-in `LearningTrack` nodes.

### Temporary response

```json
{
  "languages": ["python", "jaseci"],
  "tracks": [
    {
      "track_id": "trk_builtin_python",
      "track_version_id": "trv_builtin_python_v1",
      "title": "Python Programming",
      "track_type": "PROGRAMMING_LANGUAGE",
      "legacy_language": "python"
    }
  ]
}
```

### Later replacement

```text
list_available_tracks
```

### Rules

- Data must come from the track repository.
- Only published, valid, enrollable built-in programming tracks are returned.
- The legacy language array must be derived from the same registry.
- Do not maintain a separate hard-coded frontend list.

---

## 2. `initialize_assessment`

### Current conceptual contract

```jac
walker initialize_assessment {
    has learner_id: str;
    has language: str;
}
```

### Migrated additive contract

```jac
walker initialize_assessment {
    has learner_id: str;

    has track_id: str | None = None;
    has track_version_id: str | None = None;
    has enrollment_id: str | None = None;

    has language: str | None = None;

    has request_id: str | None = None;
    has idempotency_key: str | None = None;
}
```

### Behavior

1. Authenticate actor.
2. Verify the actor may initialize an assessment for the learner.
3. Resolve track context.
4. Validate the track is published.
5. Validate enrollment when the flow requires enrollment before assessment.
6. Check for a resumable in-progress assessment.
7. Use the assessment application service.
8. Persist `track_id` and `track_version_id` on the assessment.
9. Return normalized track metadata.

### Idempotency

The same learner, track version, assessment purpose, and idempotency key must not create duplicate active assessments.

Suggested natural key:

```text
learner_id + track_version_id + assessment_kind + active_status
```

### Prohibited behavior

- generating questions before track resolution;
- resolving curriculum from learner profile language when explicit track is supplied;
- using the latest track version when resuming an existing assessment;
- creating an assessment for an archived or invalid version.

---

## 3. `evaluate_assessment`

### Migrated contract

```jac
walker evaluate_assessment {
    has learner_id: str;
    has assessment_id: str;
    has responses: list;

    has track_id: str | None = None;
    has track_version_id: str | None = None;
    has language: str | None = None;

    has request_id: str | None = None;
    has idempotency_key: str | None = None;
}
```

### Authoritative context

The assessment node is authoritative.

Supplied track fields are optional consistency checks.

### Behavior

- Load assessment through repository.
- Verify it belongs to the learner.
- Resolve context from assessment.
- Reject conflicting supplied context.
- Reject evaluation of a different track's assessment.
- Apply deterministic or byLLM evaluation through the service.
- Persist results under the assessment's pinned version.
- Prevent duplicate final evaluation.
- Return readiness for roadmap generation.

### Idempotency

Repeated submission with the same idempotency key returns the existing result.

A completed assessment must not be evaluated again unless an explicit retry/reassessment operation exists.

---

## 4. `generate_roadmap`

### Migrated contract

```jac
walker generate_roadmap {
    has learner_id: str;
    has assessment_id: str;

    has track_id: str | None = None;
    has track_version_id: str | None = None;
    has enrollment_id: str | None = None;
    has language: str | None = None;

    has force_regenerate: bool = False;
    has request_id: str | None = None;
    has idempotency_key: str | None = None;
}
```

### Authoritative context

The evaluated assessment and valid enrollment are authoritative.

### Behavior

1. Load assessment.
2. Verify completed evaluation.
3. Resolve track context from assessment.
4. Validate enrollment where required.
5. Reject supplied context mismatch.
6. Check for an existing valid roadmap.
7. Generate through `RoadmapApplicationService`.
8. Pin roadmap to the assessment's track version.
9. Persist roadmap items with matching context.
10. Return track metadata and roadmap.

### Regeneration

`force_regenerate` must not overwrite an active roadmap destructively.

It should either:

- create a new roadmap revision; or
- require explicit archival of the previous roadmap.

### Prohibited behavior

- switching to the track's newest active version;
- mixing skills from multiple track versions;
- generating a second active roadmap unintentionally;
- using legacy language prompts without resolved track metadata.

---

## 5. `get_roadmap`

If present, migrate it to:

```jac
walker get_roadmap {
    has learner_id: str;
    has roadmap_id: str | None = None;
    has track_id: str | None = None;
    has track_version_id: str | None = None;
    has language: str | None = None;
}
```

Rules:

- `roadmap_id`, when supplied, is authoritative.
- Otherwise resolve the learner's active roadmap for the selected track version.
- Never return another track's roadmap.
- Never return another learner's roadmap.
- Include version metadata in the response.

---

## 6. `generate_lesson`

### Migrated contract

```jac
walker generate_lesson {
    has learner_id: str;
    has roadmap_item_id: str;

    has track_id: str | None = None;
    has track_version_id: str | None = None;
    has language: str | None = None;

    has regenerate: bool = False;
    has request_id: str | None = None;
    has idempotency_key: str | None = None;
}
```

### Authoritative context

The roadmap item and its parent roadmap are authoritative.

### Behavior

- Load roadmap item and parent roadmap.
- Verify learner ownership.
- Resolve track context from roadmap.
- Verify roadmap item targets a skill in the same version.
- Reject supplied mismatches.
- Retrieve or generate the lesson through the lesson service.
- Persist or link lesson with matching track context.
- Return lesson, source information when available, and track metadata.

### Reuse rules

A shared base lesson may be reused only when its cache and persistence identity includes:

```text
track_version_id
skill_id
lesson template version
difficulty/content variant
```

Learner-specific progress must not be stored on the shared lesson node.

### Regeneration

Regeneration must create a new variant or revision and must not silently mutate content already used for graded work.

---

## 7. `generate_challenge`

### Migrated contract

```jac
walker generate_challenge {
    has learner_id: str;
    has lesson_id: str;

    has track_id: str | None = None;
    has track_version_id: str | None = None;
    has language: str | None = None;

    has requested_activity_type: str | None = None;
    has retry_number: int | None = None;
    has request_id: str | None = None;
    has idempotency_key: str | None = None;
}
```

### Authoritative context

The lesson and its curriculum relationships are authoritative.

### Behavior

- Resolve lesson track context.
- Verify learner may access the lesson.
- Read track configuration for supported activity types.
- Reject unsupported activity types.
- Generate or retrieve the activity.
- Persist matching track and version references.
- Preserve retry and difficulty behavior.

### Programming compatibility

Existing coding challenges continue to work for programming tracks.

Future lecturer courses may use:

- multiple choice;
- short answer;
- numeric response;
- scenario response;
- essay;
- project activity.

The walker name may remain `generate_challenge` temporarily, while the domain model uses a generalized activity concept.

---

## 8. `evaluate_submission`

### Migrated contract

```jac
walker evaluate_submission {
    has learner_id: str;
    has activity_id: str;
    has submission_payload: dict;

    has track_id: str | None = None;
    has track_version_id: str | None = None;
    has language: str | None = None;

    has request_id: str | None = None;
    has idempotency_key: str | None = None;
}
```

If the existing contract uses `challenge_id`, retain it during compatibility or introduce a typed alias.

### Authoritative context

The activity node is authoritative.

### Behavior

- Load activity and owning lesson/skill.
- Verify learner access.
- Resolve activity track context.
- Validate submission type against activity type.
- Route to deterministic, code-test, numeric, or byLLM evaluator.
- Persist submission and grade under matching context.
- Return score, feedback, mastery impact, confidence, and review status.

### Security

- Never execute untrusted code outside the approved sandbox.
- Never select evaluation strategy solely from client input.
- Never accept a rubric supplied by the learner client.
- Use the server-owned activity and rubric.

### Idempotency

A duplicate request must not create duplicate grade or mastery events.

---

## 9. `update_mastery`

### Migration decision

Prefer to make mastery updates an internal service operation triggered by successful assessment or submission evaluation.

If a public walker must remain, restrict it carefully.

### Migrated contract

```jac
walker update_mastery {
    has learner_id: str;
    has evidence_id: str;
    has evidence_type: str;

    has track_id: str | None = None;
    has track_version_id: str | None = None;
    has language: str | None = None;

    has idempotency_key: str | None = None;
}
```

### Authoritative context

The assessment result, submission, or other evidence is authoritative.

### Behavior

- Load evidence.
- Verify evidence belongs to learner.
- Resolve track context from evidence.
- Resolve targeted skill nodes in the same version.
- Calculate mastery through the mastery service.
- Record idempotent mastery events.
- Recompute aggregate mastery if needed.

### Prohibited behavior

- accepting an arbitrary mastery score from the frontend;
- applying evidence across track versions;
- updating all skills with the same title across tracks;
- creating duplicate mastery events on retries.

---

## 10. `unlock_next_lesson`

### Migrated contract

```jac
walker unlock_next_lesson {
    has learner_id: str;
    has roadmap_id: str;
    has completed_roadmap_item_id: str;

    has track_id: str | None = None;
    has track_version_id: str | None = None;
    has language: str | None = None;

    has idempotency_key: str | None = None;
}
```

### Authoritative context

The roadmap is authoritative.

### Behavior

- Verify roadmap belongs to learner.
- Resolve track context from roadmap.
- Verify completed item belongs to roadmap.
- Read prerequisites only within the pinned version.
- Evaluate mastery threshold and completion rules.
- Unlock eligible roadmap items idempotently.
- Return unlocked items and blocking prerequisites.

### Graph safety

Traversal must be bounded to:

```text
learner
→ roadmap
→ roadmap items
→ track-version curriculum skills
→ prerequisite edges
```

Do not traverse unrelated tracks with matching skill names.

---

## 11. `get_dashboard`

### Migrated contract

```jac
walker get_dashboard {
    has learner_id: str;

    has track_id: str | None = None;
    has track_version_id: str | None = None;
    has enrollment_id: str | None = None;
    has language: str | None = None;

    has include_all_tracks: bool = False;
}
```

### Behavior

Default behavior should return one selected track context.

Future multi-track dashboard behavior may use `include_all_tracks`, but it must return separately grouped track summaries.

### Response example

```json
{
  "ok": true,
  "selected_track": {
    "track_id": "trk_builtin_python",
    "track_version_id": "trv_builtin_python_v1",
    "title": "Python Programming"
  },
  "progress": {},
  "roadmap": {},
  "mastery": {},
  "recommendation": {}
}
```

### Rules

- Do not aggregate mastery from unrelated tracks into one score.
- Do not combine versions without explicit migration logic.
- Cache keys must include learner and track version.

---

## 12. `get_skill_map`

### Migrated contract

```jac
walker get_skill_map {
    has learner_id: str;

    has track_id: str | None = None;
    has track_version_id: str | None = None;
    has roadmap_id: str | None = None;
    has language: str | None = None;
}
```

### Behavior

- Resolve selected track context.
- Load only skills belonging to that track version.
- Overlay learner mastery and roadmap state.
- Return graph nodes and edges with stable IDs.
- Mark locked, available, in-progress, and mastered states.

### Response requirements

Every returned skill node should include:

```text
skill_id
track_id
track_version_id
title
mastery_score
status
```

Every prerequisite edge should use stable skill IDs.

---

## 13. `recommend_next_action`

### Migrated contract

```jac
walker recommend_next_action {
    has learner_id: str;

    has track_id: str | None = None;
    has track_version_id: str | None = None;
    has enrollment_id: str | None = None;
    has language: str | None = None;
}
```

### Behavior

- Resolve track context.
- Load learner roadmap, mastery, recent activity, and prerequisites for the version.
- Recommend an action within the selected track only.
- Include stable target identifiers.
- Return an explanation grounded in track state.

### Prohibited behavior

- recommending content from another track without an explicit cross-track recommendation feature;
- using a title-only lookup;
- recommending content from a superseded version to a learner pinned to another version.

---

## 14. Journey-loading walkers

Walkers such as:

```text
load_assessment_journey
persist_journey
```

must become track-aware.

A learner can have multiple journeys, so a journey must be keyed by:

```text
learner_id + track_id + track_version_id
```

Do not load the most recent journey across all tracks unless the operation explicitly requests that behavior.

Suggested contract:

```jac
walker load_assessment_journey {
    has learner_id: str;
    has track_id: str | None = None;
    has track_version_id: str | None = None;
    has language: str | None = None;
}
```

---

# Authentication and learner resolution

Do not trust `learner_id` without validating it against the authenticated session.

Required patterns:

### Learner self-service

```text
authenticated user
→ learner profile
→ requested learner_id must match
```

### Lecturer or administrator operation

```text
authenticated actor
→ role and ownership authorization
→ learner access policy
```

During this specification, preserve current authentication behavior but centralize learner resolution where possible.

Suggested helper:

```jac
obj LearnerAccessService {
    def require_learner_access(
        actor: AuthenticatedActor,
        learner_id: str,
        operation: str
    ) -> Result[LearnerProfile];
}
```

---

# Enrollment validation policy

Not every existing programming flow may currently have an explicit enrollment record.

Use a phased policy.

## Compatibility phase

For built-in programming tracks:

- permit existing valid learner journeys without a formal enrollment;
- optionally create an idempotent compatibility enrollment;
- record that it was migrated or system-created.

For lecturer-created courses later:

- require explicit enrollment before assessment, roadmap, lesson, and activity access.

## Final policy

All learner progression operations require a valid enrollment pinned to a track version.

Do not block the existing programming flow before migration enrollment data exists.

---

# Public and private walker access

Review access modifiers for every walker.

## Public learner-facing walkers

Examples:

```text
initialize_assessment
evaluate_assessment
generate_roadmap
generate_lesson
generate_challenge
evaluate_submission
get_dashboard
get_skill_map
recommend_next_action
```

These must:

- require authentication;
- validate learner ownership;
- validate track access;
- return sanitized reports.

## Internal/private operations

Prefer internal services or private walkers for:

```text
update_mastery
activate_track_version
repair_track_context
backfill_track_references
rebuild_skill_map_projection
```

Do not expose privileged graph mutation merely because Jac Client can call walkers.

---

# Request and response compatibility

## Additive request migration

Old request:

```json
{
  "learner_id": "learner-1",
  "language": "python"
}
```

Temporary new request:

```json
{
  "learner_id": "learner-1",
  "track_id": "trk_builtin_python",
  "track_version_id": "trv_builtin_python_v1",
  "language": "python"
}
```

Final request:

```json
{
  "learner_id": "learner-1",
  "track_id": "trk_builtin_python",
  "track_version_id": "trv_builtin_python_v1"
}
```

## Additive response migration

Keep existing response fields while adding:

```text
track_id
track_version_id
track_title
track_type
version_number
```

Frontend migration must not depend on fields being removed in this phase.

---

# Stable response envelope

Use a consistent envelope where feasible.

## Success

```json
{
  "ok": true,
  "request_id": "req-123",
  "track": {},
  "data": {},
  "warnings": []
}
```

## Failure

```json
{
  "ok": false,
  "request_id": "req-123",
  "error": {
    "code": "TRACK_CONTEXT_CONFLICT",
    "message": "The supplied track does not match the assessment track.",
    "details": {
      "assessment_id": "assessment-1"
    },
    "retryable": false
  }
}
```

If changing all response envelopes is too disruptive, use a response mapper that preserves the old shape and includes the new metadata.

---

# Error codes

Add or standardize:

```text
TRACK_CONTEXT_REQUIRED
TRACK_CONTEXT_CONFLICT
TRACK_NOT_FOUND
TRACK_VERSION_NOT_FOUND
TRACK_VERSION_MISMATCH
TRACK_VERSION_NOT_PUBLISHED
TRACK_NOT_ACCESSIBLE
TRACK_NOT_ENROLLABLE
ENROLLMENT_REQUIRED
ENROLLMENT_NOT_FOUND
ENROLLMENT_TRACK_MISMATCH
LEARNER_ACCESS_DENIED
ASSESSMENT_TRACK_MISMATCH
ROADMAP_TRACK_MISMATCH
LESSON_TRACK_MISMATCH
ACTIVITY_TRACK_MISMATCH
SUBMISSION_TRACK_MISMATCH
MASTERY_TRACK_MISMATCH
ENTITY_NOT_IN_TRACK_VERSION
LEGACY_LANGUAGE_UNRESOLVED
LEGACY_LANGUAGE_DEPRECATED
IDEMPOTENCY_CONFLICT
```

Do not expose raw persistence errors or traversal internals.

---

# Idempotency

All mutating walkers must support safe retries.

## Required candidates

```text
initialize_assessment
evaluate_assessment
generate_roadmap
generate_lesson
generate_challenge
evaluate_submission
update_mastery
unlock_next_lesson
persist_journey
```

## Idempotency record

Suggested object or node:

```jac
node WalkerIdempotencyRecord {
    has idempotency_key: str;
    has walker_name: str;
    has actor_id: str;
    has learner_id: str | None;
    has track_id: str | None;
    has track_version_id: str | None;
    has request_hash: str;
    has status: str;
    has result_reference_id: str | None;
    has created_at: str;
    has completed_at: str | None = None;
}
```

Rules:

- Same key and same normalized request returns the existing result.
- Same key and different request returns `IDEMPOTENCY_CONFLICT`.
- Track context must be included in the normalized request hash.
- Failed retryable operations may be retried according to policy.
- Completed evaluation or mastery mutations must not run twice.

---

# Transaction and partial-failure rules

A walker may coordinate multiple graph writes.

Example `generate_roadmap`:

```text
create roadmap
create roadmap items
connect items
connect targeted skills
mark active roadmap
```

Required behavior:

- validate all inputs before mutation;
- use the service-layer unit-of-work pattern from specification 33;
- write idempotency state;
- avoid reporting success before required edges exist;
- mark incomplete operations for repair;
- do not leave a partially connected roadmap discoverable as active.

Where backend transactions are unavailable, use:

```text
PENDING
→ graph creation
→ integrity validation
→ ACTIVE
```

Failed `PENDING` aggregates must be repairable or safely removed when unreferenced.

---

# byLLM integration migration

Walkers must not construct prompts directly from unvalidated language strings.

Required flow:

```text
TrackContext
→ curriculum repository
→ typed generation input
→ byLLM service
→ typed output validation
```

Generation input should contain:

```text
track_id
track_version_id
track_title
track_type
learning objectives
skill/module context
learner level
source context when available
allowed activity types
```

Legacy language may be supplied as optional compatibility metadata only for built-in programming prompts.

Do not let LLM output select or change track identity.

---

# Cache migration

All curriculum-sensitive walker cache keys must use track version.

Before:

```text
roadmap:learner-1:python
lesson:python:variables:beginner
quiz:python:lesson-1
recommendation:learner-1
```

After:

```text
roadmap:learner-1:trv_builtin_python_v1
lesson:trv_builtin_python_v1:skill-variables:beginner
activity:trv_builtin_python_v1:lesson-1:attempt-1
recommendation:learner-1:trv_builtin_python_v1
```

Include relevant revision fields where generated content changes independently of the track version.

Do not use track title or language string as the sole cache namespace.

---

# Frontend/Jac Client migration

## Client API types

Introduce a reusable context type:

```ts
export interface TrackRequestContext {
  learnerId: string;
  trackId?: string;
  trackVersionId?: string;
  enrollmentId?: string;
  language?: string;
  requestId?: string;
  idempotencyKey?: string;
}
```

Use the naming conventions expected by the generated or existing Jac Client interface.

## Client state

Store:

```text
selectedTrackId
selectedTrackVersionId
selectedEnrollmentId
```

Retain temporarily:

```text
selectedLanguage
```

## Spawn wrapper

Create one helper that attaches selected track context consistently.

Conceptual example:

```ts
async function spawnTrackWalker<TInput, TOutput>(
  walkerName: string,
  input: TInput,
  context: TrackContext
): Promise<TOutput> {
  return spawn(walkerName, {
    ...input,
    track_id: context.trackId,
    track_version_id: context.trackVersionId,
    enrollment_id: context.enrollmentId,
    language: context.legacyLanguage,
  });
}
```

Do not make each page independently reconstruct the payload.

## Frontend response handling

- Prefer returned track metadata over stale local storage.
- Update selected track context when the server returns a valid normalized context.
- Treat context conflicts as recoverable navigation errors.
- Do not silently change tracks.

---

# Walker deprecation strategy

## Compatibility stage

- Existing walker names remain.
- Legacy `language` remains optional.
- Track fields are added.
- Warnings are emitted when fallback is used.

## Track-first stage

- Frontend always sends track fields.
- Language remains for compatibility only.
- Metrics monitor legacy fallback.

## Strict stage

- Track fields become required for new journeys.
- Existing entity operations derive context from parent entities.
- Legacy fallback is restricted to explicit compatibility endpoints.

## Cleanup stage

- Remove language inputs from migrated walker contracts.
- Remove compatibility response fields where safe.
- Remove deprecated client helpers.
- Retain human-readable programming-language metadata on tracks.

Do not remove compatibility based only on time. Use telemetry and regression evidence.

---

# Migration feature flags

Suggested flags:

```text
TRACK_AWARE_WALKERS_ENABLED
TRACK_CONTEXT_REQUIRED_FOR_NEW_JOURNEYS
LEGACY_LANGUAGE_FALLBACK_ENABLED
TRACK_RESPONSE_METADATA_ENABLED
TRACK_CONTEXT_CONFLICT_STRICT_MODE
AUTO_CREATE_PROGRAMMING_ENROLLMENT
```

Requirements:

- defaults must be documented by environment;
- flags must not permit authorization bypass;
- disabling track-aware behavior must not delete track data;
- flags should be temporary and removed after stabilization.

---

# Rollout plan

## Phase 1: Internal resolver

1. Implement track-context resolver.
2. Add repository and service support.
3. Keep existing walker contracts.
4. Resolve language internally to seeded tracks.
5. Add track references to newly created records.

## Phase 2: Additive walker contracts

1. Add optional `track_id`.
2. Add optional `track_version_id`.
3. Add optional `enrollment_id`.
4. Return track metadata.
5. Reject explicit conflicts.

## Phase 3: Frontend sends track context

1. Update selection state.
2. Update Spawn helpers.
3. Update assessment flow.
4. Update roadmap flow.
5. Update lesson/activity flow.
6. Update dashboard and skill map.
7. Keep language fallback.

## Phase 4: Track-first enforcement

1. Require track context for new learner journeys.
2. Derive context from parent entities for existing journeys.
3. Monitor fallback metrics.
4. Repair missing historical references.

## Phase 5: Compatibility removal

1. Disable legacy fallback in staging.
2. Run complete regression suite.
3. Disable fallback in production.
4. Remove deprecated fields in a later schema migration.

---

# Rollback strategy

Rollback must be possible during the compatibility period.

## Safe rollback actions

- disable track-first client payloads;
- restore language-based frontend selection;
- enable legacy fallback;
- return old response shapes;
- leave track references in persisted records;
- close incomplete new journeys if necessary.

## Prohibited rollback actions

- deleting seeded tracks;
- deleting track versions referenced by records;
- removing backfilled track IDs from valid records without a migration record;
- overwriting lecturer-course data once introduced;
- merging records across tracks.

After lecturer-created courses are active, prefer forward fixes rather than returning to language-only architecture.

---

# Observability

Emit structured walker events:

```text
walker.track_context_resolved
walker.track_context_fallback_used
walker.track_context_conflict
walker.authorization_denied
walker.enrollment_validation_failed
walker.execution_started
walker.execution_completed
walker.execution_failed
walker.idempotent_result_reused
walker.partial_operation_detected
```

Include:

```text
walker_name
request_id
actor_id
learner_id
track_id
track_version_id
resolution_source
legacy_fallback_used
duration_ms
outcome
error_code
retryable
```

Do not log:

- passwords;
- tokens;
- assessment answers;
- raw submissions;
- private course documents;
- full generated lesson content.

## Metrics

```text
walker_calls_total{walker,track_type,outcome}
walker_duration_ms{walker}
track_context_fallback_total{walker}
track_context_conflict_total{walker}
walker_authorization_denied_total{walker}
walker_idempotency_reuse_total{walker}
walker_partial_failures_total{walker}
walker_cross_version_rejections_total{walker}
```

---

# Security requirements

Every migrated walker must protect against:

- learner ID spoofing;
- track ID enumeration;
- private-track discovery;
- enrollment bypass;
- cross-track entity access;
- cross-version entity access;
- arbitrary mastery updates;
- learner-supplied grading rubrics;
- duplicate submission grading;
- prompt injection through unvalidated metadata;
- raw graph-node leakage.

Authorization order should generally be:

```text
authenticate actor
→ resolve requested entity
→ validate actor access
→ resolve and validate track context
→ execute service
```

Avoid revealing whether a private entity exists when the actor is unauthorized.

---

# Performance requirements

Track-aware migration must not cause unbounded graph scans.

Required patterns:

- resolve by stable IDs;
- traverse from known parent entities;
- use bounded named-edge traversals;
- cache validated immutable track/version metadata;
- batch repository reads where possible;
- avoid repeated active-version lookups within one request;
- include track version in projection caches.

Potential request-scoped cache:

```text
track_id → LearningTrack
track_version_id → TrackVersion
learner_id + track_version_id → Enrollment
entity_id → resolved TrackContext
```

Request-scoped caches must not outlive authorization context.

---

# Testing strategy

Use Jac tests for walker, service, repository, and graph behavior. Add frontend integration tests for Spawn payloads and response handling.

## Track-context resolver tests

- explicit track and version resolve;
- track with active version resolves only when allowed;
- parent entity context resolves;
- enrollment context resolves;
- language fallback resolves built-in track;
- unknown language fails;
- track/version mismatch fails;
- language/track conflict fails;
- parent/supplied context conflict fails;
- another learner's enrollment fails.

## Walker contract tests

For every migrated walker:

- legacy language-only request succeeds during compatibility;
- track-aware request succeeds;
- missing context returns stable error;
- conflicting context returns stable error;
- unauthorized learner ID is rejected;
- invalid track is rejected;
- invalid version is rejected;
- response includes normalized track metadata;
- raw nodes are not exposed.

## Assessment tests

- assessment is pinned to version;
- duplicate initialization is idempotent;
- evaluation derives context from assessment;
- supplied mismatched track is rejected;
- completed assessment is not re-evaluated unintentionally.

## Roadmap tests

- roadmap uses assessment version;
- roadmap items use matching context;
- existing roadmap is reused when appropriate;
- regeneration does not destructively overwrite;
- skills from another version are rejected.

## Lesson and activity tests

- lesson derives context from roadmap item;
- activity derives context from lesson;
- programming code challenge still works;
- unsupported activity type is rejected;
- cached content never crosses versions.

## Submission and mastery tests

- submission derives context from activity;
- evaluator type is server-selected;
- duplicate evaluation is idempotent;
- mastery evidence stays in one version;
- arbitrary client mastery values are rejected;
- retry does not duplicate mastery events.

## Dashboard and skill-map tests

- dashboard returns selected track only by default;
- skill map includes only version skills;
- multi-track records remain separated;
- recommendation remains in selected track;
- cache keys isolate versions.

## Security tests

- learner cannot access another learner's roadmap;
- learner cannot enumerate private track details;
- learner cannot submit against another track's activity;
- learner cannot select a rubric;
- archived or inaccessible track is rejected;
- system/internal walkers are not publicly callable where prohibited.

## Idempotency tests

- same key and same request reuses result;
- same key and different request fails;
- normalized track context participates in request hash;
- partial failures can retry safely;
- final evaluation and mastery are not duplicated.

## Regression tests

Run the existing programming flow for every supported built-in track:

```text
login
→ select track
→ initialize assessment
→ submit assessment
→ evaluate assessment
→ generate roadmap
→ load lesson
→ generate challenge
→ evaluate submission
→ update mastery
→ unlock next lesson
→ load dashboard
→ load skill map
→ recommend next action
```

Test both:

```text
legacy language-only payloads
track-aware payloads
```

---

# Example Jac test outlines

```jac
test "initialize assessment accepts track context" {
    # Arrange learner and published Python track.
    # Spawn initialize_assessment with track and version.
    # Assert assessment references the supplied version.
    # Assert response contains normalized track metadata.
}

test "assessment evaluation rejects track mismatch" {
    # Create Python assessment.
    # Evaluate while supplying Jaseci track.
    # Assert TRACK_CONTEXT_CONFLICT.
    # Assert assessment remains unchanged.
}

test "roadmap remains pinned to assessment version" {
    # Create and evaluate assessment against version 1.
    # Publish version 2 of the same track.
    # Generate roadmap.
    # Assert roadmap uses version 1.
}

test "submission retry does not duplicate mastery" {
    # Submit one activity with an idempotency key.
    # Repeat same request.
    # Assert one submission result and one mastery event.
}

test "legacy language fallback remains compatible" {
    # Spawn initialize_assessment with language='python'.
    # Assert resolver selects deterministic Python track.
    # Assert fallback metric/event is emitted.
}
```

---

# Implementation sequence

## Step 1: Build walker inventory

Document every curriculum-dependent walker and all current client call sites.

## Step 2: Implement `TrackContextResolver`

Support explicit, parent-entity, enrollment, and legacy resolution.

## Step 3: Implement common request and response types

Add optional track fields without removing language.

## Step 4: Migrate read-only walkers first

Recommended order:

```text
supported_language_tracks
get_roadmap
get_dashboard
get_skill_map
recommend_next_action
```

## Step 5: Migrate assessment walkers

```text
initialize_assessment
evaluate_assessment
load_assessment_journey
```

## Step 6: Migrate roadmap walkers

```text
generate_roadmap
get_roadmap
```

## Step 7: Migrate lesson and activity walkers

```text
generate_lesson
generate_challenge
```

## Step 8: Migrate submission and mastery operations

```text
evaluate_submission
update_mastery
unlock_next_lesson
```

## Step 9: Update Jac Client call helpers

Centralize selected track context in Spawn calls.

## Step 10: Add idempotency and observability

Ensure retries and migration fallback are measurable.

## Step 11: Run dual-mode regression tests

Test language-only and track-aware payloads.

## Step 12: Enable track-first mode

Require track context for new journeys after data and clients are ready.

---

# Acceptance criteria

## Shared infrastructure

- [ ] A single `TrackContextResolver` exists.
- [ ] Context resolution order is documented and tested.
- [ ] Parent entities are authoritative for existing operations.
- [ ] Conflicting context is rejected.
- [ ] Legacy language fallback is measurable.

## Walker contracts

- [ ] Every curriculum-dependent walker accepts or derives track context.
- [ ] New track fields are additive during compatibility.
- [ ] Response metadata identifies track and version.
- [ ] Walkers do not return raw graph nodes.
- [ ] Walkers remain thin and call application services.

## Assessment and roadmap

- [ ] Assessments are pinned to a track version.
- [ ] Assessment evaluation derives context from the assessment.
- [ ] Roadmaps derive context from evaluated assessments.
- [ ] Roadmaps never silently move to the latest version.
- [ ] Duplicate active artifacts are prevented.

## Lessons, activities, and submissions

- [ ] Lessons derive context from roadmap items.
- [ ] Activities derive context from lessons.
- [ ] Submissions derive context from activities.
- [ ] Evaluator selection is server-controlled.
- [ ] Generated and cached content is version-isolated.

## Mastery and progression

- [ ] Mastery evidence remains track- and version-scoped.
- [ ] Mastery updates are idempotent.
- [ ] Unlock traversal is bounded to the roadmap version.
- [ ] Learners cannot submit arbitrary mastery scores.

## Dashboard and recommendations

- [ ] Dashboard data is grouped by track.
- [ ] Skill maps include only the selected version.
- [ ] Recommendations remain within the selected track.
- [ ] Multi-track data does not leak or merge.

## Security

- [ ] Learner IDs are checked against authentication context.
- [ ] Enrollment is validated according to migration phase.
- [ ] Private tracks are protected.
- [ ] Cross-track and cross-version requests are rejected.
- [ ] Internal graph mutations are not unnecessarily public.

## Compatibility and rollout

- [ ] Legacy language-only calls work during compatibility.
- [ ] Track-aware calls work.
- [ ] Feature flags are documented.
- [ ] Rollback preserves track data.
- [ ] Legacy fallback can be disabled after verification.

## Quality

- [ ] `jac check` succeeds.
- [ ] Lint checks succeed.
- [ ] `jac test` passes.
- [ ] Frontend integration tests pass.
- [ ] Existing programming journeys pass in both payload modes.

---

# Check when done

Run the commands supported by the installed Jac/Jaseci version:

```bash
jac check <entry-file>
jac check --lint <entry-file>
jac test
```

Then verify manually:

```text
1. Existing learner can select Python using the old language flow.
2. The backend resolves Python to its deterministic track and version.
3. New track-aware selection also works.
4. Assessment initialization stores track references.
5. Assessment evaluation preserves the same version.
6. Roadmap generation uses the assessment version.
7. Lesson generation uses the roadmap version.
8. Challenge generation uses the lesson version.
9. Submission evaluation uses the activity version.
10. Mastery updates remain version-scoped.
11. Unlocking does not traverse another track.
12. Dashboard shows the selected track's data.
13. Skill map contains only selected-version skills.
14. Recommendation remains in the selected track.
15. Conflicting track and language inputs are rejected.
16. Another learner's entity cannot be accessed.
17. Duplicate requests do not duplicate assessment, roadmap, grade, or mastery state.
18. Backend restart preserves all track-aware records.
19. Legacy fallback events appear in observability data.
20. Disabling track-first mode does not delete migrated data.
```

---

# Expected result

After this specification is implemented:

- all existing adaptive-learning walkers understand stable track identity;
- programming-language flows continue to work;
- new clients can use `track_id` and `track_version_id`;
- old clients can temporarily use legacy language values;
- assessments, roadmaps, lessons, activities, submissions, mastery, dashboards, skill maps, and recommendations remain version-isolated;
- walkers are thin adapters over the repository and service layers;
- retries are safe and observable;
- cross-track and cross-version data leakage is prevented;
- the same walkers are ready to support published lecturer-created courses.
