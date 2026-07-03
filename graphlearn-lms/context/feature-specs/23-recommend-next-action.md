Read `AGENTS.md`, and `context/architecture-context.md` before starting.

# 23-recommend-next-action.md

We're implementing the AI Tutor recommendation subsystem.

Walker:

`recommend_next_action`

This walker analyzes the learner's current roadmap, mastery state, lesson history, challenge history, and progression state, then returns a personalized recommendation for what the learner should do next.

Do not modify learner state.

Do not update mastery.

Do not unlock lessons.

Do not generate lessons.

Do not generate challenges.

Do not evaluate submissions.

Do not create dashboard UI.

---

## Goal

Return a personalized AI tutor recommendation that helps the learner decide what to do next.

The recommendation should answer:

* What should the learner do next?
* Why is this the best next step?
* Which skill or lesson does it relate to?
* Is the learner ready to continue?
* Should the learner review, practice, retry, or move forward?

The output should be useful for a future dashboard recommendation card, AI tutor panel, or learning assistant.

---

## Required Inputs

The walker should accept:

* learner_id
* roadmap_id optional
* language optional

Supported language values:

```text id="1xx0us"
python
jac
```

If `roadmap_id` is provided:

* recommend based on that roadmap

If `roadmap_id` is not provided:

* resolve the learner's active roadmap

If `language` is not provided:

* use the language from the active roadmap

Do not accept raw recommendation context from the frontend.

Use persisted graph data only.

---

## Data To Load

The walker should load:

* learner
* active roadmap
* roadmap weeks
* roadmap lessons
* roadmap progress
* lesson progress
* generated lessons
* generated challenges
* challenge submissions
* submission evaluations
* skill mastery records
* mastery evidence
* assessment evaluation if available
* recent progression events
* dashboard summary if a helper exists

This walker should aggregate context, then ask byLLM to produce a recommendation.

Do not mutate any of these records.

---

## Required Outputs

The walker should return a `TutorRecommendationView`.

The output should include:

* learner id
* roadmap id
* language
* recommendation type
* title
* recommended action
* explanation
* confidence
* priority
* related lesson id optional
* related challenge id optional
* related skill ids
* suggested CTA label
* created timestamp

Example shape:

```json id="5o9smk"
{
  "learner_id": "learner_001",
  "roadmap_id": "roadmap_001",
  "language": "python",
  "recommendation_type": "continue_lesson",
  "title": "Continue with Functions and Parameters",
  "recommended_action": "Open the next available lesson and complete the coding challenge.",
  "explanation": "You have completed the variables lesson and your mastery in Python basics is developing. Functions are the next roadmap step and build directly on your current skills.",
  "confidence": 0.86,
  "priority": "high",
  "related_roadmap_lesson_id": "roadmap_lesson_005",
  "related_challenge_id": null,
  "related_skill_ids": ["python_functions"],
  "suggested_cta_label": "Continue lesson",
  "created_at": "2026-06-30T00:00:00Z"
}
```

---

## Recommendation Types

Support these recommendation types:

```text id="m7en5x"
start_assessment
generate_roadmap
start_roadmap
continue_lesson
generate_lesson
start_challenge
retry_challenge
review_lesson
practice_weak_skill
view_skill_map
completed
```

Use the most appropriate type based on learner state.

Do not introduce too many types early.

Keep the recommendation model stable.

---

## Priority Levels

Support:

```text id="lsm2pi"
low
medium
high
```

Priority should reflect urgency and usefulness.

Examples:

* `high`: learner is blocked or has an obvious next lesson
* `medium`: learner should review or practice
* `low`: optional skill map review or reflection

---

## AI Tutor Schemas

Create structured AI response objects for tutor recommendations.

Examples:

* TutorRecommendationResult
* TutorRecommendationReason
* TutorRecommendedResource

All AI-visible objects and fields must include `sem` descriptions.

Use structured outputs only.

Do not parse raw AI text.

The LLM should return objects, not graph nodes.

Do not persist recommendation records in this feature unless already required by the architecture.

This feature can return a generated recommendation DTO directly.

---

## AI Tutor Function

Create a reusable AI function inside the AI module.

Suggested name:

`generate_next_action_recommendation`

Inputs should include:

* language
* roadmap title
* roadmap status
* roadmap progress summary
* current lesson summary
* lesson status summary
* challenge status summary
* mastery summary
* weakest skills
* strongest skills
* recent activity
* available lessons
* locked lessons
* completed lessons

Output:

* TutorRecommendationResult

Use:

```jac id="te3jbc"
by llm(...)
```

Use complete `sem` descriptions for:

* function
* parameters
* return object
* every field on return object

Do not place large prompt text directly inside the walker.

---

## Deterministic Pre-Checks

Before calling byLLM, apply simple deterministic rules for obvious learner states.

Examples:

### No assessment exists

Return:

```text id="t3r10g"
recommendation_type = start_assessment
```

Do not call byLLM.

---

### Assessment evaluated but no roadmap exists

Return:

```text id="lxq9k5"
recommendation_type = generate_roadmap
```

Do not call byLLM.

---

### Roadmap exists but progression has not started

Return:

```text id="d5nal2"
recommendation_type = start_roadmap
```

Do not call byLLM unless explanation quality is needed.

---

### Roadmap completed

Return:

```text id="1u0e1k"
recommendation_type = completed
```

Do not call byLLM unless generating a celebratory explanation is already allowed.

---

Use byLLM mainly when the learner has meaningful progress history and the best next action depends on mastery/challenge evidence.

---

## Recommendation Logic Guidelines

The tutor should prefer:

1. Continue the current available lesson if one exists.
2. Start a challenge if the lesson is read but the challenge is not attempted.
3. Retry or review if a challenge was failed.
4. Practice weak skills if mastery is low.
5. View skill map if the learner needs orientation.
6. Celebrate completion if the roadmap is complete.

The recommendation should not override progression rules.

If a lesson is locked, do not recommend starting it.

If a challenge has not been generated yet, recommend starting/generating it only through the existing learner flow.

If no roadmap exists, do not recommend lessons.

---

## Safety And Scope Rules

The AI tutor should only recommend actions inside the LMS.

Allowed recommendation actions:

* start assessment
* continue assessment
* generate roadmap
* view roadmap
* open lesson
* review lesson
* start challenge
* retry challenge
* view feedback
* view skill map
* continue learning

Do not recommend:

* external websites
* paid courses
* downloading tools
* contacting people
* unsafe code execution
* system-level programming tasks
* activities outside the LMS flow

---

## Implement recommend_next_action Walker

The walker should:

1. Receive learner_id, optional roadmap_id, and optional language

2. Validate learner exists

3. Resolve roadmap if available

4. Load assessment state

5. Load roadmap progress

6. Load lesson progress

7. Load generated lessons

8. Load generated challenges

9. Load challenge submissions

10. Load submission evaluations

11. Load skill mastery records

12. Build a compact recommendation context

13. Apply deterministic pre-checks

14. If needed, call AI tutor recommendation function

15. Validate structured recommendation output

16. Normalize recommendation type, confidence, priority, and related ids

17. Return TutorRecommendationView

The walker should read and reason only.

No graph mutation should happen inside this walker.

---

## Context Size Control

Do not send entire lesson content or full code submissions to byLLM.

Use compact summaries only.

Allowed context:

* lesson titles
* lesson summaries
* lesson statuses
* mastery scores
* recent feedback summaries
* challenge pass/fail state
* recent activity titles

Do not include full submitted code unless a future tutoring feature specifically needs code-level help.

This feature recommends next actions, not detailed code coaching.

---

## Confidence Rules

Confidence should be a number:

```text id="4jbhid"
0.0-1.0
```

If deterministic rule produces the recommendation, use high confidence:

```text id="6hrvyd"
0.9
```

If AI chooses between multiple reasonable options, confidence may be lower.

Clamp confidence to:

```text id="apg2ad"
0.0-1.0
```

---

## Idempotency

Repeated calls to `recommend_next_action` should not create duplicate records.

Because this feature is read-only:

* return a fresh DTO
* do not persist by default
* do not update timestamps in graph state
* do not create activity events

It is acceptable for the recommendation wording to vary slightly when byLLM is used.

If deterministic rules apply, output should be stable.

---

## Error Handling

Handle:

* missing learner
* unsupported language
* roadmap not found
* roadmap does not belong to learner
* malformed progress data
* malformed mastery data
* byLLM failure
* invalid AI output

If byLLM fails after context is available, return a safe deterministic fallback recommendation when possible.

Example fallback:

```text id="z0lu3k"
Continue with your current available lesson.
```

Do not fail the whole dashboard if a fallback is possible.

---

## Testing

Create tests for:

* no assessment recommendation
* assessment completed but no roadmap recommendation
* roadmap ready recommendation
* current lesson recommendation
* lesson read but challenge missing recommendation
* failed challenge retry recommendation
* weak skill review recommendation
* completed roadmap recommendation
* unsupported language rejection
* missing learner rejection
* roadmap ownership rejection
* byLLM fallback behavior
* structured AI output validation

Use MockLLM for AI recommendation tests.

Tests must run without API keys.

---

## Frontend Contract

Create or update frontend DTOs for tutor recommendations.

The frontend should be able to consume:

* TutorRecommendationView
* TutorRecommendationType
* TutorRecommendationPriority

Do not create the AI tutor UI in this feature unless a minimal debug display is needed.

The dashboard UI can later add a recommendation card that calls this walker.

---

## Integration With Previous Features

This feature should work after:

1. learner registers/logs in
2. assessment state exists
3. roadmap state exists
4. lesson state exists
5. challenge/submission/evaluation state exists
6. mastery state exists
7. progression state exists
8. dashboard DTO exists

But it must also handle early states safely.

---

## Future Compatibility

This feature will feed:

* AI tutor card on dashboard
* AI tutor panel
* contextual lesson help
* challenge feedback assistant
* retry recommendation flow
* adaptive review loops

Design the output so the UI can render a recommendation without doing extra reasoning.

---

## Explicitly Out of Scope

Do not implement:

* AI tutor chat UI
* dashboard recommendation card
* mastery updates
* lesson unlocking
* roadmap generation
* lesson generation
* challenge generation
* submission evaluation
* code-level debugging tutor
* external resource recommendations
* notifications

This feature only returns the next recommended LMS action.

---

## Check When Done

* `recommend_next_action` walker compiles
* No-assessment recommendation returns
* Roadmap-missing recommendation returns
* Current lesson recommendation returns
* Challenge recommendation returns
* Retry recommendation returns after failed challenge
* Weak skill recommendation returns when appropriate
* Completed roadmap recommendation returns
* Recommendation includes type
* Recommendation includes title
* Recommendation includes action
* Recommendation includes explanation
* Recommendation includes confidence
* Recommendation includes priority
* Recommendation includes related ids where available
* byLLM structured outputs validate correctly
* MockLLM tests pass without API keys
* Fallback recommendation works if byLLM fails
* No learner state is modified
* No lesson is unlocked
* No mastery is updated
