# 49-lecturer-blueprint-review.md

## Overview

Implement the lecturer-facing review and approval workflow for AI-generated course blueprints.

This specification begins after:

```text
46-course-blueprint-generation.md
47-topic-and-skill-graph-generation.md
48-blueprint-validation-and-grounding.md
```

and before:

```text
50-course-publication-and-versioning.md
```

Its responsibility is to give the lecturer a controlled workspace where they can:

- inspect the generated course structure;
- inspect source-grounding evidence;
- review modules, concepts, outcomes, and prerequisites;
- resolve warnings;
- edit draft curriculum safely;
- request targeted regeneration where appropriate;
- re-run validation after changes;
- approve the blueprint for publication.

The core rule is:

```text
AI proposes.
Validation checks.
Lecturer reviews.
Only lecturer-approved curriculum may advance to publication.
```

The review layer must never:

- bypass validation;
- directly mutate published versions;
- silently overwrite lecturer edits with regenerated AI output.

---

## Status

- **Feature type:** Lecturer review / human-in-the-loop governance
- **Priority:** Critical
- **Depends on:** `46-course-blueprint-generation.md`
- **Depends on:** `47-topic-and-skill-graph-generation.md`
- **Depends on:** `48-blueprint-validation-and-grounding.md`
- **Blocks:** `50-course-publication-and-versioning.md`
- **Breaking changes allowed:** No
- **Primary implementation:** review service + private walkers + lecturer UI + change history

---

# Goals

Implement a review workflow that:

1. Shows the current generated blueprint clearly.
2. Shows validation status and warnings.
3. Lets lecturers inspect source evidence for each generated entity.
4. Lets lecturers edit modules.
5. Lets lecturers edit concepts/skills.
6. Lets lecturers edit learning outcomes.
7. Lets lecturers edit prerequisite relationships.
8. Supports adding/removing draft items where authorized.
9. Tracks all lecturer changes.
10. Distinguishes lecturer edits from AI-generated content.
11. Prevents silent AI overwrite of manual edits.
12. Supports targeted regeneration.
13. Re-runs deterministic validation after edits.
14. Regenerates draft curriculum graph deterministically after approved blueprint edits.
15. Requires all blocking validation issues to be resolved before approval.
16. Records explicit lecturer approval.
17. Prevents approval of stale/outdated blueprint generations.
18. Preserves review history.
19. Supports concurrent-edit protection.
20. Provides a clean handoff to publication/versioning.

---

# Non-goals

This specification does not:

- publish the course;
- open enrollment;
- generate learner roadmaps;
- create final lessons;
- create quizzes;
- modify published course versions;
- create external enrichment;
- bypass security/grounding validation;
- permit arbitrary graph mutation from frontend.

---

# Review architecture

```text
Validated CourseBlueprint
        │
        ▼
LecturerBlueprintReviewService
        │
        ├── load blueprint projection
        ├── load validation report
        ├── load evidence/provenance
        ├── apply lecturer edits
        ├── record change history
        ├── regenerate graph draft
        ├── rerun validation
        ├── resolve warnings
        └── approve for publication
                │
                ▼
APPROVED blueprint/version
                │
                ▼
50-course-publication-and-versioning.md
```

---

# Review eligibility

A blueprint may enter lecturer review only when:

```text
BlueprintValidationStatus == VALID
or
BlueprintValidationStatus == VALID_WITH_WARNINGS
```

and:

```text
eligible_for_review == true
```

Invalid blueprints must not enter normal approval flow.

---

# Review status enum

```jac
enum BlueprintReviewStatus {
    NOT_READY,
    READY_FOR_REVIEW,
    IN_REVIEW,
    CHANGES_REQUIRED,
    APPROVED,
    SUPERSEDED
}
```

---

# Approval status enum

```jac
enum BlueprintApprovalStatus {
    NOT_APPROVED,
    APPROVED,
    REVOKED
}
```

---

# Review session node

Create:

```jac
node BlueprintReviewSession {
    has review_session_id: str;

    has blueprint_id: str;

    has track_id: str;
    has track_version_id: str;

    has lecturer_id: str;

    has status: BlueprintReviewStatus;

    has blueprint_revision: int;

    has started_at: str;
    has updated_at: str;

    has approved_at: str | None = None;
    has approved_by: str | None = None;

    has last_validation_report_id: str | None = None;

    has review_notes: str | None = None;
}
```

