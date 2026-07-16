# 35-user-roles-and-lecturer-profile.md

## Overview

Extend GraphLearn LMS authentication and identity models so one authenticated user can be represented as a learner, lecturer, administrator, or a permitted combination of roles.

This specification introduces:

- typed user roles;
- a lecturer profile node;
- role-assignment relationships;
- lecturer onboarding state;
- lecturer ownership identity for courses;
- centralized role and profile resolution;
- authorization-ready service contracts;
- migration of existing learner-only identities;
- tests for role isolation and graph integrity.

The implementation must extend the current authentication system. It must not introduce a separate lecturer login database, duplicate password storage, or a second session mechanism.

---

## Status

- **Feature type:** Identity and authorization foundation
- **Subsystem:** Lecturer identity and course management
- **Priority:** Critical
- **Depends on:**
  - `29-learning-track-domain-model.md`
  - `32-learning-track-osp-schema.md`
  - `33-track-repositories-and-services.md`
  - `34-track-aware-walker-migration.md`
- **Blocks:**
  - `36-lecturer-authorization-policies.md`
  - `37-create-and-manage-course-track.md`
  - lecturer course ownership
  - lecturer document upload
  - lecturer dashboard
- **Primary implementation language:** Jac
- **Breaking changes allowed:** No
- **Migration required:** Yes

---

## Problem statement

The current LMS primarily authenticates learners and associates an authenticated session with a learner identity.

The lecturer-course extension requires authenticated users who can:

- create course tracks;
- upload course notes;
- review generated curriculum;
- publish course versions;
- view learners enrolled in their courses;
- review low-confidence grading results;
- manage course metadata.

These privileges must not be granted merely because a request contains a lecturer ID or role string.

The system needs a trusted identity model in which:

```text
Authenticated user
    ├── learner role → LearnerProfile
    ├── lecturer role → LecturerProfile
    └── admin role → administrative permissions
```

A lecturer-created `LearningTrack` must reference a lecturer identity derived from the authenticated session rather than a caller-provided owner ID.

---

## Goals

Implement an identity model that:

1. Reuses the existing user registration, login, and session system.
2. Supports typed roles instead of unrestricted role strings.
3. Preserves all existing learner accounts and learner flows.
4. Adds a persistent `LecturerProfile` node.
5. Allows one user to hold more than one authorized role.
6. Establishes a trusted lecturer identifier for course ownership.
7. Separates authentication identity from role-specific profile data.
8. Supports lecturer onboarding and approval states.
9. Prevents clients from self-assigning privileged roles.
10. Provides repository and service APIs for resolving roles and profiles.
11. Makes authorization decisions auditable.
12. Supports later institution-level roles without redesigning the base identity model.

---

## Non-goals

This specification does not implement:

- complete per-walker authorization rules;
- course creation UI;
- document upload;
- course publication;
- institution membership;
- lecturer analytics;
- invitation email delivery;
- administrator dashboard;
- learner enrollment;
- course grading review UI;
- payment or subscription roles;
- external identity providers;
- multi-factor authentication.

Those features may consume the identity model defined here.

---

# Design principles

## 1. One authentication identity

A user must authenticate once and receive one trusted session identity.

Do not create separate credential systems such as:

```text
LearnerAccount
LecturerAccount
AdminAccount
```

Use:

```text
UserIdentity
    ├── roles
    └── role-specific profiles
```

## 2. Roles grant capabilities, profiles store role-specific data

A role answers:

```text
What category of access may this user have?
```

A profile answers:

```text
What lecturer- or learner-specific data belongs to this user?
```

Possessing a lecturer profile without an active lecturer role must not grant lecturer permissions.

## 3. The authenticated session is authoritative

Never trust these client-supplied values as proof of identity:

```text
user_id
lecturer_id
owner_id
role
is_admin
```

The server must derive the actor from the authenticated Jac session.

## 4. Privileged roles require controlled assignment

Ordinary public registration must not permit users to assign themselves:

```text
LECTURER
ADMIN
SUPER_ADMIN
```

## 5. Multi-role support

A lecturer may also enroll in a course as a learner.

The model should support:

```text
User A → LEARNER + LECTURER
```

without duplicating the authentication account.

## 6. Explicit lifecycle

A lecturer profile must have an explicit onboarding and approval state.

A newly created profile must not automatically gain production publishing privileges unless the chosen business rule permits it.

---

# Current identity audit

Before implementation, document the current authentication model.

Inspect:

- the existing user node or built-in user identity;
- registration walker or `/user/register` flow;
- login walker or `/user/login` flow;
- `AuthSession` model;
- `current_auth_session` behavior;
- `read_auth_session` behavior;
- where `learner_id` is created and stored;
- how authenticated roots are resolved;
- how frontend local storage stores session data;
- whether email or username is the stable login identity;
- existing administrator concepts;
- existing public/private walker declarations.

