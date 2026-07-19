# 50-course-publication-and-versioning.md

## Overview

Implement the course publication and versioning subsystem that converts a lecturer-approved draft course version into an immutable published version that can be discovered, enrolled in, and consumed by learners.

This specification begins after:

```text
49-lecturer-blueprint-review.md
```

and depends on the version/domain foundations established in:

```text
29-learning-track-domain-model.md
30-programming-track-migration.md
31-track-aware-existing-models.md
32-learning-track-osp-schema.md
33-track-repositories-and-services.md
36-lecturer-authorization-policies.md
```

The subsystem must enforce:

```text
approved draft
→ publication readiness checks
→ immutable published snapshot
→ active-version switch
→ previous version superseded
→ catalog/enrollment state updated
```

The core rule is:

```text
Publishing does not mutate a draft into an editable live course.
Publishing seals a specific validated revision as an immutable course version.
Future changes require a new draft version.
```

---

## Status

- **Feature type:** Course lifecycle / publication / versioning
- **Priority:** Critical
- **Depends on:** `29-learning-track-domain-model.md`
- **Depends on:** `36-lecturer-authorization-policies.md`
- **Depends on:** `47-topic-and-skill-graph-generation.md`
- **Depends on:** `48-blueprint-validation-and-grounding.md`
- **Depends on:** `49-lecturer-blueprint-review.md`
- **Blocks:** `51-published-course-catalogue.md`
- **Blocks:** `52-course-enrollment-flow.md`
- **Blocks:** `53-generalized-diagnostic-assessment.md`
- **Breaking changes allowed:** No
- **Primary implementation:** publication service + immutable version state + repository transactions

---

# Goals

Implement publication/versioning that:

1. Publishes only lecturer-approved course versions.
2. Requires the latest blueprint revision to be approved.
3. Requires the latest validation report to be valid.
4. Requires a valid curriculum graph generation.
5. Seals a published version as immutable.
6. Preserves source-document provenance.
7. Preserves blueprint/version provenance.
8. Preserves graph generation identity.
9. Supports multiple historical course versions.
10. Allows one active published version per learning track.
11. Supersedes older published versions safely.
12. Does not break learners already enrolled in an older version.
13. Allows future edits only through a new draft version.
14. Supports controlled rollback/reactivation policies.
15. Updates catalog visibility.
16. Controls enrollment availability.
17. Produces explicit publication audit events.
18. Prevents duplicate concurrent publication.
19. Supports idempotent publish requests.
20. Maintains compatibility with built-in programming tracks.

---

# Non-goals

This specification does not:

- implement course catalog UI;
- implement enrollment UI;
- migrate existing learner enrollments automatically;
- generate new roadmap content;
- modify published learner mastery;
- allow direct editing of published graph nodes;
- replace approval/validation workflows;
- delete historical versions;
- automatically re-enroll learners into a new version.

---

# Publication architecture

```text
Approved CourseBlueprint
        │
        ▼
CoursePublicationService
        │
        ├── authorization
        ├── approval verification
        ├── validation verification
        ├── graph integrity verification
        ├── source/version consistency
        ├── publication snapshot creation
        ├── immutable sealing
        ├── active-version switch
        ├── previous-version supersede
        └── catalog/enrollment projection update
                │
                ▼
Published TrackVersion
```

---

# Version lifecycle

Recommended lifecycle:

```text
DRAFT
→ PROCESSING
→ REVIEW_REQUIRED
→ APPROVED
→ PUBLISHING
→ PUBLISHED
→ SUPERSEDED
→ ARCHIVED
```

Failure path:

```text
PUBLISHING
→ PUBLICATION_FAILED
```

Adapt exact enum names to the domain model from `29`.

---

# Track version status

Example:

```jac
enum TrackVersionStatus {
    DRAFT,
    PROCESSING,
    REVIEW_REQUIRED,
    APPROVED,
    PUBLISHING,
    PUBLISHED,
    SUPERSEDED,
    PUBLICATION_FAILED,
    ARCHIVED
}
```

If `29` already defines this enum, extend only when necessary.

---

# LearningTrack active version

`LearningTrack` should maintain:

```text
active_version_id
current_version_number
```

Meaning:

```text
active_version_id
→ version presented for new enrollment/consumption
```

Historical versions remain accessible according to enrollment and authorization rules.

---

# One active published version invariant

