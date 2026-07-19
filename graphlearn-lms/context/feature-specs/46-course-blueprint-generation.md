# 46-course-blueprint-generation.md

## Overview

Implement the orchestration pipeline that converts validated `CourseContentChunk` evidence into a complete, grounded, reviewable `CourseBlueprintDraft`.

This specification operationalizes the typed byLLM contracts defined in:

```text
45-course-blueprint-byllm-contracts.md
```

and coordinates the pipeline after:

```text
39 upload
→ 40 storage
→ 41 security validation
→ 42 extraction
→ 43 chunking
→ 44 durable job state
```

The blueprint-generation subsystem must:

- analyze chunks in bounded batches;
- extract and merge concepts;
- identify course learning outcomes;
- synthesize modules;
- infer prerequisites;
- validate evidence references;
- detect incomplete or unsupported outputs;
- persist intermediate and final draft artifacts;
- remain idempotent and restart-safe;
- integrate with the document-processing job system;
- stop at lecturer review.

It must **not** directly publish the course or write final learner-facing skill graphs.

The core rule is:

```text
Chunk evidence
→ staged byLLM interpretation
→ deterministic validation
→ grounded CourseBlueprintDraft
→ lecturer review
```

---

## Status

- **Feature type:** AI orchestration / course interpretation
- **Priority:** Critical
- **Depends on:** `43-document-content-chunking.md`
- **Depends on:** `44-document-processing-job-state.md`
- **Depends on:** `45-course-blueprint-byllm-contracts.md`
- **Blocks:** `47-topic-and-skill-graph-generation.md`
- **Blocks:** `48-blueprint-validation-and-grounding.md`
- **Blocks:** `49-lecturer-blueprint-review.md`
- **Breaking changes allowed:** No
- **Primary implementation:** Jac orchestration services + byLLM typed functions + durable AI artifacts

---

# Goals

Implement a blueprint-generation pipeline that:

1. Consumes only a valid active chunk set.
2. Uses staged byLLM calls rather than one giant prompt.
3. Analyzes each chunk or bounded batch independently.
4. Reuses cached intermediate AI results where source and prompt versions match.
5. Merges duplicate concepts across chunks.
6. Preserves all valid source evidence.
7. Synthesizes a coherent course summary.
8. Creates structured learning outcomes.
9. Groups concepts into teachable modules.
10. Proposes module ordering.
11. Infers high-confidence prerequisite relationships.
12. Produces a typed `CourseBlueprintDraft`.
13. Validates all local references.
14. Validates evidence references against the active chunk set.
15. Measures source coverage.
16. Detects unsupported/hallucinated outputs.
17. Supports retries without restarting successful earlier stages.
18. Supports restart/crash recovery.
19. Records prompt, schema, model, and source provenance.
20. Hands off only a reviewable draft to the lecturer.

---

# Non-goals

This specification does not:

- create final `Skill` nodes;
- persist final `PREREQUISITE` edges;
- publish the course;
- generate learner roadmaps;
- generate final lessons;
- generate final quizzes;
- modify existing learner mastery;
- allow external-web enrichment;
- automatically approve AI-generated curriculum;
- skip lecturer review;
- replace deterministic grounding validation.

---

# Blueprint-generation architecture

```text
DocumentChunkSet
    │
    └── CourseContentChunk[]
           │
           ▼
BlueprintGenerationService
           │
           ├── Stage 1: Chunk analysis
           │       └── CourseChunkAnalysis[]
           │
           ├── Stage 2: Concept aggregation
           │       └── MergedCourseConcept[]
           │
           ├── Stage 3: Outcome synthesis
           │       └── BlueprintLearningOutcome[]
           │
           ├── Stage 4: Module synthesis
           │       └── CourseModuleDraft[]
           │
           ├── Stage 5: Prerequisite inference
           │       └── BlueprintPrerequisiteCandidate[]
           │
           ├── Stage 6: Critique / grounding pass
           │       └── BlueprintCritique
           │
           ├── deterministic validation
           │
           ▼
CourseBlueprintDraft artifact
           │
           ▼
REVIEW_REQUIRED
```

---

# Job-state integration

Extend `DocumentProcessingStage` with:

```jac
enum DocumentProcessingStage {
    STORAGE,
    SECURITY_VALIDATION,
    TEXT_EXTRACTION,
    CONTENT_CHUNKING,
    BLUEPRINT_GENERATION,
    BLUEPRINT_VALIDATION
}
```

Generation belongs to:

```text
BLUEPRINT_GENERATION
```

Grounding/validation belongs to:

```text
BLUEPRINT_VALIDATION
```

On success:

```text
BLUEPRINT_GENERATION SUCCEEDED
→ BLUEPRINT_VALIDATION queued
```

After successful validation:

```text
course/version → REVIEW_REQUIRED
```

---

# Blueprint generation status

Define:

```jac
enum BlueprintGenerationStatus {
    NOT_STARTED,
    QUEUED,
    ANALYZING_CHUNKS,
    MERGING_CONCEPTS,
    SYNTHESIZING_BLUEPRINT,
    INFERRING_PREREQUISITES,
    CRITIQUING,
    VALIDATING,
    GENERATED,
    REVIEW_REQUIRED,
    FAILED
}
```

This may exist as an artifact status separate from document job status.

---

# Core blueprint artifact node

Create a durable draft artifact.

```jac
node CourseBlueprint {
    has blueprint_id: str;

    has track_id: str;
    has track_version_id: str;

    has document_id: str;
    has extraction_id: str;
    has chunk_set_id: str;

    has schema_version: int;

    has generation_status: BlueprintGenerationStatus;

    has source_checksum_sha256: str;

    has course_title: str;
    has course_summary: str;

    has estimated_duration_weeks: int | None = None;

    has confidence: str;

    has prompt_versions_json: str;

    has ai_execution_ids_json: str;

    has validation_status: str | None = None;

    has created_at: str;
    has updated_at: str;
    has generated_at: str | None = None;
    has approved_at: str | None = None;
}
```

Do not store the entire complex blueprint only as one opaque JSON blob if the graph needs to traverse modules/concepts later.

Use child nodes or typed artifact persistence.

---

# Blueprint child artifacts

Recommended nodes:

```text
BlueprintConcept
BlueprintLearningOutcomeNode
BlueprintModule
BlueprintPrerequisite
BlueprintWarningNode
```

These represent the reviewable draft.

They are not yet final `Skill` nodes.

---

# `BlueprintConcept`

```jac
node BlueprintConcept {
    has blueprint_concept_id: str;
    has blueprint_id: str;

    has local_concept_key: str;

    has canonical_name: str;
    has description: str;

    has concept_type: str;

    has aliases_json: str;
    has learning_objectives_json: str;
    has key_terms_json: str;

    has confidence: str;

    has should_be_taught_explicitly: bool;

    has evidence_json: str;
}
```

---

# `BlueprintLearningOutcomeNode`

```jac
node BlueprintLearningOutcomeNode {
    has blueprint_outcome_id: str;
    has blueprint_id: str;

    has local_outcome_key: str;

    has statement: str;
    has level: str;

    has confidence: str;

    has evidence_json: str;
}
```

---

# `BlueprintModule`

```jac
node BlueprintModule {
    has blueprint_module_id: str;
    has blueprint_id: str;

    has local_module_key: str;

    has title: str;
    has description: str;

    has order_index: int;

    has importance: str;

    has concept_keys_json: str;
    has learning_outcome_keys_json: str;

    has estimated_learning_hours: float | None = None;

    has confidence: str;

    has evidence_json: str;
    has warnings_json: str;
}
```

---

# `BlueprintPrerequisite`

```jac
node BlueprintPrerequisite {
    has blueprint_prerequisite_id: str;
    has blueprint_id: str;

    has prerequisite_concept_key: str;
    has dependent_concept_key: str;

    has strength: str;

    has rationale: str;

    has confidence: str;

    has evidence_json: str;
}
```

---

# Blueprint graph

```text
CourseBlueprint
├── HAS_BLUEPRINT_CONCEPT
│   └── BlueprintConcept[]
├── HAS_BLUEPRINT_OUTCOME
│   └── BlueprintLearningOutcomeNode[]
├── HAS_BLUEPRINT_MODULE
│   └── BlueprintModule[]
├── HAS_BLUEPRINT_PREREQUISITE
│   └── BlueprintPrerequisite[]
└── HAS_BLUEPRINT_WARNING
    └── BlueprintWarningNode[]
```

This is a draft interpretation graph.

The final curriculum graph is created later.

---

# Blueprint generation identity

Generation identity is defined by:

```text
track_version_id
document_id
source checksum
chunk_set_id
blueprint schema version
prompt versions
generation configuration hash
```

If all match an existing successful reviewable blueprint:

```text
reuse it
```

unless explicit regeneration is requested.

---

# Generation configuration

Create:

```jac
obj BlueprintGenerationConfig {
    has schema_version: int;

    has chunk_analysis_batch_size: int;
    has max_input_tokens_per_call: int;

    has max_parallel_chunk_calls: int;

    has min_source_coverage_ratio: float;

    has max_concepts: int;
    has max_modules: int;
    has max_prerequisites: int;

    has enable_critic_pass: bool = True;

    has prompt_versions_json: str;
}
```

---

# Configuration fingerprint

Compute:

```text
generation_config_hash
```

from canonical configuration.

This supports:

- idempotency;
- caching;
- reproducibility.

---

# Pipeline stages

## Stage 0 — Eligibility

Before generation:

```text
document validation == VALIDATED
extraction == EXTRACTED
chunking == CHUNKED
active chunk set exists
chunk source coverage acceptable
course version editable
document still active
authorization/internal job context valid
```

If not:

```text
DOCUMENT_NOT_READY_FOR_BLUEPRINT
```

---

# Stage 1 — Load bounded evidence

Load:

```text
active DocumentChunkSet
ordered CourseContentChunk[]
```