Produce an audit table:

| Concern | Current implementation | Required change |
|---|---|---|
| Authentication identity | Existing Jac user/session | Reuse unchanged |
| Learner identity | Existing learner node | Link through role/profile model |
| Role information | Missing or implicit | Add typed role assignments |
| Lecturer profile | Missing | Add persistent node |
| Course ownership | Not available | Use authenticated lecturer ID |
| Admin assignment | Undefined | Add controlled service operation |

Do not replace working Jac authentication unless a verified framework limitation requires it.

---

# Domain enums

## `UserRoleType`

```jac
enum UserRoleType {
    LEARNER,
    LECTURER,
    ADMIN
}
```

Initial meaning:

| Role | Meaning |
|---|---|
| `LEARNER` | Can enroll in tracks and use learner flows |
| `LECTURER` | Can use permitted lecturer course-management flows |
| `ADMIN` | Can execute approved administrative identity and course operations |

Do not add `SUPER_ADMIN` unless the project has a real distinction that cannot be handled through policy.

## `RoleAssignmentStatus`

```jac
enum RoleAssignmentStatus {
    PENDING,
    ACTIVE,
    SUSPENDED,
    REVOKED
}
```

## `LecturerProfileStatus`

```jac
enum LecturerProfileStatus {
    DRAFT,
    PENDING_REVIEW,
    ACTIVE,
    SUSPENDED,
    REJECTED,
    ARCHIVED
}
```

## `LecturerVerificationStatus`

```jac
enum LecturerVerificationStatus {
    NOT_REQUIRED,
    UNVERIFIED,
    PENDING,
    VERIFIED,
    FAILED
}
```

The initial project may use `NOT_REQUIRED` for development and hackathon deployment, while retaining the type for later production verification.

## `RoleAssignmentSource`

```jac
enum RoleAssignmentSource {
    SYSTEM,
    REGISTRATION,
    ADMIN,
    INVITATION,
    MIGRATION
}
```

---

# Core identity model

## Authentication user

Reuse the existing authenticated Jac user identity.

Do not duplicate credentials inside domain nodes.

The domain layer should resolve a stable user identifier, referred to in this specification as:

```text
user_id
```

The exact value may be the existing Jac user ID, root ID, or application user identifier, provided it is:

- stable;
- unique;
- server-derived;
- available from the trusted session;
- never accepted from the client as authentication proof.

If the current project already has a `User` node containing authentication-facing identity, extend or adapt it rather than creating a competing identity node.

---

## `UserIdentityProfile`

Use this node only when the current authentication user cannot safely hold application profile metadata.

```jac
node UserIdentityProfile {
    has identity_profile_id: str;
    has user_id: str;

    has display_name: str;
    has email_snapshot: str | None = None;
    has username_snapshot: str | None = None;

    has is_active: bool = True;

    has created_at: str;
    has updated_at: str;
    has last_seen_at: str | None = None;
}
```

This node must not store:

- password hashes;
- refresh tokens;
- access tokens;
- raw session tokens;
- authentication secrets.

If an equivalent existing user-profile node is already present, reuse it.

---

# Role assignment model

## `UserRoleAssignment`

Represent role assignments as nodes when lifecycle, auditing, assignment source, and suspension state need to be persisted.

```jac
node UserRoleAssignment {
    has role_assignment_id: str;
    has user_id: str;
    has role_type: UserRoleType;

    has status: RoleAssignmentStatus =
        RoleAssignmentStatus.PENDING;

    has source: RoleAssignmentSource;

    has granted_by: str | None = None;
    has reason: str = "";

    has created_at: str;
    has activated_at: str | None = None;
    has suspended_at: str | None = None;
    has revoked_at: str | None = None;
    has updated_at: str;
}
```

## Why use assignment nodes

A scalar list such as:

```jac
has roles: list[str];
```

is simpler, but does not safely capture:

- who assigned a role;
- whether it is pending;
- why it was suspended;
- when it was revoked;
- role-assignment audit history;
- future institution-scoped roles.

A role-assignment node provides a stronger foundation.

A denormalized active-role cache may be added later for performance, but assignment nodes remain authoritative.

---

# Role graph edges

## `HAS_IDENTITY_PROFILE`

```jac
edge HAS_IDENTITY_PROFILE {}
```

Direction:

```text
Authenticated user/root → UserIdentityProfile
```

## `HAS_ROLE_ASSIGNMENT`

```jac
edge HAS_ROLE_ASSIGNMENT {
    has created_at: str;
}
```

Direction:

```text
Authenticated user/root or identity profile
    → UserRoleAssignment
```

Choose one canonical parent and use it consistently.

## `HAS_LEARNER_PROFILE`

```jac
edge HAS_LEARNER_PROFILE {
    has created_at: str;
}
```

Direction:

```text
Authenticated user/root or identity profile
    → LearnerProfile
```