---

# Blueprint revision

Every lecturer edit increments:

```text
blueprint_revision
```

This supports:

- optimistic concurrency;
- stale approval prevention;
- audit history.

---

# Review identity

A review session is tied to:

```text
blueprint_id
track_version_id
generation identity
```

If a new blueprint generation supersedes the current one:

```text
old review session → SUPERSEDED
```

---

# Review projection

Create a frontend-friendly read model:

```jac
obj LecturerBlueprintReviewView {
    has blueprint_id: str;

    has review_status: BlueprintReviewStatus;
    has blueprint_revision: int;

    has course_title: str;
    has course_summary: str;

    has modules: list[ReviewModuleView];
    has concepts: list[ReviewConceptView];
    has outcomes: list[ReviewOutcomeView];
    has prerequisites: list[ReviewPrerequisiteView];

    has validation_summary: ReviewValidationSummary;

    has approval_available: bool;

    has warnings: list[str];
}
```

---

# Module review view

```jac
obj ReviewModuleView {
    has module_id: str;
    has local_module_key: str;

    has title: str;
    has description: str;

    has order_index: int;

    has concept_keys: list[str];
    has outcome_keys: list[str];

    has evidence: list[BlueprintEvidenceRef];

    has confidence: str;

    has validation_issues: list[str];

    has edited_by_lecturer: bool;
}
```

---

# Concept review view

```jac
obj ReviewConceptView {
    has concept_id: str;
    has local_concept_key: str;

    has canonical_name: str;
    has description: str;

    has aliases: list[str];
    has key_terms: list[str];

    has learning_objectives: list[str];

    has evidence: list[BlueprintEvidenceRef];

    has confidence: str;

    has validation_issues: list[str];

    has edited_by_lecturer: bool;
}
```

---

# Outcome review view

```jac
obj ReviewOutcomeView {
    has outcome_id: str;
    has local_outcome_key: str;

    has statement: str;
    has level: str;

    has evidence: list[BlueprintEvidenceRef];

    has validation_issues: list[str];

    has edited_by_lecturer: bool;
}
```

---

# Prerequisite review view

```jac
obj ReviewPrerequisiteView {
    has prerequisite_id: str;

    has prerequisite_concept_key: str;
    has dependent_concept_key: str;

    has strength: str;

    has rationale: str;

    has confidence: str;

    has evidence: list[BlueprintEvidenceRef];

    has validation_issues: list[str];

    has edited_by_lecturer: bool;
}
```

---

# Validation summary

```jac
obj ReviewValidationSummary {
    has status: str;

    has source_coverage_ratio: float;
    has concept_coverage_ratio: float;
    has module_coverage_ratio: float;
    has grounding_ratio: float;

    has warning_count: int;
    has blocking_issue_count: int;

    has blocking_issue_codes: list[str];
}
```

---

# Evidence review

Lecturers must be able to inspect why the AI created an item.

For each:

```text
concept
module
outcome
prerequisite
```

show:

```text
source chunk
page range when available
heading context
short source excerpt
```

---

# Evidence retrieval

Create safe service:

```text
BlueprintEvidenceReviewService
```

It resolves:

```text
evidence ref
→ chunk
→ source locator
→ bounded excerpt
```

Do not expose raw storage paths.

---

# Evidence excerpt policy

Return:

```text
bounded nearby source text
```

not entire source document.

Suggested:

```text
500–1500 characters
```

configurable.

---

# Lecturer edits

Support controlled edits to:

```text
course summary
module title
module description
module order
module concept assignments
module outcome assignments

concept name
concept description
aliases
learning objectives

learning outcome statement
learning objective level

prerequisite source
prerequisite target
strength
rationale
```

---

# Protected fields

Lecturer must not directly edit:

```text
track_id
track_version_id
document_id
chunk_set_id
blueprint_id
source checksum
AI execution IDs
validation report IDs
graph generation IDs
```

---

# Edit provenance

Every change must record:

```text
who
when
what entity
field
old value
new value
revision
reason optional
```

---

# Change event node

```jac
node BlueprintReviewChange {
    has change_id: str;

    has review_session_id: str;

    has blueprint_id: str;

    has actor_id: str;

    has entity_type: str;
    has entity_key: str;

    has field_name: str;

    has old_value_json: str;
    has new_value_json: str;

    has change_type: str;

    has created_at: str;
}
```