For one track:

```text
at most one TrackVersion may be active published version
```

Historical versions may still have:

```text
status = SUPERSEDED
```

and remain readable.

---

# Published version immutability

After:

```text
TrackVersion.status == PUBLISHED
```

the following must not be modified in place:

```text
source document
source checksum
blueprint revision
blueprint approval
curriculum modules
skills
learning outcomes
prerequisite edges
graph generation
diagnostic source structure
chunk set
course configuration affecting curriculum semantics
```

Any semantic change requires:

```text
new TrackVersion
```

---

# Allowed post-publication metadata changes

Some track-level metadata may remain editable if policy allows:

```text
display title
short marketing description
catalog thumbnail
visibility
enrollment-open flag
```

But distinguish:

```text
LearningTrack display metadata
```

from:

```text
immutable TrackVersion curriculum snapshot
```

---

# Publication snapshot

Create an explicit publication record.

```jac
node CoursePublication {
    has publication_id: str;

    has track_id: str;
    has track_version_id: str;

    has version_number: int;

    has blueprint_id: str;
    has blueprint_revision: int;

    has approval_id: str;
    has validation_report_id: str;
    has graph_generation_id: str;

    has source_document_id: str;
    has source_checksum_sha256: str;

    has chunk_set_id: str;
    has extraction_id: str;

    has published_by: str;
    has published_at: str;

    has publication_status: str;

    has publication_hash: str;
}
```

---

# Publication hash

Compute a canonical hash over important immutable identities.

Suggested inputs:

```text
track_id
track_version_id
version_number
blueprint_id
blueprint_revision
approval_id
validation_report_id
graph_generation_id
source checksum
graph schema version
```

Purpose:

- audit;
- idempotency;
- drift detection.

---

# Publication readiness service

Create:

```text
CoursePublicationReadinessService
```

Checks all publication prerequisites.

---

# Publication readiness result

```jac
obj PublicationReadinessResult {
    has ready: bool;

    has track_id: str;
    has track_version_id: str;

    has blocking_codes: list[str];
    has warnings: list[str];

    has blueprint_id: str | None;
    has approval_id: str | None;
    has validation_report_id: str | None;
    has graph_generation_id: str | None;

    has expected_version_number: int | None;
}
```

---

# Publication prerequisites

Required:

```text
authenticated actor
authorized publication permission
track exists
track version exists
track version belongs to track
version is draft/approved state
latest blueprint exists
latest blueprint review status APPROVED
approval is current
approval revision == current blueprint revision
latest validation report corresponds to current revision
validation status VALID or allowed VALID_WITH_WARNINGS
no blocking validation issues
draft curriculum graph exists
graph integrity valid
graph generation corresponds to current blueprint
source document still valid/current
source checksum matches
no conflicting active publication operation
```

---

# Approval freshness

Approval must bind exact:

```text
blueprint revision
validation report
graph generation
```

If any changed after approval:

```text
publication blocked
```

Error:

```text
COURSE_PUBLICATION_APPROVAL_STALE
```

---

# Validation freshness

Validation report must correspond to:

```text
current blueprint hash
current graph generation
current validation schema
```

No stale report.

---

# Graph freshness

Graph generation must correspond to:

```text
current approved blueprint
```

If lecturer edited blueprint after graph generation:

```text
publication blocked
```

---

# Source freshness

Verify:

```text
source document ID unchanged
checksum unchanged
document not replaced
document not deleted
```

Published snapshot must reference exact source.

---

# Version number allocation

Version numbers should be monotonic per track.

Example:

```text
v1
v2
v3
```

Use integer:

```text
version_number
```

Do not trust client-provided version number.

Allocate server-side.

---

# Version number race protection

Two concurrent publication attempts must not both allocate:

```text
version 2
```

Use:

```text
transaction
unique constraint
compare-and-set
publication lock
```

---

# First publication

For track with no published version:

```text
draft version number = 1
```

On publish:

```text
status → PUBLISHED
LearningTrack.active_version_id = version_id
LearningTrack.current_version_number = 1
```

---

# Publishing a new version

For existing active v1:

```text
create/edit v2 draft
approve v2
publish v2
```

Transaction:

```text
v2 → PUBLISHED
v1 → SUPERSEDED
track.active_version_id → v2
current_version_number → 2
```

---

# Superseded version semantics

`SUPERSEDED` means:

```text
not active for new enrollment
still immutable
still available to existing enrollments
still auditable
```

Do not treat superseded as deleted.

---

# Existing learners

Learners enrolled in v1 should remain pinned to:

```text
track_version_id = v1
```

after v2 publication.

Do not silently move:

```text
roadmap
mastery
assessment
lessons
```

to v2.

---

# New learners

After v2 becomes active:

```text
new enrollment defaults to v2
```

unless an explicit version is selected by authorized policy.

---

# Enrollment pinning

Every enrollment must store:

```text
track_id
track_version_id
```

Never resolve learner curriculum dynamically only through:

```text
LearningTrack.active_version_id
```

after enrollment.

---

# Draft creation for future changes

Editing a published course should invoke:

```text
create_new_draft_version(track_id)
```

The new draft may clone:

```text
metadata
approved blueprint
curriculum graph structure
configuration
```

but must receive:

```text
new track_version_id
new draft state
```

---

# Version cloning policy

Suggested:

```text
copy stable course metadata
copy curriculum graph as draft baseline
copy source provenance references only if same source is intentionally reused
```

Do not reuse mutable graph nodes directly.

Create new version-scoped nodes/edges.

---

# Source reuse

A new version may reuse the same source document bytes if:

```text
lecturer explicitly chooses existing validated source
```

But the new version must maintain its own:

```text
version identity
blueprint
validation
approval
graph generation
```

---

# Publication service

Create:

```text
CoursePublicationService
```

Responsibilities:

```text
authorize
check readiness
acquire publication lock
allocate version number
create publication snapshot
seal version
switch active version
supersede previous version
update catalog projection
update enrollment-open projection
emit events
release lock
```

---

# Service contract

```jac
obj CoursePublicationService {
    def publish_course_version(
        request: PublishCourseVersionRequest
    ) -> CoursePublicationResult;

    def get_publication_readiness(
        track_version_id: str,
        actor_context: AuthorizationActor
    ) -> PublicationReadinessResult;

    def create_new_draft_version(
        request: CreateDraftVersionRequest
    ) -> DraftVersionResult;

    def rollback_publication(
        request: RollbackPublicationRequest
    ) -> CoursePublicationResult;
}
```

---

# Publish request

```jac
obj PublishCourseVersionRequest {
    has track_id: str;
    has track_version_id: str;

    has expected_revision: int;

    has idempotency_key: str;

    has publish_note: str | None = None;
}
```

Do not accept:

```text
version_number
owner_id
published_by
active_version_id
```

from client as trusted values.

---

# Publication result

```jac
obj CoursePublicationResult {
    has publication_id: str | None;

    has track_id: str;
    has track_version_id: str;

    has version_number: int | None;

    has status: str;

    has active_version_id: str | None;

    has previous_active_version_id: str | None;

    has warnings: list[str];

    has error_code: str | None;
}
```

---

# Publication transaction

Recommended atomic sequence:

```text
1. acquire track publication lock
2. re-read track/version/approval/validation/graph
3. verify readiness
4. allocate version number
5. create CoursePublication snapshot
6. mark target version PUBLISHING
7. seal immutable fields
8. mark previous active version SUPERSEDED
9. mark target PUBLISHED
10. switch LearningTrack.active_version_id
11. update current_version_number
12. update catalog/enrollment projection
13. commit
14. emit publication event
```

---

# Failure handling

If transaction fails:

```text
do not leave two active versions
do not mark version published partially
```

Use transaction when available.

Otherwise use recoverable state plus reconciliation.

---

# Publication failure state

If mid-flight failure occurs outside atomic transaction:

```text
TrackVersion.status = PUBLICATION_FAILED
```

and run:

```text
publication reconciliation
```

---

# Publication reconciliation service

Create:

```text
CoursePublicationReconciliationService
```

Checks:

```text
publication snapshot exists
target version status
active_version_id
previous version status
catalog projection
```

Repairs only deterministic state inconsistencies.

---

# Idempotency

Publication request keyed by:

```text
track_version_id
approval_id
validation_report_id
graph_generation_id
idempotency_key
```

Repeated request after success:

```text
return existing publication
```

Do not create a second publication record.

---

# Concurrency

Only one publication operation per track at a time.

Use:

```text
track publication lock
```

not only version-level lock.

---

# Publication authorization

Required permission:

```text
LecturerPermission.PUBLISH_VERSION
```

or corresponding enum from `36`.

If approval and publication permissions are separate:

```text
APPROVE_VERSION
PUBLISH_VERSION
```

enforce both appropriately.

---

# Ownership

Verify:

```text
actor authorized for track
```

Do not trust client owner information.

---

# Self-approval policy

If system policy disallows lecturer self-approval:

```text
approval actor
!=
publication actor
```

may be required.

Use feature flag/policy from `36`.

---

# Publication visibility

Track visibility options:

```text
PUBLIC
INSTITUTION
PRIVATE
```

Publishing does not necessarily mean public catalog visibility.

Example:

```text
status = PUBLISHED
visibility = PRIVATE
```

valid for private/internal courses.

---

# Enrollment open flag

Publishing should not automatically imply:

```text
is_enrollment_open = true
```

unless product policy says so.

Recommended:

```text
publish
→ course available as published
→ enrollment opening controlled separately
```

---

# Publication readiness versus enrollment readiness

Distinguish:

```text
PUBLISHED
```

from:

```text
OPEN_FOR_ENROLLMENT
```

---

# Catalog projection

On publication, update a read model for `51`.

Fields:

```text
track_id
active_version_id
title
course_code
subject_area
academic_level
visibility
published_at
enrollment_open
```

Do not expose draft versions.

---

# Publication snapshot immutability

After publication, protect:

```text
CoursePublication
TrackVersion
CurriculumModule
Skill
LearningOutcome
PREREQUISITE edges
source references
```

through repository/service guards.

---

# Repository mutation guards

Any update method should reject:

```text
published immutable entity
```

unless operation is explicitly metadata-safe.

---

# Immutable field guard

Create:

```text
assert_version_editable(track_version_id)
```

All draft-edit services must call it.

---

# Published version reads

Published version remains readable by:

```text
enrolled learners
authorized lecturer
admin
catalog viewers according to visibility
```

---

# Archive versus supersede

`SUPERSEDED`:

```text
historical but still part of version chain
```

`ARCHIVED`:

```text
administratively hidden/retired
```

Do not automatically archive old versions on every publish.

---

# Rollback semantics

Rollback requires careful definition.

Recommended first-release meaning:

```text
reactivate a previously published immutable version
```

not:

```text
mutate current published version
```

---

# Rollback example

Current:

```text
v1 SUPERSEDED
v2 PUBLISHED active
```

Rollback to v1:

```text
v2 → SUPERSEDED
v1 → PUBLISHED active
active_version_id → v1
```

Both remain immutable.

---

# Rollback constraints

Allow only if:

```text
target version was previously published
target not archived/deleted
graph/source artifacts intact
authorization granted
```

---

# Rollback impact

Existing learners remain pinned.

New learners after rollback use newly active version.

Do not migrate learner enrollments automatically.

---

# Rollback audit record

Create publication event:

```text
ROLLBACK_ACTIVATION
```

with:

```text
from_version
to_version
actor
reason
timestamp
```

---

# Rollback request

```jac
obj RollbackPublicationRequest {
    has track_id: str;
    has target_track_version_id: str;

    has reason: str;

    has idempotency_key: str;
}
```

---

# Version chain

Optional explicit edge:

```jac
edge PREVIOUS_VERSION {}
```

Graph:

```text
v3 → PREVIOUS_VERSION → v2
v2 → PREVIOUS_VERSION → v1
```

or store:

```text
previous_version_id
```

Choose one convention.

---

# Version lineage

Persist:

```text
created_from_version_id
```

for draft cloning.

This is different from active predecessor.

---

# Publication history

Create query:

```text
list_course_publication_history(track_id)
```

Returns:

```text
version number
status
published at
published by
superseded at
rollback activations
```

---

# Publication note

Allow optional:

```text
release note
```

Example:

```text
Added normalization module and updated SQL prerequisites.
```

Useful for version history.

---

# Version release notes

Store:

```text
release_notes
```

on publication record, not necessarily course source.

---

# Semantic version labels

Initial use integer versions:

```text
Version 1
Version 2
```

Do not introduce SemVer unless product requirements need it.

---

# New draft version creation

Create request:

```jac
obj CreateDraftVersionRequest {
    has track_id: str;

    has base_version_id: str | None;

    has clone_curriculum: bool = True;

    has idempotency_key: str;
}
```