## `HAS_LECTURER_PROFILE`

```jac
edge HAS_LECTURER_PROFILE {
    has created_at: str;
}
```

Direction:

```text
Authenticated user/root or identity profile
    → LecturerProfile
```

## `ASSIGNED_ROLE`

If the project prefers direct graph semantics, an edge may connect a role assignment to a role descriptor. Do not add this complexity unless role descriptors are modeled as nodes.

---

# Lecturer profile

## `LecturerProfile`

```jac
node LecturerProfile {
    has lecturer_id: str;
    has user_id: str;

    has display_name: str;
    has professional_title: str | None = None;

    has institution_name: str | None = None;
    has institution_id: str | None = None;
    has department: str | None = None;

    has biography: str = "";
    has areas_of_expertise: list[str] = [];

    has staff_number: str | None = None;

    has status: LecturerProfileStatus =
        LecturerProfileStatus.DRAFT;

    has verification_status: LecturerVerificationStatus =
        LecturerVerificationStatus.UNVERIFIED;

    has profile_completed: bool = False;
    has can_create_courses: bool = False;
    has can_publish_courses: bool = False;
    has can_review_grading: bool = False;

    has created_at: str;
    has updated_at: str;
    has activated_at: str | None = None;
    has suspended_at: str | None = None;
    has archived_at: str | None = None;
}
```

---

## Lecturer field rules

### `lecturer_id`

Requirements:

- globally unique;
- immutable;
- server-generated;
- not based on email or username;
- used as course ownership identity.

Recommended format:

```text
lec_<uuid>
```

### `user_id`

Requirements:

- references the authenticated user identity;
- unique among active lecturer profiles;
- server-derived;
- cannot be changed through normal profile editing.

A user should have at most one active lecturer profile in the initial implementation.

### `display_name`

- required before activation;
- trimmed;
- length-limited;
- may default from existing user profile information;
- sanitized before display.

### `professional_title`

Examples:

```text
Lecturer
Senior Lecturer
Professor
Course Instructor
Teaching Assistant
```

Do not use this display field for authorization.

### `institution_name`

Use plain text initially if institution nodes are not available.

### `institution_id`

Reserved for future institution graph integration.

A non-null value must be validated when institution support is implemented.

### `department`

Examples:

```text
Computer Science
Business Administration
Marketing
Mathematics
```

### `areas_of_expertise`

Requirements:

- normalized text values;
- duplicates removed;
- bounded list length;
- not used as automatic permission grants.

### `staff_number`

- optional;
- private administrative metadata;
- not exposed to ordinary learners;
- not globally unique unless scoped to an institution;
- never used as an authentication secret.

### capability flags

The flags:

```text
can_create_courses
can_publish_courses
can_review_grading
```

are coarse operational capabilities.

They must not replace role and policy checks.

A valid lecturer operation should require:

```text
active lecturer role
AND active lecturer profile
AND required capability
AND resource-level authorization
```

---

# Learner profile compatibility

Reuse the current learner model.

If the project has a `Learner` node rather than `LearnerProfile`, do not duplicate it solely for naming consistency.

Ensure it can be resolved from the authenticated user through one canonical relationship.

Conceptual model:

```jac
node LearnerProfile {
    has learner_id: str;
    has user_id: str;
    # Existing learner fields remain unchanged.
}
```

Existing learner accounts must receive an active `LEARNER` role assignment during migration.

Do not require existing learners to register again.

---

# Identity graph

Recommended graph:

```text
Authenticated user/root
├── HAS_IDENTITY_PROFILE
│   └── UserIdentityProfile
├── HAS_ROLE_ASSIGNMENT
│   ├── UserRoleAssignment: LEARNER ACTIVE
│   └── UserRoleAssignment: LECTURER ACTIVE
├── HAS_LEARNER_PROFILE
│   └── LearnerProfile
└── HAS_LECTURER_PROFILE
    └── LecturerProfile
```

Later course ownership:

```text
LecturerProfile
└── OWNS_TRACK
    └── LearningTrack
```

Course ownership must reference `lecturer_id`, not a display name or email.

---

# Domain invariants

## User identity invariants

1. Every role assignment belongs to one authenticated user.
2. Every lecturer profile belongs to one authenticated user.
3. A user has at most one non-archived lecturer profile initially.
4. A user has at most one active assignment for each role type.
5. Authentication secrets are not copied into profile nodes.
6. Client input cannot override the session user ID.

## Role invariants

1. Public registration may create `LEARNER` only.
2. `LECTURER` and `ADMIN` require controlled assignment.
3. A revoked assignment cannot become active without a new grant or explicit reinstatement policy.
4. A suspended assignment grants no active permissions.
5. Duplicate active assignments are prohibited.
6. Role checks use enum values, not free-form strings.

## Lecturer-profile invariants