---

# Change types

```jac
enum BlueprintReviewChangeType {
    UPDATE_FIELD,
    ADD_ENTITY,
    REMOVE_ENTITY,
    REORDER_ENTITY,
    ADD_RELATIONSHIP,
    REMOVE_RELATIONSHIP,
    REGENERATE_SECTION,
    RESTORE_AI_VERSION
}
```

---

# Manual edit marker

Every editable blueprint child entity should track:

```text
edited_by_lecturer
last_edited_at
last_edited_by
```

---

# AI overwrite protection

If:

```text
edited_by_lecturer == true
```

then AI regeneration must not silently overwrite it.

Regeneration requires explicit strategy:

```text
KEEP_MANUAL
REGENERATE
COMPARE
```

---

# Regeneration strategy enum

```jac
enum BlueprintRegenerationStrategy {
    KEEP_MANUAL,
    REGENERATE_SELECTED,
    REGENERATE_ALL_UNEDITED,
    REGENERATE_FULL_BLUEPRINT
}
```

---

# Targeted regeneration

Possible targets:

```text
single module
single concept
learning outcomes
prerequisites
full blueprint
```

But targeted regeneration must still:

```text
use source evidence
return typed output
rerun validation
```

---

# Targeted regeneration constraints

Do not permit:

```text
regenerate this module using internet knowledge
```

unless future enrichment mode exists.

Current policy:

```text
SOURCE_GROUNDED_ONLY
```

---

# Regeneration conflict handling

If targeted regeneration affects manually edited dependent entities:

```text
surface conflict
```

Example:

```text
regenerating a concept
may invalidate:
module assignments
outcomes
prerequisites
```

Do not auto-apply without deterministic impact analysis.

---

# Edit service

Create:

```text
LecturerBlueprintEditService
```

Responsibilities:

```text
authorize
load current revision
validate edit request
apply allowed change
record change event
increment revision
regenerate draft graph
rerun validation
return updated review view
```

---

# Edit request

```jac
obj BlueprintEditRequest {
    has blueprint_id: str;

    has expected_revision: int;

    has entity_type: str;
    has entity_key: str;

    has operation: str;

    has payload_json: str;

    has reason: str | None = None;
}
```

---

# Optimistic concurrency

Require:

```text
expected_revision
```

If current revision differs:

```text
BLUEPRINT_REVIEW_REVISION_CONFLICT
```

Frontend must refresh.

---

# Concurrent edit behavior

Do not silently apply stale edits.

Response should include:

```text
current_revision
stale_revision
```

and safe message.

---

# Add concept

Lecturer may add a concept manually.

Required:

```text
name
description
module assignment
learning objective optional
```

Grounding policy:

```text
manual lecturer-added concept
```

may be allowed even without source evidence, but must be explicitly labeled:

```text
LECTURER_ADDED
```

---

# Lecturer-added content

This is important.

Lecturer may intentionally add material not present in uploaded notes.

Do not classify that as AI hallucination.

Use provenance:

```jac
enum BlueprintEntityProvenance {
    AI_SOURCE_GROUNDED,
    LECTURER_EDITED,
    LECTURER_ADDED
}
```

---

# Lecturer-added content validation

Require:

```text
manual provenance
author
timestamp
```

No fake source evidence required.

It should still pass:

```text
schema
graph
prerequisite
module consistency
```

---

# Remove concept

Before removal, analyze dependencies:

```text
module assignments
outcomes
prerequisites
```

If referenced:

```text
require explicit cascade decision
```

Do not leave dangling references.

---

# Remove module

Before removal:

```text
reassign contained concepts
or
explicitly remove them
```

No orphan skills.

---

# Reorder modules

Update:

```text
order_index
```

then rerun:

```text
module-order/prerequisite conflict validation
```

---

# Edit prerequisites

Lecturer can:

```text
add
remove
change strength
edit rationale
```

After every prerequisite change:

```text
run cycle detection
```

---

# Manual prerequisite override

A lecturer may approve a medium-confidence prerequisite.

Record:

```text
LECTURER_CONFIRMED
```

---

# Validation rerun after edits

Every meaningful blueprint edit invalidates prior validation.

