# 36-lecturer-authorization-policies.md

## Overview

Implement centralized authorization policies for lecturer-facing GraphLearn LMS operations.

This specification defines how authenticated users are permitted or denied access to:

- lecturer profiles;
- lecturer-owned learning tracks;
- draft and published course versions;
- source documents and extracted content;
- course blueprints and curriculum graphs;
- enrolled learner summaries;
- learner submissions and grading-review queues;
- administrative role and ownership operations.

Authentication answers:

```text
Who is making the request?
```

Authorization answers:

```text
May this authenticated actor perform this action on this resource now?
```

Every privileged walker must derive the actor from the trusted Jac authentication context, resolve the relevant resources through repositories, and evaluate an explicit authorization policy before reading or mutating protected graph state.

Client-supplied values such as `role`, `lecturer_id`, `owner_id`, `created_by`, or `is_admin` must never be treated as proof of permission.

---

## Status

- **Feature type:** Authorization and access-control foundation
- **Subsystem:** Lecturer identity and course management
- **Priority:** Critical
- **Depends on:**
  - `29-learning-track-domain-model.md`
  - `32-learning-track-osp-schema.md`
  - `33-track-repositories-and-services.md`
  - `34-track-aware-walker-migration.md`
  - `35-user-roles-and-lecturer-profile.md`
- **Blocks:**
  - `37-create-and-manage-course-track.md`
  - lecturer document upload;
  - blueprint review;
  - course publication;
  - lecturer dashboards;
  - lecturer grading review.
- **Primary implementation language:** Jac
- **Breaking changes allowed:** No
- **Migration required:** Limited
- **Security review required:** Yes

---

## Framework alignment

Jac authentication and HTTP exposure should be treated as separate layers from domain authorization.

Use private walkers or private functions where the endpoint itself must require authentication, but do not assume that `walker:priv` alone proves that an authenticated user owns a course or may access another learner's records.

The required control flow is:

```text
private walker
    → authenticated actor resolution
    → active role/profile resolution
    → resource lookup
    → authorization policy evaluation
    → service operation
    → safe report
```

A private walker protects the endpoint from unauthenticated access. The policy layer protects resources from authenticated but unauthorized users.

---

## Problem statement

After lecturer identities are introduced, multiple authenticated users may hold combinations of roles:

```text
learner
lecturer
administrator
learner + lecturer
lecturer + administrator
```

Without a centralized policy system, individual walkers may implement inconsistent checks such as:

```text
if user.role == "lecturer"
```

or:

```text
if request.owner_id == track.owner_id
```

These checks are insufficient because:

- a lecturer must not manage another lecturer's course;
- a suspended lecturer must not retain privileged access;
- publication may require a different permission from editing;
- published versions are immutable even to their owner;
- a lecturer may view only limited learner data for learners enrolled in their course;
- an administrator may need operational access without becoming course owner;
- a private course must not leak through list or detail operations;
- role names supplied by a client are untrusted;
- ownership stored only as a scalar may disagree with the graph relationship;
- authorization rules may depend on resource state, not only role.

The system needs a reusable authorization layer with explicit policies, stable decision codes, audit records, and negative security tests.

---

## Goals

Implement authorization that:

1. Resolves the actor only from trusted authentication state.
2. Uses typed roles and active role assignments.
3. Verifies lecturer profile status before lecturer operations.
4. Verifies resource ownership through trusted repository data.
5. Supports owner, collaborator, reviewer, and administrator distinctions.
6. Applies resource-state rules such as draft immutability and archival.
7. Protects both reads and writes.
8. Prevents cross-track and cross-version access.
9. Restricts access to learner records using enrollment relationships.
10. Produces stable allow/deny decisions and safe errors.
11. Emits auditable authorization events without leaking private content.
12. Keeps walkers thin and prevents duplicated policy logic.
13. Defaults to denial when context is missing or ambiguous.
14. Supports future institution-level policies without replacing the base model.

---

## Non-goals

This specification does not implement:

- login or password management;
- role-request onboarding UI;
- administrator dashboard UI;
- institution tenancy;
- billing permissions;
- document malware scanning;
- learner consent UI;
- course collaboration UI;
- publication workflow UI;
- grading-review UI;
- external identity-provider authorization;
- attribute-based access across multiple institutions.

It defines the policy foundation those features will use.

---

# Security principles

## 1. Default deny

When the system cannot prove that an operation is allowed, it must deny it.

Examples:

```text
missing authenticated identity → deny
missing role assignment → deny
inactive lecturer profile → deny
missing course → safe not-found or deny
ambiguous ownership → deny
version/track mismatch → deny
missing enrollment relationship → deny learner-data access
unknown action → deny
```

## 2. Server-derived actor context

The actor context must be created from trusted session information.

Never accept this as authoritative request input:

```json
{
  "actor_id": "user-1",
  "role": "ADMIN",
  "lecturer_id": "lecturer-1"
}
```

The frontend may communicate desired workspace or action, but the backend resolves actual identity and permissions.

## 3. Least privilege

Grant the minimum permissions required for the requested operation.

