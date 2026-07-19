# 48-blueprint-validation-and-grounding.md

## Overview

Implement the validation and grounding subsystem that evaluates an AI-generated `CourseBlueprint` and its derived draft curriculum graph before the course can move to lecturer review.

This specification sits after:

```text
45-course-blueprint-byllm-contracts.md
46-course-blueprint-generation.md
47-topic-and-skill-graph-generation.md
```

and before:

```text
49-lecturer-blueprint-review.md
50-course-publication-and-versioning.md
```

Its responsibility is to answer:

```text
Is this blueprint structurally valid?
Is it grounded in the lecturer's source material?
Did any important source content disappear?
Did the AI invent unsupported curriculum?
Are the prerequisite and module structures coherent?
Is the generated graph safe to present for lecturer review?
```

The core rule is:

```text
AI output is never considered trustworthy merely because it is typed.

Typed output
→ deterministic validation
→ grounding validation
→ graph integrity validation
→ review eligibility decision
```

---

## Status

- **Feature type:** AI quality gate / grounding validation
- **Priority:** Critical
- **Depends on:** `45-course-blueprint-byllm-contracts.md`
- **Depends on:** `46-course-blueprint-generation.md`
- **Depends on:** `47-topic-and-skill-graph-generation.md`
- **Blocks:** `49-lecturer-blueprint-review.md`
- **Blocks:** `50-course-publication-and-versioning.md`
- **Breaking changes allowed:** No
- **Primary implementation:** deterministic validators + optional bounded byLLM critique + validation report

---

# Goals

Implement validation that:

1. Verifies blueprint schema and required fields.
2. Verifies every local reference resolves.
3. Verifies all evidence references point to valid source chunks.
4. Checks evidence belongs to the correct document and track version.
5. Detects unsupported/hallucinated concepts.
6. Measures chunk/source coverage.
7. Measures candidate-to-concept coverage.
8. Measures concept-to-module coverage.
9. Detects duplicate concepts/modules/outcomes.
10. Detects missing or weakly grounded learning outcomes.
11. Detects prerequisite self-edges, duplicates, and cycles.
12. Detects module-order conflicts with prerequisite dependencies.
13. Verifies graph generation matches validated blueprint.
14. Produces a structured validation report.
15. Distinguishes fatal errors from warnings.
16. Supports bounded AI critique as secondary evidence.
17. Decides whether the blueprint is review-ready.
18. Prevents publication/readiness on invalid output.
19. Supports safe corrective regeneration.
20. Preserves complete validation history.

---

# Non-goals

This specification does not:

- regenerate the blueprint itself;
- publish the course;
- let the lecturer edit the blueprint;
- generate lessons;
- generate quizzes;
- add external knowledge;
- automatically rewrite source notes;
- silently repair major unsupported content;
- create learner roadmaps.

---

# Validation architecture

```text
CourseBlueprint
    │
    ├── BlueprintConcept[]
    ├── BlueprintModule[]
    ├── BlueprintOutcome[]
    ├── BlueprintPrerequisite[]
    │
    ▼
BlueprintValidationService
    │
    ├── schema validator
    ├── reference validator
    ├── evidence validator
    ├── grounding validator
    ├── coverage validator
    ├── duplicate validator
    ├── prerequisite validator
    ├── graph consistency validator
    ├── optional AI critic
    └── decision engine
            │
            ▼
BlueprintValidationReport
            │
            ├── VALID
            ├── VALID_WITH_WARNINGS
            └── INVALID
```

---

# Validation status

```jac
enum BlueprintValidationStatus {
    NOT_VALIDATED,
    VALIDATING,
    VALID,
    VALID_WITH_WARNINGS,
    INVALID
}
```

---

# Severity

```jac
enum BlueprintValidationSeverity {
    INFO,
    WARNING,
    ERROR,
    CRITICAL
}
```

---

# Validation category

```jac
enum BlueprintValidationCategory {
    SCHEMA,
    REFERENCE,
    EVIDENCE,
    GROUNDING,
    COVERAGE,
    DUPLICATE,
    LEARNING_OUTCOME,
    MODULE_STRUCTURE,
    PREREQUISITE,
    GRAPH_INTEGRITY,
    SOURCE_CONFLICT,
    AI_CRITIQUE
}
```

---

# Validation issue

```jac
obj BlueprintValidationIssue {
    has issue_id: str;

    has category: BlueprintValidationCategory;
    has severity: BlueprintValidationSeverity;

    has code: str;
    has message: str;

    has blueprint_entity_type: str | None = None;
    has blueprint_entity_key: str | None = None;

    has evidence_chunk_ids: list[str] = [];

    has repairable: bool = False;
    has requires_lecturer_review: bool = False;
}
```