1. An active lecturer profile requires an active lecturer role assignment.
2. A lecturer role may be pending while the profile is incomplete.
3. `can_create_courses` cannot be true for a suspended profile.
4. `can_publish_courses` cannot be true for a suspended profile.
5. `can_review_grading` cannot be true for a suspended profile.
6. An archived profile grants no lecturer capabilities.
7. Course ownership remains historically linked when a lecturer is suspended.
8. Suspending a lecturer must not delete their courses.

## Multi-role invariants

1. A lecturer may also have an active learner role.
2. Lecturer suspension must not automatically suspend learner access unless explicitly required.
3. Learner progress must remain separate from lecturer-created course ownership.
4. Role-specific dashboard selection must not alter the authenticated identity.

---

# Role lifecycle

## Role assignment transitions

```text
PENDING
├── ACTIVE
├── REVOKED
└── SUSPENDED

ACTIVE
├── SUSPENDED
└── REVOKED

SUSPENDED
├── ACTIVE
└── REVOKED

REVOKED
└── terminal by default
```

Re-granting a revoked role should normally create a new assignment record to preserve audit history.

---

# Lecturer profile lifecycle

```text
DRAFT
├── PENDING_REVIEW
├── ACTIVE
├── REJECTED
└── ARCHIVED

PENDING_REVIEW
├── ACTIVE
├── REJECTED
├── DRAFT
└── ARCHIVED

ACTIVE
├── SUSPENDED
└── ARCHIVED

SUSPENDED
├── ACTIVE
└── ARCHIVED

REJECTED
├── DRAFT
└── ARCHIVED
```

All lifecycle transitions must be performed through a service.

Ordinary update walkers must not directly mutate status fields.

---

# Lecturer onboarding modes

Support configuration for at least two deployment modes.

## Mode A: Controlled administrator approval

```text
User requests lecturer role
→ profile created
→ role assignment PENDING
→ profile PENDING_REVIEW
→ admin approves
→ assignment ACTIVE
→ profile ACTIVE
```

Recommended for production.

## Mode B: Development auto-activation

```text
Trusted development operation
→ lecturer profile created
→ assignment ACTIVE
→ profile ACTIVE
```

This mode must be protected by environment configuration and unavailable in normal public production registration.

Example configuration:

```text
LECTURER_ONBOARDING_MODE=ADMIN_APPROVAL
```

Allowed values:

```text
ADMIN_APPROVAL
INVITATION_ONLY
DEVELOPMENT_AUTO_ACTIVATE
```

Never infer auto-activation simply because the environment variable is missing.

---

# Typed contracts

## `AuthenticatedActor`

```jac
obj AuthenticatedActor {
    has user_id: str;
    has username: str | None = None;
    has email: str | None = None;

    has active_roles: list[UserRoleType] = [];

    has learner_id: str | None = None;
    has lecturer_id: str | None = None;

    has is_authenticated: bool = False;
}
```

This object must be built server-side from the trusted session and graph state.

## `LecturerProfileInput`

```jac
obj LecturerProfileInput {
    has display_name: str;
    has professional_title: str | None = None;
    has institution_name: str | None = None;
    has department: str | None = None;
    has biography: str = "";
    has areas_of_expertise: list[str] = [];
    has staff_number: str | None = None;
}
```

Do not include:

```text
user_id
lecturer_id
role
status
capability flags
```

in ordinary untrusted profile input.

## `LecturerProfileSummary`

```jac
obj LecturerProfileSummary {
    has lecturer_id: str;
    has display_name: str;
    has professional_title: str | None;
    has institution_name: str | None;
    has department: str | None;
    has areas_of_expertise: list[str];
    has status: LecturerProfileStatus;
    has verification_status: LecturerVerificationStatus;
    has profile_completed: bool;
}
```

Do not expose private administrative fields in public course views.

## `RoleAssignmentResult`

```jac
obj RoleAssignmentResult {
    has role_assignment_id: str;
    has user_id: str;
    has role_type: UserRoleType;
    has status: RoleAssignmentStatus;
    has source: RoleAssignmentSource;
}
```

---

# Session resolution

Extend the current session resolution into one authoritative identity service.

Suggested operation:

```jac
def resolve_authenticated_actor() -> AuthenticatedActor;
```

It must:

1. read the trusted Jac authentication session;
2. reject unauthenticated sessions;
3. resolve the stable user ID;
4. load active role assignments;
5. load the learner profile when present;
6. load the lecturer profile when present;
7. validate role/profile consistency;
8. return a typed actor object.

Do not scatter direct session parsing across walkers.

## Required helper checks

```jac
def has_active_role(
    actor: AuthenticatedActor,
    role: UserRoleType
) -> bool;

def require_active_role(
    actor: AuthenticatedActor,
    role: UserRoleType
) -> None;

def require_lecturer_actor(
    actor: AuthenticatedActor
) -> LecturerProfile;

def require_admin_actor(
    actor: AuthenticatedActor
) -> None;
```

