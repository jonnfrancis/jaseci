# Feature 25: Durable Graph Persistence

## Status

Implemented on 2026-07-10. Local cross-process SQLite persistence is verified. The same restart contract must still be run against the configured production MongoDB deployment before production release.

This document replaces the earlier relational-table proposal with a persistence plan that matches the application that exists today. GraphLearn already models and writes its domain state as Jac nodes and edges. The implementation phase must make that graph durable and consistently addressable across authentication sessions, server restarts, development reloads, and deployments without changing learning business logic.

Feature 24 (`24-ai-tutor-panel.md`) is the presentation and scoping reference for this specification.

---

## Problem Statement

The happy path works while one server process remains active:

```text
Register/Login
-> Assessment
-> Assessment evaluation
-> Roadmap
-> Dashboard / lessons
```

After a development restart or a stopped/restarted server, the learner can authenticate again but dashboard, roadmap, lesson, skill-map, and tutor reads can no longer reconstruct the learner's journey.

The visible symptom is missing application state. The persistence feature must distinguish among four possible causes rather than treating them as one database problem:

1. The graph store was not configured durably or the data directory changed between processes.
2. The authenticated user returned with a different application learner key.
3. Data exists but is attached to a different per-user root or is not reachable from the caller's root.
4. Persisted nodes exist but cannot be rehydrated after an archetype or field schema change.

The implementation is complete only when the same authenticated account can resume the same graph journey after a true process restart.

---

## Findings From The Current Code

### The graph is already the domain database

Current walkers create domain nodes with `root ++> Node(...)` or from another reachable node through typed edges. Jac persists reachable nodes and edges automatically; endpoint code does not need an explicit save or commit.

Examples already following this model include:

* assessment attached to `root`, with questions/options below it
* attempt attached to assessment, with responses below it
* evaluation attached to attempt
* roadmap attached to `root` and learner, with weeks/lessons/milestones below it
* generated lessons and challenges attached to `root` plus their owning graph entities
* submissions, evaluations, mastery records, and progression records attached to `root`

The implementation must not duplicate these records into an unrelated ORM schema.

### Current reads depend on the caller's root

Most lookup helpers use patterns such as:

```jac
[root -->][?:Learner, id == learner_id]
[root -->][?:Roadmap, id == roadmap_id]
[root -->][?:GeneratedLesson]
```

For authenticated private endpoints, `root` is the authenticated user's persistent root. A record stored under one root is intentionally invisible from another root. Therefore authentication identity and root continuity are part of the persistence contract.

### The learner identity contract is currently implicit

The client stores `learner_id` as normalized email during login. Registration delegates to Jac auth and then logs in. Server services create/find `Learner` nodes by that client-supplied string.

This has several risks:

* email is mutable and is not the canonical Jac auth account identifier
* normalization rules can drift between registration, login, and service calls
* a cleared or stale browser session can produce an empty/different learner id even when the auth token is valid
* accepting `learner_id` from the client allows identity mismatch unless the server verifies it

The durable design must bind one immutable auth subject to one learner node on the authenticated root.

### The documented database stack does not match the current implementation

`architecture-context.md` currently lists PostgreSQL and Prisma. The repository contains no Prisma schema, Prisma dependency, migration history, or repository layer, and its domain operations use Jac's graph store directly.

Jac's persistence convention is:

* local/default: SQLite data under `.jac/data/`
* scaled deployment: the Jac scale database backend, currently configured through `MONGODB_URI`, with optional Redis caching

The implementation phase must resolve this documentation conflict before code changes. The recommended decision for the current application is to keep the OSP graph as the only domain source of truth and use Jac's native persistence backend. Introducing PostgreSQL/Prisma would be a separate architecture migration, not a database-schema fix.

---

## Goal

Provide one durable, authenticated learner graph that survives:

* browser refresh
* logout and login
* backend process restart
* frontend/dev-server restart
* hot reload that does not intentionally purge graph data
* deployment restart with a persistent production database
* repeated learner sessions and multiple devices

The graph remains the source of truth. Dashboard, skill map, and tutor responses remain derived read models.

---

## Non-Goals

This feature must not:

* change assessment scoring, lesson generation, challenge generation, mastery, or progression rules
* add UI or alter user journeys
* persist raw LLM responses
* create dashboard, skill-map, or tutor snapshot records
* introduce Prisma or a second domain database alongside the Jac graph
* use localStorage as the learner-data source of truth
* make public/shared roots a shortcut around authenticated ownership
* rewrite existing walkers into relational repositories