---

# Validation report node

Create:

```jac
node BlueprintValidationReport {
    has validation_report_id: str;

    has blueprint_id: str;

    has track_id: str;
    has track_version_id: str;

    has status: BlueprintValidationStatus;

    has validation_schema_version: int;

    has source_coverage_ratio: float = 0.0;
    has concept_coverage_ratio: float = 0.0;
    has module_coverage_ratio: float = 0.0;
    has grounding_ratio: float = 0.0;

    has warning_count: int = 0;
    has error_count: int = 0;
    has critical_count: int = 0;

    has grounded_concept_count: int = 0;
    has unsupported_concept_count: int = 0;

    has validated_at: str | None = None;

    has validator_version: str;

    has created_at: str;
}
```

---

# Validation schema version

Define:

```text
BLUEPRINT_VALIDATION_SCHEMA_VERSION = 1
```

Persist it so later stricter validators can revalidate historical drafts.

---

# Validation graph

```text
CourseBlueprint
└── HAS_VALIDATION_REPORT
    └── BlueprintValidationReport
        └── HAS_VALIDATION_ISSUE
            └── BlueprintValidationIssue[]
```

---

# Validation identity

Validation identity:

```text
blueprint_id
blueprint content hash
validation schema version
validator version
graph generation ID
```

If nothing changed:

```text
reuse valid report
```

unless forced revalidation.

---

# Validation phases

Recommended order:

```text
1. Blueprint identity and readiness
2. Schema validation
3. Local-reference validation
4. Evidence-reference validation
5. Grounding validation
6. Coverage validation
7. Duplicate/normalization validation
8. Learning-outcome validation
9. Module-structure validation
10. Prerequisite validation
11. Graph consistency validation
12. Optional AI critique reconciliation
13. Final review-readiness decision
```

Fail early on unrecoverable structural corruption.

---

# Phase 1 — Blueprint readiness

Required:

```text
blueprint exists
status GENERATED
track/version match
source document active/current
source checksum matches expected
chunk set exists and is active
graph generation exists if required
```

Failure:

```text
BLUEPRINT_NOT_READY_FOR_VALIDATION
```

---

# Source identity invariants

Validate:

```text
blueprint.document_id
blueprint.extraction_id
blueprint.chunk_set_id
```

all belong to:

```text
same track_id
same track_version_id
```

Do not validate a blueprint against unrelated chunks.

---

# Phase 2 — Schema validation

Check:

```text
required strings non-empty
list counts within limits
valid enums
valid numeric ranges
unique local keys
valid order indexes
```

Examples:

```text
no empty module title
no negative learning hours
no duplicate module order indexes
no missing concept keys
```

---

# Schema fatality

Structural errors should normally be:

```text
ERROR or CRITICAL
```

and make the blueprint:

```text
INVALID
```

---

# Phase 3 — Local-reference validation

Validate:

```text
module concept keys resolve
module outcome keys resolve
prerequisite concept keys resolve
source candidate IDs resolve where retained
```

No dangling references.

Error:

```text
BLUEPRINT_DANGLING_REFERENCE
```

---

# Reference uniqueness

Check:

```text
concept local keys unique
module local keys unique
outcome keys unique
prerequisite candidate identities unique
```

---

# Phase 4 — Evidence-reference validation

Every evidence reference must satisfy:

```text
chunk exists
chunk belongs to active chunk set
chunk belongs to correct document
chunk belongs to correct track version
```

Unknown chunk:

```text
BLUEPRINT_INVALID_EVIDENCE_REFERENCE
```

---

# Quote-hint validation

Where `quote_hint` exists:

```text
normalize quote hint
normalize chunk text
attempt bounded substring/fuzzy match
```

If mismatch:

```text
warning
```

unless evidence itself is otherwise invalid.

Do not reject a valid chunk reference solely because wording normalization changed.

---

# Page-range validation

For PDF:

```text
evidence page_start/page_end
```

must fit within chunk provenance.

For DOCX:

```text
null page values are valid
```

Do not fabricate page metadata.

---

# Evidence strength policy

Important blueprint entities should prefer:

```text
DIRECT
STRONG_INFERENCE
```

If only:

```text
WEAK_INFERENCE
```

supports a required concept/module:

```text
requires lecturer review
```

or becomes invalid depending on threshold.

---

# Phase 5 — Grounding validation

Grounding asks:

```text
Does the source actually support the blueprint claim?
```

Grounding should use deterministic heuristics first.

Optional AI critique may supplement.

---

# Grounded concept rule

A concept is grounded when:

```text
has at least one valid evidence chunk
AND concept name/description is semantically consistent with evidence
AND not contradicted by source
```