A lecturer who may edit a draft course does not automatically gain permission to:

- grant lecturer roles;
- publish every course;
- view unrelated learners;
- modify another lecturer's track;
- mutate a published version;
- read system audit logs.

## 4. Separate role from ownership

Role answers whether an actor belongs to an authorization category.

Ownership answers whether that actor controls a specific resource.

Both may be required:

```text
active lecturer role
AND active lecturer profile
AND owns the selected track
```

## 5. Separate discoverability from management

A learner may discover a public course but may not manage it.

A lecturer may manage a private draft they own but it must not appear in the learner catalogue.

## 6. State-aware permissions

Permission depends on resource state.

Examples:

```text
owner + draft version → edit permitted
owner + published version → direct mutation denied
owner + archived track → limited metadata access, normal editing denied
suspended lecturer + owned draft → access denied
```

## 7. Graph relationship verification

Scalar references such as `owner_id`, `track_id`, and `track_version_id` are useful for indexing, but sensitive decisions must validate graph relationships and domain invariants where available.

## 8. No security-by-frontend

Hidden buttons are usability controls, not authorization controls.

Every protected operation must be checked on the backend.

---

# Authorization vocabulary

## Actor

The authenticated user attempting an operation.

## Subject profile

The role-specific profile used for a particular action, such as `LecturerProfile`.

## Resource

The domain object being accessed, such as a track, version, document, enrollment, submission, or learner summary.

## Action

The operation being attempted, represented by a typed permission value.

## Policy

A deterministic rule that evaluates actor, action, resource, and context.

## Decision

The result of policy evaluation:

```text
ALLOW
DENY
```

with a stable reason code.

## Scope

The boundary within which a permission applies:

```text
SELF
OWNED_TRACK
ASSIGNED_TRACK
INSTITUTION
SYSTEM
```

---

# Core authorization enums

## `AuthorizationDecisionType`

```jac
enum AuthorizationDecisionType {
    ALLOW,
    DENY
}
```

## `AuthorizationScope`

```jac
enum AuthorizationScope {
    SELF,
    OWNED_TRACK,
    ASSIGNED_TRACK,
    ENROLLED_TRACK,
    INSTITUTION,
    SYSTEM
}
```

Do not enable `INSTITUTION` behavior until institution membership is implemented.

## `LecturerPermission`

```jac
enum LecturerPermission {
    VIEW_OWN_PROFILE,
    EDIT_OWN_PROFILE,

    LIST_OWN_TRACKS,
    CREATE_TRACK,
    VIEW_TRACK,
    EDIT_TRACK_METADATA,
    ARCHIVE_TRACK,
    RESTORE_TRACK,

    CREATE_TRACK_VERSION,
    VIEW_TRACK_VERSION,
    EDIT_DRAFT_VERSION,
    SUBMIT_VERSION_FOR_REVIEW,
    APPROVE_VERSION,
    PUBLISH_VERSION,
    SUPERSEDE_VERSION,

    UPLOAD_COURSE_DOCUMENT,
    VIEW_COURSE_DOCUMENT,
    DELETE_DRAFT_DOCUMENT,
    PROCESS_COURSE_DOCUMENT,

    VIEW_BLUEPRINT,
    EDIT_BLUEPRINT,
    APPROVE_BLUEPRINT,
    REGENERATE_BLUEPRINT_SECTION,

    VIEW_COURSE_ENROLLMENTS,
    VIEW_COURSE_LEARNER_SUMMARY,
    VIEW_COURSE_SUBMISSION,
    REVIEW_LOW_CONFIDENCE_GRADE,

    MANAGE_TRACK_COLLABORATORS,
    VIEW_TRACK_AUDIT_LOG
}
```

Some permissions are reserved for later specifications, but defining them now prevents arbitrary strings.

## `AdministrativePermission`

```jac
enum AdministrativePermission {
    VIEW_ANY_LECTURER_PROFILE,
    APPROVE_LECTURER_PROFILE,
    SUSPEND_LECTURER_PROFILE,
    REINSTATE_LECTURER_PROFILE,

    VIEW_ANY_TRACK,
    ARCHIVE_ANY_TRACK,
    RESTORE_ANY_TRACK,
    PUBLISH_ANY_TRACK,

    ASSIGN_ROLE,
    REVOKE_ROLE,
    VIEW_SECURITY_AUDIT_LOG,
    REPAIR_RESOURCE_OWNERSHIP
}
```

Administrator permissions should remain explicit. Avoid one unrestricted `is_admin` bypass that ignores resource invariants.

## `AuthorizationReasonCode`