Full resource authorization remains in `36-lecturer-authorization-policies.md`.

---

# Repository contracts

## `IdentityRepository`

```jac
obj IdentityRepository {
    def find_identity_profile_by_user_id(
        user_id: str
    ) -> UserIdentityProfile | None;

    def list_role_assignments(
        user_id: str
    ) -> list[UserRoleAssignment];

    def find_active_role_assignment(
        user_id: str,
        role_type: UserRoleType
    ) -> UserRoleAssignment | None;

    def find_learner_profile(
        user_id: str
    ) -> LearnerProfile | None;

    def find_lecturer_profile(
        user_id: str
    ) -> LecturerProfile | None;

    def save_role_assignment(
        assignment: UserRoleAssignment
    ) -> None;

    def save_lecturer_profile(
        profile: LecturerProfile
    ) -> None;
}
```

## `LecturerRepository`

```jac
obj LecturerRepository {
    def find_by_lecturer_id(
        lecturer_id: str
    ) -> LecturerProfile | None;

    def find_by_user_id(
        user_id: str
    ) -> LecturerProfile | None;

    def list_by_status(
        status: LecturerProfileStatus
    ) -> list[LecturerProfile];

    def save(
        profile: LecturerProfile
    ) -> None;
}
```

Repositories must verify graph relationships and not trust scalar identifiers alone.

---

# Service contracts

## `IdentityService`

Responsibilities:

```text
resolve authenticated actor
list active roles
validate role assignment consistency
resolve learner identity
resolve lecturer identity
```

## `RoleManagementService`

Responsibilities:

```text
request lecturer role
assign role
activate role
suspend role
revoke role
restore suspended role
list user roles
validate duplicate assignment
emit audit events
```

Privileged methods require an authorized administrator or trusted migration context.

## `LecturerProfileService`

Responsibilities:

```text
create draft lecturer profile
update lecturer profile
calculate profile completion
submit profile for review
activate profile
reject profile
suspend profile
restore profile
archive profile
resolve course-owner identity
```

## `LecturerOnboardingService`

Coordinates:

```text
role assignment
lecturer profile creation
onboarding mode
approval state
capability defaults
notifications or reports
```

---

# Profile-completion rules

Calculate `profile_completed` server-side.

Initial required fields:

```text
display_name
institution_name or explicit independent status
area of expertise
```

A stricter production policy may require:

```text
professional title
department
verified institutional email
staff number
```

Do not trust a client-supplied `profile_completed` boolean.

Example helper:

```jac
def calculate_lecturer_profile_completion(
    profile: LecturerProfile
) -> bool;
```

---

# Capability defaults

## Draft or pending profile

```text
can_create_courses = false
can_publish_courses = false
can_review_grading = false
```

## Active lecturer in initial release

```text
can_create_courses = true
can_publish_courses = true or policy-controlled
can_review_grading = true
```

For safer production rollout:

```text
can_create_courses = true
can_publish_courses = false until approved
can_review_grading = true for owned courses
```

The final choice must be controlled through configuration and authorization policy, not frontend behavior.

---

# Course ownership integration

A later course-creation service must derive:

```text
owner_id = actor.lecturer_id
ownership_type = LECTURER
track_type = LECTURER_COURSE
```

The client must not choose another lecturer as owner.

Recommended relationship:

```jac
edge OWNS_TRACK {
    has granted_at: str;
}
```

Direction:

```text
LecturerProfile → LearningTrack
```

The scalar `LearningTrack.owner_id` and the `OWNS_TRACK` edge must agree.

If they disagree, course-management operations must fail with a graph-integrity error.

---

# Minimal walkers

## `get_current_identity`

Purpose:

- return the current actor's active roles and profile identifiers;
- support frontend role-aware navigation.

Example output:

```json
{
  "ok": true,
  "identity": {
    "user_id": "usr_123",
    "active_roles": ["LEARNER", "LECTURER"],
    "learner_id": "lrn_123",
    "lecturer_id": "lec_123"
  }
}
```

Do not expose internal role-assignment records unless needed.

## `get_my_lecturer_profile`

Returns the authenticated user's lecturer profile.

It must not accept an arbitrary `user_id`.

## `update_my_lecturer_profile`

Accepts only editable profile fields.

It must not allow ordinary users to update:

```text
lecturer_id
user_id
status
verification_status
capability flags
```

## `request_lecturer_role`

Creates or resumes a controlled lecturer-onboarding workflow.

It must be idempotent.

## Administrative walkers

Potential internal/admin walkers:

```text
approve_lecturer
reject_lecturer
suspend_lecturer
restore_lecturer
revoke_user_role
```

These must be private or strictly protected.

---

# Walker response patterns

## Success