The semantic-consistency component may use:

- lexical match;
- alias match;
- key-term match;
- bounded AI critic.

---

# Deterministic grounding signals

Possible checks:

```text
canonical name appears in evidence
alias appears in evidence
key terms appear
learning-objective terminology appears
multiple direct references
```

Absence of exact words does not always mean hallucination.

Use thresholds conservatively.

---

# Optional AI grounding critic

Use:

```text
critique_course_blueprint()
```

from `45`.

The critic may identify:

```text
unsupported concept
weak module
missing topic
conflicting source
```

It must not become the sole validator.

---

# Critic agreement policy

Possible:

```text
deterministic invalid + critic invalid
→ strong invalid

deterministic valid + critic warning
→ warning/review

deterministic weak + critic unsupported
→ invalid or lecturer review
```

---

# Unsupported concept

A concept is unsupported when:

```text
no valid evidence
or
evidence does not plausibly support it
or
critic flags unsupported and deterministic evidence is weak
```

Required explicit unsupported concept:

```text
ERROR
```

Optional low-confidence unsupported concept:

```text
WARNING or exclude before review
```

---

# Hallucination code

```text
BLUEPRINT_UNSUPPORTED_CONCEPT
```

Do not label every inferred prerequisite as hallucination.

Grounding rules vary by entity type.

---

# Unsupported module

A module may be unsupported if:

```text
its concepts are unsupported
or
module description introduces new material not present in concepts/evidence
```

---

# Unsupported learning outcome

Outcome is unsupported when:

```text
capability is not derivable from concept/source evidence
```

Example bad:

```text
Design distributed database consensus algorithms
```

when notes only cover basic SQL.

---

# Phase 6 — Coverage validation

Coverage checks whether important source material disappeared.

---

# Source chunk coverage

```text
analyzed eligible chunks
/
total eligible chunks
```

Expected:

```text
1.0
```

unless explicit skip reason exists.

---

# Candidate concept coverage

```text
source candidates accounted for
/
all source candidates
```

Accounted means:

```text
merged
excluded with reason
retained
```

---

# Blueprint concept coverage

Compare:

```text
merged concepts
→ blueprint concepts
```

Required concepts must not disappear.

---

# Module coverage

```text
explicit required concepts assigned to primary module
/
required explicit concepts
```

Recommended:

```text
1.0
```

for review readiness.

---

# Outcome coverage

Measure:

```text
modules with at least one relevant learning outcome
/
required modules
```

Do not require outcomes for optional/supporting modules unless policy says so.

---

# Coverage thresholds

Suggested configuration:

```text
MIN_SOURCE_CHUNK_COVERAGE = 1.0
MIN_CONCEPT_COVERAGE = 0.95
MIN_MODULE_COVERAGE = 1.0
MIN_GROUNDING_RATIO = 0.90
```

Tune with real courses.

---

# Coverage error examples

```text
BLUEPRINT_SOURCE_COVERAGE_LOW
BLUEPRINT_CONCEPT_COVERAGE_LOW
BLUEPRINT_MODULE_COVERAGE_LOW
```

---

# Phase 7 — Duplicate validation

Normalize:

```text
Unicode
casefold
trim
collapse whitespace
```

Detect duplicate:

```text
concept names
module titles
outcome statements
prerequisite edges
```

---

# Duplicate concept policy

If exact normalized duplicates remain:

```text
ERROR
```

because concept merge should have resolved them.

Near duplicates:

```text
WARNING
```

Examples:

```text
SQL Basics
Introduction to SQL
```

may or may not be duplicates.

---

# Duplicate module policy

Exact duplicate titles:

```text
WARNING or ERROR
```

depending on content similarity.

Modules may intentionally repeat labels like:

```text
Review
```

but should be distinguishable.

---

# Phase 8 — Learning outcome validation

Check outcomes for:

```text
non-empty learner action
reasonable specificity
evidence
valid objective level
no duplicates
```

---

# Outcome verb heuristic

Prefer outcomes beginning with measurable/action verbs.

Examples:

```text
Explain
Apply
Analyze
Compare
Design
Evaluate
```

Weak outcomes:

```text
Understand everything about databases
Know SQL
```

These should trigger quality warnings.

---

# Outcome-to-module mapping

Each required module should have:

```text
at least one outcome
```

unless course design intentionally places outcomes only at course level.

Configuration may allow either.

---

# Phase 9 — Module structure validation

Check:

```text
module order indexes unique
modules non-empty
required concepts assigned
module evidence present
module size reasonable
```

---

# Empty module

Module with:

```text
0 concepts
```

is normally invalid.

Exception:

```text
orientation
capstone instructions
review
```

only if explicitly supported.