```jac
enum AuthorizationReasonCode {
    ALLOWED,

    AUTHENTICATION_REQUIRED,
    ACTOR_NOT_FOUND,
    ROLE_REQUIRED,
    ROLE_INACTIVE,
    LECTURER_PROFILE_REQUIRED,
    LECTURER_PROFILE_PENDING,
    LECTURER_PROFILE_SUSPENDED,
    LECTURER_PROFILE_ARCHIVED,

    RESOURCE_NOT_FOUND,
    RESOURCE_OWNERSHIP_REQUIRED,
    RESOURCE_OWNERSHIP_MISMATCH,
    RESOURCE_SCOPE_MISMATCH,

    TRACK_NOT_EDITABLE,
    TRACK_ARCHIVED,
    TRACK_PRIVATE,
    VERSION_NOT_EDITABLE,
    VERSION_IMMUTABLE,
    VERSION_TRACK_MISMATCH,

    ENROLLMENT_REQUIRED,
    LEARNER_DATA_SCOPE_DENIED,
    SUBMISSION_TRACK_MISMATCH,

    ADMIN_PERMISSION_REQUIRED,
    POLICY_CONTEXT_INVALID,
    PERMISSION_NOT_SUPPORTED
}
```

---

# Actor context

Create one trusted actor-context object.

```jac
obj AuthorizationActor {
    has user_id: str;
    has session_id: str | None = None;

    has role_assignments: list[UserRole];

    has learner_id: str | None = None;
    has lecturer_id: str | None = None;

    has lecturer_status: LecturerProfileStatus | None = None;

    has is_authenticated: bool = False;
    has resolved_at: str;
}
```

## Actor resolution rules

1. Resolve `user_id` from the authenticated Jac session or root identity.
2. Load active role assignments from the identity repository.
3. Ignore revoked, expired, suspended, or invalid role assignments.
4. Resolve a lecturer profile only when the actor has a lecturer role.
5. Validate that the lecturer profile belongs to the authenticated user.
6. Include only stable identifiers and status values in the actor context.
7. Never construct a privileged actor from request parameters.

## Multi-role behavior

A user may hold learner and lecturer roles simultaneously.

The policy evaluates the action, not merely the currently displayed frontend workspace.

Example:

```text
User has LEARNER + LECTURER.
Action = EDIT_TRACK_METADATA.
Policy requires active lecturer capability and ownership.
```

The learner role neither grants nor blocks the lecturer permission.

---

# Resource context

Create a typed policy context for protected resources.

```jac
obj AuthorizationResourceContext {
    has resource_type: str;
    has resource_id: str;

    has track_id: str | None = None;
    has track_version_id: str | None = None;

    has owner_lecturer_id: str | None = None;
    has owner_user_id: str | None = None;

    has track_status: LearningTrackStatus | None = None;
    has version_status: TrackVersionStatus | None = None;

    has learner_id: str | None = None;
    has enrollment_id: str | None = None;
    has submission_id: str | None = None;

    has institution_id: str | None = None;
}
```

Resource contexts must be constructed by repositories or trusted services after loading the actual resource graph.

Do not let callers submit arbitrary resource context objects to authorization services.

---

# Authorization decision

```jac
obj AuthorizationDecision {
    has decision: AuthorizationDecisionType;
    has permission: str;
    has scope: AuthorizationScope | None = None;
    has reason_code: AuthorizationReasonCode;
    has message: str;

    has actor_id: str | None = None;
    has resource_type: str | None = None;
    has resource_id: str | None = None;

    has evaluated_at: str;
}
```

Rules:

- allow decisions use `ALLOWED`;
- deny decisions use a precise stable reason code;
- messages are safe for logs and API mapping;
- decisions must not contain document content, learner answers, or secrets.

---

# Lecturer profile eligibility

A lecturer permission requires:

```text
authenticated actor
AND active lecturer role assignment
AND lecturer profile exists
AND lecturer profile belongs to actor
AND lecturer profile status permits action
```

Suggested profile behavior:

| Lecturer profile status | Read own profile | Edit own profile | Create/manage course | Review learner data |
|---|---:|---:|---:|---:|
| `PENDING` | Yes | Limited | No | No |
| `ACTIVE` | Yes | Yes | Yes | Yes, scoped |
| `SUSPENDED` | Yes | No | No | No |
| `REJECTED` | Yes | Limited | No | No |
| `ARCHIVED` | Limited | No | No | No |

A later onboarding policy may permit a pending lecturer to edit fields required for approval.

---

# Ownership model

A lecturer-owned track must be associated with its owner through trusted domain data.

Preferred verification:

```text
LecturerProfile
    └── OWNS_TRACK
          └── LearningTrack
```

The track may also contain:

```text
ownership_type = LECTURER
owner_id = <lecturer_id>
```

For sensitive mutations, verify both when both exist.

## Ownership consistency rules

Allow owner-scoped access only when:

```text
track.ownership_type == LECTURER
AND track.owner_id == actor.lecturer_id
AND OWNS_TRACK relationship exists
```

During an additive migration period where the edge may not yet exist, a temporary compatibility policy may use a validated scalar owner ID. This fallback must:

- be feature-flagged;
- emit a warning metric;
- never override a contradictory edge;
- be removed after ownership-edge backfill.

## Ownership conflict

If scalar ownership and graph ownership disagree:

```text
DENY
reason = RESOURCE_OWNERSHIP_MISMATCH
```

Do not guess which value is correct.

---

# Collaborator-ready access model

The initial release may support only one owner. Define the policy shape so collaborators can be added later without changing every walker.