---

## Persistence Architecture Decision

### Selected model

Use Jac native graph persistence for all LMS domain nodes and edges.

```text
Jac auth account
-> persistent per-user Root
-> Learner
-> assessment / roadmap / generated content / progress graph
```

Local development uses the default SQLite-backed `.jac/data/` store. Production uses the Jac-supported persistent database backend and a durable volume/service. At the time of this specification, that scaled backend is MongoDB configured by `MONGODB_URI`; deployment documentation must use the exact backend supported by the installed Jac version.

### Required documentation alignment

Before implementation begins:

1. Update `context/architecture-context.md` so its Database and ORM rows describe the selected Jac graph persistence backend.
2. Record whether PostgreSQL/Prisma is removed from the planned stack or deferred as a separately approved migration.
3. Add the chosen local and production database settings to deployment documentation and environment examples.

No implementation should proceed while two different systems are both described as the source of truth.

---

## Identity And Ownership Contract

### Canonical learner identity

The server must derive the current auth subject from the verified Jac auth context. It must not trust a caller-provided email or learner id as proof of ownership.

Persist one `Learner` node per authenticated root with:

```text
Learner
- id: stable application id
- auth_user_id: immutable verified auth subject
- name
- email: profile/display value, not ownership key
- created_at
- updated_at
```

If the Jac runtime exposes only one stable auth identifier, `Learner.id` may equal that identifier. Otherwise `Learner.id` remains an application id and `auth_user_id` is the unique binding.

### Resolution rules

Every authenticated service must:

1. Resolve the verified auth subject on the server.
2. Search the caller's root for the learner bound to that subject.
3. Create the learner only in the explicit onboarding/get-or-create path.
4. Reject any supplied learner id that does not match the resolved learner.
5. Pass the server-resolved learner id to walkers.

Client localStorage may cache display/session hints, but deleting it must not delete or orphan learner data. After login, the server must be able to return the canonical learner id again.

### Ownership invariants

* One auth subject maps to exactly one learner on its root.
* A learner's assessments, roadmaps, lessons, challenges, mastery, and progression remain reachable from that same root.
* A second authenticated account cannot load records by guessing domain ids.
* Cross-user sharing is out of scope. If introduced later, it must use Jac grants and `jobj()` plus explicit authorization, not root-global scans.

---

## Durable Graph Schema

The existing node and edge archetypes are the schema. Implementation should normalize them incrementally; it must not translate them into tables.

### Learner and assessment aggregate

```text
Root -> Learner
Root -> Assessment
Learner -assigned-> Assessment
Assessment -AssessmentQuestionLink-> AssessmentQuestion
AssessmentQuestion -AssessmentOptionLink-> AssessmentOption
Assessment -AssessmentAttemptLink-> AssessmentAttempt
Learner -LearnerAssessmentAttemptLink-> AssessmentAttempt
AssessmentAttempt -AssessmentAttemptResponseLink-> AssessmentResponse
AssessmentResponse -AssessmentResponseQuestionLink-> AssessmentQuestion
AssessmentAttempt -AssessmentEvaluationLink-> AssessmentEvaluation
```

Required stable business keys:

* learner: auth subject (unique per root)
* assessment: `id`
* attempt: `id`, plus assessment/learner ownership
* evaluation: `id`, one effective evaluation per attempt/version

Question results, score objects, and skill signals may remain validated embedded objects because they are owned values and are read with their evaluation. Do not persist raw model output.

### Roadmap aggregate

```text
Root -> Roadmap
Learner -assigned-> Roadmap
Roadmap -contains-> RoadmapWeek
RoadmapWeek -contains-> RoadmapLesson
RoadmapWeek -contains-> RoadmapMilestone
RoadmapLesson -targets-> Skill
RoadmapMilestone -requires-> Skill
```

Required uniqueness:

* one active roadmap per learner and language unless product scope explicitly permits versions
* roadmap week unique by `(roadmap_id, week_number)`
* roadmap lesson unique by its stable `id` and deterministic order within its roadmap

The `weeks`, `lessons`, and `milestones` embedded lists currently duplicate graph relationships. During implementation, choose one canonical representation. Recommended: edges are canonical and embedded lists are compatibility/read caches only. If retained, every write path must update both atomically and restart tests must prove that rehydrated values match edge traversal.

