Read `AGENTS.md`, `context/architecture-context.md`, `context/feature-specs/25-database-schema.md`, and `context/progress-tracker.md` before starting.

# Feature 26: Graph Query and Persistence Helpers

## Status

Specification ready. This feature replaces the previous ORM-style repository-layer proposal.

GraphLearn uses Jac's persistent OSP graph as its domain database. Jac nodes, typed edges, authenticated roots, graph traversal, and automatic persistence already provide the application's persistence model. This feature must improve consistency and remove meaningful duplication without hiding those Jac concepts behind a generic repository abstraction.

---

## Goal

Extract repeated, well-defined graph queries and idempotency checks into small typed helper modules.

The result should:

* reduce duplicated traversal code across walkers and server services
* give repeated graph relationships one canonical query implementation
* make ownership and idempotency checks consistent
* preserve visible graph topology in walker code
* keep domain mutations and orchestration easy to follow
* preserve all existing behavior

This is a focused refactor. It is not a new persistence layer.

---

## Core Principles

### No generic repository abstraction over Jac

Do not build generic helpers such as:

* `find_nodes_by_type`
* `save_entity`
* `update_entity`
* `connect_nodes`
* `get_outgoing_edges`
* `repository_transaction`

Those functions merely rename native Jac operations, weaken static typing, and hide graph shape.

Use Jac directly for simple one-off operations:

```jac
[root -->][?:Learner, id == learner_id]
root ++> GeneratedLesson(...)
roadmap +>:contains:+> week
```

### No folder or module per entity by default

Do not create learner, assessment, roadmap, lesson, challenge, submission, mastery, progression, skill, and dashboard repositories merely to satisfy a prescribed structure.

Create a helper module only when:

1. the same typed traversal or lookup appears in multiple production modules;
2. the relationship has one canonical meaning;
3. centralizing it reduces drift or fixes a known inconsistency; and
4. the helper can be named after the graph relationship or domain query it performs.

### Keep graph creation and mutation visible

Walkers remain responsible for domain orchestration and graph mutation.

The following should normally remain visible in the walker that owns the behavior:

* creating an assessment and connecting its questions
* creating a roadmap and connecting weeks, lessons, and milestones
* persisting generated lesson or challenge aggregates
* attaching evaluation evidence
* updating mastery fields
* changing lesson or roadmap progress state
* creating progression events

Do not move a multi-step domain mutation into a helper merely to shorten a walker.

### Extract typed queries, not business decisions

Good helpers answer graph questions:

```text
assessment_attempts(assessment)
attempt_responses(attempt)
attempt_evaluation(attempt)
roadmap_weeks(roadmap)
roadmap_lessons(roadmap)
generated_lesson_for(learner_id, roadmap_lesson_id)
submission_evaluation(submission_id)
skill_mastery_for(learner_id, skill_id)
lesson_progress_for(learner_id, roadmap_lesson_id)
```

Helpers must not decide:

* how an assessment is scored
* what roadmap content to generate
* whether a submission passes
* how mastery changes
* which lesson unlocks next
* what the dashboard state means
* what the tutor recommends

### Preserve graph topology in names

Helper names must reveal the relationship being traversed or key being checked.

Prefer:

* `assessment_attempts(assessment)`
* `roadmap_lessons(roadmap)`
* `challenge_submissions(challenge, learner_id)`
* `mastery_evidence_for_source(learner_id, source_type, source_id)`

Avoid:

* `get_children(entity)`
* `query_records(type, filters)`
* `load_related(id)`
* `repository.find(...)`

---

## Scope

### First-pass candidates

Audit production code before creating modules. The current codebase has repeated candidates around:

* learner lookup on the authenticated root
* assessment-to-attempt-to-evaluation traversal
* roadmap week, lesson, and milestone traversal
* generated lesson and generated challenge lookup by owner/context
* challenge submission and evaluation lookup
* skill lookup and get-or-create behavior
* learner mastery lookup
* lesson and roadmap progress lookup
* progression-event idempotency checks

Only extract candidates confirmed to be duplicated in at least two production modules.

### Suggested organization

Use a small topology-oriented location:

```text
lib/graph/
├── assessment_queries.jac
├── roadmap_queries.jac
├── learning_queries.jac
├── mastery_queries.jac
└── progression_queries.jac
```

This list is illustrative, not mandatory. Merge modules when they would otherwise be tiny. Omit modules without demonstrated duplication. Do not create an `index.jac` unless it materially simplifies imports without creating cycles.

Identity resolution remains in `services/identity.sv.jac` because it is an authenticated service boundary, not a generic graph query.

---

## Allowed Helper Categories

### Typed relationship traversal

Centralize a traversal when multiple consumers must agree on the same edge path.

Examples:

```jac
def assessment_attempts(assessment: Assessment) -> list[AssessmentAttempt] {
    return [assessment ->:AssessmentAttemptLink:->][?:AssessmentAttempt];
}

def roadmap_weeks(roadmap: Roadmap) -> list[RoadmapWeek] {
    return [roadmap ->:contains:->][?:RoadmapWeek];
}
```

Return concrete typed nodes. Do not return `list[any]` or unvalidated dictionaries.

### Typed lookup by stable business key

Centralize repeated root-scoped lookups whose ownership meaning is already established.

Examples:

* learner by canonical learner id
* roadmap by roadmap id
* generated lesson by learner and roadmap lesson
* submission evaluation by submission id
* skill mastery by learner and skill

These helpers operate only on the caller's authenticated root unless their name explicitly identifies a granted/shared graph lookup.