Flow:

```text
edit
→ blueprint revision++
→ graph regeneration/patch
→ validation report stale
→ rerun validation
→ update review eligibility
```

---

# Graph regeneration after edits

Recommended:

```text
edited blueprint remains source of truth
→ deterministic regeneration of draft curriculum graph
```

Do not directly mutate graph from frontend operations.

---

# Graph regeneration scope

For simplicity first release:

```text
full draft graph regeneration
```

after blueprint edits.

Later optimize to partial graph patching.

---

# Preserve published graph

Review operates only on:

```text
draft track version
```

Never mutate published graph.

---

# Review notes

Lecturer may add review notes:

```text
internal rationale
approval notes
known limitations
```

These are not learner-visible by default.

---

# Warning resolution

Each validation warning can have:

```text
OPEN
ACKNOWLEDGED
RESOLVED
WAIVED
```

---

# Warning resolution enum

```jac
enum ReviewIssueResolutionStatus {
    OPEN,
    ACKNOWLEDGED,
    RESOLVED,
    WAIVED
}
```

---

# Waiver policy

Only non-blocking warnings may be waived.

Blocking errors/critical issues cannot be waived.

---

# Issue resolution node

```jac
node BlueprintIssueResolution {
    has resolution_id: str;

    has validation_issue_id: str;
    has review_session_id: str;

    has status: ReviewIssueResolutionStatus;

    has resolved_by: str;
    has resolution_note: str | None;

    has created_at: str;
}
```

---

# Approval eligibility

Approval requires:

```text
latest blueprint revision validated
latest validation status VALID or VALID_WITH_WARNINGS
no blocking issues
graph integrity valid
review session not superseded
track version still draft/editable
lecturer authorized
```

---

# Approval request

```jac
obj BlueprintApprovalRequest {
    has blueprint_id: str;
    has expected_revision: int;

    has approval_note: str | None = None;
}
```

---

# Approval service

Create:

```text
LecturerBlueprintApprovalService
```

Responsibilities:

```text
authorize
verify current revision
verify latest validation report
verify graph generation
verify no blocking issues
record approval
lock approved revision
handoff to publication readiness
```

---

# Approval event

```jac
node BlueprintApproval {
    has approval_id: str;

    has blueprint_id: str;
    has track_version_id: str;

    has approved_revision: int;

    has approved_by: str;
    has approved_at: str;

    has validation_report_id: str;

    has graph_generation_id: str;

    has approval_note: str | None = None;
}
```

---

# Approval immutability

Approval references exact:

```text
blueprint revision
validation report
graph generation
```

If any of these change:

```text
approval becomes stale/revoked
```

---

# Post-approval edits

If lecturer edits after approval:

```text
approval revoked automatically
status → IN_REVIEW
```

Must revalidate/reapprove.

---

# Approval status transition

```text
READY_FOR_REVIEW
→ IN_REVIEW
→ APPROVED
```

or:

```text
IN_REVIEW
→ CHANGES_REQUIRED
→ IN_REVIEW
→ APPROVED
```

---

# Publication handoff

Approval does not publish.

It sets:

```text
track version approval_status = APPROVED
```

or equivalent.

Then `50-course-publication-and-versioning.md` handles:

```text
publication readiness
immutable version snapshot
catalog visibility
enrollment opening
```

---

# Review walkers

Suggested private walkers:

```text
get_lecturer_blueprint_review
update_blueprint_entity
add_blueprint_entity
remove_blueprint_entity
reorder_blueprint_modules
update_blueprint_prerequisite
resolve_blueprint_warning
regenerate_blueprint_section
approve_course_blueprint
get_blueprint_review_history
```

---

# `get_lecturer_blueprint_review`

Input:

```text
track_id
track_version_id
```

Returns:

```text
LecturerBlueprintReviewView
```

---

# `update_blueprint_entity`

Input:

```text
blueprint_id
expected_revision
entity_type
entity_key
patch
```

Must use field allowlist.

---

# Edit allowlists

## Course

```text
course_summary
estimated_duration_weeks
```

## Module

```text
title
description
order_index
importance
estimated_learning_hours
```

## Concept

```text
canonical_name
description
aliases
learning_objectives
key_terms
should_be_taught_explicitly
```

## Outcome

```text
statement
level
```

## Prerequisite