```json
{
  "ok": true,
  "profile": {
    "lecturer_id": "lec_123",
    "display_name": "Dr. Example",
    "status": "ACTIVE",
    "profile_completed": true
  }
}
```

## Missing role

```json
{
  "ok": false,
  "error": {
    "code": "LECTURER_ROLE_REQUIRED",
    "message": "An active lecturer role is required.",
    "details": {}
  }
}
```

## Suspended profile

```json
{
  "ok": false,
  "error": {
    "code": "LECTURER_PROFILE_SUSPENDED",
    "message": "This lecturer profile is currently suspended.",
    "details": {
      "lecturer_id": "lec_123"
    }
  }
}
```

Do not reveal sensitive administrative reasons to ordinary clients unless policy permits it.

---

# Domain errors

Required error codes:

```text
AUTHENTICATION_REQUIRED
IDENTITY_NOT_FOUND
IDENTITY_GRAPH_INVALID
ROLE_ASSIGNMENT_NOT_FOUND
ROLE_ALREADY_ACTIVE
ROLE_ASSIGNMENT_CONFLICT
ROLE_NOT_ACTIVE
ROLE_SUSPENDED
ROLE_REVOKED
ROLE_ASSIGNMENT_FORBIDDEN
LECTURER_ROLE_REQUIRED
LECTURER_PROFILE_NOT_FOUND
LECTURER_PROFILE_ALREADY_EXISTS
LECTURER_PROFILE_INCOMPLETE
LECTURER_PROFILE_NOT_ACTIVE
LECTURER_PROFILE_SUSPENDED
LECTURER_PROFILE_ARCHIVED
INVALID_LECTURER_STATUS_TRANSITION
INVALID_ROLE_STATUS_TRANSITION
ADMIN_ROLE_REQUIRED
COURSE_OWNER_IDENTITY_INVALID
```

---

# Registration behavior

## Existing public registration

The current public registration flow should create:

```text
active authenticated user
active LEARNER role assignment
learner profile
```

It must not accept arbitrary privileged role input.

Unsafe payload:

```json
{
  "username": "example",
  "password": "...",
  "role": "ADMIN"
}
```

The `role` field must be ignored or rejected.

## Lecturer onboarding

Lecturer onboarding occurs after authentication through:

- an administrator invitation;
- an administrator assignment;
- a lecturer-role request;
- a trusted development seed;
- a migration.

Do not maintain a separate lecturer password.

---

# Frontend implications

The frontend must resolve roles after login.

Suggested client identity type:

```ts
export type UserRole = "LEARNER" | "LECTURER" | "ADMIN";

export interface CurrentIdentity {
  userId: string;
  activeRoles: UserRole[];
  learnerId?: string | null;
  lecturerId?: string | null;
}
```

Role-aware navigation may display:

```text
Learner Dashboard
Lecturer Dashboard
Admin Area
```

Hiding navigation is not authorization.

Backend walkers must independently enforce permissions.

## Role switching

A multi-role user may choose a UI workspace:

```text
Learner workspace
Lecturer workspace
```

This is a frontend context selection only.

It must not alter the authenticated roles or issue a less-trusted client-selected identity.

---

# Migration of existing users

Existing accounts must remain functional.

## Migration goals

For every existing authenticated user with learner state:

1. resolve the trusted `user_id`;
2. retain the existing learner node;
3. ensure a canonical user-to-learner relationship exists;
4. create one active `LEARNER` role assignment when absent;
5. avoid duplicate assignments;
6. preserve learner IDs;
7. preserve assessment and roadmap relationships;
8. produce a migration record.

## Migration mapping

```text
Existing authenticated user + learner node
→ existing user identity
→ ACTIVE LEARNER assignment
→ existing learner profile relationship
```

Do not generate new learner IDs when an existing learner node is valid.

## Lecturer seed users

Development or demo lecturer users may be created through an explicit seed file.

Use deterministic IDs only for known demo accounts.

Never seed a default production password in source control.

## Migration idempotency

A second migration run must create:

```text
0 duplicate learner profiles
0 duplicate lecturer profiles
0 duplicate active learner assignments
0 duplicate profile edges
```

---

# Migration record

```jac
obj UserRoleMigrationRecord {
    has migration_id: str;
    has migration_version: int;
    has user_id: str;
    has learner_id: str | None = None;
    has lecturer_id: str | None = None;
    has status: str;
    has message: str = "";
    has migrated_at: str | None = None;
}
```

Statuses:

```text
MIGRATED
UNCHANGED
SKIPPED
CONFLICT
FAILED
```

---

# Conflict handling

Conflicts include:

- one user connected to multiple active lecturer profiles;
- one lecturer profile referencing multiple user IDs;
- duplicate active role assignments;
- learner profile belonging to another user;
- scalar user ID and graph relationship mismatch;
- suspended role with active capability grants;
- active lecturer profile without an active lecturer role.

