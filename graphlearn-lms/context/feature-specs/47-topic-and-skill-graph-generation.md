# 47-topic-and-skill-graph-generation.md

## Overview

Implement the deterministic graph-generation layer that converts a validated `CourseBlueprint` draft into the course curriculum graph used by the adaptive LMS.

This specification begins after:

```text
45-course-blueprint-byllm-contracts.md
46-course-blueprint-generation.md
```

and before:

```text
48-blueprint-validation-and-grounding.md
49-lecturer-blueprint-review.md
50-course-publication-and-versioning.md
```

Its responsibility is to transform structured blueprint artifacts into graph-native curriculum entities such as:

- curriculum modules;
- topics;
- skills/concepts;
- prerequisite relationships;
- module/topic containment;
- evidence/provenance links;
- ordering metadata.

The core rule is:

```text
AI proposes curriculum structure.
Deterministic application logic creates the graph.
```

The AI must never directly create graph nodes or edges.

---

## Status

- **Feature type:** Curriculum graph generation
- **Priority:** Critical
- **Depends on:** `32-learning-track-osp-schema.md`
- **Depends on:** `45-course-blueprint-byllm-contracts.md`
- **Depends on:** `46-course-blueprint-generation.md`
- **Blocks:** `48-blueprint-validation-and-grounding.md`
- **Blocks:** `49-lecturer-blueprint-review.md`
- **Blocks:** `50-course-publication-and-versioning.md`
- **Breaking changes allowed:** No
- **Primary implementation:** deterministic graph service + repository layer

---

# Goals

Implement graph generation that:

1. Converts blueprint modules into curriculum-module nodes.
2. Converts blueprint concepts into reusable course-version-scoped skill/topic nodes.
3. Preserves blueprint ordering.
4. Creates prerequisite edges only after deterministic validation.
5. Maintains strict track/version isolation.
6. Preserves evidence provenance from graph nodes back to source chunks.
7. Uses application-generated stable IDs.
8. Is idempotent for the same blueprint generation.
9. Supports regeneration without corrupting historical graph state.
10. Prevents duplicate nodes and edges.
11. Prevents prerequisite cycles.
12. Preserves module-to-skill membership.
13. Supports later lesson and quiz generation.
14. Supports learner-specific roadmap generation from the shared curriculum graph.
15. Does not publish or expose unreviewed curriculum automatically.
16. Supports rollback/cleanup of failed graph builds.
17. Produces graph-integrity reports.
18. Integrates with repositories and services from `33`.
19. Preserves provenance for lecturer review.
20. Supports future multi-document and multi-version courses.

---

# Non-goals

This specification does not:

- perform byLLM calls;
- generate lessons;
- generate quizzes;
- create learner mastery;
- create learner roadmaps;
- publish the course;
- enroll learners;
- infer new concepts beyond the blueprint;
- repair unsupported blueprint content using external knowledge;
- allow cross-version prerequisite edges by default.

---

# Graph-generation architecture

```text
Validated CourseBlueprint
        │
        ▼
TopicSkillGraphGenerationService
        │
        ├── validate blueprint identity
        ├── allocate stable domain IDs
        ├── generate curriculum modules
        ├── generate skill/topic nodes
        ├── generate containment edges
        ├── generate prerequisite edges
        ├── generate provenance relationships
        ├── validate graph
        └── persist graph-generation result
                │
                ▼
TrackVersion curriculum graph
```

---

# Shared curriculum graph versus draft blueprint graph

Keep these layers distinct.

## Blueprint graph

Represents:

```text
AI-generated, reviewable interpretation
```

Nodes:

```text
CourseBlueprint
BlueprintConcept
BlueprintModule
BlueprintPrerequisite
```

## Curriculum graph

Represents:

```text
domain curriculum structure consumed by the LMS
```

Nodes:

```text
CurriculumModule
Skill
Topic where retained by current architecture
Lesson later
Challenge later
```

Do not make blueprint nodes themselves become runtime skill nodes.

---

# Graph generation timing

Recommended first-release flow:

```text
blueprint generated
→ blueprint grounding validation
→ graph draft generated
→ graph validation
→ lecturer review
→ approval/publication
```

Alternatively, graph generation may occur before final lecturer review to power a visual graph preview.

In either case:

```text
generated graph remains DRAFT
```

until publication.

---

# Graph-generation status

```jac
enum CurriculumGraphGenerationStatus {
    NOT_STARTED,
    GENERATING,
    GENERATED,
    GENERATED_WITH_WARNINGS,
    FAILED,
    SUPERSEDED
}
```

---

# Graph-generation run

Create:

```jac
node CurriculumGraphGenerationRun {
    has graph_generation_id: str;

    has track_id: str;
    has track_version_id: str;

    has blueprint_id: str;

    has blueprint_schema_version: int;

    has status: CurriculumGraphGenerationStatus;

    has generation_number: int;

    has module_count: int = 0;
    has skill_count: int = 0;
    has prerequisite_count: int = 0;

    has source_blueprint_hash: str;

    has created_at: str;
    has completed_at: str | None = None;

    has error_code: str | None = None;
}
```

---

# Generation identity

A graph generation is identified by:

```text
track_version_id
blueprint_id
blueprint content hash
graph schema version
generation configuration hash
```

Equivalent requests must reuse the existing successful generation.

---

# Curriculum graph schema version

Define:

```text
CURRICULUM_GRAPH_SCHEMA_VERSION = 1
```

Record on the generation run.

This differs from:

- blueprint schema version;
- track version;
- AI prompt version.

---

# Curriculum module node

Reuse or extend the model established in `32`.

Conceptual:

```jac
node CurriculumModule {
    has module_id: str;

    has track_id: str;
    has track_version_id: str;

    has title: str;
    has description: str;

    has order_index: int;

    has importance: str;

    has estimated_learning_hours: float | None = None;

    has status: str = "DRAFT";

    has blueprint_module_key: str | None = None;

    has created_at: str;
}
```

---

# Skill node

Reuse the current shared curriculum `Skill` node.

Conceptual:

```jac
node Skill {
    has skill_id: str;

    has track_id: str;
    has track_version_id: str;

    has canonical_name: str;
    has description: str;

    has concept_type: str;

    has aliases: list[str] = [];
    has key_terms: list[str] = [];

    has default_difficulty: str | None = None;

    has status: str = "DRAFT";

    has blueprint_concept_key: str | None = None;

    has created_at: str;
}
```

Do not put learner mastery fields on shared `Skill`.

---

# Topic compatibility

If the existing LMS still relies on `Topic` nodes, define a compatibility strategy.

Recommended:

```text
CurriculumModule = high-level course grouping
Skill = atomic learnable/mastery concept
Topic = compatibility/display grouping only if still needed
```

Do not create redundant Topic and Skill nodes for every concept without a clear purpose.

---

# Topic strategy options

## Preferred

Use:

```text
CurriculumModule
→ CONTAINS_SKILL
→ Skill
```

and migrate legacy topic usage to projections.

## Compatibility mode

For legacy walkers requiring Topic:

```text
one Topic per module
```

Then:

```text
CurriculumModule
→ REPRESENTED_BY_TOPIC
→ Topic
→ CONTAINS_SKILL
→ Skill
```

Do not duplicate prerequisite graphs across both Topic and Skill.

---

# Stable ID generation

The application generates all IDs.

Example:

```text
module_id = mod_<uuid>
skill_id = skl_<uuid>
```

Never use LLM local keys as final IDs.

Persist mapping:

```text
blueprint module key → module_id
blueprint concept key → skill_id
```

---

# Deterministic mapping table

Create in memory or persist:

```jac
obj BlueprintGraphIdMap {
    has blueprint_id: str;

    has concept_key_to_skill_id: dict;
    has module_key_to_module_id: dict;
}
```

Exact Jac dictionary typing may vary.

Persistent mapping is recommended for auditability.

---

# Blueprint-to-domain mapping node

Optional:

```jac
node BlueprintDomainMapping {
    has mapping_id: str;

    has blueprint_id: str;

    has blueprint_local_key: str;

    has domain_entity_type: str;
    has domain_entity_id: str;

    has created_at: str;
}
```

This provides explicit provenance.

---

# Module mapping

For each:

```text
CourseModuleDraft
```

create exactly one:

```text
CurriculumModule
```

unless deterministic validation rejects the module.

Preserve:

```text
title
description
order
importance
estimated hours
evidence
```

---

# Skill mapping

For each:

```text
MergedCourseConcept
```

where:

```text
should_be_taught_explicitly == true
```

create one:

```text
Skill
```

If false:

- it may remain metadata/supporting concept;
- do not automatically create mastery-tracked skill.

---

# Explicit versus supporting concepts

Suggested behavior:

```text
should_be_taught_explicitly = true
→ Skill node

false
→ optional supporting concept metadata
```

Do not create thousands of trivial mastery nodes.

---

# Skill granularity validation

Before graph creation, reject concepts that are obviously invalid:

```text
empty concept
entire course as one skill
single punctuation/token
duplicate canonical concept without intentional distinction
```

Detailed semantic validation is handled in `48`.

---

# Module containment

Create:

```jac
edge CONTAINS_SKILL {
    has order_index: int;
    has primary: bool = True;
}
```

Graph:

```text
CurriculumModule
→ CONTAINS_SKILL
→ Skill
```

---

# Skill ordering inside modules

The blueprint may not provide explicit concept order inside a module.

Determine order using:

```text
prerequisite relationships
source order
blueprint evidence order
concept listing order
```

Use deterministic rules.

Do not ask another LLM during graph generation.

---

# Primary module assignment

Initial invariant:

```text
each explicit Skill has exactly one primary CurriculumModule
```

A skill may be referenced/reinforced elsewhere later through:

```text
REINFORCES
```

but not duplicated as separate skill nodes.

---

# Duplicate concept detection

Before creating skills, normalize key:

```text
casefold(canonical_name)
trim whitespace
Unicode normalize
```

If two blueprint concepts normalize identically:

```text
generation should fail or require explicit distinction
```

Do not silently create duplicates.

---

# Alias behavior

Store aliases on the same skill.

Do not create separate skill nodes for:

```text
DBMS
Database Management System
```

when blueprint merge already classified them as aliases.

---

# Prerequisite edge

Use:

```jac
edge PREREQUISITE {
    has strength: str;

    has rationale: str | None = None;

    has confidence: str | None = None;

    has source_blueprint_prerequisite_id: str | None = None;

    has created_at: str;
}
```

Direction convention must match `32`.

Recommended:

```text
prerequisite_skill
→ PREREQUISITE
→ dependent_skill
```

Document this once and test it everywhere.

---

# Prerequisite invariants

A prerequisite edge must satisfy:

```text
source != target
same track_id
same track_version_id
both skills exist
both active in same graph generation
edge unique
no directed cycle
```

---

# Required versus recommended prerequisites

Options:

```text
PREREQUISITE edge strength field
```

Recommended:

```text
REQUIRED
RECOMMENDED
```

Runtime unlock logic may enforce only:

```text
REQUIRED
```

unless future rules specify otherwise.

---

# Graph-cycle detection

Run cycle detection:

```text
before committing prerequisite edges
```

and:

```text
after graph persistence
```

Use deterministic traversal/topological sort.

Failure:

```text
CURRICULUM_GRAPH_PREREQUISITE_CYCLE
```

---

# Topological ordering

Calculate a topological order for skills where possible.

Persist optionally:

```text
topological_rank
```

or compute through repository/service.

This can support:

- roadmap generation;
- prerequisite visualization;
- unlock logic.

---

# Module ordering versus prerequisites

A prerequisite may reveal an invalid module order.

Example:

```text
Module 3 skill
→ prerequisite of
Module 1 skill
```

Flag:

```text
MODULE_ORDER_PREREQUISITE_CONFLICT
```

Do not silently reorder lecturer modules during this layer.

Detailed repair belongs to blueprint validation/review.

---

# Evidence provenance

