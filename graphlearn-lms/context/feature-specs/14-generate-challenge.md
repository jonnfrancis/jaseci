Read `AGENTS.md`, `context/architecture-context.md`, and `context/ui-context.md` before starting.

# 14-generate-challenge.md

We're implementing on-demand coding challenge generation.

Walker:

`generate_challenge`

This walker generates a hands-on coding challenge for a generated lesson.

The lesson subsystem creates readable lesson content. This feature turns that lesson into a practical coding task that the learner can attempt later in the challenge workspace.

Do not evaluate submissions.

Do not run code.

Do not update mastery.

Do not unlock the next lesson.

Do not create the challenge workspace UI.

---

## Goal

Generate a coding challenge that is:

* aligned with the generated lesson
* focused on the lesson's target skills
* appropriate for the learner's roadmap language
* practical enough to test understanding
* structured enough for future AI evaluation
* persisted for reuse

The challenge should prepare the next subsystem: challenge workspace and submission evaluation.

---

## Required Inputs

The walker should accept:

* learner_id
* roadmap_id
* roadmap_lesson_id
* generated_lesson_id
* language

Supported language values:

* python
* jac

The walker should load:

* learner
* roadmap
* roadmap lesson
* generated lesson
* lesson sections
* lesson examples
* lesson mini exercises
* target skills
* assessment evaluation summary if available

Do not accept arbitrary challenge prompts from the frontend.

Do not accept raw prompt text from the frontend.

Use the generated lesson and roadmap lesson as the source of truth.

---

## Required Outputs

The walker should return a generated challenge view.

The output should include:

* challenge id
* learner id
* roadmap id
* roadmap lesson id
* generated lesson id
* language
* title
* prompt
* difficulty
* starter code
* instructions
* expected outcomes
* constraints
* hints
* evaluation criteria
* created timestamp

Example shape:

```json
{
  "id": "challenge_001",
  "generated_lesson_id": "lesson_001",
  "roadmap_lesson_id": "roadmap_lesson_001",
  "language": "python",
  "title": "Practice Variables and Data Types",
  "prompt": "Create variables to store a learner's name, age, and score, then print a formatted summary.",
  "difficulty": "beginner",
  "starter_code": "# Write your code here\n",
  "instructions": [
    "Create a variable called name.",
    "Create a variable called age.",
    "Create a variable called score.",
    "Print a sentence using all three variables."
  ],
  "expected_outcomes": [
    "Learner creates valid variables.",
    "Learner uses appropriate data types.",
    "Learner prints a readable output."
  ],
  "constraints": [
    "Do not hardcode the full output as one string.",
    "Use variables in the final print statement."
  ],
  "hints": [
    "Use assignment with the equals sign.",
    "Use f-strings for formatted output."
  ],
  "evaluation_criteria": [
    {
      "skill_id": "python_variables",
      "description": "Uses variables correctly.",
      "weight": 0.5
    }
  ]
}
```

---

## Challenge Domain Models

Ensure challenge entities exist or extend the existing challenge model.

Create or update:

* GeneratedChallenge
* ChallengeInstruction
* ChallengeExpectedOutcome
* ChallengeConstraint
* ChallengeHint
* ChallengeEvaluationCriterion

GeneratedChallenge should support:

* id
* learner_id
* roadmap_id
* roadmap_lesson_id
* generated_lesson_id
* language
* title
* prompt
* difficulty
* starter_code
* created_at
* updated_at

ChallengeInstruction should support:

* id
* challenge_id
* content
* order_index

ChallengeExpectedOutcome should support:

* id
* challenge_id
* content
* order_index

ChallengeConstraint should support:

* id
* challenge_id
* content
* order_index

ChallengeHint should support:

* id
* challenge_id
* content
* order_index

ChallengeEvaluationCriterion should support:

* id
* challenge_id
* skill_id
* description
* weight
* order_index

Do not create submission entities in this feature.

Do not create evaluation result entities in this feature.

---