Validate:

```text
track/version match
document match
chunk set status CHUNKED
chunk order valid
content hashes valid
```

Do not load stale/old chunk sets accidentally.

---

# Stage 2 — Chunk analysis planning

Create analysis units.

Options:

```text
one chunk per call
or
small contiguous chunk batches
```

Batching rules:

- preserve source order;
- stay under max input tokens;
- keep heading continuity where useful;
- never mix chunks from different documents/versions;
- include exact chunk IDs.

---

# Analysis unit

```jac
obj BlueprintAnalysisUnit {
    has unit_id: str;

    has chunk_ids: list[str];

    has total_estimated_tokens: int;

    has start_order_index: int;
    has end_order_index: int;

    has heading_context: list[str];
}
```

---

# Chunk-analysis caching

For each chunk or batch, compute cache key:

```text
content hashes
chunk IDs
prompt version
contract schema version
model execution policy
```

If valid cached analysis exists:

```text
reuse
```

Do not call byLLM again.

---

# Cached chunk-analysis artifact

Create optional node:

```jac
node ChunkAnalysisArtifact {
    has analysis_id: str;

    has chunk_set_id: str;
    has chunk_ids_json: str;

    has input_hash: str;

    has prompt_version: int;
    has contract_schema_version: int;

    has result_json: str;

    has ai_execution_id: str | None;

    has created_at: str;
}
```

Store typed/validated result serialization.

---

# Parallel chunk analysis

Bound concurrency.

Config:

```text
max_parallel_chunk_calls
```

Avoid:

```text
hundreds of simultaneous model calls
```

Use small bounded concurrency.

Example:

```text
3–8 calls
```

depending on provider limits.

---

# Chunk analysis retry behavior

Retry only failed analysis units.

Successful units remain cached.

Example:

```text
100 chunks
95 successful
5 failed
```

Retry only the 5 failed units.

Do not restart all 100.

---

# Chunk analysis outputs

Collect:

```text
CourseChunkAnalysis[]
```

Validate each before aggregation.

Invalid analysis:

```text
retry bounded
or fail generation stage
```

---

# Stage 3 — Candidate aggregation

Collect:

```text
CourseConceptCandidate[]
explicit learning outcomes
assessment signals
prerequisite signals
warnings
```

Before AI merge:

- normalize whitespace;
- deduplicate exact candidate duplicates;
- validate evidence IDs;
- validate candidate IDs within analysis unit.

---

# Deterministic pre-merge normalization

Normalize concept names:

```text
trim
Unicode normalize
collapse whitespace
case-insensitive comparison key
```

Do not aggressively stem or merge semantically.

---

# Stage 4 — Concept merge

Call:

```text
merge_course_concepts()
```

in bounded batches if candidate set is large.

Possible strategy:

```text
group candidates by lexical similarity / heading cluster
→ LLM merge within groups
→ global reconciliation
```

Do not send 500 concepts blindly in one call.

---

# Merge reconciliation

After each merge:

```text
every source candidate accounted for
all evidence preserved
all source_candidate_ids valid
local_concept_key unique
```

Compute:

```text
candidate coverage ratio
```

Expected:

```text
1.0
```

or explicit exclusions.

---

# Explicit exclusion record

If a candidate is intentionally removed:

```jac
obj ConceptExclusion {
    has source_candidate_id: str;
    has reason: str;
    has warning_type: str;
}
```

Do not silently drop candidate concepts.

---

# Stage 5 — Learning outcome synthesis

Inputs:

```text
explicit lecturer-declared outcomes
explicit outcomes found in chunks
concept-level suggested outcomes
```

Generate normalized outcomes.

Rules:

- avoid duplicates;
- keep evidence;
- prefer assessable verbs;
- do not create unsupported accreditation claims;
- preserve lecturer-declared outcomes even if wording is normalized.

---

# Lecturer-declared outcomes

Treat lecturer-provided metadata outcomes as trusted declared intent.

But mark provenance separately:

```text
DECLARED_METADATA
SOURCE_DOCUMENT
AI_SYNTHESIZED
```

Do not pretend metadata came from source notes.

---

# Outcome provenance type

```jac
enum OutcomeProvenanceType {
    LECTURER_DECLARED,
    SOURCE_EXPLICIT,
    SOURCE_SYNTHESIZED
}
```

Add if needed to blueprint outcome metadata.

---

# Stage 6 — Module synthesis

Call:

```text
synthesize_course_blueprint()
```

using:

```text
course context
merged concepts
normalized outcomes
chunk summaries
allowed chunk IDs
```

The model proposes:

```text
course summary
modules
ordering
module-concept assignments
module-outcome assignments
estimated duration
warnings
```

---

# Module synthesis validation

Check:

```text
all module keys unique
order indexes unique/contiguous
concept keys exist
outcome keys exist
module evidence valid
all required concepts assigned appropriately
module count within bounds
```

---

# Unassigned concepts

After module synthesis:

```text
required explicit concepts not assigned to any module
```

must trigger:

```text
warning or validation failure
```

Do not silently lose them.

---

# Multi-module concept policy

A concept may appear in more than one module only when:

```text
reinforced/revisited intentionally
```

Initial recommendation:

```text
one primary module per concept
optional reinforcement metadata later
```

Avoid duplicate module assignments by default.

---

# Stage 7 — Prerequisite inference

Call:

```text
infer_course_prerequisites()
```

using validated concepts/modules.

Post-validate:

```text
keys exist
no self-edge
evidence valid
no exact duplicates
strength valid
```

---

# Deterministic cycle detection

Before storing accepted prerequisites:

```text
run directed cycle detection
```

If cycles exist:

```text
do not silently persist
```

Options:

```text
remove lowest-confidence edge
or
return validation warning for later 48
```

Recommended in `46`:

```text
flag cycle
do not finalize blueprint as grounded
```

Detailed repair belongs in `48`.

---

# Stage 8 — Assemble blueprint draft

Build:

```text
CourseBlueprintDraft
```

from:

```text
merged concepts
outcomes
modules
prerequisites
warnings
course summary
```

Do not trust synthesis output's duplicated concept list if it conflicts with validated merged concepts.

Use deterministic assembly.

---

# Stage 9 — Critique pass

If enabled:

```text
critique_course_blueprint()
```

Input includes:

```text
draft blueprint
bounded evidence index
```

Critic checks:

- unsupported concepts;
- weak modules;
- missing topic hints;
- evidence mismatch;
- prerequisite risks;
- grounding concerns.

---

# Critic limitations

The critic must not rewrite the blueprint directly.

It returns findings.

A deterministic service decides:

```text
accept
retry specific stage
mark warning
fail grounding
```

---

# Stage 10 — Deterministic validation

Run:

```text
schema validation
local key validation
referential integrity
evidence integrity
source coverage
module coverage
prerequisite cycles
limits
duplicate detection
```

Detailed validation logic is expanded in `48`.

`46` must invoke the validator before success.

---

# Source coverage

Calculate at least:

```text
chunk evidence coverage
concept candidate coverage
merged concept coverage
module concept coverage
```

---

# Chunk evidence coverage

Measure:

```text
chunks represented in analysis / total eligible chunks
```

Expected:

```text
100%
```

unless explicitly skipped with reason.

---

# Concept coverage

Measure:

```text
source candidates accounted for
/
total source candidates
```

Expected:

```text
near 100%
```

with explicit exclusions.

---

# Module coverage

Measure:

```text
required explicit concepts assigned to modules
/
required explicit concepts
```

Threshold configurable.

---

# Blueprint generation failure conditions

Fail generation when:

```text
chunk analysis incomplete
invalid evidence IDs remain
critical concept coverage too low
unresolved dangling references
output exceeds safety limits
provider retries exhausted
no meaningful concepts extracted
no meaningful modules generated
```

---

# Warning-only conditions

May still produce reviewable blueprint when:

```text
minor ordering uncertainty
low-confidence optional concept
complex layout warning
small source coverage gap
uncertain prerequisite
```

These must surface in lecturer review.

---

# Blueprint confidence

Compute final confidence from:

```text
AI qualitative confidence
source coverage
validation warnings
unsupported-item count
evidence strength distribution
```

Do not blindly copy one LLM-returned confidence enum.

Recommended deterministic aggregator:

```text
HIGH
MEDIUM
LOW
```

---

# Blueprint persistence

Persist only after:

```text
all required generation stages complete
minimum deterministic validation passes
```

A partially generated blueprint may have temporary staging artifacts, but must not become active review blueprint.

---

# Persistence transaction sequence

Recommended:

```text
1. create CourseBlueprint shell/status
2. persist concepts
3. persist outcomes
4. persist modules
5. persist prerequisites
6. persist warnings
7. connect edges
8. validate persisted graph
9. mark GENERATED
10. queue BLUEPRINT_VALIDATION job
```

If persistence fails:

```text
mark generation job failed
clean partial draft graph safely
or mark incomplete generation artifact
```

---

# Blueprint generation graph edges

Suggested:

```jac
edge HAS_BLUEPRINT {}
edge HAS_BLUEPRINT_CONCEPT {}
edge HAS_BLUEPRINT_OUTCOME {}
edge HAS_BLUEPRINT_MODULE {
    has order_index: int;
}
edge HAS_BLUEPRINT_PREREQUISITE {}
edge HAS_BLUEPRINT_WARNING {}
```

Direction:

```text
TrackVersion
→ HAS_BLUEPRINT
→ CourseBlueprint
```

---

# One active draft blueprint

Initial policy:

```text
one active generated blueprint per track version + generation identity
```

Regeneration creates a new blueprint generation.

Do not overwrite old reviewed drafts silently.

---

# Blueprint generations

Add:

```text
generation_number
```

if useful.

Example:

```text
Blueprint generation 1
→ lecturer requests regeneration
Blueprint generation 2
```

Preserve history.

---

# Regeneration triggers

Allow explicit regeneration when:

```text
source document replaced
new extraction/chunk set
prompt/schema version changed
lecturer requests regeneration
admin corrective workflow
```

---

# Regeneration does not mutate published version

For a published course:

```text
regeneration belongs to a new draft course version
```

Do not regenerate active published curriculum in place.

---

# Idempotency

Generation key:

```text
track_version_id
chunk_set_id
source checksum
schema version
prompt versions
config hash
```

Equivalent successful request returns existing active blueprint.

---

# Concurrent generation

Only one active generation per generation key.

Duplicate requests:

```text
reuse current job/status
```

---

# Job worker

Create:

```text
BlueprintGenerationWorker
```

Implements:

```text
ProcessingStageWorker
```

for:

```text
BLUEPRINT_GENERATION
```

---

# Worker responsibilities

```text
assert eligibility
load chunk set
run staged analysis
persist intermediate artifacts
assemble draft
persist blueprint
complete job
```

Do not include publication.

---

# Restart recovery

Intermediate artifacts should be durable enough to resume.

Example:

```text
chunk analyses complete
concept merge started
worker crashes
```

Recovery should reuse existing chunk analyses.

---

# Stage checkpoints

Persist checkpoints:

```text
CHUNK_ANALYSIS_COMPLETE
CONCEPT_MERGE_COMPLETE
OUTCOME_SYNTHESIS_COMPLETE
MODULE_SYNTHESIS_COMPLETE
PREREQUISITE_INFERENCE_COMPLETE
CRITIQUE_COMPLETE
DRAFT_PERSISTED
```

---

# Blueprint generation run node

Recommended:

```jac
node BlueprintGenerationRun {
    has generation_run_id: str;

    has blueprint_id: str | None;

    has track_version_id: str;
    has chunk_set_id: str;

    has status: str;
    has current_step: str;

    has generation_config_hash: str;

    has started_at: str;
    has updated_at: str;
    has completed_at: str | None = None;

    has error_code: str | None = None;
}
```

This may complement the generic job node.

---

# Intermediate artifact reuse

Reuse:

```text
ChunkAnalysisArtifact
MergedConceptArtifact
OutcomeSynthesisArtifact
ModuleSynthesisArtifact
PrerequisiteInferenceArtifact
CritiqueArtifact
```

when matching inputs/versions.

You may persist only the most valuable intermediate artifacts initially:

```text
chunk analyses
merged concept set
```

These save the most expensive recomputation.

---

# Cost controls

Apply:

```text
bounded batch size
bounded parallelism
cache successful chunk analysis
retry only failed units
reuse merged concepts where inputs unchanged
do not critique repeatedly
```

---

# Token budgeting

Before every AI call:

```text
estimate input tokens
reserve output budget
reject/split over-limit batch
```

Never rely only on provider failure.

---

# Analysis batch planning

Example:

```text
max model context = X
trusted prompt reserve = A
output reserve = B
available evidence budget = X - A - B
```

Create units accordingly.

---

# Progress reporting

Map blueprint progress:

```text
0–20% analyze chunks
20–40% merge concepts
40–60% synthesize outcomes/modules
60–75% infer prerequisites
75–90% critique
90–100% persist/validate draft
```

These are approximate stage projections, not exact completion estimates.

---

# Lecturer-facing messages

Examples:

```text
Analyzing course topics…
Combining related concepts…
Organizing course modules…
Mapping prerequisite relationships…
Checking the generated course structure…
Preparing the course for review…
```

---

# Errors

Define:

```text
BLUEPRINT_SOURCE_NOT_READY
BLUEPRINT_CHUNK_SET_INVALID
BLUEPRINT_GENERATION_ALREADY_RUNNING
BLUEPRINT_CHUNK_ANALYSIS_FAILED
BLUEPRINT_CONCEPT_MERGE_FAILED
BLUEPRINT_OUTCOME_SYNTHESIS_FAILED
BLUEPRINT_MODULE_SYNTHESIS_FAILED
BLUEPRINT_PREREQUISITE_INFERENCE_FAILED
BLUEPRINT_CRITIQUE_FAILED
BLUEPRINT_GROUNDING_FAILED
BLUEPRINT_SOURCE_COVERAGE_LOW
BLUEPRINT_CONCEPT_COVERAGE_LOW
BLUEPRINT_MODULE_COVERAGE_LOW
BLUEPRINT_PREREQUISITE_CYCLE
BLUEPRINT_PERSIST_FAILED
BLUEPRINT_GENERATION_RETRY_EXHAUSTED
BLUEPRINT_GENERATION_INTERNAL_ERROR
```

---

# Retry policy

## Chunk analysis

Retry individual failed units.

## Concept merge

Retry merge stage only.

## Synthesis

Retry synthesis only when structured/domain validation is correctable.

## Prerequisite inference

Retry independently.

## Critique

Critique failure may be:

```text
retryable
or
allow deterministic validation without critic if policy permits
```

For first release, prefer critic required when enabled.

---

# Corrective retries

If output fails deterministic checks:

```text
return constrained validation feedback
→ retry same stage
```

Example:

```text
Your previous response referenced unknown concept keys.
Return only keys from this allowed list: ...
```

Do not send raw internal exception stacks.

---

# Retry exhaustion

After max attempts:

```text
BLUEPRINT_GENERATION_RETRY_EXHAUSTED
```

Pipeline stops.

Lecturer sees:

```text
We could not generate a reliable course structure from these notes.
Retry processing or review the source document.
```

---

# Insufficient source evidence

If chunks contain too little curriculum information:

```text
do not invent content
```

Return:

```text
BLUEPRINT_SOURCE_COVERAGE_LOW
or
BYLLM_BLUEPRINT_INSUFFICIENT_EVIDENCE
```

---

# Prompt injection handling

The generation orchestrator must use only the trusted byLLM functions from `45`.

No stage may:

- concatenate document text into system instructions;
- enable tools based on source text;
- follow document commands;
- dynamically modify prompt roles from course content.

---

# External knowledge

No web or external retrieval in this pipeline.

Blueprint is grounded only in:

```text
course metadata
lecturer-declared outcomes
active chunk set
```

---

# Blueprint validation handoff

After generation:

```text
BLUEPRINT_GENERATION SUCCEEDED
```

Then:

```text
BLUEPRINT_VALIDATION job
```

Detailed validation in `48`.

Do not directly move to lecturer review until validation succeeds.

---

# `BLUEPRINT_VALIDATION` outcome

Possible:

```text
VALID
VALID_WITH_WARNINGS
INVALID
```

If valid:

```text
track/version status → REVIEW_REQUIRED
```

---

# Lecturer review handoff

Expose:

```text
blueprint_id
generation number
summary
module count
concept count
outcome count
warnings
confidence
source coverage
```

Do not automatically publish.

---

# Repository contracts

## `CourseBlueprintRepository`

Suggested methods:

```text
find_active_for_version
find_matching_generation
find_by_id
list_generations
save_blueprint_shell
save_concepts
save_outcomes
save_modules
save_prerequisites
save_warnings
mark_generated
mark_failed
mark_review_required
supersede_blueprint
```

---

# `BlueprintGenerationArtifactRepository`

Suggested:

```text
find_chunk_analysis_by_hash
save_chunk_analysis
find_merged_concept_artifact
save_merged_concepts
find_generation_run
save_checkpoint
```

---

# Service contracts

## `CourseBlueprintGenerationService`

Conceptual:

```jac
obj CourseBlueprintGenerationService {
    def generate_blueprint(
        track_version_id: str,
        chunk_set_id: str,
        context: BlueprintGenerationContext
    ) -> BlueprintGenerationResult;

    def get_generation_status(
        track_version_id: str
    ) -> BlueprintGenerationStatusView;

    def retry_generation(
        blueprint_id: str,
        context: BlueprintGenerationContext
    ) -> BlueprintGenerationResult;
}
```

---

# Generation context

```jac
obj BlueprintGenerationContext {
    has track_id: str;
    has track_version_id: str;

    has document_id: str;
    has chunk_set_id: str;

    has request_id: str;
    has actor_id: str | None;

    has config: BlueprintGenerationConfig;

    has force_regenerate: bool = False;
}
```

---

# Generation result

```jac
obj BlueprintGenerationResult {
    has blueprint_id: str | None;

    has status: BlueprintGenerationStatus;

    has concept_count: int;
    has module_count: int;
    has outcome_count: int;
    has prerequisite_count: int;

    has source_coverage_ratio: float;

    has confidence: str | None;

    has warnings: list[str];

    has error_code: str | None;
}
```

---

# Walker/API boundary

Suggested private/internal walkers:

```text
generate_course_blueprint
get_course_blueprint_generation_status
retry_course_blueprint_generation
```

Lecturer authorization applies to explicit manual generation/retry.

Automatic pipeline progression uses internal trusted worker context.

---

# `generate_course_blueprint`

Behavior:

1. authenticate/authorize if manually triggered;
2. resolve track version;
3. resolve active document/chunk set;
4. assert readiness;
5. create/reuse generation job;
6. return job/processing summary.

Do not keep request open until generation finishes.

---

# `get_course_blueprint_generation_status`

Return:

```text
current step
progress
warning count
retry availability
safe error
```

Do not expose raw model prompts/responses.

---

# `retry_course_blueprint_generation`

Resume from the failed checkpoint where safe.

Example:

```text
chunk analysis complete
module synthesis failed
```

Retry module synthesis onward.

Do not repeat successful chunk analysis.

---

# Course status integration

Track version states may evolve:

```text
DRAFT
→ PROCESSING
→ REVIEW_REQUIRED
```

During blueprint generation:

```text
track status = PROCESSING
```

After successful validation:

```text
track/version status = REVIEW_REQUIRED
```

Do not mark `PUBLISHED`.

---

# Processing job integration

Generic job:

```text
stage = BLUEPRINT_GENERATION
```