### Idempotency lookup

Centralize the read/check portion of an existing idempotent mutation when several workflows use it.

Examples:

* existing active roadmap for an evaluation
* existing generated lesson for a learner and roadmap lesson
* existing generated challenge for a learner and generated lesson
* existing mastery evidence for a source
* existing lesson/roadmap progress
* existing progression event

The helper returns the existing typed node or `None`. The walker remains responsible for deciding whether to reuse, update, reject, or create.

### Canonical ordering

Extract ordering helpers only where order is part of the persisted graph contract and multiple consumers currently reproduce it.

Examples:

* roadmap weeks by `week_number`
* roadmap lessons by week and `order_index`
* lesson/challenge child content by `order_index`

Do not move dashboard ranking, recommendation priority, or other presentation/business ordering into graph helpers.

### Ownership validation

A helper may answer whether a root-scoped node belongs to the current learner/context when that check is repeated and purely structural.

It must not authorize `jobj()` solely because the object exists. Direct jid resolution always requires a subsequent ownership/grant check.

---

## Disallowed Abstractions

Do not add:

* base repository classes
* generic type-driven CRUD
* generic node or edge factories
* database adapters for SQLite versus MongoDB
* `save()`, `commit()`, or `flush()` wrappers for served endpoints
* transaction wrappers without a concrete supported Jac transaction API and an identified use
* foreign-key or database-row terminology over graph relationships
* dashboard repositories that precompute or persist dashboard DTOs
* frontend repositories
* helpers that call byLLM
* helpers that contain scoring, mastery, progression, or recommendation rules

Jac's backend selection is transparent to graph code. Helpers must work identically with the supported SQLite and MongoDB backends.

---

## Mutation and Transaction Rules

Do not invent transaction APIs.

If the installed Jac runtime exposes a transaction capability required by a specific multi-node operation:

1. document the exact supported API;
2. identify the mutation that requires it;
3. add the smallest helper needed for that mutation; and
4. test rollback behavior against supported backends.

Otherwise, preserve the current request-scoped graph mutation behavior and aggregate status safeguards from Feature 25.

`commit()` is not needed inside normal served endpoints. It is reserved for scripts that may exit before automatic persistence completes.

---

## Refactor Process

### Step 1: inventory duplication

Search walkers and server services for repeated implementations of:

* root-scoped find functions
* typed relationship traversal
* ordered child retrieval
* idempotency checks
* ownership checks

Record each candidate, its callers, graph path, key fields, and missing-record behavior before extraction.

### Step 2: choose canonical topology

For each extracted query, define:

* starting node or authenticated root
* edge type/path
* resulting concrete node type
* stable business-key filters
* ordering, if contractually required
* whether `None`, `[]`, or a structured error is correct when absent

Do not extract a helper while callers disagree about topology. Resolve the inconsistency first without changing business behavior.

### Step 3: extract one domain cluster at a time

Recommended sequence:

1. assessment attempt/evaluation queries
2. roadmap structure queries
3. generated lesson/challenge/submission queries
4. mastery and skill queries
5. progression queries

Run focused checks and tests after each cluster. Avoid a repository-style big-bang refactor.

### Step 4: remove duplicate local helpers

After all callers use the canonical helper:

* remove the duplicated local implementation
* keep domain-specific calculations local
* keep creation and mutation statements in their owning walkers
* check for circular imports

---

## Return Types and Errors

Helpers should return:

* a concrete node type
* `ConcreteNode | None` for optional single lookups
* `list[ConcreteNode]` for collections
* a small typed structural result only when one query naturally returns several related collections

Helpers should not catch database availability or schema-rehydration errors and convert them to empty results. An empty graph result and a persistence failure are different outcomes.

Frontend-safe error translation remains in walkers and server services.

---

## Testing

Add focused deterministic tests for each extracted helper.

Required coverage where applicable:

* returns only the expected concrete node type
* follows the canonical typed edge path
* respects the authenticated/root-scoped graph
* returns `None` or `[]` for genuinely missing data
* preserves required ordering
* idempotency lookup returns the original record
* similarly keyed records belonging to another learner/context are not returned
* callers preserve their pre-refactor behavior

Tests must not require live AI providers.

After each cluster, run the existing focused walker/service tests that exercise its callers. At completion, run the full learner-flow regression suite and the Feature 25 cross-process persistence test.

---

## Explicitly Out of Scope

Do not implement:

* a repository layer
* a new database schema or migration
* new graph entities or relationships unless required to correct a documented topology defect
* new business rules
* new walkers or endpoints
* UI changes
* AI prompt or provider changes
* scoring, mastery, progression, dashboard, or recommendation behavior changes
* PostgreSQL, Prisma, or another persistence system
* shared cross-user catalogs or permission grants

---

## Check When Done

* Repeated graph queries have been inventoried before extraction.
* Only demonstrated duplication has been centralized.
* No generic repository abstraction exists.
* No entity-per-repository folder structure was created.
* No generic CRUD, save, commit, or transaction wrappers were added.
* Helper names expose graph topology and domain meaning.
* Helpers return concrete typed nodes or typed structural results.
* Graph creation and domain mutations remain visible in walkers.
* Business calculations and decisions remain outside query helpers.
* Root ownership and direct-jid authorization rules remain intact.
* Duplicate local helpers are removed after adoption.
* Existing behavior is preserved.
* Focused helper and caller tests pass.
* Feature 25 cross-process persistence still passes.
* The full LMS flow does not regress.
