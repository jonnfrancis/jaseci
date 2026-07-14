## Goal

Implement assessment evaluation.

Create a walker that evaluates a completed assessment attempt and produces scoring results and skill evidence signals.

This feature converts learner responses into structured assessment outcomes.

Do not update mastery, learner models, progression state, recommendations, or learning plans.

## Walker
`evaluate_assessment`

Evaluate a submitted assessment attempt.

#### Inputs:

* assessment
* assessment attempt
* learner answers

#### Outputs:

* score
* question results
* skill signals
* evaluation metadata

## Responsibilities
### 1. Load Assessment

Retrieve:

* assessment definition
* question set
* answer keys
* scoring configuration
* skill mappings

Validate:

* assessment exists
* assessment is active
* attempt exists
* attempt is submitted

Fail if assessment data is invalid.

### 2. Evaluate Questions

Process each question independently.

Supported question types for MVP:

#### Multiple Choice

Compare learner answer against answer key.

Output:
* correct
* incorrect
* points earned
* points possible

#### Multi-Select

Validate selected options.

Support:
* exact match scoring

Output:
* correct
* incorrect
* points earned
* points possible

#### Short Answer
Use evaluation strategy defined by assessment.

Support:
* exact match
* normalized text match

Normalization should include:
* trim whitespace
* lowercase comparison

Output:
* correct
* incorrect
* points earned
* points possible

### 3. Generate Question Result
Create a result record for every question.

Example:
````
{
  "question_id": "q_001",
  "correct": true,
  "earned_points": 1,
  "possible_points": 1
}
````
Store all question results for auditing.
Question results must be reproducible.

### 4. Calculate Overall Score
Aggregate question outcomes.

Calculate:

* earned points
* possible points
* percentage score

Example:
```
{
  "earned_points": 8,
  "possible_points": 10,
  "percentage": 80
}
```
Scoring must be deterministic.
Same inputs must always produce same outputs.

### 5. Generate Skill Signals
Convert question outcomes into evidence about skills.

Each question should map to one or more skills.
Example:
````
{
  "skill_id": "fractions",
  "correct": true,
  "weight": 1.0
}
````
Aggregate evidence per skill.
Example:
````
{
  "skill_id": "fractions",
  "correct_count": 4,
  "incorrect_count": 1,
  "accuracy": 0.8
}
````
Skill signals are evidence only.
Do not determine mastery levels.
Do not update learner state.

### 6. Create Evaluation Record
Persist evaluation results.

Store:
* assessment id
* assessment attempt id
* learner id
* question results
* overall score
* skill signals
* evaluation timestamp
* evaluation version

Example:
```
{
  "evaluation_id": "eval_123",
  "attempt_id": "attempt_456",
  "score": {
    "earned_points": 8,
    "possible_points": 10,
    "percentage": 80
  }
}
```
### 7. Ensure Idempotency
Evaluating the same submitted attempt multiple times should not create conflicting results.
Options:

* return existing evaluation
* replace previous evaluation
Choose one strategy and document it.
Behavior must be deterministic.

### Data Model
#### AssessmentEvaluation
Fields:
* id
* assessment_id
* assessment_attempt_id
* learner_id
* score
* question_results
* skill_signals
* evaluation_version
* created_at

#### QuestionResult
Fields:
* question_id
* correct
* earned_points
* possible_points

#### SkillSignal
Fields:
* skill_id
* correct_count
* incorrect_count
* accuracy
* Architecture Rules
* Evaluation Logic
Place all scoring logic in domain services.
Walker should orchestrate only.
Do not embed scoring rules in persistence code.

#### Separation of Concerns

Evaluation:
* reads assessments
* reads attempts
* scores responses
* generates skill evidence

Evaluation must not:
* update mastery
* unlock content
* create recommendations
* modify learner profile
* modify learning plans
Those belong to later features.

### Error Handling
Handle:
* missing assessment
* missing attempt
* assessment not found
* attempt not submitted
* invalid answer key
* unsupported question type
* persistence failures
Return structured errors.

### Acceptance Criteria
#### Functional
* Assessment can be evaluated
* Question results generated correctly
* Overall score calculated correctly
* Skill signals generated correctly
* Results persisted correctly

#### Architectural
* Evaluation separated from mastery updates
* Deterministic scoring
* Idempotent evaluation behavior
* Domain logic separated from storage

#### Testing
Verify:
* all-correct assessment
* all-incorrect assessment
* mixed results
* multiple skills
* short-answer normalization
* repeated evaluation of same attempt
* invalid assessment handling

### Out of Scope
Do not implement:
* mastery updates
* learner progression
* recommendations
* adaptive sequencing
* content unlocking
* assessment regeneration
* partial credit scoring
* AI-assisted grading
* rubric-based grading
Those belong to future features.