Artifact-specific checkpoints live in generation run.

On success:

```text
complete BLUEPRINT_GENERATION
→ queue BLUEPRINT_VALIDATION
```

---

# Cancellation

If source document or track version changes while generation runs:

```text
request cancel
```

Before final commit:

```text
revalidate active chunk set
revalidate generation identity
```

Obsolete result must not become active blueprint.

---

# Regeneration during review

If lecturer requests regeneration before approval:

```text
old blueprint remains historical
new generation created
new generation becomes active review candidate
```

Do not silently overwrite lecturer edits.

---

# Edited blueprint conflict

If lecturer has already edited blueprint:

```text
regeneration requires explicit confirmation in later UI
```

This is enforced more fully in `49`.

---

# Observability

Emit:

```text
blueprint_generation.started
blueprint_generation.chunk_analysis_started
blueprint_generation.chunk_analysis_completed
blueprint_generation.concept_merge_completed
blueprint_generation.outcome_synthesis_completed
blueprint_generation.module_synthesis_completed
blueprint_generation.prerequisite_completed
blueprint_generation.critique_completed
blueprint_generation.persisted
blueprint_generation.failed
blueprint_generation.reused
blueprint_generation.cancelled
```

Fields:

```text
blueprint_id
generation_run_id
track_id
track_version_id
document_id
chunk_set_id
step
prompt_version
schema_version
provider
model
duration_ms
attempt
error_code
```

Do not log raw course content.

---

# Metrics

Track:

```text
blueprint_generation_total
blueprint_generation_completed_total
blueprint_generation_failed_total
blueprint_generation_reused_total

blueprint_generation_duration_ms
blueprint_chunk_analysis_calls_total
blueprint_chunk_analysis_cache_hit_total

blueprint_concepts_generated
blueprint_modules_generated
blueprint_outcomes_generated
blueprint_prerequisites_generated

blueprint_source_coverage_ratio
blueprint_concept_coverage_ratio
```

---

# Testing strategy

## Eligibility tests

Attempt generation when:

```text
validation incomplete
extraction incomplete
chunking incomplete
wrong chunk set
replaced document
archived track version
```

All must fail safely.

---

# Chunk-analysis tests

- all chunks analyzed;
- bounded batches;
- cache reuse;
- only failed units retried;
- invalid evidence rejected.

---

# Concept-merge tests

- duplicates merged;
- evidence preserved;
- distinct concepts retained;
- all candidate IDs accounted for.

---

# Outcome tests

- explicit outcomes preserved;
- duplicates normalized;
- evidence retained;
- unsupported outcomes rejected.

---

# Module synthesis tests

- module keys unique;
- order deterministic/valid;
- concept references valid;
- required concepts assigned;
- module count bounded.

---

# Prerequisite tests

- no self-edge;
- all keys valid;
- duplicates removed;
- cycle detection runs;
- weak unsupported edges warned/rejected.

---

# Critique tests

- unsupported concept flagged;
- weak evidence flagged;
- critic cannot mutate source graph directly.

---

# Coverage tests

Test:

```text
all chunks analyzed
all candidates accounted
all required concepts assigned
```

---

# Idempotency tests

Same generation identity:

```text
returns existing successful blueprint
```

---

# Regeneration tests

Changed:

```text
chunk set
prompt version
config
```

creates new generation.

Old generation preserved.

---

# Restart recovery tests

Crash after:

```text
chunk analysis
concept merge
module synthesis
```

Verify resume from durable checkpoint.

---

# Concurrency tests

Two generate requests:

```text
one active generation job
```

---

# Replacement race tests

Replace source while generation runs.

Verify obsolete generation cannot become active.

---

# Failure-injection tests

Simulate:

```text
provider timeout
rate limit
invalid structured output
repository failure
worker crash
partial blueprint persistence
```

Verify recoverability.

---

# Prompt-injection tests

Source chunk contains instruction-like content.

Verify:

- typed task remains constrained;
- no external action;
- evidence still grounded.

---

# Example Jac test outlines

```jac
test "blueprint generation requires active chunk set" {
    # Supply stale chunk set.
    # Assert BLUEPRINT_CHUNK_SET_INVALID.
}

test "successful chunk analyses are reused after restart" {
    # Persist chunk-analysis artifacts.
    # Simulate crash.
    # Resume generation.
    # Assert no duplicate analysis calls.
}

test "all required concepts must be assigned to modules" {
    # Synthesis omits a required concept.
    # Assert module coverage validation warning/failure.
}

test "equivalent generation is idempotent" {
    # Generate twice with same identity.
    # Assert existing blueprint reused.
}

test "source replacement invalidates active generation" {
    # Start generation.
    # Replace document/chunk set.
    # Finish old run.
    # Assert old blueprint not activated.
}
```

---

# Implementation sequence

## Step 1 — Add blueprint artifact nodes

Implement:

```text
CourseBlueprint
BlueprintConcept
BlueprintLearningOutcomeNode
BlueprintModule
BlueprintPrerequisite
BlueprintWarningNode
```