Conflict behavior:

1. do not delete records automatically;
2. do not choose an arbitrary identity;
3. mark the identity graph invalid;
4. emit an audit event;
5. block privileged operations;
6. preserve ordinary learner access when safely separable;
7. require deterministic repair or administrative review.

---

# Persistence requirements

- Identity and profile nodes must be connected to the authenticated user's persistent graph path.
- Shared administrative indexes must not expose private profile data to other users.
- Role assignments must survive backend restarts.
- Profile edits must update `updated_at`.
- Revocation and suspension history must remain persisted.
- Historical course ownership must survive lecturer suspension or archival.
- Destructive deletion should be avoided in favor of archival.

---

# Security requirements

1. Derive the user from the trusted session.
2. Never trust client-provided role, user ID, lecturer ID, or capability flags.
3. Prevent public role escalation.
4. Restrict admin walkers.
5. Validate role and profile state on every privileged operation.
6. Do not use frontend route guards as the only authorization layer.
7. Do not expose staff numbers publicly.
8. Do not log session tokens or passwords.
9. Do not leak private lecturer-profile existence to unauthorized callers.
10. Rate-limit role-request operations where supported.
11. Audit all privileged role changes.
12. Treat suspended accounts as denied even when cached role data exists.

---

# Caching requirements

Identity caching must be conservative.

Safe cache candidates:

```text
active role summary
lecturer profile summary
learner profile identifier
```

Cache key example:

```text
graphlearn:identity:v1:<user_id>
```

Invalidate when:

```text
role assigned
role activated
role suspended
role revoked
lecturer profile activated
lecturer profile suspended
capabilities changed
profile archived
```

Privileged operations should revalidate critical authorization state instead of trusting a long-lived cache.

---

# Observability

Emit structured events:

```text
identity.actor_resolved
identity.graph_invalid
role.requested
role.assigned
role.activated
role.suspended
role.revoked
lecturer_profile.created
lecturer_profile.updated
lecturer_profile.submitted
lecturer_profile.activated
lecturer_profile.rejected
lecturer_profile.suspended
lecturer_profile.restored
lecturer_profile.archived
identity_migration.started
identity_migration.completed
identity_migration.conflict
```

Recommended fields:

```text
user_id
lecturer_id
learner_id
role_type
assignment_id
old_status
new_status
actor_user_id
request_id
timestamp
```

Do not log:

- passwords;
- session tokens;
- full private biographies unless explicitly safe;
- staff numbers;
- raw identity documents.

---

# Metrics

Track:

```text
active_learners_total
active_lecturers_total
pending_lecturer_requests_total
suspended_lecturers_total
role_assignment_failures_total
identity_graph_conflicts_total
identity_resolution_duration_ms
unauthorized_lecturer_attempts_total
```

Metrics must not expose personally identifying labels.

---

# Testing strategy

Use Jac test blocks with isolated graph state.

## Role tests

- public registration creates only the learner role;
- a public caller cannot assign lecturer role;
- a public caller cannot assign admin role;
- duplicate active role assignments are rejected;
- pending role grants no active permission;
- suspended role grants no active permission;
- revoked role grants no active permission;
- admin assignment records `granted_by`;
- role lifecycle transitions are validated.

## Lecturer-profile tests

- creates one draft profile per user;
- duplicate active profiles are rejected;
- lecturer ID is stable;
- user ID cannot be changed;
- ordinary updates cannot change status;
- ordinary updates cannot change capability flags;
- profile completion is calculated server-side;
- active profile requires active lecturer role;
- suspended profile disables capabilities;
- archived profile grants no lecturer access.

## Multi-role tests

- a user can be learner and lecturer;
- lecturer suspension does not erase learner progress;
- learner role revocation does not delete lecturer-owned courses;
- workspace selection does not change role assignments;
- course ownership and learner enrollment remain separate.

## Session tests

- unauthenticated actor resolution fails;
- authenticated user resolves active roles;
- user-provided lecturer ID is ignored;
- graph mismatch produces `IDENTITY_GRAPH_INVALID`;
- inactive assignments are omitted from active roles.

## Migration tests

- existing learner receives active learner assignment;
- existing learner ID is preserved;
- rerunning migration creates no duplicate role assignment;
- rerunning migration creates no duplicate profile edge;
- conflicting learner ownership is reported;
- migration preserves assessment and roadmap graph relationships.

## Security tests

- learner cannot update lecturer capability flags;
- lecturer cannot approve their own role unless policy allows it;
- lecturer cannot fetch another lecturer's private profile;
- suspended lecturer cannot create a course;
- inactive role cannot call lecturer operations;
- client-supplied owner ID cannot override session identity.

## Persistence tests

- role assignments survive restart;
- lecturer profiles survive restart;
- suspension state survives restart;
- course ownership remains readable after lecturer suspension;
- archived profiles remain available for historical audit.

