Read `AGENTS.md`, `context/architecture-context.md`, `context/project-overview.md`, `context/feature-specs/`, and `context/progress-tracker.md` before starting.

# 25-database-schema.md

We're implementing the persistence layer.

This feature creates the database schema needed to persist the LMS state across sessions, restarts, deployments, and learner activity.

The core LMS flows already work.

Now we need durable storage for:

* learners
* assessments
* assessment attempts
* assessment evaluations
* roadmaps
* roadmap weeks
* roadmap lessons
* generated lessons
* generated challenges
* challenge submissions
* submission evaluations
* mastery records
* progression records
* dashboard source data

Do not change business logic.

Do not create UI.

Do not add new walkers unless minimal persistence helpers are required.

Do not modify the learner workflow unless required to support persistence.

---

## Goal

Create a production-ready database schema for the LMS.

The schema should persist all core entities created by previous subsystems and support reliable retrieval by walkers.

The system should survive:

* page refresh
* user logout/login
* backend restart
* frontend restart
* deployment restart
* repeated learner sessions

The graph remains the learning model, but persistent storage must ensure learner data is durable.

---

## Database Choice

Use the database approach already selected in the project architecture.

Preferred:

```text id="dbengine"
PostgreSQL
```

If Prisma is already used in the project, define the schema through Prisma.

If the Jac/Jaseci stack already provides a preferred persistence mechanism, follow the project convention and document it clearly.

Do not introduce a second unrelated database.

Do not use localStorage as the main persistence layer.

Frontend localStorage may only be used for temporary journey recovery state.

---

## Persistence Scope

Persist data for these subsystems:

1. Authentication and learners
2. Assessment system
3. Roadmap system
4. Lesson generation system
5. Challenge generation system
6. Submission evaluation system
7. Mastery engine
8. Skill map source data
9. Progression engine
10. Dashboard aggregation source data
11. AI tutor source data where needed

Do not persist raw LLM responses.

Persist validated structured outputs only.

---

## Core Design Rules

Use stable IDs for all persisted entities.

Every table/model should include:

* id
* created_at
* updated_at where appropriate

Use foreign keys where supported.

Use indexes for frequently queried fields.

Use enum-like values consistently.

Avoid storing duplicated derived values unless needed for performance.

If derived values are stored, document their source and update rules.

---

## Learner Persistence

Persist learners.

Suggested model:

```text id="learner-model"
Learner
- id
- name
- username optional
- email optional
- created_at
- updated_at
```

Do not store plaintext passwords.

If auth endpoints already manage credentials separately, only store LMS learner profile data here.

If auth user and learner are separate concepts, store a link:

```text id="auth-link"
auth_user_id
```

---

## Assessment Persistence

Persist:

* Assessment
* AssessmentQuestion
* AssessmentOption
* AssessmentAttempt
* AssessmentResponse
* AssessmentEvaluation
* AssessmentQuestionResult
* AssessmentSkillSignal

Suggested models:

```text id="assessment-models"
Assessment
- id
- learner_id
- language
- title
- description
- status
- created_at
- updated_at

AssessmentQuestion
- id
- assessment_id
- question_text
- question_type
- skill_id optional
- difficulty
- order_index
- required

AssessmentOption
- id
- question_id
- label
- value
- order_index

AssessmentAttempt
- id
- learner_id
- assessment_id
- status
- submitted_at
- created_at
- updated_at

AssessmentResponse
- id
- attempt_id
- question_id
- response_type
- answer_value
- created_at

AssessmentEvaluation
- id
- learner_id
- assessment_id
- attempt_id
- score
- evaluation_version
- created_at

AssessmentQuestionResult
- id
- evaluation_id
- question_id
- correct
- earned_points
- possible_points
- order_index

AssessmentSkillSignal
- id
- evaluation_id
- skill_id
- score
- confidence
- evidence
- order_index
```

Do not store assessment evaluation as one large unstructured JSON blob unless the project intentionally uses JSON columns for flexible graph data.

Structured relational fields should be preferred for reporting and dashboard aggregation.

---

## Roadmap Persistence

Persist:

* Roadmap
* RoadmapWeek
* RoadmapLesson
* RoadmapMilestone

Suggested models:

```text id="roadmap-models"
Roadmap
- id
- learner_id
- language
- title
- description
- estimated_weeks
- status
- assessment_evaluation_id optional
- created_at
- updated_at

RoadmapWeek
- id
- roadmap_id
- week_number
- title
- summary
- created_at
- updated_at

RoadmapLesson
- id
- roadmap_id
- week_id
- title
- summary
- difficulty
- estimated_minutes
- order_index
- generation_status
- created_at
- updated_at

RoadmapMilestone
- id
- roadmap_id
- week_id
- title
- description
- order_index
- created_at
- updated_at
```

Roadmap lesson generation status values:

```text id="generation-status"
pending
generated
```

Roadmap status values:

```text id="roadmap-status"
draft
active
completed
```

---

## Skill Persistence

Persist:

* Skill
* SkillRelationship
* LessonSkillTarget
* ChallengeSkillTarget

Suggested models:

```text id="skill-models"
Skill
- id
- language
- name
- description
- category
- created_at
- updated_at

SkillRelationship
- id
- from_skill_id
- to_skill_id
- relationship_type
- created_at

LessonSkillTarget
- id
- roadmap_lesson_id
- skill_id
- created_at

ChallengeSkillTarget
- id
- challenge_id
- skill_id
- created_at
```

Supported skill relationship types:

```text id="skill-relationship-types"
prerequisite
teaches
reinforces
```

Do not create duplicate skill definitions for every learner unless required.

Skills should generally be reusable reference data scoped by language.

---

## Generated Lesson Persistence

Persist:

* GeneratedLesson
* LessonSection
* LessonExample
* LessonMiniExercise
* LessonTakeaway

Suggested models:

```text id="generated-lesson-models"
GeneratedLesson
- id
- learner_id
- roadmap_id
- roadmap_lesson_id
- language
- title
- summary
- difficulty
- estimated_minutes
- created_at
- updated_at

LessonSection
- id
- generated_lesson_id
- title
- content
- order_index

LessonExample
- id
- generated_lesson_id
- title
- code
- explanation
- order_index

LessonMiniExercise
- id
- generated_lesson_id
- prompt
- expected_concept
- order_index

LessonTakeaway
- id
- generated_lesson_id
- content
- order_index
```

Enforce uniqueness where possible:

```text id="lesson-unique"
learner_id + roadmap_lesson_id
```

This prevents duplicate generated lessons for the same roadmap lesson.

---

## Generated Challenge Persistence

Persist:

* GeneratedChallenge
* ChallengeInstruction
* ChallengeExpectedOutcome
* ChallengeConstraint
* ChallengeHint
* ChallengeEvaluationCriterion

Suggested models:

```text id="challenge-models"
GeneratedChallenge
- id
- learner_id
- roadmap_id
- roadmap_lesson_id
- generated_lesson_id
- language
- title
- prompt
- difficulty
- starter_code
- created_at
- updated_at

ChallengeInstruction
- id
- challenge_id
- content
- order_index

ChallengeExpectedOutcome
- id
- challenge_id
- content
- order_index

ChallengeConstraint
- id
- challenge_id
- content
- order_index

ChallengeHint
- id
- challenge_id
- content
- order_index

ChallengeEvaluationCriterion
- id
- challenge_id
- skill_id
- description
- weight
- order_index
```

Enforce uniqueness where possible:

```text id="challenge-unique"
learner_id + generated_lesson_id
```

This prevents duplicate generated challenges for the same lesson.

---

## Challenge Submission Persistence

Persist:

* ChallengeSubmission

Suggested model:

```text id="submission-model"
ChallengeSubmission
- id
- learner_id
- challenge_id
- language
- code
- status
- submitted_at
- created_at
- updated_at
```

Submission status values:

```text id="submission-status"
draft
submitted
```

Do not store evaluation score on the submission itself.

Submission evaluation belongs in a separate table/model.

---

## Submission Evaluation Persistence

Persist:

* SubmissionEvaluation
* CriterionResult
* SubmissionSkillSignal
* FeedbackItem

Suggested models:

```text id="submission-eval-models"
SubmissionEvaluation
- id
- learner_id
- challenge_id
- submission_id
- language
- score
- passed
- feedback_summary
- suggested_next_step
- evaluation_version
- evaluated_at
- created_at

CriterionResult
- id
- evaluation_id
- criterion_id
- skill_id
- score
- feedback
- met
- order_index

SubmissionSkillSignal
- id
- evaluation_id
- skill_id
- score
- confidence
- evidence
- order_index

FeedbackItem
- id
- evaluation_id
- feedback_type
- content
- order_index
```