---

# Overly broad module

Signals:

```text
very high concept count
very high estimated hours
spans unrelated headings
```

Warning:

```text
BLUEPRINT_MODULE_TOO_BROAD
```

---

# Overly narrow module

Signals:

```text
single trivial concept
very low evidence
```

Warning:

```text
BLUEPRINT_MODULE_TOO_NARROW
```

---

# Module order coherence

Compare:

```text
module order
prerequisite direction
source order
```

If later module is prerequisite for earlier module:

```text
MODULE_ORDER_PREREQUISITE_CONFLICT
```

This may be warning or error depending on severity.

---

# Phase 10 — Prerequisite validation

Validate:

```text
source concept exists
target concept exists
source != target
same track/version
edge unique
evidence valid
confidence threshold
strength valid
no cycle
```

---

# Self prerequisite

```text
A → A
```

is always invalid.

---

# Duplicate prerequisite

Duplicate:

```text
A → B
```

must collapse.

If strengths conflict:

```text
REQUIRED wins over RECOMMENDED
```

only if evidence supports required strength.

Otherwise flag.

---

# Cycle detection

Run deterministic cycle detection over required and optionally recommended edges.

At minimum:

```text
REQUIRED graph must be acyclic
```

Recommended edges may be checked separately.

---

# Cycle result

```jac
obj PrerequisiteCycleResult {
    has has_cycle: bool;
    has cycle_paths: list[list[str]];
}
```

---

# Cycle severity

Required-edge cycle:

```text
CRITICAL
```

Recommended-edge cycle:

```text
WARNING or ERROR
```

depending on runtime usage.

---

# Phase 11 — Graph consistency validation

Compare blueprint against `CurriculumGraphGenerationRun`.

Validate:

```text
module count
skill count
outcome count
prerequisite count
blueprint-to-domain mappings
graph_generation_id
track/version scope
```

---

# Blueprint-to-graph consistency

Every explicit blueprint concept should map to:

```text
exactly one Skill
```

Every module to:

```text
exactly one CurriculumModule
```

unless intentionally excluded with reason.

---

# Graph orphan check

No active draft skill may be:

```text
without a primary module
```

---

# Cross-version check

No graph entity/edge may cross:

```text
track_version_id
```

---

# Provenance check

Every runtime draft graph entity must retain:

```text
blueprint ID
blueprint local key
source evidence reference
```

Missing provenance:

```text
ERROR
```

---

# Graph hash consistency

Optionally compute:

```text
blueprint semantic hash
graph semantic hash
```

to detect drift.

---

# Phase 12 — Source conflict detection

Course notes may contradict themselves.

Examples:

```text
two different definitions
different grading weights
different prerequisite order
```

Validation should not silently choose one.

Issue:

```text
BLUEPRINT_SOURCE_CONFLICT
```

Requires lecturer review.

---

# Contradiction detection

Use:

- duplicate/variant statements;
- chunk-level warnings;
- optional critic.

Do not overclaim certainty.

---

# Validation decision engine

Final status rules.

## `VALID`

Requirements:

```text
no ERROR
no CRITICAL
coverage thresholds met
grounding threshold met
graph valid
```

## `VALID_WITH_WARNINGS`

Requirements:

```text
no CRITICAL
no blocking ERROR
warnings exist
lecturer can meaningfully review/resolve
```

## `INVALID`

Any:

```text
critical issue
unresolved blocking error
coverage below hard threshold
unsupported required concept
dangling references
required prerequisite cycle
graph integrity failure
```

---

# Review readiness

Create:

```jac
obj BlueprintReviewEligibility {
    has eligible: bool;

    has validation_status: BlueprintValidationStatus;

    has blocking_issue_codes: list[str];

    has warning_codes: list[str];

    has requires_regeneration: bool;
    has requires_source_replacement: bool;
}
```

---

# Repair classification

Each issue should classify possible resolution.

```jac
enum BlueprintRepairAction {
    NONE,
    AUTO_RETRY_STAGE,
    REGENERATE_BLUEPRINT,
    REGENERATE_GRAPH,
    LECTURER_REVIEW,
    REPLACE_SOURCE_DOCUMENT
}
```

---

# Auto-repair policy

Safe auto-repair examples:

```text
remove exact duplicate prerequisite edge
recompute order index
drop invalid quote hint while keeping valid chunk evidence
```

Do not auto-repair:

```text
unsupported concept
source contradiction
missing major topic
prerequisite cycle requiring semantic choice
```

These require regeneration or lecturer review.

---

# Validation issue code catalogue

Define:

```text
BLUEPRINT_NOT_READY_FOR_VALIDATION
BLUEPRINT_SCHEMA_INVALID
BLUEPRINT_DANGLING_REFERENCE
BLUEPRINT_DUPLICATE_LOCAL_KEY

BLUEPRINT_INVALID_EVIDENCE_REFERENCE
BLUEPRINT_EVIDENCE_TRACK_VERSION_MISMATCH
BLUEPRINT_EVIDENCE_QUOTE_MISMATCH
BLUEPRINT_EVIDENCE_TOO_WEAK

BLUEPRINT_UNSUPPORTED_CONCEPT
BLUEPRINT_UNSUPPORTED_MODULE
BLUEPRINT_UNSUPPORTED_OUTCOME
BLUEPRINT_UNSUPPORTED_PREREQUISITE

BLUEPRINT_SOURCE_COVERAGE_LOW
BLUEPRINT_CONCEPT_COVERAGE_LOW
BLUEPRINT_MODULE_COVERAGE_LOW
BLUEPRINT_GROUNDING_RATIO_LOW

BLUEPRINT_DUPLICATE_CONCEPT
BLUEPRINT_DUPLICATE_MODULE
BLUEPRINT_DUPLICATE_OUTCOME

BLUEPRINT_OUTCOME_TOO_VAGUE
BLUEPRINT_OUTCOME_NOT_GROUNDED
BLUEPRINT_MODULE_EMPTY
BLUEPRINT_MODULE_TOO_BROAD
BLUEPRINT_MODULE_TOO_NARROW
BLUEPRINT_MODULE_ORDER_CONFLICT

BLUEPRINT_PREREQUISITE_SELF_EDGE
BLUEPRINT_PREREQUISITE_DUPLICATE
BLUEPRINT_PREREQUISITE_CYCLE
BLUEPRINT_PREREQUISITE_LOW_CONFIDENCE

BLUEPRINT_GRAPH_MAPPING_MISSING
BLUEPRINT_GRAPH_ORPHAN_SKILL
BLUEPRINT_GRAPH_CROSS_VERSION_EDGE
BLUEPRINT_GRAPH_PROVENANCE_MISSING
BLUEPRINT_GRAPH_INCONSISTENT

BLUEPRINT_SOURCE_CONFLICT
BLUEPRINT_VALIDATION_INTERNAL_ERROR
```

---

# Validation service

Create:

```text
BlueprintValidationService
```

Responsibilities:

```text
assert_ready
load_blueprint
load_evidence
load_graph_generation
run_schema_validation
run_reference_validation
run_evidence_validation
run_grounding_validation
run_coverage_validation
run_duplicate_validation
run_outcome_validation
run_module_validation
run_prerequisite_validation
run_graph_validation
run_optional_critic
build_report
decide_review_eligibility
persist_report
```

---

# Service contract

Conceptual:

```jac
obj BlueprintValidationService {
    def validate_blueprint(
        blueprint_id: str,
        context: BlueprintValidationContext
    ) -> BlueprintValidationResult;

    def get_validation_report(
        blueprint_id: str
    ) -> BlueprintValidationResult | None;

    def revalidate_blueprint(
        blueprint_id: str,
        context: BlueprintValidationContext
    ) -> BlueprintValidationResult;
}
```

---

# Validation context

```jac
obj BlueprintValidationContext {
    has track_id: str;
    has track_version_id: str;

    has blueprint_id: str;
    has graph_generation_id: str | None;

    has request_id: str;
    has actor_id: str | None;

    has validation_schema_version: int;

    has force_revalidate: bool = False;
}
```

---

# Validation result

```jac
obj BlueprintValidationResult {
    has validation_report_id: str;

    has status: BlueprintValidationStatus;

    has source_coverage_ratio: float;
    has concept_coverage_ratio: float;
    has module_coverage_ratio: float;
    has grounding_ratio: float;

    has issue_count: int;
    has warning_count: int;
    has error_count: int;
    has critical_count: int;

    has eligible_for_review: bool;

    has requires_regeneration: bool;
    has requires_source_replacement: bool;
}
```

---

# Repository contracts

## `BlueprintValidationRepository`

Suggested methods:

```text
find_matching_report
find_latest_report
save_report
save_issues
mark_valid
mark_invalid
list_issues
```

---

# Read models required

Need efficient batched reads for:

```text
blueprint
concepts
modules
outcomes
prerequisites
chunk evidence
graph mappings
graph nodes/edges
```

Avoid N+1 traversal.

---

# Validation idempotency

If:

```text
blueprint hash unchanged
graph generation unchanged
validator version unchanged
validation schema unchanged
```

reuse report.

---

# Revalidation

Required when:

```text
blueprint edited
graph regenerated
validator version changed
source/chunk set changed
validation policy changed
```

---

# Validation history

