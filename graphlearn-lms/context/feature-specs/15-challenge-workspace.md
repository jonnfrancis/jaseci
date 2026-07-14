Read `AGENTS.md`, `context/ui-context.md`, and `context/architecture-context.md` before starting.

# 15-challenge-workspace.md

We're implementing the coding challenge workspace.

This feature gives learners a place to attempt a generated coding challenge.

The workspace should display the generated challenge, provide an editor for the learner's solution, and persist the learner submission.

Do not grade code.

Do not evaluate submissions.

Do not update mastery.

Do not unlock the next lesson.

Do not run code in a sandbox unless a safe runner already exists.

---

## Goal

Create a challenge workspace where a learner can:

* open a challenge linked to a generated lesson
* read challenge instructions
* view starter code
* write or edit a solution
* submit their answer
* persist the submitted solution
* see a submission captured/saved state

This feature should prepare the next subsystem: `evaluate_submission`.

---

## Route / Page

Create a challenge workspace page.

Suggested route:

```text
/roadmap/:roadmapId/lesson/:roadmapLessonId/challenge/:challengeId
```

or use the routing convention already established in the Jac Client / React + Vite app.

The page should use:

* learner id from authenticated user context
* roadmap id from route params
* roadmap lesson id from route params
* challenge id from route params

Do not rely only on navigation state.

A page refresh should still load the challenge correctly.

---

## Data Loading Behavior

When the challenge workspace opens:

1. Load the generated challenge by id.
2. Validate it belongs to the selected lesson and roadmap.
3. Load existing draft submission if one exists.
4. If no draft exists, initialize the editor with challenge starter code.
5. Display the challenge workspace.

Do not call `generate_challenge` repeatedly if a challenge already exists.

If a challenge does not exist yet, the lesson viewer may navigate here only after calling `generate_challenge`.

Do not generate a new challenge from inside the workspace unless the current project flow already requires that behavior.

---

## Required Challenge Data Shape

The UI should consume the generated challenge result from Feature 14.

Expected shape:

```ts
type GeneratedChallengeView = {
  id: string;
  learner_id: string;
  roadmap_id: string;
  roadmap_lesson_id: string;
  generated_lesson_id: string;
  language: "python" | "jac";
  title: string;
  prompt: string;
  difficulty: "beginner" | "intermediate" | "advanced";
  starter_code: string;
  instructions: ChallengeInstructionView[];
  expected_outcomes: ChallengeExpectedOutcomeView[];
  constraints: ChallengeConstraintView[];
  hints: ChallengeHintView[];
  evaluation_criteria: ChallengeEvaluationCriterionView[];
  created_at: string;
  updated_at?: string;
};
```

Use existing frontend DTOs if already created.

Do not create duplicate incompatible types.

---

## Submission Model

Create or update frontend DTOs for challenge submissions.

Suggested shape:

```ts
type ChallengeSubmissionDraft = {
  challenge_id: string;
  learner_id: string;
  code: string;
  language: "python" | "jac";
  status: "draft" | "submitted";
  updated_at?: string;
};
```

Submitted response shape:

```ts
type ChallengeSubmissionView = {
  id: string;
  challenge_id: string;
  learner_id: string;
  code: string;
  language: "python" | "jac";
  status: "submitted";
  submitted_at: string;
};
```

Do not include score fields.

Do not include feedback fields.

Do not include mastery fields.

---

## Backend Submission Walker

If not already available, create a focused walker:

```text
submit_challenge
```

Responsibilities:

1. Receive learner id, challenge id, and submitted code.
2. Validate learner exists.
3. Validate challenge exists.
4. Validate challenge belongs to the learner's roadmap/lesson context.
5. Create ChallengeSubmission entity.
6. Persist submitted code.
7. Link submission to learner.
8. Link submission to challenge.
9. Return created submission.

The walker should only persist the submission.

Do not grade code.

Do not call byLLM.

Do not calculate mastery.

Do not unlock content.

---

## Challenge Submission Domain Models

Create or update:

* ChallengeSubmission

ChallengeSubmission should support:

* id
* learner_id
* challenge_id
* language
* code
* status
* submitted_at
* created_at
* updated_at

Status values:

* draft
* submitted

If draft persistence is implemented, drafts should be saved separately from final submissions or with status `draft`.

Do not add evaluation fields.

Do not add score fields.

---

## Graph Relationships

Persist relationships between:

Learner → ChallengeSubmission

GeneratedChallenge → ChallengeSubmission

ChallengeSubmission → GeneratedChallenge

Use existing graph edge patterns where possible.

Suggested relationships:

* attempted
* submitted_for

Do not create mastery edges.

Do not create unlock edges.

Do not create evaluation edges yet.

---

## Workspace Layout

Use the bento-style LMS workspace direction established earlier.

Recommended desktop layout:

```text
Left panel: challenge instructions
Center panel: code editor
Right panel: outcomes, constraints, hints, submit state
```

Recommended mobile layout:

```text
Top: challenge summary
Middle: editor
Bottom: instructions, hints, submit action
```

The editor should be the visual priority.

Do not hide critical challenge instructions inside collapsed UI by default.

---

## Challenge Header

Display:

* challenge title
* language badge
* difficulty badge
* linked lesson title if available
* estimated completion hint if available

Include navigation back to the lesson viewer.

Example:

```text
Practice Variables and Data Types
Python · Beginner
```

---

## Instructions Panel

Display:

* prompt
* ordered instructions
* expected outcomes
* constraints

Each section should be clearly labeled.

Use existing design system cards and spacing.

Do not render evaluation criteria as hidden grading rules unless the UI already presents them clearly as “What this challenge checks”.

---

## Hints Panel

Display hints in a non-spoiler way.

Recommended behavior:

* show hint titles or collapsed hint cards
* learner can reveal hints one by one

Do not block submission if hints are opened.

Do not count hints against score in this feature.

---

## Code Editor

Add a coding editor.

Preferred:

* Monaco Editor if already installed or already planned
* CodeMirror if the project uses it
* Textarea fallback if editor installation is not part of this feature

The editor must support:

* initial starter code
* editing code
* preserving indentation
* language mode for Python or Jac if available
* dark theme styling

Do not implement code execution yet.

Do not add terminal output unless a safe runner already exists.

---

## Draft Behavior

Preserve learner progress while working.

Minimum requirement:

* keep editor code in local React state

Preferred:

* autosave draft locally using localStorage keyed by challenge id

Optional if simple:

* persist draft through backend with status `draft`

Do not let page refresh wipe work if avoidable.

---

## Submission Flow

When the learner clicks submit:

1. Validate code is not empty.
2. Disable submit button.
3. Call `submit_challenge`.
4. Persist final submission.
5. Show success state.
6. Store returned submission id.
7. Offer next action.

Next action should be:

```text
Continue to feedback
```

or:

```text
Evaluate submission
```

Only if the next feature route already exists.

For this feature, it is acceptable to show:

```text
Submission saved. Evaluation will be added next.
```

Do not call `evaluate_submission`.

---

## Validation

Before submission:

* code must not be empty
* challenge id must exist
* learner must be authenticated
* language must be supported

Show user-friendly validation messages.

Do not perform correctness validation.

Do not run static analysis.

Do not infer score.

---

## Loading States

Handle:

* challenge loading
* draft loading
* submission in progress
* submission success
* submission failure

Use skeletons where layout is known.

Example messages:

```text
Loading your challenge...
Saving your solution...
Submission saved.
```

Do not leave the user on a blank screen.

---

## Error States

Handle:

* missing auth context
* missing challenge id
* challenge not found
* failed challenge load
* failed submission
* unsupported language
* malformed challenge response

Each error should offer a clear action:

* retry
* return to lesson
* return to roadmap
* log in again

Do not expose raw backend traces.

---

## UI Components

Create challenge-specific components.

Suggested structure:

```text
features/
└── challenge/
    ├── components/
    │   ├── challenge-workspace-layout.cl.jac
    │   ├── challenge-header.cl.jac
    │   ├── challenge-instructions-panel.cl.jac
    │   ├── challenge-editor.cl.jac
    │   ├── challenge-hints-panel.cl.jac
    │   ├── challenge-submit-panel.cl.jac
    │   ├── challenge-loading-state.cl.jac
    │   └── challenge-error-state.cl.jac
    ├── hooks/
    │   ├── use-generated-challenge.cl.jac
    │   └── use-challenge-submission.cl.jac
    └── types/
        └── challenge-workspace.cl.jac
```

Adapt paths to the project convention if needed.

Keep components presentation-focused.

---

## Design Requirements

Use existing UI primitives.

Recommended:

* Button
* Card
* Badge if available
* ScrollArea
* Dialog only if confirming final submission
* Textarea if editor fallback is needed

Use Lucide icons sparingly.

Suggested icons:

* `Code2`
* `BookOpen`
* `CheckCircle2`
* `Lightbulb`
* `Send`
* `AlertCircle`
* `ChevronLeft`

Follow the dark-only technical workspace theme.

Do not use hardcoded hex colors.

Do not use raw Tailwind colors like `zinc-*`, `slate-*`, or `neutral-*`.

Use tokens from `globals.css`.

---

## Accessibility

Ensure:

* page has one clear `h1`
* editor has an accessible label
* submit button state is announced clearly
* errors are associated with relevant inputs
* keyboard navigation works
* focus states are visible
* hint reveal buttons are keyboard accessible

Do not rely on color alone for status.

---

## Responsive Behavior

Desktop:

* three-panel workspace
* editor receives the largest area
* instructions and hints stay visible

Tablet:

* two-column layout if space allows

Mobile:

* panels stack vertically
* editor remains usable
* submit action remains easy to reach
* no critical information is hidden behind hover-only UI

---

## Integration With Lesson Viewer

Update the lesson viewer from Feature 13 to expose a challenge CTA.

Suggested CTA:

```text
Start coding challenge
```

Behavior:

1. If a challenge already exists for the lesson, navigate to workspace.
2. If no challenge exists, call `generate_challenge`.
3. Show loading state while challenge is generated.
4. Navigate to challenge workspace after generation.

Do not evaluate anything from the lesson viewer.

Do not update mastery.

---

## Future Compatibility

This feature will feed:

* evaluate_submission
* update_mastery
* unlock_next_lesson
* get_dashboard
* recommend_next_action

Ensure the submitted code is persisted with enough context for future evaluation:

* learner id
* challenge id
* language
* submitted code
* submitted timestamp

Do not implement these future features now.

---

## Explicitly Out of Scope

Do not implement:

* code execution
* terminal output
* AI grading
* evaluate_submission
* mastery updates
* unlock logic
* dashboard analytics
* skill map updates
* AI tutor feedback
* certificates

This feature only displays challenges and captures submissions.

---

## Check When Done

* Challenge workspace route works
* Generated challenge loads by id
* Challenge title and prompt render correctly
* Instructions render correctly
* Expected outcomes render correctly
* Constraints render correctly
* Hints render correctly
* Code editor displays starter code
* Learner can edit code
* Draft code survives refresh where feasible
* Empty submissions are blocked
* Submission button disables while saving
* `submit_challenge` persists submitted code
* Submission id is returned and stored
* Success state displays after submission
* Lesson viewer can start or open a challenge
* No grading occurs
* No byLLM evaluation occurs
* No mastery update occurs
* No unlock logic exists