```text
strength
rationale
```

Relationships require dedicated operations.

---

# Frontend review page

Recommended route:

```text
/lecturer/courses/:trackId/blueprint
```

---

# Page structure

```text
Header
├── course title
├── review status
├── validation badge
├── revision
└── approve button

Validation summary
├── grounding
├── coverage
├── warnings
└── blocking issues

Module navigator
├── module cards
└── reorder controls

Main editor
├── module details
├── concepts
├── outcomes
├── prerequisites
└── evidence panel

Right panel
├── source evidence
├── validation issue details
└── change history
```

---

# Module cards

Show:

```text
module number
title
concept count
outcome count
warning count
confidence
```

---

# Concept editor

Allow:

```text
rename
description edit
aliases
learning objectives
module reassignment
remove
add concept
```

---

# Evidence panel

For selected item show:

```text
source heading
page range
short excerpt
evidence strength
```

---

# Validation issue display

Use:

```text
Critical
Error
Warning
Info
```

with actionable remediation.

Examples:

```text
This prerequisite creates a cycle.
This concept has weak source grounding.
This module has no learning outcome.
```

---

# Save model

Prefer explicit or autosave with revision protection.

If autosave:

```text
debounced
revision-aware
visible saved state
```

Do not silently discard failed saves.

---

# Unsaved changes

Frontend should track:

```text
saving
saved
conflict
failed
```

---

# Reorder UX

Use:

```text
drag-and-drop
or
move up/down
```

Backend remains authoritative.

After reorder:

```text
validation reruns
```

---

# Regeneration UX

For each section:

```text
Regenerate
```

must explain impact.

Examples:

```text
Regenerate module
Regenerate prerequisites
Regenerate full blueprint
```

---

# Compare before apply

Preferred:

```text
current version
vs
regenerated suggestion
```

Lecturer chooses:

```text
Keep current
Use regenerated
Merge manually
```

Do not auto-replace manual edits.

---

# Change history

Lecturer can inspect:

```text
revision
timestamp
actor
change summary
```

---

# Restore prior revision

Optional first-release feature.

If implemented:

```text
restore creates new revision
```

Do not rewrite history.

---

# Authorization

All review/edit/approve operations require:

```text
authenticated actor
active lecturer role
track ownership/edit permission
draft track version
```

Approval may require stronger:

```text
PUBLISH/APPROVE permission
```

from `36`.

---

# Admin behavior

Admins must have explicit permission.

Do not use:

```text
if admin allow everything
```

---

# Security

Never trust:

```text
blueprint entity IDs from frontend
```

without verifying:

```text
belongs to blueprint
belongs to track/version
actor authorized
```

---

# Error codes

Define:

```text
BLUEPRINT_REVIEW_NOT_READY
BLUEPRINT_REVIEW_NOT_AUTHORIZED
BLUEPRINT_REVIEW_SUPERSEDED
BLUEPRINT_REVIEW_REVISION_CONFLICT
BLUEPRINT_REVIEW_ENTITY_NOT_FOUND
BLUEPRINT_REVIEW_FIELD_NOT_EDITABLE
BLUEPRINT_REVIEW_INVALID_PATCH
BLUEPRINT_REVIEW_DANGLING_REFERENCE
BLUEPRINT_REVIEW_ORPHAN_CONCEPT
BLUEPRINT_REVIEW_PREREQUISITE_CYCLE
BLUEPRINT_REVIEW_REGENERATION_CONFLICT
BLUEPRINT_REVIEW_VALIDATION_FAILED
BLUEPRINT_REVIEW_APPROVAL_BLOCKED
BLUEPRINT_REVIEW_APPROVAL_STALE
BLUEPRINT_REVIEW_INTERNAL_ERROR
```

---

# Approval blocked reasons

Examples:

```text
blocking validation issue
stale revision
stale validation report
stale graph generation
unresolved cycle
orphan concept
superseded blueprint
published/non-editable version
```

---

# Idempotency

Repeated identical edit request with same idempotency key should not duplicate change events.

Approval request repeated for same:

```text
blueprint revision
validation report
graph generation
```

should return existing approval.

---

# Audit logging

Emit:

```text
blueprint_review.started
blueprint_review.entity_updated
blueprint_review.entity_added
blueprint_review.entity_removed
blueprint_review.modules_reordered
blueprint_review.prerequisite_changed
blueprint_review.warning_resolved
blueprint_review.regeneration_requested
blueprint_review.regeneration_applied
blueprint_review.validation_rerun
blueprint_review.approved
blueprint_review.approval_revoked
```

Fields:

```text
blueprint_id
track_id
track_version_id
review_session_id
actor_id
revision
entity_type
entity_key
change_type
request_id
```

Do not log full source text unnecessarily.

---

# Metrics

Track:

```text
blueprint_review_sessions_total
blueprint_review_edits_total
blueprint_review_regenerations_total
blueprint_review_validation_reruns_total
blueprint_review_approvals_total
blueprint_review_approval_blocked_total
blueprint_review_revision_conflicts_total
```

---

# Testing strategy

## Eligibility tests

Verify:

```text
INVALID blueprint cannot enter approval flow
VALID blueprint can
VALID_WITH_WARNINGS can when eligible
```

---

# Authorization tests

Verify:

```text
owner lecturer allowed
other lecturer denied
learner denied
suspended lecturer denied
authorized admin explicit permission allowed
```

---

# Edit tests

Test editing:

```text
module
concept
outcome
prerequisite
```

Verify revision increments.

---

# Protected field tests

Attempt editing:

```text
track_id
blueprint_id
document_id
```

Reject.

---

# Concurrency tests

Two edits with same old revision:

```text
first succeeds
second gets REVISION_CONFLICT
```

---

# Add/remove concept tests

Verify:

```text
add concept
manual provenance recorded
remove referenced concept requires dependency handling
```

---

# Reorder tests

Reorder modules.

Verify:

```text
order indexes valid
validation reruns
prerequisite conflicts surfaced
```

---

# Prerequisite edit tests

Add:

```text
A → B
```

then:

```text
B → A
```

Expected:

```text
cycle blocked
```

---

# Regeneration tests

Manual edit concept.

Request regeneration.

Verify:

```text
manual change not silently overwritten
```

---

# Validation rerun tests

Edit blueprint.

Verify:

```text
old validation stale
new validation report created
```

---

# Approval tests

Approve when:

```text
latest revision valid
latest graph valid
no blocking issues
```

Success.

---

# Stale approval tests

Edit after validation but before approval.

Expected:

```text
approval blocked
```

---

# Post-approval edit tests

Edit approved blueprint.

Expected:

```text
approval revoked
status IN_REVIEW
```

---

# Superseded blueprint tests

Generate new blueprint.

Old review session:

```text
SUPERSEDED
```

Cannot approve.

---

# Evidence review tests

Verify lecturer can retrieve evidence only for own course.

---

# Failure injection

Simulate:

```text
change persistence failure
graph regeneration failure
validation failure
approval persistence failure
```

Verify no false approval.

---

# Example Jac test outlines

```jac
test "lecturer edit increments blueprint revision" {
    # Edit module title.
    # Assert revision +1.
    # Assert change history.
}

test "stale revision edit is rejected" {
    # Submit old expected_revision.
    # Assert BLUEPRINT_REVIEW_REVISION_CONFLICT.
}

test "manual edit is not overwritten by regeneration" {
    # Edit concept manually.
    # Regenerate unedited sections.
    # Assert manual concept preserved.
}

test "approval requires latest valid revision" {
    # Validate revision 2.
    # Edit to revision 3.
    # Attempt approval.
    # Assert blocked.
}

test "post approval edit revokes approval" {
    # Approve.
    # Edit.
    # Assert approval no longer active.
}
```

---

# Implementation sequence

## Step 1 — Add review enums and session

Implement:

```text
BlueprintReviewStatus
BlueprintApprovalStatus
BlueprintReviewSession
```

## Step 2 — Add review projections

Build lecturer-friendly DTOs.

## Step 3 — Add evidence review service

Resolve bounded source excerpts.

## Step 4 — Add change history

Implement:

```text
BlueprintReviewChange
```

## Step 5 — Add edit service

Support allowlisted field changes.

## Step 6 — Add entity add/remove operations

With dependency validation.

## Step 7 — Add reorder operation

Update module ordering safely.

## Step 8 — Add prerequisite editing

With cycle detection.

## Step 9 — Add regeneration workflow

Protect lecturer edits.

## Step 10 — Regenerate draft graph after edits