### Generated lesson and challenge aggregates

Generated content must remain reachable from root and from its owner/context nodes.

Required idempotency keys:

* generated lesson: `(learner_id, roadmap_lesson_id)`
* generated challenge: `(learner_id, generated_lesson_id)` for the current single-challenge behavior, or an explicit attempt/version key if retries create variants

Sections, examples, exercises, takeaways, instructions, outcomes, constraints, hints, criteria, and feedback items may be child nodes connected from their aggregate root. Embedded child lists, if retained, must follow the same canonical/cache rule as roadmap lists.

### Submission, mastery, and progression aggregates

Required uniqueness/idempotency:

* submission evaluation: `submission_id` plus evaluation version
* skill mastery: `(learner_id, skill_id)`
* mastery evidence: `(learner_id, skill_id, source_type, source_id)`
* lesson progress: `(learner_id, roadmap_lesson_id)`
* roadmap progress: `(learner_id, roadmap_id)`
* progression event: deterministic event key or a uniqueness check over learner, event type, lesson, and source

All update walkers must mutate the existing persistent node when the idempotency key already exists. They must not create a second root-level record after restart.

### Skills

The current per-user root model means root-attached skills are scoped to that user unless explicitly shared. Feature 25 should preserve that behavior to avoid an unplanned multi-user permission change. A future shared skill catalog must use the shared-root/grant model and explicit authorization.

---

## Reachability Rules

Jac persists a node after it is connected to a reachable graph. Therefore every create path must satisfy all of the following before reporting success:

* the aggregate root is attached to the caller's root
* owned child nodes are attached to their aggregate parent
* ownership/context edges are created where downstream traversal depends on them
* no domain node is constructed and left dangling
* no persisted lookup uses Python's in-memory `id()`

Application ids remain useful business keys, but Jac `jid()` is the stable graph-object identifier. Use:

* typed traversal from the authenticated root for owned collections
* `jobj(jid_value)` for direct graph-object retrieval only when the jid has been persisted or returned
* an ownership check after `jobj()`; object resolution is not authorization

Do not replace current business ids with `jid()` in one large change. Define DTO fields explicitly (`id` versus `jid`) and migrate endpoint-by-endpoint if direct lookup is needed.

---

## Database Configuration

### Local development

* Use a stable project working directory so `.jac/data/` resolves consistently.
* Do not delete `.jac/data/` during ordinary restart or hot reload.
* Ensure cleanup scripts distinguish compiler/cache cleanup from database deletion.
* Exclude `.jac/data/` from source control while preserving it on the developer machine.
* Document that deliberate data reset is destructive and requires stopping the server first.

### Production

* Configure the Jac-supported durable backend through environment variables, currently `MONGODB_URI` for the scale database plugin.
* Do not rely on container-local SQLite storage unless the data directory is mounted to a durable single-writer volume and that deployment constraint is accepted.
* Store credentials only in deployment secrets.
* Define backup, restore, retention, health-check, and connection-failure behavior.
* If Redis caching is enabled, the database remains authoritative; cache loss must not lose learner state.

### Startup diagnostics

On startup, log non-secret diagnostics sufficient to verify:

* selected backend type
* logical database/data path
* schema-repair mode
* successful database connection

Never log passwords, tokens, connection credentials, learner content, or raw LLM input/output.

---

## Schema Evolution And Restart Safety

Persisted Jac archetypes must evolve through Jac's schema compatibility mechanisms.

### Rules

* Adding a field requires a safe default or an intentional migration rule.
* Renaming a field requires `schema_alias(new_name, stored="old_name")` in `__jac_schema__`.
* Removing a field must be deliberate; use the supported schema drop/history mechanism.
* Renaming an archetype requires `@archetype_alias` for its previous qualified name.
* Shape upgrades must be idempotent and deterministic.
* Production startup must not silently purge data that fails to load.

Unloadable rows are quarantined by Jac rather than treated as absent. The operator runbook must include:

```text
jac db quarantine list --app main.jac
jac db recover-all --app main.jac
```

Use the exact CLI syntax supported by the installed compiler. Inspect quarantined data before any destructive reset.

### Development stale-anchor condition

An `Invalid anchor id` error can indicate stale local anchors produced under an incompatible development schema. Deleting `.jac/data/` is acceptable only as an explicit local reset after the server stops. It is not a production migration strategy and must not be part of normal dev restart automation.