---

# Draft version result

```jac
obj DraftVersionResult {
    has track_version_id: str;
    has version_number_hint: int | None;

    has status: str;

    has base_version_id: str | None;
}
```

Version number may remain provisional until publication depending on domain choice.

---

# Draft numbering strategy

Recommended:

```text
assign version_number when draft created
```

or:

```text
assign only at publication
```

For concurrency simplicity and user clarity:

```text
assign immutable integer at draft creation
```

is reasonable.

If `29` already established version numbering, follow it.

---

# Draft cloning

Clone:

```text
TrackConfiguration
CurriculumModule structure
Skill structure
LearningOutcomes
Prerequisite relationships
```

into new version-scoped entities.

Do not share mutable nodes across versions.

---

# Clone provenance

Record:

```text
cloned_from_version_id
```

on new version.

---

# Blueprint cloning

If cloned course uses previous curriculum as baseline:

```text
create new draft blueprint derived from previous approved blueprint
```

with provenance:

```text
DERIVED_FROM_VERSION
```

---

# Validation after clone

A cloned draft is not automatically approved.

Status:

```text
DRAFT
```

Any changes require:

```text
review
validation
approval
publication
```

---

# Existing learner protection

Never delete historical:

```text
Skill nodes
Roadmap references
Lesson references
Mastery
Assessment attempts
```

needed by enrolled learners.

---

# Version-aware cache keys

All published curriculum caches must include:

```text
track_version_id
```

Do not cache only by:

```text
track_id
```

---

# Version-aware API responses

Learner-facing responses should expose:

```text
track_id
track_version_id
version_number
```

where relevant.

---

# Version mismatch protection

If learner enrollment references v1 and client sends v2:

```text
reject or resolve enrollment's authoritative version
```

Do not let client switch versions silently.

---

# Publication walker

Suggested:

```text
publish_course_version
```

Private walker.

Behavior:

```text
authenticate
authorize
validate expected revision
invoke publication service
return typed result
```

---

# Publication readiness walker

```text
get_course_publication_readiness
```

Returns:

```text
ready
blocking issues
warnings
version info
```

---

# Create new version walker

```text
create_course_draft_version
```

Used after a course is already published.

---

# Rollback walker

Admin/authorized lecturer:

```text
rollback_course_publication
```

Use stricter permission.

---

# Frontend publication flow

From blueprint review:

```text
Approve blueprint
→ Publication readiness screen
→ Review version summary
→ Publish
→ Published confirmation
```

---

# Publication readiness screen

Show:

```text
course title
version number
module count
skill count
outcome count
validation status
approval status
visibility
enrollment-open state
release note
```

---

# Publish confirmation

Warn:

```text
Publishing seals this version.
Future curriculum changes require a new version.
```

---

# Post-publication UI

Show:

```text
Published
Version N
Published date
Active version
Create new version
View history
```

---

# Error codes

Define:

```text
COURSE_PUBLICATION_NOT_AUTHORIZED
COURSE_PUBLICATION_TRACK_NOT_FOUND
COURSE_PUBLICATION_VERSION_NOT_FOUND
COURSE_PUBLICATION_VERSION_NOT_READY
COURSE_PUBLICATION_BLUEPRINT_NOT_APPROVED
COURSE_PUBLICATION_APPROVAL_STALE
COURSE_PUBLICATION_VALIDATION_STALE
COURSE_PUBLICATION_GRAPH_STALE
COURSE_PUBLICATION_SOURCE_STALE
COURSE_PUBLICATION_BLOCKING_ISSUES
COURSE_PUBLICATION_ALREADY_RUNNING
COURSE_PUBLICATION_ALREADY_PUBLISHED
COURSE_PUBLICATION_VERSION_CONFLICT
COURSE_PUBLICATION_ACTIVE_VERSION_CONFLICT
COURSE_PUBLICATION_PERSIST_FAILED
COURSE_PUBLICATION_RECONCILIATION_REQUIRED
COURSE_PUBLICATION_ROLLBACK_NOT_ALLOWED
COURSE_PUBLICATION_INTERNAL_ERROR
```

---

# User-facing errors

Example:

```text
This course version is not ready to publish.
Review the remaining validation or approval issues.
```

Stale approval:

```text
The course changed after approval.
Please review and approve the latest revision before publishing.
```

---

