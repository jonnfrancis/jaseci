Read `AGENTS.md`, `context/domain-context.md`, `context/assessment-context.md`, and `context/ui-context.md` before starting.

# 09-landingpage-ui.md

## Goal

Create the first end-to-end user experience for the platform.

Implement a landing page that allows a learner to begin an assessment journey for one of the initial supported languages:

* Python
* Jac

This feature serves as the integration point for all assessment workflows implemented in previous features.

The landing page should initiate the assessment lifecycle and prove the complete assessment pipeline works.

---

## User Journey

The learner should be able to:

1. Open landing page
2. View supported learning tracks
3. Select Python or Jac
4. Start assessment
5. Complete assessment
6. Submit responses
7. Receive evaluation results

This should exercise:

* initialize_assessment
* assessment_ui
* submit_assessment
* evaluate_assessment

End-to-end.

---

## Create Landing Page

Create:

`/`

Landing page should include:

### Hero Section

Display:

* platform name
* value proposition
* start assessment CTA

Example messaging:

* Discover your current skill level
* Get personalized learning guidance
* Start with a quick assessment

Exact copy may vary.

---

### Supported Languages Section

Initially support:

* Python
* Jac

Display:

* language name
* short description
* assessment CTA

Example:

Python

* fundamentals
* syntax
* functions
* control flow

Jac

* graph-native programming
* walkers
* nodes
* edges
* traversal concepts

Do not expose future languages yet.

---

## Create Language Selection Flow

User selects:

* Python
* Jac

Selection should determine:

* assessment template
* question set
* evaluation rules

Pass selected language into assessment initialization.

---

## Integrate initialize_assessment

When learner clicks:

Start Assessment

System should:

1. Create assessment instance
2. Generate assessment questions
3. Create assessment entity
4. Persist assessment

Use:

`initialize_assessment`

Do not generate results yet.

---

## Integrate Assessment UI

After initialization:

Navigate learner to assessment interface.

Use:

`assessment_ui`

Assessment UI should:

* render questions
* collect responses
* track progress
* allow submission

Assessment UI should remain presentation-only.

Business logic stays in walkers.

---

## Integrate submit_assessment

When learner submits:

1. Validate responses
2. Create assessment attempt
3. Persist responses
4. Persist attempt

Use:

`submit_assessment`

Do not evaluate in UI layer.

---

## Integrate evaluate_assessment

After successful submission:

Invoke:

`evaluate_assessment`

Generate:

* question results
* score
* skill signals

Persist evaluation.

---

## Create Assessment Results Screen

Display:

### Overall Score

Show:

* percentage
* earned points
* total points

Example:

80%

8 / 10 Correct

---

### Skill Breakdown

Display generated skill signals.

Example:

Python Functions

* 90%

Variables

* 100%

Control Flow

* 60%

This is evaluation output only.

Do not display mastery levels.

---

### Assessment Summary

Display:

* questions answered
* completion time
* submission timestamp

---

## Create Navigation Flow

Landing Page

↓

Language Selection

↓

Assessment

↓

Submit

↓

Evaluation

↓

Results

Navigation should be deterministic and recoverable.

Page refresh should not lose persisted state.

---

## State Management

Persist:

* selected language
* assessment id
* attempt id

State should survive navigation.

Prefer server-backed persistence.

Do not rely solely on client memory.

---

## Error Handling

Handle:

### Assessment Initialization Failure

Display:

Unable to start assessment

Allow retry.

---

### Submission Failure

Display:

Unable to submit assessment

Allow retry.

Prevent duplicate submissions.

---

### Evaluation Failure

Display:

Assessment submitted successfully

Evaluation pending

Allow evaluation retry.

---

## UI Architecture

Separate:

### Presentation Layer

Responsible for:

* rendering
* user interaction
* navigation

---

### Application Layer

Responsible for:

* walker orchestration
* API calls
* state coordination

---

### Domain Layer

Responsible for:

* assessment logic
* scoring logic
* persistence

UI should never contain business rules.

---

## Accessibility

Support:

* keyboard navigation
* screen readers
* focus management
* semantic HTML

Assessment should be usable without a mouse.

---

## Responsive Design

Support:

* desktop
* tablet
* mobile

Assessment flow should remain functional on all screen sizes.

---

## End-to-End Testing

Create integration tests covering:

### Python Assessment Flow

Landing Page

→ Python

→ Assessment

→ Submit

→ Evaluate

→ Results

---

### Jac Assessment Flow

Landing Page

→ Jac

→ Assessment

→ Submit

→ Evaluate

→ Results

---

### Failure Scenarios

Verify:

* initialization failure
* invalid submission
* evaluation failure
* page refresh recovery

---

## Success Criteria

The following workflow succeeds:

Landing Page

↓

Select Python

↓

Assessment Created

↓

Questions Displayed

↓

Answers Submitted

↓

Assessment Evaluated

↓

Results Displayed

The same workflow succeeds for Jac.

---

## Explicitly Out of Scope

Do not implement:

* mastery calculation
* learner progression
* adaptive assessments
* roadmap generation
* challenge generation
* AI tutoring
* recommendations
* achievement systems
* authentication
* multi-language expansion

This feature exists solely to validate the Phase 1 assessment pipeline.

---

## Check When Done

* Landing page renders
* Python assessment can be started
* Jac assessment can be started
* initialize_assessment invoked successfully
* Assessment UI renders questions
* Responses can be submitted
* submit_assessment invoked successfully
* evaluate_assessment invoked successfully
* Results screen displays score
* Results screen displays skill signals
* State survives refresh
* Python flow passes end-to-end tests
* Jac flow passes end-to-end tests
* No mastery updates occur
* No roadmap generation occurs
* All integration tests pass
