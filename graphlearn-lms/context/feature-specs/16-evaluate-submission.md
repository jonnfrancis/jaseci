Read `AGENTS.md`, and `context/architecture-context.md` before starting.

# 16-evaluate-submission.md

We're implementing the submission evaluation subsystem.

Walker:

`evaluate_submission`

This walker evaluates a learner's submitted code against a generated coding challenge.

The challenge workspace captures and persists learner submissions. This feature consumes those submissions and produces structured feedback, scoring, and skill evidence.

Do not update mastery.

Do not unlock the next lesson.

Do not update roadmap progress.

Do not generate a new challenge.

Do not run unsafe code execution.

---

## Goal

Evaluate a submitted coding challenge solution and produce:

* overall score
* structured feedback
* skill signals
* criterion-level results
* improvement suggestions
* evaluation metadata

The output should help the learner understand how they performed and provide enough evidence for the future mastery subsystem.

---

## Required Inputs

The walker should accept:

* learner_id
* challenge_id
* submission_id

The walker should load:

* learner
* generated challenge
* challenge instructions
* expected outcomes
* constraints
* hints
* evaluation criteria
* submitted code
* linked generated lesson
* linked roadmap lesson
* target skills

Do not accept raw challenge data directly from the frontend.

Do not accept arbitrary code outside a persisted submission.

Use the persisted `ChallengeSubmission` as the source of truth.

---

## Required Outputs

The walker should return a submission evaluation view.

The output should include:

* evaluation id
* learner id
* challenge id
* submission id
* language
* overall score
* passed status
* feedback summary
* criterion results
* skill signals
* strengths
* improvement areas
* suggested next step
* evaluated timestamp

Example shape:

```json
{
  "id": "submission_eval_001",
  "submission_id": "submission_001",
  "challenge_id": "challenge_001",
  "learner_id": "learner_001",
  "language": "python",
  "score": 82,
  "passed": true,
  "feedback_summary": "Good use of variables and formatted output. Improve naming consistency.",
  "criterion_results": [
    {
      "criterion_id": "criterion_001",
      "skill_id": "python_variables",
      "score": 0.9,
      "feedback": "Variables were used correctly.",
      "met": true
    }
  ],
  "skill_signals": [
    {
      "skill_id": "python_variables",
      "score": 0.9,
      "confidence": 0.85,
      "evidence": "The solution assigns and uses variables correctly."
    }
  ],
  "strengths": [
    "Used clear variable assignments."
  ],
  "improvement_areas": [
    "Use more descriptive variable names."
  ],
  "suggested_next_step": "Review formatting output with f-strings.",
  "evaluated_at": "2026-06-30T00:00:00Z"
}
```

---

## Evaluation Domain Models

Create or update:

* SubmissionEvaluation
* CriterionResult
* SubmissionSkillSignal
* FeedbackItem

SubmissionEvaluation should support:

* id
* learner_id
* challenge_id
* submission_id
* language
* score
* passed
* feedback_summary
* suggested_next_step
* evaluation_version
* evaluated_at
* created_at

CriterionResult should support:

* id
* evaluation_id
* criterion_id
* skill_id
* score
* feedback
* met
* order_index

SubmissionSkillSignal should support:

* id
* evaluation_id
* skill_id
* score
* confidence
* evidence
* order_index

FeedbackItem should support:

* id
* evaluation_id
* feedback_type
* content
* order_index

Feedback type values:

* strength
* improvement
* suggestion

Do not add mastery fields.

Do not add unlock fields.

---

## AI Evaluation Schemas

Create structured AI response objects for submission evaluation.

Examples:

* SubmissionEvaluationResult
* GeneratedCriterionResult
* GeneratedSkillSignal
* GeneratedFeedbackItem

All AI-visible objects and fields must include `sem` descriptions.

Use structured outputs only.

Do not parse raw AI text.

The LLM should return objects, not graph nodes.

After byLLM returns structured objects, copy validated fields into persistent graph nodes.

---

## AI Evaluation Function

Create a reusable AI function inside the AI module.

Suggested name:

`evaluate_code_submission`

Inputs should include:

* language
* challenge title
* challenge prompt
* starter code
* instructions
* expected outcomes
* constraints
* evaluation criteria
* submitted code
* lesson title
* lesson summary
* target skills

Output:

* SubmissionEvaluationResult

Use:

```jac
by llm(...)
```

Use complete `sem` descriptions for:

* function
* parameters
* return object
* every field on return object

Do not use free-form feedback strings as the only result.

The feedback must be structured.

---

## Evaluation Rules

The evaluator should grade based on the persisted challenge definition.

Use:

* challenge prompt
* instructions
* expected outcomes
* constraints
* evaluation criteria
* submitted code

Evaluation should consider:

* correctness
* skill alignment
* clarity
* completeness
* whether constraints were followed

Evaluation should not require running code unless a safe execution layer already exists.

For this feature, AI evaluation is acceptable as static review.

Do not execute arbitrary learner code.

Do not use shell access.

Do not install packages.

Do not make network calls.

Do not access files.

---

## Scoring Rules

Overall score should be numeric:

```text
0-100
```

Criterion scores should be numeric:

```text
0.0-1.0
```

Skill signal scores should be numeric:

```text
0.0-1.0
```

Passing threshold:

```text
score >= 70
```

The threshold should be centralized as a constant or config value.

Do not hardcode the value in multiple files.

Do not treat passing as mastery.

Passing means:

```text
The submitted solution meets the challenge requirements.
```

It does not mean:

```text
The learner has mastered the topic.
```

Mastery will be handled later by `update_mastery`.

---

## Implement evaluate_submission Walker

The walker should:

1. Receive learner_id, challenge_id, and submission_id

2. Validate learner exists

3. Validate challenge exists