Reserved relationship:

```jac
edge HAS_TRACK_ACCESS {
    has access_role: TrackAccessRole;
    has granted_by: str;
    has granted_at: str;
    has expires_at: str | None = None;
    has revoked_at: str | None = None;
}
```

Reserved roles:

```jac
enum TrackAccessRole {
    OWNER,
    EDITOR,
    REVIEWER,
    VIEWER
}
```

Initial rules:

- `OWNER`: full owner-scoped permissions subject to state rules;
- `EDITOR`: draft editing but no publication or collaborator management;
- `REVIEWER`: blueprint/version review but no ordinary metadata mutation;
- `VIEWER`: read-only access to permitted course authoring resources.

Do not expose collaborator-management walkers until the corresponding feature is implemented.

---

# Permission matrix

## Lecturer track management

| Action | Active owner | Editor | Reviewer | Admin permission | Learner |
|---|---:|---:|---:|---:|---:|
| List owned tracks | Yes | Assigned only | Assigned only | Any track if granted | No |
| View private draft | Yes | Yes | Yes | Yes | No |
| Create track | Yes | No | No | Optional | No |
| Edit track metadata | Yes | Yes | No | Yes | No |
| Archive track | Yes | No | No | Yes | No |
| Restore track | Policy-controlled | No | No | Yes | No |
| Create draft version | Yes | Yes | No | Yes | No |
| Edit draft version | Yes | Yes | No | Yes | No |
| Submit for review | Yes | Yes | No | Yes | No |
| Approve version | Policy-controlled | No | Yes | Yes | No |
| Publish version | Policy-controlled | No | No | Yes | No |
| View audit events | Own track only | Limited | Limited | Yes | No |

The project must explicitly choose one publication model:

### Owner-publish model

An active owner may approve and publish their own course.

### Reviewer/admin-publish model

An owner submits for review, and a separate reviewer or administrator publishes.

For the first release, choose and document one model. Do not leave publication authority ambiguous.

Recommended initial model:

```text
owner may edit and submit;
administrator or explicitly assigned reviewer may approve;
administrator or owner with PUBLISH_VERSION may publish.
```

For a hackathon prototype, owner publishing may be enabled through a feature flag while preserving the permission boundary.

---

# Resource-state rules

## Track metadata

Editable when:

```text
track.status in [DRAFT, PROCESSING, REVIEW_REQUIRED, FAILED]
AND actor has EDIT_TRACK_METADATA
```

Protected fields must remain service-controlled:

```text
track_id
ownership_type
owner_id
active_version_id
current_version_number
published_at
archived_at
```

Published track display metadata may be editable only through a controlled metadata-update policy that does not mutate curriculum content.

## Draft version

Editable when:

```text
version.status in [DRAFT, REVIEW_REQUIRED]
AND version belongs to authorized track
AND actor has EDIT_DRAFT_VERSION
```

A `REVIEW_REQUIRED` version may restrict ordinary editors until returned to draft.

## Published version

Published versions are immutable.

Even owner or administrator access must not directly mutate a published version.

Required pattern:

```text
published version
    → create next draft version
    → edit new draft
    → review
    → publish new version
    → supersede old version
```

## Archived track

Default behavior:

- owner may view historical metadata;
- new uploads are denied;
- new versions are denied;
- new enrollment is denied;
- learner history remains readable to authorized users;
- restore requires an explicit permission.

---

# Course-document policies

## Upload

Allow when:

```text
active lecturer
AND owns or may edit track
AND target version is editable
AND track is not archived
AND UPLOAD_COURSE_DOCUMENT permission is granted
```

The target `track_id` and `track_version_id` must be resolved by the server.

## View

A lecturer may view source documents only for a track they own or are assigned to.

Learners must not receive raw lecturer documents unless a future course-content feature explicitly publishes them.

## Delete

Deletion is allowed only when:

```text
document belongs to an editable draft version
AND document is not referenced by an active processing job that cannot be cancelled
AND actor has DELETE_DRAFT_DOCUMENT
```

Published source records should be immutable or replaced through a new version.

## Processing

Starting or retrying extraction requires ownership/edit permission and an editable target version.

Background or queued processing must revalidate authorization-sensitive state before finalizing changes. It must not rely only on the permission observed when the job was initially requested.

---

# Blueprint policies

## View blueprint

Allow owner, assigned editor, reviewer, or authorized administrator.

Deny ordinary learners.

## Edit blueprint

Allow owner or editor when the version is editable.

## Approve blueprint

Require an explicit approval permission.

If self-approval is allowed for the prototype, make it a configuration decision:

```text
ALLOW_LECTURER_SELF_APPROVAL=true|false
```

The authorization service must still evaluate `APPROVE_BLUEPRINT`; do not bypass it inside the walker.

## Regenerate section

Requires:

- access to the track;
- editable version;
- valid source documents;
- regeneration permission;
- rate-limit and idempotency checks handled by the use-case service.

---

# Learner-data policies

Lecturer access to learner information must be course-scoped.

A lecturer must not list or inspect every learner in the system.

## Required relationship