---

## Write Consistency

Multi-node graph mutations must not expose a partially completed aggregate.

Required atomic units include:

* assessment plus questions/options
* attempt plus responses
* assessment evaluation plus results/signals
* roadmap plus weeks/lessons/milestones/skill edges
* generated lesson plus all child content
* generated challenge plus all child content and criteria
* submission evaluation plus results/signals/feedback
* mastery evidence plus mastery update
* lesson completion plus next unlock, roadmap summary, and progression event

Implementation must use the transaction/atomic request behavior supported by the installed Jac backend. If the runtime cannot provide a transaction across the full mutation, create records with a non-complete status and mark the aggregate complete only after all required children and edges exist. Readers must ignore incomplete aggregates.

---

## Data Access And Walker Changes

Keep walkers responsible for domain orchestration. Add only small persistence helpers needed to centralize:

* current authenticated learner resolution
* find-by-business-id within the caller's root
* get-or-create by idempotency key
* ownership validation
* canonical child traversal

Do not create generic repositories that hide graph topology. Do not allow client services to choose another learner by passing an arbitrary id.

Audit every current root scan in assessment journey, dashboard, roadmap, lesson, challenge, mastery, progression, skill-map, and tutor paths. For each scan, document:

* expected owning root
* node type and business key
* required ownership edge
* behavior when missing
* whether legacy/reachable child nodes need a fallback traversal

Temporary compatibility fallbacks may read both the canonical edge path and older root-level placement, but all new writes must use one canonical topology. Remove fallbacks after migration verification.

---

## Migration Plan

### Phase A: diagnose without mutation

1. Reproduce the issue with one test account.
2. Record the auth subject, application learner id, root jid, domain business ids, and domain jids before restart.
3. Restart without deleting `.jac/data/`.
4. Record the same identifiers after login.
5. Inspect database/quarantine state.
6. Classify the failure as backend/path, identity, root, reachability, or schema rehydration.

Do not build migration code until this evidence identifies the failing boundary.

### Phase B: establish canonical identity

1. Add the auth-subject binding to `Learner` with a schema-safe default/migration.
2. Add a server-owned current-learner resolver.
3. Backfill existing learners only where the owner can be determined unambiguously from their root/session.
4. Quarantine or report ambiguous duplicates; do not merge them automatically.
5. Stop trusting client-provided learner ownership.

### Phase C: normalize graph topology

1. Inventory every archetype and edge used by current walkers.
2. Verify each aggregate is reachable from the authenticated root.
3. Select edges as canonical for duplicated child relationships.
4. Add idempotent compatibility/migration helpers for legacy records.
5. Add uniqueness checks in create/update walkers.

### Phase D: configure durable environments

1. Pin and document local SQLite data location.
2. Configure the supported production database backend.
3. Add startup diagnostics and health checks.
4. Add backup/restore and quarantine runbooks.
5. Correct architecture documentation.

### Phase E: remove compatibility paths

Only after migrated data passes restart tests:

* remove legacy identity fallbacks
* remove dual-topology read fallbacks
* retain schema aliases for as long as stored legacy data may exist

---

## Validation And Error Handling

Validate before persistent mutation:

* learner ownership matches verified auth subject
* referenced roadmap/lesson/challenge/submission belongs to the learner
* scores and percentages are within their domain ranges
* enum values are valid
* order indexes are non-negative and unique within an aggregate
* referenced child/source nodes exist
* idempotency keys do not conflict with another owner

Return stable application errors for unavailable data, ownership mismatch, duplicate state, invalid state transition, and database unavailability. Do not expose raw database errors, graph internals, tokens, or stack traces to the client.

---

## Test Plan

Tests must use deterministic fixtures and no live AI provider.

### Persistence unit/integration coverage

* authenticated learner get-or-create is idempotent
* same auth subject resolves the same learner after logout/login
* different auth subjects resolve different roots/learners
* every aggregate and child is reachable after creation
* business ids and jids remain stable after restart
* embedded compatibility lists, if retained, match canonical edge traversal
* uniqueness rules prevent duplicate lesson, challenge, evaluation, mastery, evidence, and progress records
* unauthorized ids cannot cross learner boundaries
* schema field addition, rename, and archetype alias rehydrate old fixtures
* incomplete multi-node writes are rolled back or hidden

### Mandatory process-restart acceptance test

