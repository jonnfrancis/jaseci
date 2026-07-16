# Feature 35 Authentication and Identity Audit

| Concern | Current implementation | Feature 35 change |
|---|---|---|
| Authentication identity | Jac Scale `/user/register`, `/user/login`, JWT runtime helpers, and one persistent root per authenticated caller | Reused unchanged; no lecturer credentials or second session system |
| Trusted server identity | Authenticated private endpoints execute against the caller's root; the previous learner binder also accepted `auth_user_id` from the client | `jid(root)` is now the canonical, server-derived `user_id`; client profile IDs are never authentication proof |
| Learner identity | `Learner` is attached to the user's root and stores `auth_user_id`/`auth_root_id`; the client caches `learner_id` for recovery | Existing `Learner.id` is preserved and linked through `HAS_LEARNER_PROFILE`; registration/login binding idempotently creates an ACTIVE LEARNER assignment |
| Registration | Client uses Jac runtime signup, then login, then resolves/creates the learner | Public registration has no role input and can create only the learner role |
| Login/session | Jac runtime owns the JWT; GraphLearn local storage mirrors token, learner ID, email, and username | Role summary and lecturer ID are cached only for navigation; every privileged backend operation revalidates graph state |
| Roles | Built-in Scale roles exist for platform administration, but application roles were implicit | Typed application `UserRoleAssignment` nodes carry lifecycle, source, grant, reason, and timestamps |
| Lecturer profile | Missing | Persistent, root-owned `LecturerProfile` with onboarding, verification, completion, capabilities, and lifecycle |
| Administrator | No application-domain administrator model | ACTIVE ADMIN assignment is required by protected identity administration operations; public callers cannot assign it |
| Course ownership | Track service used generic `ActorContext.user_id` | Lecturer ownership comparisons now use trusted `ActorContext.lecturer_id`; Feature 37 will create the ownership edge during course creation |
| Endpoint visibility | Learner identity resolver is `def:priv`; catalogue reads are public; user state mutations are authenticated | Identity/profile/onboarding endpoints remain `def:priv`; no arbitrary `user_id` or `lecturer_id` is accepted |

The exact stable domain user identifier is the authenticated root JID. Email and username remain mutable display/login snapshots and are not ownership authorities.