## AI Challenge Schemas

Create structured AI response objects for challenge generation.

Examples:

* ChallengeGenerationResult
* GeneratedChallengeInstruction
* GeneratedChallengeExpectedOutcome
* GeneratedChallengeConstraint
* GeneratedChallengeHint
* GeneratedChallengeEvaluationCriterion

All AI-visible objects and fields must include `sem` descriptions.

Use structured outputs only.

Do not parse raw AI text.

The LLM should return objects, not graph nodes.

After byLLM returns structured objects, copy validated fields into persistent graph nodes.

---

## AI Challenge Generation Function

Create a reusable AI function inside the AI module.

Suggested name:

`generate_coding_challenge`

Inputs should include:

* language
* lesson title
* lesson summary
* lesson difficulty
* lesson sections
* lesson examples
* lesson mini exercises
* target skills
* learner weak skills if available
* learner strong skills if available
* previous challenge titles if available

Output:

* ChallengeGenerationResult

Use:

```jac
by llm(...)
```

Use complete `sem` descriptions for:

* function
* parameters
* return object
* every field on return object

Do not use free-form text generation.

Do not place large prompt text directly inside the walker.

---

## Challenge Generation Rules

The generated challenge should be hands-on.

It should ask the learner to write or modify code.

It should not be a multiple-choice quiz.

It should not ask only conceptual questions.

It should not require external packages, internet access, files, databases, or hidden services.

The challenge should be completable in:

* beginner: 5–10 minutes
* intermediate: 10–15 minutes
* advanced: 15–25 minutes

For Python challenges:

* starter code must be valid Python
* challenge should run in a simple Python environment
* avoid external libraries unless the lesson specifically covered them
* expected outcomes should be observable from code structure or output

For Jac challenges:

* starter code must use Jac syntax where possible
* challenge should reinforce graph-native thinking where relevant
* connect to nodes, edges, walkers, abilities, OSP, or byLLM when appropriate
* keep beginner Jac challenges small and approachable

Do not generate dangerous or system-level tasks.

Do not generate tasks requiring filesystem mutation, network calls, secrets, credentials, package installation, or shell access.

---

## Implement generate_challenge Walker

The walker should:

1. Receive learner_id, roadmap_id, roadmap_lesson_id, generated_lesson_id, and language

2. Validate learner exists

3. Validate roadmap exists

4. Validate roadmap belongs to learner

5. Validate roadmap lesson exists

6. Validate generated lesson exists

7. Validate generated lesson belongs to the roadmap lesson

8. Check if a generated challenge already exists for this generated lesson

9. If generated challenge exists, return it

10. Build challenge generation context

11. Call the AI challenge generation function

12. Validate structured challenge output

13. Create GeneratedChallenge node

14. Create ChallengeInstruction nodes

15. Create ChallengeExpectedOutcome nodes

16. Create ChallengeConstraint nodes

17. Create ChallengeHint nodes

18. Create ChallengeEvaluationCriterion nodes

19. Connect challenge to generated lesson

20. Connect challenge to roadmap lesson

21. Connect challenge to target skills

22. Return generated challenge view

The walker should orchestrate only.

Do not embed long prompt logic directly inside the walker.

---

## Graph Relationships

Persist relationships between:

Learner → GeneratedChallenge

Roadmap → GeneratedChallenge

RoadmapLesson → GeneratedChallenge

GeneratedLesson → GeneratedChallenge

GeneratedChallenge → ChallengeInstruction

GeneratedChallenge → ChallengeExpectedOutcome

GeneratedChallenge → ChallengeConstraint

GeneratedChallenge → ChallengeHint

GeneratedChallenge → ChallengeEvaluationCriterion

GeneratedChallenge → Skill

Use existing graph edge patterns where possible.

If new edges are required, add only the minimum needed.

Suggested relationships:

* generated_for
* contains
* targets
* evaluates

Do not add submission edges yet.

Do not add mastery edges yet.

Do not add unlock edges yet.

---