---

# Example Jac test outlines

```jac
test "public registration cannot self-assign lecturer role" {
    # Register through the public flow with a malicious role field.
    # Resolve active roles.
    # Assert LEARNER is active.
    # Assert LECTURER is absent.
}

test "active lecturer requires role and profile" {
    # Create an active lecturer profile without an active role.
    # Resolve lecturer actor.
    # Assert identity graph validation fails.
}

test "user may hold learner and lecturer roles" {
    # Create both active assignments and profiles.
    # Resolve actor.
    # Assert both role types and both profile IDs are returned.
}

test "role migration is idempotent" {
    # Create a legacy learner identity.
    # Run migration twice.
    # Assert one active learner role assignment exists.
}
```

---

# Implementation sequence

## Step 1: Audit current authentication

Document the current session, user root, learner identity, and auth helper behavior.

## Step 2: Add enums and domain nodes

Implement:

- role enums;
- role-assignment node;
- lecturer-profile node;
- identity edges;
- typed contracts;
- errors.

## Step 3: Add repositories

Implement bounded identity and role traversals.

## Step 4: Add actor resolution

Create one trusted `AuthenticatedActor` resolver.

## Step 5: Add role-management service

Centralize assignment, activation, suspension, and revocation.

## Step 6: Add lecturer-profile service

Implement draft creation, profile editing, completion checks, and lifecycle transitions.

## Step 7: Migrate existing learners

Create active learner assignments while preserving existing learner nodes.

## Step 8: Add minimal walkers

Implement current identity, lecturer profile, role request, and protected administration operations.

## Step 9: Add frontend role awareness

Load active roles after login and expose learner or lecturer workspaces.

## Step 10: Add tests and migration verification

Run type, graph, persistence, security, and regression tests.

---

# Acceptance criteria

## Identity

- [ ] Existing authentication remains the only credential system.
- [ ] A stable server-derived user ID is available.
- [ ] `AuthenticatedActor` resolves active roles and profile IDs.
- [ ] Unauthenticated actor resolution fails safely.

## Roles

- [ ] Roles use typed enum values.
- [ ] Role assignments record status, source, and timestamps.
- [ ] Public registration cannot self-assign privileged roles.
- [ ] Duplicate active assignments are prevented.
- [ ] Suspended and revoked roles grant no access.

## Lecturer profile

- [ ] `LecturerProfile` exists.
- [ ] `lecturer_id` is stable and immutable.
- [ ] One user has at most one active lecturer profile.
- [ ] Profile completion is calculated server-side.
- [ ] Profile lifecycle transitions are validated.
- [ ] Capability flags cannot be changed by ordinary profile updates.

## Learner compatibility

- [ ] Existing learner IDs are preserved.
- [ ] Existing learners receive active learner assignments.
- [ ] Existing assessment and roadmap flows still work.
- [ ] Existing users do not need to register again.

## Multi-role behavior

- [ ] A user can hold learner and lecturer roles.
- [ ] Role-specific data remains separated.
- [ ] Suspending lecturer access does not delete learner data.
- [ ] Frontend workspace selection does not alter authorization.

## Security

- [ ] Course owner identity can be derived from the session.
- [ ] Client-provided role and lecturer IDs are not authoritative.
- [ ] Administrative role operations are protected.
- [ ] Identity graph conflicts block privileged operations.
- [ ] Privileged role changes are audited.

## Persistence and migration

- [ ] Roles and profiles persist after restart.
- [ ] Migration is idempotent.
- [ ] Duplicate profile edges are prevented.
- [ ] Identity conflicts are reported instead of guessed.

## Quality

- [ ] `jac check` passes.
- [ ] Lint checks pass.
- [ ] `jac test` passes.
- [ ] Existing learner regression tests pass.
- [ ] Identity security tests pass.

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
1. An existing learner can still log in.
2. The existing learner ID is returned.
3. The user has an active learner role.
4. A normal user cannot self-assign lecturer role.
5. An approved lecturer can access the lecturer workspace.
6. A lecturer can also retain learner access.
7. A suspended lecturer cannot perform lecturer operations.
8. Lecturer suspension does not delete owned courses.
9. Client-provided lecturer IDs do not override session identity.
10. Role and profile data remain after backend restart.
11. Running the learner-role migration twice creates no duplicates.
12. Privileged role changes appear in audit logs.
```

---

# Expected result

After implementation:

- GraphLearn uses one trusted authentication identity for all user types;
- existing users continue to function as learners;
- lecturers have persistent role-specific profiles;
- users may safely hold learner and lecturer roles;
- lecturer course ownership can be derived from authenticated identity;
- clients cannot self-grant lecturer or administrator permissions;
- role and profile lifecycle changes are auditable;
- later lecturer authorization, course creation, upload, review, publication, and analytics specifications can build on a consistent identity foundation.