Blueprint remains source of truth.

## Step 11 — Rerun validation

Every material edit invalidates previous validation.

## Step 12 — Add warning resolution

Track acknowledgment/resolution/waiver.

## Step 13 — Add approval service

Bind approval to exact revision/report/graph.

## Step 14 — Add frontend review page

Modules, concepts, outcomes, prerequisites, evidence, warnings.

## Step 15 — Add history UI

Show revision/change trail.

## Step 16 — Add tests

Authorization, concurrency, edit, regeneration, approval.

---

# Acceptance criteria

## Review access

- [ ] Only eligible validated blueprints enter review.
- [ ] Lecturer sees modules, concepts, outcomes, prerequisites.
- [ ] Validation summary is visible.
- [ ] Source evidence is inspectable.

## Editing

- [ ] Lecturer can edit allowed fields.
- [ ] Protected fields cannot be edited.
- [ ] Blueprint revision increments.
- [ ] Every change is audited.
- [ ] Manual edits are marked.

## Manual additions

- [ ] Lecturer can add course concepts where allowed.
- [ ] Lecturer-added content has explicit provenance.
- [ ] Manual additions do not require fake source evidence.
- [ ] Graph/structural validation still applies.

## Relationships

- [ ] Concepts can be reassigned safely.
- [ ] Modules can be reordered.
- [ ] Prerequisites can be edited.
- [ ] Cycles are blocked.
- [ ] Dangling references are blocked.

## Regeneration

- [ ] Targeted regeneration is supported.
- [ ] Manual edits are not silently overwritten.
- [ ] Regeneration conflicts are surfaced.
- [ ] Regenerated output remains source-grounded.

## Validation

- [ ] Every material edit invalidates prior validation.
- [ ] Validation reruns.
- [ ] Graph regenerates deterministically.
- [ ] Approval uses latest valid report.

## Approval

- [ ] Blocking issues prevent approval.
- [ ] Approval binds exact blueprint revision.
- [ ] Approval binds exact validation report.
- [ ] Approval binds exact graph generation.
- [ ] Post-approval edits revoke approval.
- [ ] Approval does not publish automatically.

## Concurrency

- [ ] Optimistic revision checks exist.
- [ ] Stale edits are rejected.
- [ ] Stale approval attempts are rejected.

## Authorization

- [ ] Owner/editor permission enforced.
- [ ] Other lecturers denied.
- [ ] Learners denied.
- [ ] Admin access requires explicit permission.

## Quality

- [ ] `jac check` passes.
- [ ] `jac check --lint` passes.
- [ ] `jac test` passes.
- [ ] Edit tests pass.
- [ ] Revision conflict tests pass.
- [ ] Regeneration protection tests pass.
- [ ] Approval tests pass.
- [ ] Authorization tests pass.

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
1. Generate and validate a course blueprint.
2. Open lecturer review.
3. Confirm validation summary appears.
4. Select a concept.
5. Inspect source evidence.
6. Edit the concept description.
7. Confirm revision increments.
8. Confirm change history records edit.
9. Confirm graph regenerates.
10. Confirm validation reruns.

11. Reorder modules.
12. Confirm prerequisite/order warnings update.

13. Add a prerequisite that creates a cycle.
14. Confirm change is rejected or approval blocked.

15. Add a lecturer-authored concept.
16. Confirm provenance is LECTURER_ADDED.
17. Confirm it does not falsely claim source evidence.

18. Request targeted regeneration.
19. Confirm manually edited fields are not overwritten silently.

20. Resolve non-blocking warnings.
21. Confirm approval becomes available only when latest revision is valid.

22. Approve blueprint.
23. Confirm approval references exact revision/report/graph.
24. Confirm course is not yet published.

25. Edit blueprint after approval.
26. Confirm approval is revoked and review resumes.
```

---

# Expected result

After this specification is implemented:

- lecturers have a complete human-in-the-loop review workspace;
- every AI-generated course structure can be inspected against source evidence;
- lecturers can safely correct modules, concepts, outcomes, and prerequisites;
- manual changes are fully audited and protected from silent AI overwrite;
- graph and grounding validation rerun after edits;
- stale or invalid revisions cannot be approved;
- approval binds a specific validated blueprint revision and graph generation;
- only lecturer-approved curriculum can proceed to publication/versioning.