## Persistence Requirements

The generated challenge must persist successfully.

Instructions must persist successfully.

Expected outcomes must persist successfully.

Constraints must persist successfully.

Hints must persist successfully.

Evaluation criteria must persist successfully.

Relationships must persist successfully.

The generated challenge must be retrievable after generation.

Do not store raw LLM output.

Only store validated structured challenge data.

---

## Idempotency

Generating the same challenge repeatedly should not create duplicates.

If a generated challenge already exists for the same learner and generated_lesson_id:

* return the existing generated challenge
* do not call byLLM again
* do not create duplicate instructions/outcomes/hints/criteria

This is important because users may refresh the challenge page.

---

## Loading State Compatibility

This walker may take longer than normal graph operations.

The frontend should be able to display loading states such as:

* Creating your coding challenge...
* Building starter code...
* Preparing hints...
* Saving challenge...

Do not implement challenge UI loading in this feature unless needed for local testing.

The walker should return clear success or structured error states.

---

## Error Handling

Handle:

* missing learner
* missing roadmap
* roadmap does not belong to learner
* missing roadmap lesson
* missing generated lesson
* generated lesson does not belong to roadmap lesson
* unsupported language
* invalid target skills
* invalid AI output
* byLLM failure
* persistence failure

Return structured errors.

Do not silently create partial challenges.

If persistence fails after partial creation, document the cleanup strategy or ensure partial records cannot be returned as complete challenges.

---

## MockLLM Test Coverage

Create MockLLM tests for:

* Python challenge generation
* Jac challenge generation
* beginner challenge
* intermediate challenge
* existing generated challenge reuse
* instruction creation
* expected outcome creation
* constraint creation
* hint creation
* evaluation criterion creation
* invalid generated lesson rejection
* unsupported language rejection

Tests must run without API keys.

Use structured MockLLM outputs.

Do not rely on live providers.

---

## Frontend Contract

Create or update frontend DTOs for generated challenge results.

The frontend should be able to consume:

* GeneratedChallengeView
* ChallengeInstructionView
* ChallengeExpectedOutcomeView
* ChallengeConstraintView
* ChallengeHintView
* ChallengeEvaluationCriterionView

Do not create challenge workspace UI in this feature.

Do not create code editor UI in this feature.

---

## Integration With Previous Features

This feature should work after:

1. learner completes assessment
2. assessment is evaluated
3. roadmap is generated
4. lesson is generated
5. lesson viewer displays the generated lesson
6. learner requests a coding challenge

The generated challenge should be tied to the generated lesson, not just the roadmap lesson outline.

---

## Future Compatibility

This generated challenge will feed future features:

* challenge workspace
* submit challenge solution
* evaluate_submission
* update_mastery
* unlock_next_lesson
* get_dashboard
* recommend_next_action

Design challenge data so the evaluation walker can later use:

* prompt
* starter code
* expected outcomes
* constraints
* evaluation criteria
* target skills
* learner submitted code

Do not implement those features now.

---

## Explicitly Out of Scope

Do not implement:

* challenge workspace UI
* Monaco editor
* code execution
* submission storage
* AI grading
* answer evaluation
* mastery updates
* unlock logic
* dashboard analytics
* skill map visualization
* AI tutor recommendations
* certificates

This feature only generates and persists coding challenges.

---

## Check When Done

* `generate_challenge` walker compiles
* Python challenge can be generated
* Jac challenge can be generated
* Generated challenge uses generated lesson content
* Generated challenge includes prompt
* Generated challenge includes starter code
* Generated challenge includes instructions
* Generated challenge includes expected outcomes
* Generated challenge includes constraints
* Generated challenge includes hints
* Generated challenge includes evaluation criteria
* Generated challenge is persisted to the graph
* Existing generated challenge is reused on repeat calls
* Structured AI outputs validate correctly
* MockLLM tests pass without API keys
* No submission is created
* No evaluation occurs
* No mastery update occurs
* No unlock logic exists
