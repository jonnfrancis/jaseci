Read `AGENTS.md`, `context/architecture-context.md`, and `context/feature-specs/25-database-schema.md` before starting.

# 26-repositories.md

We're implementing the repository layer.

The database schema now exists. This feature creates clean repository modules that separate persistence access from walker orchestration and domain logic.

Repositories should provide a consistent way for walkers to load, save, update, and query persisted LMS data.

Do not change business rules.

Do not create UI.

Do not add new learner features.

Do not move AI prompts into repositories.

Do not put scoring, mastery, unlocking, or recommendation logic inside repositories.

---

## Goal

Create a repository layer that separates:

* graph access
* database access
* learner access
* assessment access
* roadmap access
* lesson access
* challenge access
* submission access
* mastery access
* progression access
* dashboard read access

Walkers should become easier to read because they can call clear repository functions instead of manually querying persistence details everywhere.

---

## Repository Principles

Repositories should:

* load entities
* save entities
* update entities
* query relationships
* support transactions where needed
* return typed domain/view objects
* hide persistence implementation details

Repositories should not:

* decide what lesson unlocks next
* calculate mastery formulas
* grade submissions
* generate AI content
* build prompts
* render UI
* perform frontend navigation
* mutate unrelated subsystems

Business logic belongs in walkers, domain services, or dedicated engine modules.

---

## Suggested Backend Structure

Create repository modules under a clear backend location.

Suggested structure:

```text id="repo-structure"
lib/repositories/
├── graph_repository.jac
├── learner_repository.jac
├── assessment_repository.jac
├── roadmap_repository.jac
├── lesson_repository.jac
├── challenge_repository.jac
├── submission_repository.jac
├── mastery_repository.jac
├── progression_repository.jac
├── dashboard_repository.jac
├── skill_repository.jac
└── index.jac
```

Adapt paths to the existing Jac project convention if needed.

Do not scatter repository helpers across walker files.

---

## Graph Repository

Create:

```text id="graph-repo"
graph_repository.jac
```

Purpose:

* centralize graph lookup patterns
* centralize relationship traversal helpers
* centralize node/edge resolution
* avoid duplicating graph traversal code in every walker

Suggested functions:

* find_node_by_id
* find_nodes_by_type
* connect_nodes
* relationship_exists
* get_connected_nodes
* get_incoming_edges
* get_outgoing_edges
* ensure_relationship
* delete_relationship_if_needed

Rules:

* graph repository should not know LMS business rules
* it should not decide progression, mastery, or recommendations
* it should only provide safe graph operations

---

## Learner Repository

Create:

```text id="learner-repo"
learner_repository.jac
```

Responsibilities:

* get learner by id
* get learner by auth user id
* create learner profile if needed
* update learner profile
* verify learner exists
* resolve authenticated learner context

Suggested functions:

* get_learner
* get_learner_by_auth_user_id
* create_learner
* update_learner
* require_learner
* resolve_authenticated_learner

Do not handle password logic here unless the existing architecture places auth there.

Do not store plaintext passwords.

---

## Assessment Repository

Create:

```text id="assessment-repo"
assessment_repository.jac
```

Responsibilities:

* create assessment with questions/options
* get assessment
* get learner assessments
* create assessment attempt
* save assessment responses
* get assessment attempt
* get attempt responses
* create assessment evaluation
* get assessment evaluation
* get assessment skill signals

Suggested functions:

* create_assessment
* create_assessment_questions
* get_assessment
* get_latest_assessment_for_learner
* create_assessment_attempt
* save_assessment_responses
* get_assessment_attempt
* get_attempt_responses
* save_assessment_evaluation
* get_assessment_evaluation
* get_assessment_skill_signals

Do not evaluate answers here.

Do not calculate scores here.

Do not generate assessment questions here.

---

## Roadmap Repository

Create:

```text id="roadmap-repo"
roadmap_repository.jac
```

Responsibilities:

* create roadmap
* create roadmap weeks
* create roadmap lessons
* create roadmap milestones
* get roadmap by id
* get active roadmap
* get roadmap lessons in order
* update roadmap status
* update roadmap lesson generation status
* check duplicate active roadmap

Suggested functions:

* create_roadmap
* create_roadmap_structure
* get_roadmap
* get_active_roadmap
* get_roadmap_weeks
* get_roadmap_lessons
* get_roadmap_lessons_ordered
* get_roadmap_milestones
* update_roadmap_status
* update_roadmap_lesson_generation_status
* find_existing_roadmap_for_evaluation

Do not generate roadmap content here.

Do not call byLLM.

Do not unlock lessons here.

---

## Lesson Repository

Create:

```text id="lesson-repo"
lesson_repository.jac
```

Responsibilities:

* save generated lesson
* save lesson sections
* save examples
* save mini exercises
* save takeaways
* get generated lesson by id
* get generated lesson by roadmap lesson
* check if lesson already exists
* get lesson content for viewer

Suggested functions:

* create_generated_lesson
* save_lesson_sections
* save_lesson_examples
* save_lesson_mini_exercises
* save_lesson_takeaways
* get_generated_lesson
* get_generated_lesson_for_roadmap_lesson
* get_lesson_view
* generated_lesson_exists

Do not generate lesson content here.

Do not mark mastery.

Do not handle challenge generation.

---

## Challenge Repository

Create:

```text id="challenge-repo"
challenge_repository.jac
```

Responsibilities:

* save generated challenge
* save challenge instructions
* save expected outcomes
* save constraints
* save hints
* save evaluation criteria
* get challenge by id
* get challenge by generated lesson
* get challenge workspace data
* check duplicate challenge

Suggested functions:

* create_generated_challenge
* save_challenge_instructions
* save_challenge_expected_outcomes
* save_challenge_constraints
* save_challenge_hints
* save_challenge_evaluation_criteria
* get_generated_challenge
* get_challenge_for_generated_lesson
* get_challenge_workspace
* generated_challenge_exists

Do not generate challenge content here.

Do not evaluate code here.

Do not create submissions here except through submission repository.

---

## Submission Repository

Create:

```text id="submission-repo"
submission_repository.jac
```

Responsibilities:

* create challenge submission
* save draft if supported
* get submission
* get learner submissions
* get submissions for challenge
* save submission evaluation
* get submission evaluation
* get criterion results
* get skill signals
* get feedback items

Suggested functions:

* create_challenge_submission
* save_challenge_draft
* get_challenge_submission
* get_latest_submission_for_challenge
* get_submissions_for_challenge
* save_submission_evaluation
* get_submission_evaluation
* get_criterion_results
* get_submission_skill_signals
* get_feedback_items

Do not grade code here.

Do not call byLLM.

Do not update mastery.

---

## Mastery Repository

Create:

```text id="mastery-repo"
mastery_repository.jac
```

Responsibilities:

* get skill mastery
* get learner mastery records
* create skill mastery
* update skill mastery
* create mastery evidence
* check existing evidence
* get mastery summary
* get strongest/weakest skills

Suggested functions:

* get_skill_mastery
* get_learner_mastery
* create_skill_mastery
* update_skill_mastery
* create_mastery_evidence
* evidence_exists
* get_mastery_evidence_for_source
* get_mastery_summary
* get_strongest_skills
* get_weakest_skills

Do not calculate mastery formula here unless the project specifically treats repository as persistence plus simple data update.

Preferred:

* mastery calculation in mastery engine/helper
* repository saves the result

---

## Progression Repository

Create:

```text id="progression-repo"
progression_repository.jac
```

Responsibilities:

* get lesson progress
* create lesson progress
* update lesson progress
* get roadmap progress
* create/update roadmap progress
* create progression event
* get recent progression events
* get current lesson progress
* check existing unlock/completion event

Suggested functions:

* get_lesson_progress
* get_lesson_progress_for_roadmap
* create_lesson_progress
* update_lesson_progress
* get_roadmap_progress
* upsert_roadmap_progress
* create_progression_event
* progression_event_exists
* get_recent_progression_events
* get_current_lesson_progress

Do not decide which lesson unlocks here.

Do not calculate progression rules here.

The `unlock_next_lesson` walker or progression engine should decide, then repository persists.

---

## Skill Repository

Create:

```text id="skill-repo"
skill_repository.jac
```

Responsibilities:

* get skill by id
* get skills by language
* get skills for roadmap
* get skill relationships
* get prerequisite relationships
* get lesson target skills
* get challenge target skills

Suggested functions:

* get_skill
* get_skills_by_language
* get_skills_for_roadmap
* get_skill_relationships
* get_prerequisites_for_skill
* get_lesson_target_skills
* get_challenge_target_skills
* ensure_skill_exists

Do not compute mastery here.

Do not generate skill recommendations here.

---

## Dashboard Repository

Create:

```text id="dashboard-repo"
dashboard_repository.jac
```

Purpose:

Support read-only dashboard aggregation queries.

Responsibilities:

* get dashboard source records
* get roadmap summary data
* get lesson summary data
* get challenge summary data
* get recent activity records
* get current lesson source data

Suggested functions:

* get_dashboard_sources
* get_roadmap_progress_summary
* get_lesson_status_summary
* get_challenge_status_summary
* get_current_lesson_source
* get_recent_activity_sources

This repository can gather data, but should not decide dashboard state if that logic already lives in `get_dashboard`.

Do not mutate records.

Do not call other mutating walkers.

---

## Transactions