An in-process reload is insufficient. The test must:

1. Start the backend against an isolated persistent database.
2. Register and log in as learner A.
3. Complete assessment and evaluation.
4. Generate a roadmap.
5. Generate/open a lesson and challenge.
6. Submit/evaluate a challenge and update progression/mastery where the fixture permits.
7. Capture learner, roadmap, lesson, challenge, mastery, progress, and root identifiers.
8. Stop the backend process cleanly.
9. Start a new backend process against the same database.
10. Log in again as learner A with a fresh browser/session context.
11. Assert all captured records and relationships are available with stable identifiers.
12. Assert dashboard, roadmap, lesson, skill map, and tutor read models rebuild successfully.
13. Log in as learner B and assert learner A's graph is unavailable.

Run the same contract against local SQLite and the selected production backend in CI or a deployment test environment.

### Restart matrix

| Event | Expected result |
| --- | --- |
| Browser refresh | Current journey reloads from server graph |
| Logout/login | Same learner and graph resolve |
| Frontend restart | No learner data changes |
| Backend restart | Same root, nodes, edges, ids, and read models resolve |
| Hot reload without schema change | Data remains available |
| Compatible schema change | Existing records rehydrate through defaults/aliases |
| Database unavailable | Structured temporary failure; no false empty onboarding state |
| Cache cleared | Authoritative database still restores state |

---

## Observability And Operations

Add non-sensitive metrics/logs for:

* current backend connection health
* learner resolution success/failure category
* missing aggregate by type
* ownership mismatch attempts
* duplicate/idempotent write prevention
* schema repair and quarantine counts
* restart acceptance test status

An unavailable database must not be reported to the UI as "no assessment" or "no roadmap." Empty learner state and persistence failure are different outcomes.

---

## Implementation Order

1. Reproduce and classify the restart failure.
2. Resolve the architecture documentation conflict.
3. Configure a stable durable backend/data path.
4. Implement server-derived learner identity binding.
5. Audit and normalize graph reachability/topology.
6. Add schema aliases/upgrades required by existing data.
7. Add idempotency and atomic-write safeguards.
8. Add cross-process restart tests.
9. Validate the full learner flow on both local and deployment backends.
10. Remove temporary compatibility reads after migration acceptance.

---

## Check When Done

* One verified auth subject resolves one durable learner.
* Client localStorage is not required to rediscover learner data.
* The selected Jac database backend and data path are explicit.
* No second ORM/database is introduced.
* All domain nodes are reachable from the correct authenticated root.
* Business ids and graph jids remain stable across process restarts.
* Schema changes use aliases/upgrades rather than destructive resets.
* Duplicate aggregate records are prevented after retries/restarts.
* Dashboard, roadmap, lesson, challenge, skill-map, and tutor reads rebuild from persisted graph state.
* A database outage produces an error, not a false new-user state.
* Cross-user isolation is verified.
* SQLite and production-backend restart acceptance tests pass.
* Architecture and deployment documentation match the implemented backend.

---

## Implementation Result

The approval gate was satisfied by the explicit implementation request. The delivered persistence foundation includes:

* Jac native graph persistence configured as the only LMS domain store
* MongoDB scale configuration through `MONGODB_URI` and deployment-secret placeholders
* server-derived authenticated root binding through `jid(root)`
* immutable auth `user_id` profile binding metadata
* unambiguous migration of existing email-keyed learner records on the same authenticated root
* client session restoration through `/user/me`, so clearing GraphLearn learner-id storage does not orphan server data
* authenticated/private boundaries for assessment, roadmap, dashboard, lesson, challenge, skill-map, and tutor services
* safe-default learner schema additions for existing persisted records
* an operations/quarantine/backup runbook
* a deterministic test that writes in one Jac process and restores the same graph node in a second process using an isolated SQLite database

No PostgreSQL/Prisma layer or duplicate dashboard/tutor persistence was introduced.

## Explicit Approval Gate

This gate was cleared by the user's 2026-07-10 instruction to implement this specification. The accepted decisions are:

1. Jac native graph persistence is accepted as the domain database.
2. The production backend supported by the installed Jac version is accepted.
3. The canonical auth subject exposed by Jac auth is identified.
4. The restart diagnosis in Migration Phase A has been captured.

Production release remains gated on running the restart acceptance flow against the deployed MongoDB backend and validating backup restoration in a non-production environment.