Every generated curriculum entity must trace back to blueprint and source evidence.

Required chain:

```text
Skill
→ blueprint concept mapping
→ BlueprintConcept
→ chunk evidence
→ CourseContentChunk
→ ExtractionBlock
→ CourseDocument
```

---

# Evidence edge

Optional graph representation:

```jac
edge DERIVED_FROM {
    has source_type: str;
    has source_id: str;
}
```

Avoid overly dense edges if provenance is already reliably stored by IDs.

At minimum persist:

```text
blueprint_id
blueprint_concept_key
evidence refs
```

---

# Module provenance

Each module retains:

```text
blueprint_module_key
blueprint_id
evidence references
```

---

# Skill provenance

Each skill retains:

```text
blueprint_concept_key
blueprint_id
evidence references
```

---

# Prerequisite provenance

Each prerequisite edge retains:

```text
blueprint prerequisite reference
rationale
evidence IDs
confidence
```

---

# Learning outcomes graph

Course outcomes may remain attached to blueprint/version or become domain nodes.

Recommended:

```jac
node LearningOutcome {
    has learning_outcome_id: str;

    has track_id: str;
    has track_version_id: str;

    has statement: str;
    has level: str;

    has status: str = "DRAFT";

    has blueprint_outcome_key: str;
}
```

Graph:

```text
TrackVersion
→ HAS_LEARNING_OUTCOME
→ LearningOutcome
```

---

# Module-outcome relationships

Create:

```jac
edge TARGETS_OUTCOME {}
```

Graph:

```text
CurriculumModule
→ TARGETS_OUTCOME
→ LearningOutcome
```

---

# Skill-outcome relationships

Optional:

```jac
edge SUPPORTS_OUTCOME {}
```

Only create if mapping is present and useful.

Do not infer extra mapping in this deterministic stage.

---

# Track version root

All generated curriculum must attach to:

```text
TrackVersion
```

Example:

```text
TrackVersion
├── HAS_CURRICULUM_MODULE
├── CONTAINS_SKILL / HAS_SKILL
├── HAS_LEARNING_OUTCOME
└── HAS_CURRICULUM_GRAPH_GENERATION
```

---

# Version isolation

Never connect:

```text
track version A Skill
→ PREREQUISITE
→ track version B Skill
```

unless a future explicit shared-curriculum design permits it.

Initial invariant:

```text
all generated curriculum is track-version scoped
```

---

# Shared programming tracks

For built-in programming tracks migrated in `30`, graph generation may not use blueprint AI.

Do not force regeneration.

This feature primarily applies to:

```text
LECTURER_COURSE
```

but the generated graph must conform to the same runtime schema used by programming tracks.

---

# Runtime compatibility

After generation, existing services should be able to consume:

```text
skills
prerequisites
modules
outcomes
```

through the track-aware repository layer.

Do not create a special separate lecturer-only runtime graph.

---

# Lesson-generation compatibility

Future lesson generation must query:

```text
Skill
module context
source provenance
track version
```

The graph must provide enough context for grounded lesson generation.

---

# Roadmap compatibility

`generate_roadmap` must later be able to traverse:

```text
TrackVersion
→ modules
→ skills
→ prerequisites
```

using the same adaptive roadmap logic.

---

# Assessment compatibility

Diagnostic generation should be able to sample:

```text
foundational/core skills
module coverage
prerequisite depth
```

from the graph.

---

# Graph-generation service

Create:

```text
TopicSkillGraphGenerationService
```

Responsibilities:

```text
assert blueprint eligible
load blueprint
validate blueprint identity
build ID mapping
build modules
build skills
build outcomes
build containment
build prerequisites
build provenance
validate graph
persist graph-generation run
```

---

# Service contract

Conceptual:

```jac
obj TopicSkillGraphGenerationService {
    def generate_graph(
        blueprint_id: str,
        context: GraphGenerationContext
    ) -> GraphGenerationResult;

    def get_graph_generation(
        graph_generation_id: str
    ) -> GraphGenerationResult;

    def rollback_failed_generation(
        graph_generation_id: str
    ) -> GraphRollbackResult;
}
```