```text
LecturerProfile
    └── owns/assigned to LearningTrack

LearnerProfile
    └── ENROLLED_IN → same LearningTrack / TrackVersion
```

## Course enrollment list

Allow when:

```text
actor may manage or view the track
AND requested enrollment records belong to that track
```

Return the minimum required projection.

Suggested initial learner summary:

```text
learner_id
safe display name
track enrollment status
roadmap progress
aggregate mastery
last learning activity timestamp
needs-review indicator
```

Do not automatically return:

- authentication identifiers;
- password-related data;
- unrelated course history;
- private profile fields;
- unrelated submissions;
- raw session data.

## Submission access

Allow only when all are true:

```text
submission belongs to learner
submission belongs to challenge/activity
activity belongs to selected track version
learner enrollment belongs to same track
lecturer owns or is assigned to same track
permission allows submission review
```

Reject cross-version or cross-track references.

## Low-confidence grading review

Allow only submissions flagged for review within an authorized track.

A lecturer must not use a submission ID alone to access the record.

The repository must resolve the complete chain:

```text
Submission
→ Activity
→ Lesson/Skill
→ TrackVersion
→ LearningTrack
```

## Learner's own access

Learner policies remain separate. A learner may view their own progress and submissions but may not invoke lecturer review operations merely because they are enrolled.

---

# Administrator policies

Administrators may receive broad operational permissions, but resource invariants still apply.

Examples:

- an administrator may archive a course they do not own;
- an administrator may repair ownership through a dedicated operation;
- an administrator may approve a lecturer profile;
- an administrator must still create a new version instead of mutating a published version;
- an administrator's access must be audited.

Do not implement:

```text
if admin: allow everything
```

Instead evaluate the required `AdministrativePermission`.

---

# Self-service profile policies

## View own lecturer profile

Allow authenticated user when the lecturer profile belongs to their user identity.

## Edit own lecturer profile

Allow only a safe field allowlist.

Potential self-editable fields:

```text
display_name
bio
department
academic_title
public_contact_preferences
```

Protected fields:

```text
lecturer_id
user_id
status
approved_by
approved_at
suspended_by
suspended_at
role assignments
```

Protected fields require administrative services.

## View another lecturer profile

Ordinary lecturers and learners should receive only published public profile information, if that feature exists.

Private onboarding and status information requires administrative permission.

---

# Policy service

Create a centralized service:

```text
AuthorizationPolicyService
```

Suggested contract:

```jac
obj AuthorizationPolicyService {
    def authorize_lecturer_action(
        actor: AuthorizationActor,
        permission: LecturerPermission,
        resource: AuthorizationResourceContext | None
    ) -> AuthorizationDecision;

    def authorize_admin_action(
        actor: AuthorizationActor,
        permission: AdministrativePermission,
        resource: AuthorizationResourceContext | None
    ) -> AuthorizationDecision;

    def require_allowed(
        decision: AuthorizationDecision
    ) -> None;
}
```

`require_allowed` should convert denials to a consistent domain/application error.

## Policy evaluation order

Use a predictable order:

```text
1. Is the actor authenticated?
2. Does the actor exist and have a valid active role?
3. Is the required role-specific profile present and active?
4. Is the permission supported?
5. Is a resource required?
6. Does the resource exist?
7. Does the resource belong to the expected track/version?
8. Does actor ownership or assignment match?
9. Does resource state allow the action?
10. Do additional scope rules pass?
11. Allow.
```

This order reduces accidental information leaks and inconsistent decisions.

---

# Policy composition

Create small reusable policy predicates rather than one giant conditional.

Suggested predicates:

```text
is_authenticated
has_active_role
has_active_lecturer_profile
has_admin_permission
owns_track
has_track_assignment
can_view_track
can_edit_track
can_edit_version
can_publish_version
can_access_enrollment
can_access_submission
is_same_track
is_same_version
is_resource_not_archived
```

Predicates should return structured internal results so the final denial reason remains specific.

---

# Repository responsibilities

Authorization services must use repositories to load trusted data.

Required repository capabilities:

## Identity repository

```text
resolve user from authenticated identity
list active role assignments
resolve lecturer profile
validate profile ownership
```

## Track repository

```text
find track by ID
resolve owner
validate OWNS_TRACK edge
list tracks owned or assigned to lecturer
resolve track status
```

## Version repository

```text
find version
validate parent track
resolve version status
```

## Enrollment repository

```text
find enrollment
validate learner
validate track and version
list enrollments scoped to track
```

## Submission repository

```text
find submission
resolve activity
resolve track and version
validate learner enrollment
```

Walkers must not perform ad hoc graph traversals that bypass these repository checks.

---

# Service integration

Application services should request authorization near the start of each use case.

Example:

```text
UpdateTrackMetadataService
    1. resolve actor
    2. load track
    3. build resource context
    4. authorize EDIT_TRACK_METADATA
    5. validate command
    6. update allowed fields
    7. persist
    8. emit domain and audit events
```

For state-sensitive operations, revalidate immediately before final persistence if the service performs long-running work.

---

# Walker requirements

Every privileged walker must:

1. be private/authenticated where appropriate;
2. resolve the actor from the runtime session;
3. ignore client-provided role or ownership claims;
4. validate input identifiers;
5. call an application service;
6. rely on the service/policy layer for authorization;
7. return a safe typed report;
8. avoid exposing whether a private resource exists when the actor has no access.

Example conceptual walker:

```jac
walker update_course_track:priv {
    has track_id: str;
    has title: str | None = None;
    has short_description: str | None = None;

    can with entry {
        # Resolve trusted actor.
        # Call track-management service.
        # Report typed success or safe error.
    }
}
```

Do not duplicate ownership logic in every walker.

---

# Safe error mapping

Map internal authorization reasons to stable public errors.

Suggested public codes:

```text
AUTHENTICATION_REQUIRED
FORBIDDEN
LECTURER_NOT_ACTIVE
TRACK_NOT_FOUND
TRACK_NOT_EDITABLE
VERSION_NOT_EDITABLE
RESOURCE_SCOPE_MISMATCH
```

## Information-leak prevention

For private resources, it may be safer to return:

```text
TRACK_NOT_FOUND
```

instead of revealing:

```text
You do not own lecturer X's private draft course.
```

Internally, audit the precise reason.

Use consistent project-wide behavior for not-found versus forbidden responses.

---

# Authorization cache

Role and profile status may be cached briefly, but security-sensitive changes must invalidate the cache.

Invalidate when:

```text
role assigned
role revoked
lecturer approved
lecturer suspended
lecturer reinstated
profile archived
track ownership changed
track access granted
track access revoked
```

Do not cache final authorization decisions for long periods because resource state may change.

If caching is used, include:

```text
actor ID
permission
resource ID
resource version/status token
role/profile revision
```

---

# Concurrency and time-of-check concerns

A resource may change after authorization but before mutation.

Examples:

- a draft version becomes published;
- lecturer access is revoked;
- a track becomes archived;
- ownership changes;
- a submission moves out of the review queue.

Sensitive services must perform final invariant validation at persistence time.

Do not rely exclusively on an authorization check performed before a long LLM or document-processing operation.

---

# Audit logging

Emit an audit event for privileged allow and deny outcomes.

Suggested node or external event model:

```jac
obj AuthorizationAuditEvent {
    has audit_id: str;
    has actor_user_id: str | None;
    has actor_lecturer_id: str | None;

    has permission: str;
    has decision: AuthorizationDecisionType;
    has reason_code: AuthorizationReasonCode;

    has resource_type: str | None;
    has resource_id: str | None;
    has track_id: str | None;
    has track_version_id: str | None;

    has request_id: str | None;
    has occurred_at: str;
}
```

Log at minimum:

- role and profile administrative changes;
- course creation;
- private course reads where required;
- metadata mutation;
- document upload/deletion;
- blueprint approval;
- version approval/publication;
- learner enrollment-list access;
- submission review;
- authorization denials for privileged operations.

Do not log:

- passwords;
- access tokens;
- complete request bodies;
- raw learner submissions;
- raw course documents;
- LLM prompts containing sensitive material.

Audit records must not be editable by ordinary lecturers.

---

# Rate limiting and abuse controls

Authorization does not replace rate limiting.

Privileged operations that may consume significant resources should also apply quotas or rate limits:

```text
document upload
text extraction
blueprint generation
blueprint regeneration
lesson generation
bulk learner export
bulk grading review
```

An allowed actor may still be denied or delayed by operational limits through a separate error code.

---

# Configuration flags

Suggested flags:

```text
ALLOW_LECTURER_SELF_APPROVAL=false
ALLOW_LECTURER_SELF_PUBLISH=true
ALLOW_OWNER_SCALAR_FALLBACK=false
AUTHORIZATION_AUDIT_DENIES=true
PRIVATE_RESOURCE_HIDE_EXISTENCE=true
```

Defaults should favor stricter authorization.

Feature flags must not allow frontend clients to choose their own policy behavior.

---

# Example policy decisions

## Owner edits draft metadata

Input:

```text
actor: active lecturer
permission: EDIT_TRACK_METADATA
track owner: same lecturer
track status: DRAFT
```

Decision:

```json
{
  "decision": "ALLOW",
  "reason_code": "ALLOWED",
  "scope": "OWNED_TRACK"
}
```

## Lecturer edits another lecturer's draft

Decision:

```json
{
  "decision": "DENY",
  "reason_code": "RESOURCE_OWNERSHIP_REQUIRED"
}
```

## Suspended lecturer edits owned course

Decision:

```json
{
  "decision": "DENY",
  "reason_code": "LECTURER_PROFILE_SUSPENDED"
}
```

## Owner directly edits published version

Decision:

```json
{
  "decision": "DENY",
  "reason_code": "VERSION_IMMUTABLE"
}
```

## Lecturer reviews unrelated learner submission

Decision:

```json
{
  "decision": "DENY",
  "reason_code": "LEARNER_DATA_SCOPE_DENIED"
}
```

---

# Migration requirements

## Existing lecturer records