Feedback type values:

```text id="feedback-types"
strength
improvement
suggestion
```

Enforce uniqueness where possible:

```text id="eval-unique"
submission_id
```

This prevents duplicate evaluations for the same submitted code.

---

## Mastery Persistence

Persist:

* SkillMastery
* MasteryEvidence

Suggested models:

```text id="mastery-models"
SkillMastery
- id
- learner_id
- skill_id
- score
- level
- evidence_count
- last_source_type
- last_source_id
- created_at
- updated_at

MasteryEvidence
- id
- learner_id
- skill_id
- source_type
- source_id
- signal_score
- confidence
- weighted_score
- evidence_summary
- created_at
```

Mastery levels:

```text id="mastery-levels"
beginner
developing
proficient
mastered
```

Source types:

```text id="mastery-source-types"
assessment_evaluation
submission_evaluation
```

Enforce uniqueness where possible:

```text id="mastery-unique"
learner_id + skill_id
```

For idempotency, enforce:

```text id="mastery-evidence-unique"
learner_id + skill_id + source_type + source_id
```

This prevents double-counting the same evidence.

---

## Progression Persistence

Persist:

* LessonProgress
* RoadmapProgress
* ProgressionEvent

Suggested models:

```text id="progression-models"
LessonProgress
- id
- learner_id
- roadmap_id
- roadmap_lesson_id
- status
- completed_at
- unlocked_at
- created_at
- updated_at

RoadmapProgress
- id
- learner_id
- roadmap_id
- total_lessons
- completed_lessons
- available_lessons
- locked_lessons
- percent_complete
- current_roadmap_lesson_id
- status
- created_at
- updated_at

ProgressionEvent
- id
- learner_id
- roadmap_id
- roadmap_lesson_id optional
- event_type
- source_type optional
- source_id optional
- message
- created_at
```

Lesson status values:

```text id="lesson-status"
locked
available
in_progress
completed
```

Roadmap progress status values:

```text id="roadmap-progress-status"
not_started
in_progress
completed
```

Progression event types:

```text id="progression-event-types"
roadmap_started
lesson_unlocked
lesson_completed
roadmap_completed
```

Enforce uniqueness where possible:

```text id="lesson-progress-unique"
learner_id + roadmap_lesson_id
```

```text id="roadmap-progress-unique"
learner_id + roadmap_id
```

---

## AI Tutor Persistence

Do not persist AI tutor recommendations in this feature unless the existing architecture requires recommendation history.

For now, `recommend_next_action` can remain read-only and return fresh DTOs.

If later persistence is needed, create it in a separate feature.

---

## Dashboard Persistence

Do not create a Dashboard table.

`get_dashboard` should remain a read model that aggregates from persisted entities.

Do not store dashboard DTOs as primary data.

---

## Enum / Constant Alignment

Create a shared constants source for statuses and types where appropriate.

Values that must remain consistent:

* language
* assessment status
* question type
* roadmap status
* lesson generation status
* difficulty
* submission status
* feedback type
* mastery level
* mastery source type
* lesson progress status
* roadmap progress status
* progression event type

Avoid string drift between backend and frontend.

---

## Indexing Requirements

Add indexes for common query patterns.

Recommended indexes:

```text id="indexes"
learner_id
roadmap_id
roadmap_lesson_id
generated_lesson_id
challenge_id
submission_id
skill_id
language
status
created_at
```

Composite indexes:

```text id="composite-indexes"
learner_id + language
learner_id + roadmap_id
learner_id + skill_id
learner_id + roadmap_lesson_id
learner_id + generated_lesson_id
learner_id + source_type + source_id
roadmap_id + order_index
roadmap_id + week_number
challenge_id + skill_id
```

Use unique constraints for idempotent entities.

---

## Migration Requirements

Create migration files using the project’s migration tool.

If Prisma is used:

```text id="prisma-migration"
npx prisma migrate dev --name init_lms_persistence
```

or the project-specific equivalent.

Do not rely on manual database edits.

Do not modify production data manually.

Document any required environment variables such as:

```text id="db-env"
DATABASE_URL
```

---

## Data Access Layer

Create or update repository/service helpers only if needed.

Suggested persistence helpers:

* learner repository
* assessment repository
* roadmap repository
* lesson repository
* challenge repository
* mastery repository
* progression repository

Keep repositories focused on persistence.

Do not move business logic into database helpers.

Walkers should orchestrate domain behavior.

Persistence helpers should save, load, and query.

---

## Graph And Database Synchronization

Clarify the relationship between OSP graph and database persistence.

The implementation must ensure:

* graph-created entities are persisted
* persisted entities can be reloaded into graph-aware workflows
* ids remain stable
* relationships are recoverable
* duplicate graph/database records are avoided

If the graph engine already persists nodes/edges internally, document that and ensure schema changes align with that mechanism.

If separate relational tables are used, document how graph IDs map to database IDs.

Do not allow frontend-only state to become the source of truth.

---

## Seed Data

Create minimal seed data if useful for testing.

Suggested seed skills:

Python:

* Variables
* Control Flow
* Functions
* Data Structures
* Error Handling

Jac:

* Nodes
* Edges
* Walkers
* OSP Traversal
* byLLM

Do not seed fake learner progress as production data.

Test fixtures can create progress separately.

---

## Validation Rules

Add persistence-level validation where appropriate.

Examples:

* score must be between 0 and 100
* signal score must be between 0.0 and 1.0
* confidence must be between 0.0 and 1.0
* order_index must be non-negative
* percent_complete must be between 0 and 100
* status must use allowed values
* language must use allowed values

Use database constraints where practical.

Use application-level validation where database constraints are not available.

---

## Idempotency Support

The schema must support idempotency for previous features.

Prevent duplicates for:

* generated lesson per learner + roadmap lesson
* generated challenge per learner + generated lesson
* submission evaluation per submission
* skill mastery per learner + skill
* mastery evidence per learner + skill + source
* lesson progress per learner + roadmap lesson
* roadmap progress per learner + roadmap

Do not rely only on frontend button disabling.

---

## Error Handling

Handle:

* database connection failure
* migration failure
* duplicate constraint violations
* missing foreign keys
* invalid enum values
* invalid score ranges
* failed transaction

Return structured backend errors where applicable.

Do not expose raw database errors to the frontend.

---

## Transactions

Use transactions for multi-entity writes.

Required transaction examples:

* create assessment with questions/options
* submit assessment with responses
* create roadmap with weeks/lessons/milestones
* generate lesson with sections/examples/exercises/takeaways
* generate challenge with instructions/outcomes/constraints/hints/criteria
* evaluate submission with criterion results/skill signals/feedback items
* update mastery with evidence and mastery record
* unlock next lesson with progress/event updates

Do not leave partially-created records as completed entities.

---

## Testing

Create persistence tests for:

* learner creation
* assessment creation with questions/options
* assessment attempt and responses
* assessment evaluation and skill signals
* roadmap creation with weeks/lessons/milestones
* generated lesson with sections/examples/exercises/takeaways
* generated challenge with criteria
* challenge submission
* submission evaluation
* mastery update
* progression update
* dashboard aggregation source queries
* uniqueness constraints
* foreign key constraints
* transaction rollback on failure

Tests should not require live AI providers.

Use deterministic fixtures.

---

## Verification Flow

After schema and persistence integration, verify the full LMS flow:

```text id="verification-flow"
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
→ Load dashboard
→ Load skill map
→ Load AI tutor recommendation
```

Then restart the backend and verify the same learner can log in and continue from persisted state.

---

## Explicitly Out of Scope

Do not implement:

* dashboard UI
* skill map UI
* AI tutor UI
* new recommendation logic
* new lesson generation logic
* new challenge generation logic
* new mastery calculation logic
* certificates
* notifications
* payments
* admin panel

This feature only implements durable LMS persistence.

---

## Check When Done

* Database schema exists
* Migration runs successfully
* Learners persist
* Assessments persist
* Assessment attempts persist
* Assessment evaluations persist
* Roadmaps persist
* Roadmap lessons persist
* Generated lessons persist
* Generated challenges persist
* Challenge submissions persist
* Submission evaluations persist
* Mastery records persist
* Progression records persist
* Skill records persist
* Required relationships persist
* Unique constraints prevent duplicates
* Transactions protect multi-entity writes
* Data reloads correctly after backend restart
* Dashboard DTO can be rebuilt from persisted data
* Skill map can be rebuilt from persisted data
* AI tutor can read persisted context
* Tests pass