# Publication audit events

Emit:

```text
course_publication.readiness_checked
course_publication.started
course_publication.completed
course_publication.failed
course_publication.version_superseded
course_publication.active_version_changed
course_publication.rollback_started
course_publication.rollback_completed
course_version.draft_created
course_version.cloned
```

Fields:

```text
publication_id
track_id
track_version_id
version_number
previous_active_version_id
actor_id
approval_id
validation_report_id
graph_generation_id
request_id
```

---

# Metrics

Track:

```text
course_publication_total
course_publication_completed_total
course_publication_failed_total
course_publication_duration_ms

course_versions_created_total
course_versions_superseded_total
course_publication_rollbacks_total
course_publication_readiness_blocked_total
```

---

# Repository contracts

## `LearningTrackRepository`

Need:

```text
get_track
get_active_version
set_active_version
update_current_version_number
```

## `TrackVersionRepository`

Need:

```text
get_version
list_versions
lock_for_publication
mark_publishing
mark_published
mark_superseded
mark_publication_failed
assert_editable
```

## `CoursePublicationRepository`

Need:

```text
find_by_idempotency_key
find_for_version
save_publication
list_publication_history
```

---

# Transaction boundary

The publication operation should be one strong consistency boundary.

At minimum atomically coordinate:

```text
target version status
previous active version status
LearningTrack.active_version_id
publication record
```

---

# Reconciliation audit

Create:

```text
audit_course_publication_state(track_id)
```

Checks:

```text
max one active published version
active_version_id exists
active version status PUBLISHED
superseded versions immutable
publication snapshot exists for published version
version numbers unique
```

---

# Security

Publication is a high-impact write action.

Require:

```text
explicit publish request
authorization
fresh approval
fresh validation
```

Do not automatically publish immediately after approval unless explicitly required by product policy.

---

# Testing strategy

## Readiness tests

Test missing:

```text
approval
validation
graph
source
```

Each blocks publication.

---

# Stale approval tests

Approve revision 3.

Edit to revision 4.

Attempt publish.

Expected:

```text
COURSE_PUBLICATION_APPROVAL_STALE
```

---

# First publication test

Publish v1.

Verify:

```text
status PUBLISHED
active_version_id = v1
publication snapshot exists
```

---

# New version publication test

Publish v2.

Verify:

```text
v2 PUBLISHED
v1 SUPERSEDED
active_version_id = v2
```

---

# Existing enrollment test

Learner enrolled in v1.

Publish v2.

Verify:

```text
learner remains on v1
```

---

# New enrollment resolution test

After v2 active:

```text
new enrollment resolves v2
```

---

# Immutability tests

Attempt to edit:

```text
published Skill
published CurriculumModule
published prerequisite edge
```

Reject.

---

# New draft version test

Create draft from v2.

Verify:

```text
new track_version_id
DRAFT status
cloned nodes are new version-scoped nodes
```

---

# Idempotency test

Call publish twice with same idempotency key.

Expected:

```text
same publication result
```

---

# Concurrency test

Two simultaneous publish attempts.

Expected:

```text
one succeeds
no duplicate version number
one active version
```

---

# Failure injection

Simulate failure after:

```text
publication record
previous version supersede
active version switch
```

Verify transaction/reconciliation restores consistency.

---

# Rollback test

v1 superseded, v2 active.

Rollback to v1.

Verify:

```text
v1 active
v2 superseded
existing enrollments unchanged
```

---

# Cross-version mutation test

Ensure v2 edits do not mutate v1 nodes.

---

# Example Jac test outlines

```jac
test "publication requires current approval" {
    # Approve revision.
    # Edit blueprint.
    # Attempt publish.
    # Assert approval stale.
}

test "publishing new version supersedes old active version" {
    # Publish v1 then v2.
    # Assert v2 active and v1 superseded.
}

test "existing enrollment remains pinned to historical version" {
    # Enroll learner in v1.
    # Publish v2.
    # Assert enrollment.track_version_id == v1.
}

test "published curriculum is immutable" {
    # Attempt skill update on published version.
    # Assert edit denied.
}

test "publication is idempotent" {
    # Repeat publish request.
    # Assert one publication snapshot.
}
```

---

# Implementation sequence

## Step 1 — Reconcile version states with `29`

Confirm:

```text
TrackVersionStatus
LearningTrack.active_version_id
version numbering
```