After `35-user-roles-and-lecturer-profile.md` migration:

1. resolve active lecturer role assignments;
2. verify profile-to-user relationships;
3. identify lecturer-created tracks;
4. backfill trusted ownership edges if missing;
5. compare scalar and graph ownership;
6. quarantine conflicts;
7. enable owner-scoped policies only after validation.

## Existing development/admin walkers

Inventory privileged walkers that currently:

- accept `owner_id`;
- accept `lecturer_id`;
- check unrestricted role strings;
- expose course data publicly;
- mutate track status directly;
- return all learners;
- read submissions only by ID.

Replace these checks with the policy service.

## Compatibility phase

A temporary scalar ownership fallback may remain only if:

```text
edge missing
AND owner_id valid
AND no contradictory graph ownership
AND fallback feature flag enabled
```

Every fallback use must emit a migration metric.

---

# Testing strategy

Authorization tests must prioritize negative cases.

Use isolated Jac graph state and test:

- policy predicates;
- full policy evaluation;
- repository relationship validation;
- service integration;
- walker endpoint behavior;
- audit generation;
- cache invalidation;
- migration compatibility.

## Actor-resolution tests

- unauthenticated request creates no privileged actor;
- active lecturer role resolves lecturer profile;
- revoked lecturer role is ignored;
- profile belonging to another user is rejected;
- multi-role user resolves both learner and lecturer identities;
- client-supplied role is ignored;
- client-supplied lecturer ID is ignored.

## Profile-state tests

- active lecturer can manage an owned draft;
- pending lecturer cannot create a course;
- suspended lecturer cannot manage owned tracks;
- archived lecturer cannot access course management;
- administrator may approve a pending lecturer when explicitly permitted.

## Ownership tests

- owner may view private draft;
- unrelated lecturer cannot view private draft;
- owner may edit draft metadata;
- unrelated lecturer cannot edit draft metadata;
- scalar/edge ownership conflict denies access;
- missing edge fallback is allowed only under configured compatibility mode;
- system track cannot be edited by lecturer owner policies.

## Version tests

- owner may edit draft version;
- editor may edit assigned draft version;
- reviewer cannot perform ordinary editing;
- published version is immutable;
- superseded version is immutable;
- version from another track is denied;
- version publication requires explicit permission.

## Document tests

- owner may upload to editable draft version;
- owner cannot upload to published version;
- unrelated lecturer cannot view source document;
- learner cannot access raw source document;
- draft document deletion is denied when ownership fails;
- archived course rejects new uploads.

## Blueprint tests

- owner may view owned blueprint;
- editor may edit draft blueprint;
- reviewer may approve when assigned;
- self-approval follows configuration;
- learner cannot access blueprint authoring data;
- cross-version blueprint access is denied.

## Learner-data tests

- lecturer can list learners enrolled in owned course;
- lecturer cannot list all platform learners;
- lecturer cannot view unrelated enrollment;
- lecturer can review submission belonging to owned track;
- lecturer cannot review submission from another track;
- submission ID guessing does not bypass scope validation;
- cross-version mismatch is denied;
- response projection excludes unrelated private data.

## Administrator tests

- admin with explicit permission may archive another lecturer's track;
- admin without required permission is denied;
- admin cannot directly mutate published curriculum;
- admin actions generate audit events;
- ordinary lecturer cannot assign roles.

## Information-leak tests

- private resource response follows configured not-found behavior;
- denial reports omit owner identity;
- audit event retains precise internal reason;
- list operations do not reveal inaccessible resources;
- error messages do not expose graph topology.

## Cache tests

- role revocation invalidates cached authorization context;
- lecturer suspension takes effect immediately or within documented strict TTL;
- track-access revocation invalidates assignment cache;
- resource-status change prevents stale permission use.

## Concurrency tests

- version published after initial check cannot be mutated;
- course archived during processing cannot receive finalized unauthorized mutation;
- collaborator access revoked before persistence causes denial;
- repeated requests remain idempotent where required.

---

# Example Jac test outlines

Adapt syntax to the installed Jac version and project conventions.

```jac
test "active owner may edit draft track" {
    # Arrange authenticated user, active lecturer role/profile,
    # owned draft track, and matching OWNS_TRACK edge.
    # Evaluate EDIT_TRACK_METADATA.
    # Assert ALLOW and OWNED_TRACK scope.
}

test "lecturer cannot edit another lecturer's track" {
    # Arrange two active lecturers and one owned track.
    # Evaluate the non-owner actor.
    # Assert DENY with RESOURCE_OWNERSHIP_REQUIRED.
}

test "published version remains immutable for owner" {
    # Arrange an owned published version.
    # Evaluate EDIT_DRAFT_VERSION.
    # Assert DENY with VERSION_IMMUTABLE.
}

test "submission access requires same track enrollment" {
    # Arrange owned track and submission from another track.
    # Evaluate VIEW_COURSE_SUBMISSION.
    # Assert DENY with LEARNER_DATA_SCOPE_DENIED.
}

test "client role claim grants no permission" {
    # Make an authenticated learner-only request containing role='ADMIN'.
    # Resolve actor from trusted identity.
    # Assert privileged action is denied.
}
```

