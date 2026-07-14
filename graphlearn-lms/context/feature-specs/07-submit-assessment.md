Read `AGENTS.md`, and `context/architecture-context.md` before starting.

We're implementing assessment submission and response persistence.

Walker:

`submit_assessment`

This walker receives learner responses from the assessment UI and persists them to the graph.

The purpose of this feature is to create a durable assessment attempt record that future walkers can evaluate.

Do not perform scoring, grading, mastery calculation, or roadmap generation.

---

### Create Assessment Attempt Domain Models

Create persistence models for learner submissions.

Examples:

* AssessmentAttempt
* AssessmentResponse

AssessmentAttempt should support:

* id
* learner_id
* assessment_id
* status
* submitted_at
* completed_at

AssessmentResponse should support:

* id
* question_id
* answer_value
* response_type

Responses should remain independent from evaluation results.

Do not add score-related fields.

Do not add mastery-related fields.

---

### Create submit_assessment Walker

Implement:

`submit_assessment`

Responsibilities:

1. Receive learner responses

2. Validate assessment exists

3. Validate learner exists

4. Create assessment attempt

5. Create response entities

6. Link responses to attempt

7. Link attempt to learner

8. Link attempt to assessment

9. Persist everything to graph

10. Return created attempt

The walker should be persistence-focused.

Do not perform business evaluation.

---

### Input Requirements

The walker should accept:

* learner identifier
* assessment identifier
* submitted responses

Responses should include:

* question identifier
* answer value

Support:

* multiple choice responses
* short answer responses

Design so additional response types can be added later.

---

### Validation

Validate:

* assessment exists
* learner exists
* questions belong to assessment
* response references valid question ids
* required questions have responses

Reject invalid submissions.

Do not attempt to auto-correct invalid data.

---

### Graph Relationships

Persist relationships between:

Learner → AssessmentAttempt

Assessment → AssessmentAttempt

AssessmentAttempt → AssessmentResponse

AssessmentResponse → AssessmentQuestion

The graph should allow future walkers to retrieve:

* all learner attempts
* all responses for an attempt
* all responses for an assessment
* all attempts for a learner

---

### Submission Status Tracking

Support assessment lifecycle states.

Examples:

* draft
* in_progress
* submitted

When submission succeeds:

* attempt status becomes submitted
* submission timestamp is recorded

Do not introduce grading states yet.

---

### Persistence Requirements

Only persist validated responses.

Do not store raw UI state.

Do not store frontend-only objects.

Persist normalized graph entities only.

The attempt must be retrievable after creation.

The responses must be retrievable after creation.

---

### Create Response Retrieval Helpers

Create reusable query helpers for future walkers.

Examples:

* get_attempt()
* get_attempt_responses()
* get_learner_attempts()
* get_assessment_attempts()

These helpers will be used later by scoring and mastery workflows.

Do not implement scoring logic.

---

### Mock Testing

Create tests covering:

* successful submission
* attempt creation
* response creation
* graph persistence
* invalid assessment
* invalid learner
* invalid question references

Verify persisted data can be retrieved.

---

### Future Compatibility

Design submission records so future walkers can consume them.

Future walkers include:

* score_assessment
* evaluate_responses
* calculate_mastery
* generate_learning_roadmap
* recommend_challenges

This feature should provide all data required by those workflows.

Do not implement them now.

---

### Explicitly Out of Scope

Do not implement:

* assessment scoring
* answer correctness checks
* mastery calculation
* skill evaluation
* challenge recommendations
* roadmap generation
* learner feedback generation
* AI analysis of responses

This feature is persistence only.

---

### Check when done

* submit_assessment walker compiles
* AssessmentAttempt entities are created
* AssessmentResponse entities are created
* Responses persist successfully
* Learner relationships persist successfully
* Assessment relationships persist successfully
* Submitted attempts can be retrieved
* Submitted responses can be retrieved
* Validation rejects invalid submissions
* Tests pass successfully
* No scoring logic exists
* No mastery logic exists
* No roadmap generation exists