---

# Generation context

```jac
obj GraphGenerationContext {
    has track_id: str;
    has track_version_id: str;

    has blueprint_id: str;

    has request_id: str;
    has actor_id: str | None;

    has graph_schema_version: int;
    has force_regenerate: bool = False;
}
```

---

# Generation result

```jac
obj GraphGenerationResult {
    has graph_generation_id: str | None;

    has status: CurriculumGraphGenerationStatus;

    has module_count: int;
    has skill_count: int;
    has learning_outcome_count: int;
    has prerequisite_count: int;

    has warnings: list[str];

    has error_code: str | None;
}
```

---

# Repository contracts

## `CurriculumGraphRepository`

Suggested methods:

```text
create_generation_run
find_matching_generation
find_active_generation
save_modules
save_skills
save_outcomes
save_module_skill_edges
save_prerequisite_edges
save_outcome_edges
save_provenance
mark_generated
mark_failed
mark_superseded
delete_draft_generation
```

---

# Blueprint repository reads

Need:

```text
get_blueprint
list_blueprint_concepts
list_blueprint_modules
list_blueprint_outcomes
list_blueprint_prerequisites
list_blueprint_warnings
```

Use batched reads.

Avoid N+1 traversal.

---

# Atomicity strategy

Graph generation may involve many nodes/edges.

Preferred:

```text
stage entire generation
→ validate
→ activate generation
```

If full transaction support exists, use it.

Otherwise use generation IDs and active flags.

---

# Generation ownership field

Every generated draft curriculum entity should record:

```text
graph_generation_id
```

This allows:

- cleanup;
- rollback;
- distinguishing generations.

---

# Activation model

Entities from a new generation begin:

```text
DRAFT_INACTIVE
```

After graph validation:

```text
generation marked active review graph
```

Do not partially expose a generation.

---

# Rollback

If generation fails:

```text
delete or mark failed all entities created under graph_generation_id
```

Never delete entities from older valid generation.

---

# Regeneration

When regenerating graph from a new blueprint:

```text
create new graph generation
```

Do not mutate the existing generation in place.

After successful validation:

```text
new generation becomes current draft
old generation → SUPERSEDED
```

---

# Published graph protection

Published graph generation is immutable.

Any changes require:

```text
new TrackVersion
or new draft generation tied to new version
```

Do not modify published skill/prerequisite graph in place.

---

# Graph validation before activation

Check:

```text
module count matches expected
skill count matches eligible concepts
outcomes resolve
all module concept keys mapped
each skill has primary module
no duplicate skills
all prerequisite endpoints resolve
no self prerequisites
no duplicate prerequisite edges
no cross-version edges
no cycles
provenance valid
```

---

# Graph integrity report

Create:

```jac
obj CurriculumGraphIntegrityReport {
    has valid: bool;

    has module_count: int;
    has skill_count: int;
    has prerequisite_count: int;

    has orphan_skills: list[str];
    has duplicate_skills: list[str];
    has dangling_edges: list[str];
    has cycle_paths: list[str];
    has cross_version_edges: list[str];
    has missing_provenance: list[str];

    has warnings: list[str];
}
```

---

# Orphan skill definition

A skill is orphaned when:

```text
not connected to a primary module
```

Initial policy:

```text
orphan explicit skills → invalid graph
```

---

# Duplicate prerequisite edge

For pair:

```text
A → B
```

only one edge should exist per generation.

If blueprint returns both REQUIRED and RECOMMENDED:

```text
retain strongest = REQUIRED
```

with merged evidence/rationale where possible.

---

# Self-edge

Reject:

```text
A → A
```

---

# Transitive edges

Do not automatically remove:

```text
A → C
```

just because:

```text
A → B → C
```

A direct prerequisite may be meaningful.

Transitive reduction is optional and out of scope.

---

# Prerequisite confidence

Initial acceptance policy:

```text
HIGH confidence
→ eligible

MEDIUM
→ eligible with review warning

LOW
→ do not materialize as enforced REQUIRED edge automatically
```