4. Validate submission exists

5. Validate submission belongs to learner

6. Validate submission belongs to challenge

7. Validate submission status is `submitted`

8. Check if evaluation already exists for this submission

9. If evaluation exists, return it

10. Load challenge context

11. Load evaluation criteria

12. Load submitted code

13. Build evaluation context

14. Call AI evaluation function

15. Validate structured evaluation output

16. Normalize score values

17. Create SubmissionEvaluation node

18. Create CriterionResult nodes

19. Create SubmissionSkillSignal nodes

20. Create FeedbackItem nodes

21. Connect evaluation to submission

22. Connect evaluation to challenge

23. Connect evaluation to learner

24. Return evaluation view

The walker should orchestrate only.

Do not place long prompt text directly inside the walker.

---

## Graph Relationships

Persist relationships between:

Learner → SubmissionEvaluation

GeneratedChallenge → SubmissionEvaluation

ChallengeSubmission → SubmissionEvaluation

SubmissionEvaluation → CriterionResult

SubmissionEvaluation → SubmissionSkillSignal

SubmissionEvaluation → FeedbackItem

SubmissionSkillSignal → Skill

Use existing graph edge patterns where possible.

Suggested relationships:

* evaluated
* contains
* signals
* targets

Do not create mastery edges.

Do not create unlock edges.

Do not create completion edges.

---

## Persistence Requirements

The evaluation must persist successfully.

Criterion results must persist successfully.

Skill signals must persist successfully.

Feedback items must persist successfully.

Relationships must persist successfully.

The evaluation must be retrievable after creation.

Do not store raw LLM responses.

Only store validated structured outputs.

---

## Idempotency

Evaluating the same submitted solution repeatedly should not create duplicate evaluations.

If a submission evaluation already exists for the same submission:

* return the existing evaluation
* do not call byLLM again
* do not create duplicate criterion results
* do not create duplicate skill signals
* do not create duplicate feedback items

This is important because learners may refresh after submitting.

---

## Feedback Requirements

Feedback should be:

* specific
* encouraging
* actionable
* tied to the challenge requirements
* appropriate for the learner's level

Feedback should include:

* what was done well
* what needs improvement
* what to do next

Avoid vague feedback such as:

```text
Good job.
```

Prefer:

```text
You correctly used variables to store separate values, but your final output should combine those variables instead of hardcoding the full sentence.
```

---

## Skill Signal Requirements

Skill signals are evidence only.

Each skill signal should include:

* skill id
* score
* confidence
* evidence

Skill signals should be usable later by:

* update_mastery
* unlock_next_lesson
* get_skill_map
* recommend_next_action

Do not update those systems now.

---

## Error Handling

Handle:

* missing learner
* missing challenge
* missing submission
* submission does not belong to learner
* submission does not belong to challenge
* submission is still draft
* unsupported language
* missing evaluation criteria
* invalid AI output
* byLLM failure
* persistence failure

Return structured errors.

Do not silently create partial evaluations.

If persistence fails after partial creation, document the cleanup strategy or ensure partial evaluation records cannot be returned as complete.

---

## MockLLM Test Coverage

Create MockLLM tests for:

* Python submission evaluation
* Jac submission evaluation
* passing submission
* failing submission
* partial success submission
* criterion result creation
* skill signal creation
* feedback item creation
* existing evaluation reuse
* draft submission rejection
* submission/challenge mismatch rejection
* unsupported language rejection
* malformed AI output rejection

Tests must run without API keys.

Use structured MockLLM outputs.

Do not rely on live providers.

---

## Frontend Contract

Create or update frontend DTOs for submission evaluation results.

The frontend should be able to consume:

* SubmissionEvaluationView
* CriterionResultView
* SubmissionSkillSignalView
* FeedbackItemView

Do not create the full feedback UI in this feature unless a minimal local test display is needed.

The challenge workspace may show a simple post-submission action:

```text
Evaluate submission
```

or navigate to a future feedback page after evaluation.

---

## Integration With Previous Features

This feature should work after:

1. learner completes assessment
2. roadmap is generated
3. lesson is generated
4. challenge is generated
5. learner submits code in the challenge workspace

The evaluator should consume:

* GeneratedChallenge
* ChallengeEvaluationCriterion
* ChallengeSubmission

Do not modify the original challenge.

Do not modify the original submission.

Create a separate evaluation record.

---

## Future Compatibility

This evaluation will feed future features:

* submission feedback UI
* update_mastery
* unlock_next_lesson
* get_dashboard
* get_skill_map
* recommend_next_action
* retry challenge generation

Design evaluation data so the mastery system can later use:

* overall score
* passed status
* skill signals
* criterion results
* feedback summary

Do not implement those features now.

---

## Explicitly Out of Scope

Do not implement:

* mastery updates
* lesson unlocking
* roadmap progress updates
* dashboard analytics
* skill map visualization
* retry challenge generation
* AI tutor chat
* certificate logic
* unsafe code execution
* terminal output

This feature only evaluates a submitted coding challenge and persists feedback evidence.

---

## Check When Done

* `evaluate_submission` walker compiles
* Submitted Python challenge can be evaluated
* Submitted Jac challenge can be evaluated
* Draft submissions are rejected
* Challenge/submission mismatch is rejected
* Existing evaluation is reused on repeat calls
* Evaluation includes overall score
* Evaluation includes passed status
* Evaluation includes feedback summary
* Evaluation includes criterion results
* Evaluation includes skill signals
* Evaluation includes strengths
* Evaluation includes improvement areas
* Evaluation includes suggested next step
* Evaluation is persisted to the graph
* Structured AI outputs validate correctly
* MockLLM tests pass without API keys
* No mastery update occurs
* No unlock logic exists
* No roadmap progress update occurs
