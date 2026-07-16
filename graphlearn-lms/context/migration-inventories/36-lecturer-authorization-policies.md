# Feature 36 Privileged Operation Inventory

Publication model: reviewer/admin approval is the strict default. Owners may edit and submit; reviewer assignment or an administrator is required for approval. An owner may publish only when both the server-controlled lecturer capability and `ALLOW_LECTURER_SELF_PUBLISH=true` permit it. Self-approval defaults off.

| Operation | Current exposure | Permission | Trusted resource/scope | Allowed state | Safe public error |
|---|---|---|---|---|---|
| View/edit own lecturer profile | Private identity functions | `VIEW_OWN_PROFILE` / `EDIT_OWN_PROFILE` | Root-owned profile, `SELF` | Status-specific safe allowlist | `LECTURER_NOT_ACTIVE` / `FORBIDDEN` |
| List lecturer tracks | New private authorization function | `LIST_OWN_TRACKS`, then `VIEW_TRACK` per item | `OWNS_TRACK` or active assignment | Active lecturer; archived metadata remains viewable | Empty filtered list |
| Create lecturer track | Internal authorized adapter; public workflow remains Feature 37 | `CREATE_TRACK` | Trusted actor lecturer ID | Active profile and create capability | `LECTURER_NOT_ACTIVE` / `FORBIDDEN` |
| View private track | No pre-existing public private-draft endpoint | `VIEW_TRACK` | Owner/assignment | Active lecturer; archived historical view allowed | `TRACK_NOT_FOUND` |
| Edit/archive/restore metadata | Internal authorized policy/adapters; management walkers remain Feature 37 | `EDIT_TRACK_METADATA`, `ARCHIVE_TRACK`, `RESTORE_TRACK` | Owner/editor as matrix permits | Editable track statuses; owner restore disabled by default | `TRACK_NOT_FOUND` / `TRACK_NOT_EDITABLE` |
| Create/edit/view version | Existing internal application services plus authorized adapters | Version permissions | Track edge, `HAS_TRACK_VERSION`, owner/assignment | Draft/review state; published and superseded immutable | `VERSION_NOT_EDITABLE` / `RESOURCE_SCOPE_MISMATCH` |
| Approve/publish/supersede version | Existing internal lifecycle services plus authorized publication adapter | Explicit approval/publication permissions | Owner/reviewer/admin scope | Approved publication preflight; no direct published mutation | `FORBIDDEN` / `VERSION_NOT_EDITABLE` |
| Course documents | Domain nodes exist; upload/process walkers planned | Document permissions | `HAS_SOURCE_DOCUMENT`, same track/version | Editable version and non-archived track | `TRACK_NOT_FOUND` / `VERSION_NOT_EDITABLE` |
| Blueprint | Domain node exists; review walkers planned | Blueprint permissions | `HAS_BLUEPRINT`, same track/version | Editable version; approval policy explicit | `TRACK_NOT_FOUND` / `RESOURCE_SCOPE_MISMATCH` |
| Enrollment summaries | Repository nodes exist; lecturer endpoint planned | Enrollment permissions | `FOR_TRACK`, `FOR_TRACK_VERSION`, owned/assigned track | Course-scoped only | `TRACK_NOT_FOUND` / `RESOURCE_SCOPE_MISMATCH` |
| Submission/grade review | Repository nodes exist; lecturer endpoint planned | Submission/review permissions | Enrollment `HAS_SUBMISSION`, same learner/track/version | Review capability; low-confidence item must be flagged | `RESOURCE_SCOPE_MISMATCH` |
| Lecturer approval | Existing private development operation | `APPROVE_LECTURER_PROFILE` | Explicit ADMIN permission | Pending, complete profile | `FORBIDDEN` |
| Role assignment/revocation | Internal Feature 35 service only | `ASSIGN_ROLE` / `REVOKE_ROLE` | Explicit ADMIN permission | Valid role transition | `FORBIDDEN` |
| Ownership backfill/repair | New private self-backfill endpoint; cross-user repair remains admin-only | `LIST_OWN_TRACKS` / `REPAIR_RESOURCE_OWNERSHIP` | Scalar/edge comparison | Missing non-contradictory edge only | Conflict report, no guessing |
| Programming-track migration | Existing authenticated environment-gated functions | System migration policy, not lecturer policy | Built-in system tracks | Environment enabled | Existing migration errors |

Public catalogue functions continue to return only discoverable published tracks. Private drafts are never returned by those functions. No existing lecturer document, blueprint, enrollment-list, submission-review, or collaborator-management walker was found, so Feature 36 provides their required policy and trusted repository contexts without inventing those later use-case APIs.