Recommended:

- store low-confidence candidates in blueprint;
- exclude from runtime graph until lecturer approval.

---

# Graph-generation configuration

```jac
obj CurriculumGraphGenerationConfig {
    has graph_schema_version: int;

    has include_medium_confidence_prerequisites: bool = True;
    has include_low_confidence_prerequisites: bool = False;

    has create_topic_compatibility_nodes: bool = False;

    has enforce_single_primary_module: bool = True;
}
```

---

# Deterministic prerequisite filter

Before edge creation:

```text
confidence policy
strength policy
valid evidence
valid endpoints
not duplicate
not self-edge
```

Then cycle validation.

---

# Lecturer review visibility

Graph generation should support a visual review projection.

Return:

```text
modules
skills
prerequisite edges
warnings
evidence counts
```

But review UI is specified in `49`.

---

# Graph preview projection

Create:

```jac
obj CurriculumGraphPreview {
    has modules: list[GraphPreviewModule];
    has skills: list[GraphPreviewSkill];
    has prerequisites: list[GraphPreviewEdge];
    has warnings: list[str];
}
```

Do not expose internal graph IDs unnecessarily when local review keys suffice.

---

# Error codes

Define:

```text
CURRICULUM_GRAPH_BLUEPRINT_NOT_READY
CURRICULUM_GRAPH_BLUEPRINT_INVALID
CURRICULUM_GRAPH_ALREADY_GENERATING
CURRICULUM_GRAPH_DUPLICATE_SKILL
CURRICULUM_GRAPH_ORPHAN_SKILL
CURRICULUM_GRAPH_DANGLING_REFERENCE
CURRICULUM_GRAPH_CROSS_VERSION_EDGE
CURRICULUM_GRAPH_SELF_PREREQUISITE
CURRICULUM_GRAPH_DUPLICATE_PREREQUISITE
CURRICULUM_GRAPH_PREREQUISITE_CYCLE
CURRICULUM_GRAPH_MODULE_ORDER_CONFLICT
CURRICULUM_GRAPH_PROVENANCE_INVALID
CURRICULUM_GRAPH_PERSIST_FAILED
CURRICULUM_GRAPH_ROLLBACK_FAILED
CURRICULUM_GRAPH_INTERNAL_ERROR
```

---

# Job integration

Graph generation may run:

```text
inside BLUEPRINT_VALIDATION
```

or as a dedicated future stage.

Recommended:

```text
BLUEPRINT_GENERATION
→ BLUEPRINT_VALIDATION
   ├── validate blueprint
   ├── generate curriculum graph draft
   └── validate graph
→ REVIEW_REQUIRED
```

Do not add another job stage unless operational complexity requires it.

---

# Idempotency

Generation key:

```text
blueprint_id
blueprint content hash
track_version_id
graph schema version
config hash
```

Equivalent successful generation should be reused.

---

# Concurrency

Only one active graph generation for the same key.

Use:

```text
generation lock
unique active generation
compare-and-set
```

---

# Source change invalidation

If source/chunk/blueprint changes:

```text
current draft graph becomes stale
```

Do not reuse it.

Generate a new graph generation.

---

# Blueprint edit invalidation

Lecturer edits in `49` may change:

```text
module
concept
prerequisite
```

Those edits must either:

```text
patch the draft graph deterministically
or
regenerate graph from edited blueprint
```

Recommended:

```text
edited blueprint remains source of truth
→ regenerate deterministic graph
```

---

# Performance

Use batch persistence.

Avoid:

```text
one write per skill
one write per edge
```

when repository supports batches.

Typical course graph sizes are manageable but should still avoid N+1 patterns.

---

# Graph traversal bounds

All validation traversals must be scoped by:

```text
track_version_id
graph_generation_id
```

Do not traverse unrelated global graphs.

---

# Observability

Emit:

```text
curriculum_graph.generation_started
curriculum_graph.modules_created
curriculum_graph.skills_created
curriculum_graph.prerequisites_created
curriculum_graph.validation_started
curriculum_graph.validation_completed
curriculum_graph.generation_completed
curriculum_graph.generation_failed
curriculum_graph.rollback_started
curriculum_graph.rollback_completed
curriculum_graph.superseded
```