Add transaction helpers where the project/database supports them.

Multi-entity writes should be transaction-safe.

Transaction examples:

* create assessment with questions/options
* submit assessment with responses
* create roadmap with weeks/lessons/milestones
* create generated lesson with sections/examples/exercises/takeaways
* create generated challenge with instructions/outcomes/constraints/hints/criteria
* save submission evaluation with criterion results/skill signals/feedback
* update mastery with mastery evidence
* update progression with lesson progress/roadmap progress/events

If transaction helpers are centralized, create:

```text id="transaction-helper"
repository_transaction.jac
```

or equivalent project convention.

Do not leave partially-created entities marked as complete.

---

## Return Types

Repositories should return predictable typed results.

Prefer:

* domain objects
* DTO-compatible objects
* structured result objects
* `None` for not found where appropriate
* explicit error result where project convention requires

Avoid returning raw database rows throughout walker code.

Avoid returning unvalidated unstructured maps unless that is the established Jac convention.

---

## Error Handling

Repositories should handle low-level persistence errors and return meaningful failures.

Handle:

* missing record
* duplicate unique constraint
* foreign key violation
* invalid enum/status
* database connection failure
* transaction rollback
* malformed graph relationship
* graph/database mismatch

Do not expose raw database errors to frontend-facing walker responses.

Walkers should translate repository errors into structured user-safe errors.

---

## Idempotency Helpers

Add helper methods that support previous feature idempotency.

Examples:

* generated lesson already exists
* generated challenge already exists
* submission evaluation already exists
* mastery evidence already exists
* lesson progress already exists
* roadmap progress already exists
* progression event already exists
* active roadmap already exists for learner/language/evaluation

These helpers should prevent duplicate writes without relying on frontend button disabling.

---

## Refactor Existing Walkers

Update existing walkers to use repositories where appropriate.

Relevant walkers include:

* initialize_assessment
* submit_assessment
* evaluate_assessment
* generate_roadmap
* generate_lesson
* generate_challenge
* submit_challenge
* evaluate_submission
* update_mastery
* get_skill_map
* unlock_next_lesson
* get_dashboard
* recommend_next_action

Do not rewrite all walker logic unnecessarily.

Only replace direct low-level persistence access with repository calls.

Preserve existing behavior.

---

## Repository Boundaries

Use these boundaries:

```text id="repo-boundaries"
Walker = orchestration
Repository = persistence/query
Domain helper = calculations/rules
AI module = byLLM structured generation/evaluation
Frontend = presentation/navigation
```

Do not let repositories become a dumping ground for all logic.

---

## Frontend Repository Layer

Do not create frontend repositories in this feature.

Frontend API/client hooks belong in separate UI/data-fetching layers.

This feature is backend persistence access only.

If frontend types need alignment, update DTO imports only.

---

## Testing

Create repository tests for:

* learner repository load/create
* assessment repository create/load
* assessment attempt/response persistence
* assessment evaluation persistence
* roadmap create/load
* roadmap ordered lesson retrieval
* generated lesson create/load
* generated challenge create/load
* challenge submission create/load
* submission evaluation create/load
* mastery record create/update
* mastery evidence idempotency
* skill relationship retrieval
* progression create/update
* dashboard source queries
* transaction rollback
* duplicate detection helpers
* missing record behavior

Tests should not require live AI providers.

Use deterministic fixtures.

---

## Integration Testing

After repository refactor, verify the full LMS flow still works:

```text id="full-flow"
Register/Login
→ Start assessment
→ Submit assessment
→ Evaluate assessment
→ Generate roadmap
→ View roadmap
→ Generate lesson
→ View lesson
→ Generate challenge
→ Submit challenge
→ Evaluate submission
→ Update mastery
→ Unlock next lesson
→ Load skill map
→ Load dashboard
→ Load AI tutor panel
```

The behavior should match the pre-repository implementation.

No feature should regress.

---

## Explicitly Out of Scope

Do not implement:

* new database schema
* new UI
* new walkers
* new AI prompts
* new mastery formulas
* new progression rules
* dashboard redesign
* skill map redesign
* certificates
* notifications
* admin panel

This feature only creates and adopts a repository layer.

---

## Check When Done

* Repository folder exists
* Graph repository exists
* Learner repository exists
* Assessment repository exists
* Roadmap repository exists
* Lesson repository exists
* Challenge repository exists
* Submission repository exists
* Mastery repository exists
* Skill repository exists
* Progression repository exists
* Dashboard repository exists
* Repositories expose typed helper functions
* Multi-entity writes use transactions where available
* Idempotency helpers exist
* Walkers use repositories instead of direct persistence queries
* Existing walker behavior is preserved
* Repository tests pass
* Full LMS flow still works
* Data persists correctly after refactor