## Step 2 — Add publication record

Implement:

```text
CoursePublication
```

## Step 3 — Add readiness service

Check approval, validation, graph, source freshness.

## Step 4 — Add publication lock

One operation per track.

## Step 5 — Implement version sealing

Protect immutable entities.

## Step 6 — Implement first publication

Set active version.

## Step 7 — Implement superseding

Switch active version safely.

## Step 8 — Add enrollment pinning checks

Ensure existing learners remain version-bound.

## Step 9 — Implement new draft version creation

Clone version-scoped curriculum.

## Step 10 — Add rollback/reactivation

Strictly controlled.

## Step 11 — Add walkers

Publish, readiness, create draft, rollback.

## Step 12 — Add catalog projection hooks

Prepare `51`.

## Step 13 — Add audit/metrics

Publication history and observability.

## Step 14 — Add tests

Concurrency, immutability, enrollment pinning, rollback.

---

# Acceptance criteria

## Readiness

- [ ] Only approved current blueprint can publish.
- [ ] Validation must be current.
- [ ] Graph generation must be current.
- [ ] Source document/checksum must be current.
- [ ] Blocking validation issues prevent publication.

## Publication

- [ ] Publication creates immutable snapshot.
- [ ] Version number allocated server-side.
- [ ] Exactly one active published version exists.
- [ ] Previous active version becomes superseded.
- [ ] Track.active_version_id switches atomically.

## Immutability

- [ ] Published curriculum nodes cannot be edited.
- [ ] Published prerequisite edges cannot be edited.
- [ ] Source provenance cannot be changed.
- [ ] Future semantic changes require new TrackVersion.

## Versioning

- [ ] Historical versions remain accessible.
- [ ] New draft version gets new version-scoped entities.
- [ ] Versions do not share mutable curriculum nodes.
- [ ] Version lineage is recorded.

## Learners

- [ ] Existing learners remain pinned to enrolled version.
- [ ] New learners resolve active version.
- [ ] Learner data is not silently migrated.

## Idempotency/concurrency

- [ ] Duplicate publish request is idempotent.
- [ ] Concurrent publication cannot create two active versions.
- [ ] Version numbers remain unique.

## Rollback

- [ ] Previously published version can be reactivated only through explicit rollback policy.
- [ ] Rollback does not mutate learner enrollments.
- [ ] Rollback is audited.

## Authorization

- [ ] Publication requires explicit permission.
- [ ] Other lecturers cannot publish unauthorized tracks.
- [ ] Learners cannot publish.
- [ ] Admin override requires explicit permission.

## Quality

- [ ] `jac check` passes.
- [ ] `jac check --lint` passes.
- [ ] `jac test` passes.
- [ ] Publication readiness tests pass.
- [ ] Immutability tests pass.
- [ ] Enrollment pinning tests pass.
- [ ] Concurrency tests pass.
- [ ] Rollback tests pass.
- [ ] Failure-reconciliation tests pass.

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
1. Generate, validate, review, and approve a course.
2. Open publication readiness.
3. Confirm all prerequisites are current.
4. Publish version 1.
5. Confirm version 1 is PUBLISHED and active.
6. Confirm publication snapshot exists.
7. Confirm curriculum is immutable.

8. Create a new draft version.
9. Edit it.
10. Validate and approve.
11. Publish version 2.
12. Confirm version 1 becomes SUPERSEDED.
13. Confirm version 2 becomes active.

14. Verify an existing v1 learner remains on v1.
15. Verify a new enrollment resolves to v2.

16. Attempt to edit published v2 directly.
17. Confirm edit is rejected.

18. Retry same publication request.
19. Confirm no duplicate publication.

20. Test concurrent publish attempts.
21. Confirm exactly one active version.

22. Roll back active version to v1.
23. Confirm v1 reactivates safely.
24. Confirm learner enrollments remain unchanged.
```

---

# Expected result

After this specification is implemented:

- lecturer-approved course drafts can be safely published as immutable course versions;
- publication is bound to an exact approved blueprint, validation report, graph generation, and source checksum;
- only one active published version exists per learning track;
- older versions remain available to learners already enrolled in them;
- future changes occur through new draft versions rather than in-place mutation;
- publication is idempotent, concurrency-safe, auditable, and rollback-aware;
- catalog and enrollment features can safely consume the active published version in the next specifications.