Do not overwrite old reports.

Persist:

```text
report 1
report 2
...
```

One report becomes:

```text
current/latest
```

---

# Job integration

This service runs under:

```text
BLUEPRINT_VALIDATION
```

job stage from `44`.

On success:

```text
if VALID or VALID_WITH_WARNINGS
→ track/version REVIEW_REQUIRED
```

On invalid:

```text
→ processing blocked
→ expose repair action
```

---

# Course status transitions

```text
PROCESSING
→ REVIEW_REQUIRED
```

only when:

```text
validation eligible_for_review == true
```

Otherwise:

```text
PROCESSING
→ BLOCKED / NEEDS_ATTENTION
```

depending on current domain enums.

---

# Corrective regeneration

If validation identifies a repairable AI-stage problem:

```text
AUTO_RETRY_STAGE
or
REGENERATE_BLUEPRINT
```

the job orchestrator may create a new generation.

Never mutate failed blueprint in place silently.

---

# Source replacement decision

Set:

```text
requires_source_replacement = true
```

when problems originate from source:

```text
insufficient content
contradictory source too severe
OCR/quality issues
unsupported course structure
```

---

# Lecturer review decision

Set:

```text
requires_lecturer_review = true
```

for:

```text
ambiguous ordering
medium-confidence prerequisites
source conflicts
weak optional concepts
```

---

# Grounding score

Calculate deterministic score.

Example weighted formula:

```text
grounded required concepts
+ grounded modules
+ grounded outcomes
+ grounded prerequisites
/
total weighted entities
```

Do not expose false precision as certainty.

The ratio is an internal quality metric.

---

# Grounding weights

Suggested:

```text
required concept = 3
module = 3
outcome = 2
required prerequisite = 2
optional concept = 1
recommended prerequisite = 1
```

Tune later.

---

# Confidence aggregation

Combine:

```text
AI confidence
evidence strength
coverage
validation warnings
critic findings
```

Do not trust LLM confidence alone.

---

# Blueprint confidence result

Possible:

```text
HIGH
MEDIUM
LOW
```

Low confidence may still be reviewable if issues are explicit.

---

# Optional critic execution

Only run if:

```text
enable_critic_pass == true
```

and evidence fits token budget.

For large courses:

- sample relevant evidence per entity;
- do not resend entire course unnecessarily.

---

# Critic caching

Cache by:

```text
blueprint hash
evidence hash
prompt version
```

Do not rerun unchanged critique.

---

# Hallucination validation examples

## Example 1 — unsupported concept

Source:

```text
basic relational SQL
```

Blueprint adds:

```text
Raft consensus
```

Result:

```text
BLUEPRINT_UNSUPPORTED_CONCEPT
ERROR
```

## Example 2 — reasonable inference

Source:

```text
primary keys, foreign keys, table relationships
```

Blueprint concept:

```text
Relational integrity
```

May be:

```text
STRONG_INFERENCE
```

and valid if evidence supports it.

---

# Coverage examples

If 100 chunks exist:

```text
100 analyzed
→ source coverage 1.0
```

If 5 were skipped due to errors:

```text
0.95
```

This should normally block final review readiness until explained/resolved.

---

# Duplicate concept examples

```text
Normalization
Database Normalization
```

May be near duplicate.

```text
Normalization
Third Normal Form
```

Not duplicate.

Do not over-merge through simple string matching.

---

# Module order conflict example

```text
Module 1: Advanced Transactions
Module 4: Basic Transaction Concepts
```

If Module 4 skills are prerequisites for Module 1:

```text
BLUEPRINT_MODULE_ORDER_CONFLICT
```

---

# Prerequisite cycle example

```text
A → B
B → C
C → A
```

Result:

```text
CRITICAL
INVALID
```

No course review/publish progression.

---

# Graph consistency example

Blueprint concepts:

```text
20 explicit concepts
```

Graph:

```text
19 Skill nodes
```

Result:

```text
BLUEPRINT_GRAPH_MAPPING_MISSING
```

unless one explicit exclusion is documented.

---

# Lecturer-facing validation summary

Expose:

```text
status
confidence
coverage
warnings
blocking issues
recommended action
```

Do not expose internal stack traces.

Example:

```json
{
  "status": "VALID_WITH_WARNINGS",
  "eligible_for_review": true,
  "source_coverage": 1.0,
  "grounding_ratio": 0.94,
  "warnings": [
    "Two prerequisite relationships need lecturer confirmation."
  ]
}
```

---

# Frontend review readiness states

Suggested:

```text
Checking generated course…
Course structure ready for review
Course structure needs attention
Course generation failed validation
```

---

# Security

Validation operates only on:

```text
trusted application metadata
validated source evidence
AI draft artifacts
```

Do not allow user-supplied arbitrary chunk IDs during validation.

---

# Authorization

Lecturer may:

```text
view validation report
```

only for authorized course.

Manual revalidation requires:

```text
owner/editor permission
draft version
```

Internal jobs may revalidate automatically.

---

# Observability

Emit:

```text
blueprint_validation.started
blueprint_validation.schema_failed
blueprint_validation.evidence_failed
blueprint_validation.grounding_completed
blueprint_validation.coverage_completed
blueprint_validation.prerequisite_failed
blueprint_validation.graph_failed
blueprint_validation.completed
blueprint_validation.invalid
blueprint_validation.reused
```

Fields:

```text
blueprint_id
validation_report_id
track_id
track_version_id
status
coverage ratios
issue counts
duration_ms
error_code
```

Do not log full source text.

---

# Metrics

Track:

```text
blueprint_validation_total
blueprint_validation_valid_total
blueprint_validation_warning_total
blueprint_validation_invalid_total

blueprint_validation_duration_ms

blueprint_validation_grounding_ratio
blueprint_validation_source_coverage_ratio
blueprint_validation_concept_coverage_ratio
blueprint_validation_module_coverage_ratio

blueprint_validation_unsupported_concepts_total
blueprint_validation_cycles_total
blueprint_validation_dangling_refs_total
```

---

# Testing strategy

## Schema tests

Test:

```text
empty module title
duplicate local key
negative hours
invalid order indexes
```

---

# Reference tests

Test dangling:

```text
concept
outcome
prerequisite
```

---

# Evidence tests

Test:

```text
unknown chunk ID
wrong track/version chunk
invalid page range
quote mismatch
```

---

# Grounding tests

Test:

```text
directly supported concept
strong inference
weak inference
unsupported hallucination
```

---

# Coverage tests

Test:

```text
all chunks analyzed
missing chunks
candidate lost in merge
concept omitted from modules
```

---

# Duplicate tests

Test:

```text
exact duplicate concept
near duplicate concept
duplicate module
duplicate outcome
duplicate prerequisite edge
```

---

# Outcome tests

Test:

```text
grounded measurable outcome
vague outcome
unsupported outcome
```

---

# Module tests

Test:

```text
empty module
overly broad module
orphan required concept
order conflict
```

---

# Prerequisite tests

Test:

```text
self edge
duplicate edge
cycle
weak confidence
cross-version edge
```

---

# Graph consistency tests

Verify:

```text
one explicit concept → one skill
one module → one curriculum module
no orphan skills
provenance exists
```

---

# Critic reconciliation tests

Simulate:

```text
critic flags unsupported concept
deterministic evidence strong
```

Expected:

```text
warning/review
```

Simulate:

```text
critic unsupported
deterministic evidence weak
```

Expected:

```text
blocking error
```

---

# Idempotency tests

Same blueprint/hash:

```text
existing validation reused
```

---

# Revalidation tests

Change blueprint.

Expected:

```text
new report
old report preserved
```

---

# Failure injection

Simulate:

```text
chunk repository failure
graph query failure
critic timeout
report persistence failure
```

Verify:

```text
no false VALID state
```

---

# Example Jac test outlines

```jac
test "unknown chunk evidence invalidates blueprint" {
    # Add evidence reference to nonexistent chunk.
    # Assert INVALID.
}

test "unsupported required concept blocks review" {
    # Add concept with no source support.
    # Assert BLUEPRINT_UNSUPPORTED_CONCEPT.
    # Assert eligible_for_review == false.
}

test "required prerequisite cycle is critical" {
    # A→B→C→A
    # Assert CRITICAL.
    # Assert INVALID.
}

test "complete grounded blueprint becomes review ready" {
    # Valid evidence, coverage, graph.
    # Assert VALID or VALID_WITH_WARNINGS.
    # Assert eligible_for_review.
}

test "validation is idempotent for unchanged blueprint" {
    # Validate twice.
    # Assert report reused.
}
```

---

# Implementation sequence

## Step 1 — Add validation enums and nodes

Implement:

```text
BlueprintValidationStatus
BlueprintValidationSeverity
BlueprintValidationCategory
BlueprintValidationReport
BlueprintValidationIssue
```

## Step 2 — Add validation repository

Support report history and issue persistence.

## Step 3 — Add schema/reference validator

Validate typed structure and local keys.

## Step 4 — Add evidence validator

Resolve chunk provenance.

## Step 5 — Add grounding validator

Use deterministic signals first.

## Step 6 — Add coverage validator

Measure chunk/candidate/concept/module coverage.

## Step 7 — Add duplicate validator

Detect unresolved duplicates.