Fields:

```text
graph_generation_id
blueprint_id
track_id
track_version_id
module_count
skill_count
prerequisite_count
duration_ms
error_code
```

---

# Metrics

Track:

```text
curriculum_graph_generation_total
curriculum_graph_generation_failed_total
curriculum_graph_modules_total
curriculum_graph_skills_total
curriculum_graph_prerequisites_total
curriculum_graph_cycles_detected_total
curriculum_graph_orphans_detected_total
curriculum_graph_generation_duration_ms
```

---

# Security

Graph generation is an internal domain operation.

Normal client input must not provide:

```text
skill IDs
module IDs
prerequisite endpoints
graph_generation_id overrides
```

as trusted values.

All mappings derive from validated blueprint.

---

# Authorization

Manual regeneration by lecturer requires:

```text
authorized owner/editor
draft track version
blueprint editable
```

Automatic internal generation uses trusted worker context.

---

# Testing strategy

## Module mapping tests

Verify:

```text
one blueprint module → one curriculum module
order preserved
metadata preserved
```

---

# Skill mapping tests

Verify:

```text
one explicit blueprint concept → one skill
aliases retained
support-only concepts handled according to policy
```

---

# ID tests

Verify:

```text
LLM local keys are not final IDs
IDs unique
mapping preserved
```

---

# Containment tests

Verify:

```text
each explicit skill has one primary module
no orphan skills
```

---

# Duplicate skill tests

Input duplicate normalized concepts.

Expected:

```text
generation fails or validation blocks
```

---

# Prerequisite tests

Verify:

```text
valid A→B created
self-edge rejected
duplicate edge merged/rejected
cross-version edge impossible
cycle detected
```

---

# Cycle test

Input:

```text
A → B
B → C
C → A
```

Expected:

```text
CURRICULUM_GRAPH_PREREQUISITE_CYCLE
```

No active generation.

---

# Evidence tests

Verify each:

```text
module
skill
prerequisite
```

traces to blueprint evidence.

---

# Idempotency tests

Run generation twice with same key.

Expected:

```text
same successful generation reused
```

---

# Regeneration tests

Change blueprint.

Expected:

```text
new graph generation
old generation preserved/superseded
```

---

# Failure injection

Simulate:

```text
module persistence failure
skill persistence failure
edge persistence failure
validation failure
activation failure
```

Verify rollback or inactive failed generation.

---

# Published protection tests

Attempt to mutate published generation.

Expected:

```text
rejected
```

---

# Runtime compatibility tests

Verify existing track-aware services can:

```text
list modules
list skills
traverse prerequisites
generate roadmap inputs
```

for lecturer-course graph.

---

# Example Jac test outlines

```jac
test "blueprint concepts become version-scoped skills" {
    # Generate graph.
    # Assert skills carry correct track/version.
}

test "generated graph contains no orphan skills" {
    # Assert every explicit skill has a primary module.
}

test "prerequisite cycle prevents activation" {
    # Build cyclic prerequisite draft.
    # Assert generation invalid.
}

test "graph generation is idempotent" {
    # Generate twice from unchanged blueprint.
    # Assert existing generation reused.
}

test "regeneration preserves prior graph generation" {
    # Change blueprint.
    # Generate again.
    # Assert old generation is preserved/superseded.
}
```

---

# Implementation sequence

## Step 1 — Reconcile with `32-learning-track-osp-schema.md`

Confirm final names for:

```text
CurriculumModule
Skill
Topic compatibility
PREREQUISITE
CONTAINS_SKILL
LearningOutcome
```

Do not create duplicate competing graph concepts.

## Step 2 — Add graph-generation run

Implement:

```text
CurriculumGraphGenerationRun
```

## Step 3 — Add blueprint-to-domain mapping

Map local blueprint keys to domain IDs.

## Step 4 — Generate modules

Persist draft modules.

## Step 5 — Generate skills