## Step 2 — Add graph edges

Implement blueprint relationships.

## Step 3 — Add generation run/checkpoints

Persist restart-safe progress.

## Step 4 — Add eligibility service

Validate source/chunk readiness.

## Step 5 — Add analysis planner

Create bounded chunk analysis units.

## Step 6 — Integrate chunk analyzer

Use typed contract from `45`.

## Step 7 — Add chunk-analysis caching

Reuse unchanged results.

## Step 8 — Implement concept merge stage

Validate candidate accounting.

## Step 9 — Implement outcome synthesis

Normalize explicit and derived outcomes.

## Step 10 — Implement blueprint/module synthesis

Validate references/order/coverage.

## Step 11 — Implement prerequisite inference

Run deterministic cycle detection.

## Step 12 — Add critic pass

Record findings, do not mutate automatically.

## Step 13 — Add deterministic assembly

Build canonical `CourseBlueprintDraft`.

## Step 14 — Persist blueprint draft

Use safe graph transaction/checkpointing.

## Step 15 — Integrate job state

Queue `BLUEPRINT_VALIDATION`.

## Step 16 — Add retry/resume

Resume from durable checkpoints.

## Step 17 — Add observability

Metrics, logs, execution metadata.

## Step 18 — Add tests

Mocks, recovery, grounding, coverage, concurrency.

---

# Acceptance criteria

## Input/source

- [ ] Only active valid chunk sets can generate blueprints.
- [ ] Source checksum/chunk set identity is recorded.
- [ ] Stale or replaced sources cannot become active blueprint.

## AI orchestration

- [ ] Chunk analysis is bounded.
- [ ] Successful chunk analyses are reusable.
- [ ] Only failed units are retried.
- [ ] Concept merge preserves evidence.
- [ ] Outcomes remain grounded.
- [ ] Module synthesis uses valid local references.
- [ ] Prerequisites use valid concept keys.

## Grounding

- [ ] Unknown evidence IDs fail.
- [ ] Candidate coverage is measured.
- [ ] Required concept/module coverage is measured.
- [ ] Unsupported concepts are flagged.
- [ ] External curriculum enrichment is not performed.

## Persistence

- [ ] Blueprint draft has durable identity.
- [ ] Intermediate artifacts/checkpoints support restart.
- [ ] Partial failed generation does not become active.
- [ ] Historical generations are preserved.

## Idempotency

- [ ] Equivalent generation request reuses existing result.
- [ ] Duplicate concurrent runs are prevented.
- [ ] Changed source/config/prompt versions create new generation.

## Job integration

- [ ] `BLUEPRINT_GENERATION` is durable.
- [ ] Progress is exposed.
- [ ] Retry resumes from safe checkpoint.
- [ ] Successful generation queues validation.
- [ ] Course does not become published automatically.

## Security

- [ ] Source text remains untrusted.
- [ ] No arbitrary tool access is used.
- [ ] Prompt-injection content cannot change the generation task.
- [ ] No secrets or unrelated PII are sent to the model.

## Quality

- [ ] `jac check` passes.
- [ ] `jac check --lint` passes.
- [ ] `jac test` passes.
- [ ] Mock-mode pipeline tests pass.
- [ ] Restart recovery tests pass.
- [ ] Grounding/coverage tests pass.
- [ ] Concurrency tests pass.
- [ ] Failure-injection tests pass.

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
1. Process a valid course through chunking.
2. Start blueprint generation.
3. Chunk analyses execute in bounded batches.
4. Successful analysis artifacts are persisted.
5. Duplicate concepts are merged.
6. Evidence from all relevant chunks is preserved.
7. Outcomes are generated and grounded.
8. Modules are synthesized in valid order.
9. Required concepts are assigned.
10. Prerequisites are inferred.
11. Cycle detection runs.
12. Critique runs.
13. Blueprint draft persists.
14. BLUEPRINT_VALIDATION is queued.
15. Course/version moves toward REVIEW_REQUIRED only after validation.

16. Restart midway after chunk analysis.
17. Resume without redoing successful chunk analyses.

18. Retry a failed synthesis stage.
19. Confirm earlier successful stages are reused.

20. Replace the source document during generation.
21. Confirm obsolete result cannot become active.

22. Run equivalent generation again.
23. Confirm existing result is reused.

24. Confirm no learner roadmap, lesson, or publication is created by this specification.
```

---

# Expected result

After this specification is implemented:

- GraphLearn can transform a full lecturer-provided course into a structured, evidence-backed blueprint using staged byLLM interpretation;
- large courses are processed in bounded, restart-safe stages;
- unchanged chunks do not incur repeated AI cost;
- generated concepts, outcomes, modules, and prerequisites remain traceable to source evidence;
- failures can resume from checkpoints instead of restarting the whole course;
- duplicate concurrent generation is prevented;
- stale/replaced source material cannot become active curriculum;
- the result is a reviewable `CourseBlueprintDraft`, not a published course;
- `47`, `48`, and `49` can safely transform, validate, and review that draft.
