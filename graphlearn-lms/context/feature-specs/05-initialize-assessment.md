Read `AGENTS.md`, and `context/architecture-context.md` before starting.

We're implementing the first LMS walker.

Walker:

`initialize_assessment`

This walker creates a personalized assessment for a learner using byLLM and persists the result to the graph.

The assessment is intended to establish the learner's current skill level before roadmap generation.

Implement:

* assessment generation schemas
* assessment AI prompts
* assessment creation walker
* assessment entity creation
* graph persistence

Use the AI foundation created in Feature 04.

Do not implement scoring, grading, evaluation, or mastery calculations.

---

### Create Assessment Domain Models

Ensure assessment-related entities exist.

Examples:

* Assessment
* AssessmentQuestion
* AssessmentOption

Assessment should support:

* id
* learner_id
* title
* description
* status
* created_at
* questions

AssessmentQuestion should support:

* id
* question_text
* question_type
* skill
* difficulty
* options

AssessmentOption should support:

* id
* label
* value

Do not add score-related fields.

---

### Create Assessment AI Schemas

Create structured AI response objects for assessment generation.

Examples:

* AssessmentGenerationResult
* GeneratedQuestion
* GeneratedOption

All AI-visible objects and fields must use sem descriptions.

Use structured outputs only.

Do not parse raw AI text.

---

### Create Assessment Generation Functions

Create reusable AI-powered functions inside the AI module.

Responsibilities:

* generate assessment title
* generate assessment description
* generate assessment questions
* generate answer options

Inputs may include:

* learner goals
* learner interests
* target skills
* target role
* assessment length

Outputs must be typed objects.

Use `by llm(...)`.

Provide complete sem descriptions.

---

### Implement initialize_assessment Walker

Create the first assessment workflow walker.

Responsibilities:

1. Receive learner information

2. Gather assessment generation context

3. Call assessment AI generation functions

4. Create assessment entities

5. Create assessment question entities

6. Connect entities appropriately

7. Persist to graph

The walker should return the created Assessment.

The walker should not perform scoring.

The walker should not evaluate answers.

The walker should not create roadmaps.

---

### Persistence Requirements

Assessments must persist successfully.

Questions must persist successfully.

Relationships between assessment and questions must persist successfully.

The assessment must be retrievable after creation.

Do not store raw LLM responses.

Only persist validated structured outputs.

---

### Assessment Generation Rules

Generate questions appropriate to:

* learner goals
* learner experience level
* target skills

Support at least:

* multiple choice
* short answer

Question difficulty should be included.

Questions should be skill-oriented and useful for later mastery evaluation.

The generated assessment should be deterministic enough for testing.

---

### MockLLM Test Coverage

Create MockLLM tests for:

* assessment generation
* assessment creation
* graph persistence

Tests must run without API keys.

Use structured mock outputs.

Do not rely on live providers.

---

### Future Compatibility

Design the assessment so future walkers can consume it.

Future features will include:

* score_assessment
* evaluate_responses
* calculate_mastery
* generate_roadmap
* recommend_challenges

Do not implement these features now.

Ensure initialize_assessment produces all information they will need later.

---

### Check when done

* initialize_assessment walker compiles
* Assessment entities are created successfully
* Assessment questions are created successfully
* Structured AI outputs validate correctly
* Assessment is persisted to the graph
* Persisted assessment can be retrieved
* MockLLM tests pass
* No scoring logic exists
* No mastery calculation exists
* No roadmap generation exists