Persist explicit mastery-worthy concepts.

## Step 6 — Generate outcomes

Persist course learning outcomes.

## Step 7 — Create containment

Connect modules and skills.

## Step 8 — Create outcome relationships

Connect modules/outcomes where specified.

## Step 9 — Filter prerequisite candidates

Apply confidence/validity policies.

## Step 10 — Create prerequisite edges

Use fixed direction convention.

## Step 11 — Add provenance

Preserve blueprint/source traceability.

## Step 12 — Run graph integrity validator

Check duplicates, orphans, cycles, version boundaries.

## Step 13 — Activate draft generation

Only after validation.

## Step 14 — Add rollback

Clean failed generation safely.

## Step 15 — Add preview projection

Support later lecturer review.

## Step 16 — Add tests

Graph mapping, cycles, provenance, idempotency, runtime compatibility.

---

# Acceptance criteria

## Domain mapping

- [ ] Blueprint modules map to curriculum modules.
- [ ] Explicit blueprint concepts map to skills.
- [ ] Learning outcomes map to domain outcome entities where enabled.
- [ ] Model-local keys never become authoritative IDs.

## Graph structure

- [ ] Modules connect to skills.
- [ ] Each explicit skill has one primary module.
- [ ] Prerequisite direction is consistent.
- [ ] Duplicate edges are prevented.
- [ ] Self prerequisites are prevented.
- [ ] Cycles are prevented.

## Version isolation

- [ ] Every entity has `track_id`.
- [ ] Every entity has `track_version_id`.
- [ ] No cross-version prerequisite edges exist.
- [ ] Published graph remains immutable.

## Provenance

- [ ] Skills trace to blueprint concepts.
- [ ] Modules trace to blueprint modules.
- [ ] Prerequisites trace to blueprint prerequisite/evidence.
- [ ] Source-document provenance remains recoverable.

## Reliability

- [ ] Generation is idempotent.
- [ ] Failed generation does not become active.
- [ ] Rollback is safe.
- [ ] Regeneration creates a new generation.
- [ ] Old graph generations remain protected.

## Runtime compatibility

- [ ] Lecturer-course graph uses the same shared runtime schema as programming tracks.
- [ ] Track-aware repositories can query it.
- [ ] Roadmap services can traverse it.
- [ ] Lesson/challenge services can later consume its skills.

## Quality

- [ ] `jac check` passes.
- [ ] `jac check --lint` passes.
- [ ] `jac test` passes.
- [ ] Cycle tests pass.
- [ ] Orphan tests pass.
- [ ] Version isolation tests pass.
- [ ] Idempotency tests pass.
- [ ] Runtime compatibility tests pass.

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
1. Generate a grounded blueprint.
2. Run curriculum graph generation.
3. Confirm one module node per blueprint module.
4. Confirm explicit concepts become skill nodes.
5. Confirm every skill belongs to the correct track/version.
6. Confirm module-skill containment is correct.
7. Confirm prerequisite edges use the documented direction.
8. Confirm no cycles exist.
9. Confirm no orphan skills exist.
10. Confirm outcomes are connected correctly.
11. Confirm graph entities retain blueprint/source provenance.

12. Run generation again unchanged.
13. Confirm existing generation is reused.

14. Change blueprint.
15. Generate again.
16. Confirm new generation is created.
17. Confirm old generation remains preserved/superseded.

18. Query graph through existing track-aware repositories.
19. Confirm roadmap/lesson services can see the lecturer-course curriculum.

20. Confirm nothing is published automatically.
```

---

# Expected result

After this specification is implemented:

- GraphLearn can deterministically convert a grounded AI course blueprint into its shared OSP curriculum graph;
- lecturer-created courses and programming tracks use the same runtime graph model;
- modules, skills, outcomes, and prerequisites are track-version isolated;
- every generated graph entity remains traceable to blueprint/source evidence;
- prerequisite cycles and orphan skills are blocked before activation;
- graph generations are idempotent, versioned, rollback-safe, and immutable once published;
- the resulting draft graph is ready for grounding validation and lecturer review.