---

# Implementation sequence

## Step 1 — Audit privileged operations

List all current and planned lecturer/admin walkers and classify:

```text
permission
resource type
required scope
allowed states
safe public error
```

## Step 2 — Add permission and decision types

Implement:

- lecturer permissions;
- administrative permissions;
- scopes;
- reason codes;
- actor context;
- resource context;
- decision object.

## Step 3 — Implement actor resolver

Resolve authentication identity, active roles, lecturer profile, and status.

## Step 4 — Backfill and validate ownership

Create or validate `OWNS_TRACK` relationships and report conflicts.

## Step 5 — Implement reusable predicates

Start with:

```text
is_authenticated
has_active_lecturer_profile
owns_track
can_edit_version
can_access_enrollment
can_access_submission
```

## Step 6 — Implement policy service

Centralize decision order and stable denial reasons.

## Step 7 — Integrate application services

Protect track, version, document, blueprint, learner-list, and submission-review services.

## Step 8 — Protect walkers

Use private walkers where required and remove duplicated ad hoc checks.

## Step 9 — Add audit events

Log privileged allows and denials according to configuration.

## Step 10 — Add negative security tests

Test unauthorized users, unrelated lecturers, suspended profiles, cross-track IDs, and stale state.

## Step 11 — Enable strict mode

Disable scalar ownership fallback after migration validation.

---

# Acceptance criteria

## Actor trust

- [ ] Actor identity comes only from trusted authentication state.
- [ ] Client role and ownership claims are ignored.
- [ ] Active role assignments are resolved centrally.
- [ ] Lecturer profile ownership is validated.
- [ ] Suspended and archived lecturers lose privileged access.

## Policy model

- [ ] Typed permissions exist.
- [ ] Typed reason codes exist.
- [ ] Authorization defaults to denial.
- [ ] Policy evaluation is centralized.
- [ ] Resource-state checks are enforced.
- [ ] Published versions remain immutable.

## Ownership

- [ ] Owner-scoped operations validate trusted ownership.
- [ ] Scalar and graph ownership conflicts are denied.
- [ ] System tracks cannot be modified through lecturer-owner permissions.
- [ ] Ownership fallback is temporary, observable, and feature-flagged.

## Course authoring

- [ ] Private drafts are visible only to authorized actors.
- [ ] Track metadata mutations are authorized.
- [ ] Version creation and editing are authorized.
- [ ] Document access is track/version scoped.
- [ ] Blueprint access is track/version scoped.
- [ ] Publication requires an explicit permission.

## Learner data

- [ ] Lecturer learner lists are course-scoped.
- [ ] Submission access resolves the full track relationship.
- [ ] Cross-track and cross-version access is denied.
- [ ] Learner projections return minimum required data.
- [ ] Submission-ID guessing does not bypass authorization.

## Administration

- [ ] Administrative actions require explicit permissions.
- [ ] Administrator actions remain subject to domain invariants.
- [ ] Ordinary lecturers cannot assign or revoke privileged roles.

## Operations

- [ ] Authorization events are audited safely.
- [ ] Role/profile/access changes invalidate caches.
- [ ] Long-running operations revalidate sensitive state.
- [ ] Public errors do not leak private resource details.
- [ ] Negative security tests pass.

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
1. An unauthenticated request cannot create a course.
2. A learner-only user cannot invoke lecturer management walkers.
3. An active lecturer can create and manage their own draft course.
4. The same lecturer cannot manage another lecturer's private course.
5. A suspended lecturer immediately loses management access.
6. An owner cannot directly mutate a published version.
7. A lecturer can view only learners enrolled in an authorized course.
8. A guessed submission ID from another course is denied.
9. An administrator requires explicit permission for privileged operations.
10. Denied private-resource requests do not reveal sensitive metadata.
11. Authorization allow and deny events are recorded.
12. Revoking a role or track assignment invalidates cached access.
```

---

# Expected result

After this specification is implemented:

- lecturer permissions are derived from trusted authentication state;
- role, profile status, ownership, assignment, resource state, and track scope are evaluated consistently;
- privileged walkers no longer contain duplicated ad hoc authorization logic;
- lecturers can manage only courses they own or are explicitly assigned to;
- published curriculum remains immutable;
- learner and submission access is restricted to the lecturer's course graph;
- administrator operations are explicit and auditable;
- private resources do not leak through list, detail, or error responses;
- later course creation, upload, review, publication, and analytics features can safely rely on one authorization layer.

---

## Official Jac/Jaseci references

Implementation must be verified against the versions installed by the project:

- Authentication tutorial: https://docs.jaseci.org/tutorials/fullstack/auth/
- Jac Scale HTTP and walkers: https://docs.jaseci.org/reference/plugins/jac-scale-http/
- Jac Scale release notes: https://docs.jaseci.org/community/release_notes/jac-scale/
- Jac Client release notes: https://docs.jaseci.org/community/release_notes/jac-client/
- Jac configuration reference: https://docs.jaseci.org/reference/config/