## Step 8 — Add outcome/module validators

Check quality and completeness.

## Step 9 — Add prerequisite validator

Detect self-edges, duplicates, cycles, confidence issues.

## Step 10 — Add graph consistency validator

Compare blueprint to draft curriculum graph.

## Step 11 — Integrate optional critic

Use bounded byLLM critique.

## Step 12 — Add decision engine

Determine:

```text
VALID
VALID_WITH_WARNINGS
INVALID
```

## Step 13 — Integrate job state

Complete `BLUEPRINT_VALIDATION`.

## Step 14 — Integrate course readiness

Move valid drafts to `REVIEW_REQUIRED`.

## Step 15 — Add tests

Grounding, coverage, cycles, hallucination, graph consistency.

---

# Acceptance criteria

## Structure

- [ ] Blueprint schema is validated.
- [ ] Local references resolve.
- [ ] Duplicate local keys are rejected.
- [ ] Invalid ordering is detected.

## Evidence

- [ ] Every evidence chunk exists.
- [ ] Evidence belongs to correct course/version.
- [ ] Invalid page ranges are detected.
- [ ] Quote hints are treated as hints, not authority.

## Grounding

- [ ] Unsupported required concepts block review.
- [ ] Weak inference is surfaced.
- [ ] Unsupported outcomes are detected.
- [ ] Unsupported prerequisites are detected.
- [ ] External enrichment is not accepted as source-grounded.

## Coverage

- [ ] Source chunk coverage measured.
- [ ] Candidate concept coverage measured.
- [ ] Module coverage measured.
- [ ] Missing major content cannot disappear silently.

## Curriculum integrity

- [ ] Required concepts map to modules.
- [ ] Duplicate concepts/modules/outcomes are detected.
- [ ] Empty modules are detected.
- [ ] Module-order conflicts are surfaced.

## Prerequisites

- [ ] Self-edges rejected.
- [ ] Duplicate edges rejected/merged safely.
- [ ] Required graph is acyclic.
- [ ] Low-confidence edges are surfaced.
- [ ] Cross-version edges are invalid.

## Graph consistency

- [ ] Blueprint concepts map correctly to Skill nodes.
- [ ] Modules map correctly.
- [ ] No orphan draft skills.
- [ ] Provenance exists.
- [ ] Graph generation matches blueprint version.

## Decision

- [ ] `VALID` only when no blocking issue exists.
- [ ] `VALID_WITH_WARNINGS` supports lecturer review.
- [ ] `INVALID` blocks review/publication.
- [ ] Repair/regeneration/source-replacement guidance is produced.

## Reliability

- [ ] Validation is idempotent.
- [ ] Revalidation preserves history.
- [ ] Critic failure cannot create false VALID.
- [ ] Repository failure cannot create false VALID.

## Quality

- [ ] `jac check` passes.
- [ ] `jac check --lint` passes.
- [ ] `jac test` passes.
- [ ] Hallucination tests pass.
- [ ] Coverage tests pass.
- [ ] Cycle tests pass.
- [ ] Graph consistency tests pass.
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
1. Generate a valid blueprint.
2. Generate the draft curriculum graph.
3. Run blueprint validation.
4. Confirm all local references resolve.
5. Confirm evidence references point to valid chunks.
6. Confirm source coverage is calculated.
7. Confirm concept/module coverage is calculated.
8. Confirm grounding ratio is calculated.
9. Confirm prerequisite cycle detection runs.
10. Confirm graph mappings match blueprint entities.

11. Add an unsupported concept manually.
12. Revalidate.
13. Confirm blueprint becomes INVALID.

14. Remove the unsupported concept.
15. Add an uncertain prerequisite.
16. Revalidate.
17. Confirm warning/review behavior.

18. Add a required prerequisite cycle.
19. Confirm CRITICAL issue and review blocked.

20. Restore valid graph.
21. Confirm VALID or VALID_WITH_WARNINGS.
22. Confirm course/version moves to REVIEW_REQUIRED.

23. Revalidate unchanged blueprint.
24. Confirm existing report is reused.

25. Edit blueprint and revalidate.
26. Confirm new report is created and history preserved.
```

---

# Expected result

After this specification is implemented:

- GraphLearn has a hard quality gate between AI interpretation and lecturer review;
- typed byLLM output is not accepted blindly;
- every blueprint entity is checked against source evidence;
- hallucinated or unsupported curriculum is detected;
- missing source coverage is measurable;
- duplicate concepts and invalid module structures are surfaced;
- prerequisite cycles and graph inconsistencies block progression;
- valid drafts receive a structured validation report;
- only grounded, internally consistent course structures move to lecturer review;
- validation history remains auditable and reproducible.
