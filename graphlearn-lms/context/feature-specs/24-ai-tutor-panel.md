Read `AGENTS.md`, `context/ui-context.md`, and `context/architecture-context.md` before starting.

# 24-ai-tutor-panel.md

We're implementing the AI Tutor panel UI.

This feature displays the recommendation returned by the `recommend_next_action` walker.

The panel should show the learner what to do next, why it matters, and provide a clear navigation action.

Do not generate recommendations in the frontend.

Do not modify learner state.

Do not update mastery.

Do not unlock lessons.

Do not generate lessons.

Do not generate challenges.

Do not evaluate submissions.

---

## Goal

Create a focused AI Tutor interface that displays:

* recommended next action
* explanation/rationale
* priority
* confidence if useful
* related skill or lesson context
* suggested next step CTA

The AI Tutor panel should make the LMS feel guided without taking control away from the learner.

---

## Placement

Add the AI Tutor panel where it is most useful.

Recommended placement:

```text id="i17f6l"
Dashboard page → near the current lesson card or above recent activity
```

Optional additional placements:

```text id="ecwj76"
Roadmap page → above roadmap timeline
Lesson viewer → side panel or bottom card
Challenge feedback page → later
```

For this feature, implement the panel in the dashboard first.

Do not redesign the full dashboard.

Do not create a chat interface yet.

---

## Data Source

Load recommendation data through:

```text id="y27n8x"
recommend_next_action
```

Inputs:

* learner_id
* roadmap_id optional
* language optional

Use learner and roadmap context already available from the dashboard when possible.

Do not duplicate recommendation logic in the frontend.

Do not infer the recommended action from dashboard values in React.

The backend walker remains the source of truth.

---

## Required Data Shape

The UI should consume the output from Feature 23.

Expected shape:

```ts id="egnk9h"
type TutorRecommendationView = {
  learner_id: string;
  roadmap_id?: string;
  language?: "python" | "jac";
  recommendation_type: TutorRecommendationType;
  title: string;
  recommended_action: string;
  explanation: string;
  confidence: number;
  priority: "low" | "medium" | "high";
  related_roadmap_lesson_id?: string | null;
  related_challenge_id?: string | null;
  related_skill_ids?: string[];
  suggested_cta_label: string;
  created_at: string;
};
```

Recommendation type:

```ts id="s858bm"
type TutorRecommendationType =
  | "start_assessment"
  | "generate_roadmap"
  | "start_roadmap"
  | "continue_lesson"
  | "generate_lesson"
  | "start_challenge"
  | "retry_challenge"
  | "review_lesson"
  | "practice_weak_skill"
  | "view_skill_map"
  | "completed";
```

Use existing DTOs if already created.

Do not create duplicate incompatible types.

---

## UI Behavior

When the AI Tutor panel loads:

1. Read authenticated learner context.
2. Read active roadmap/language from dashboard context if available.
3. Call `recommend_next_action`.
4. Display loading state.
5. Display recommendation when returned.
6. Render CTA based on recommendation type.
7. Handle errors gracefully.

Do not call mutating walkers from this panel.

The CTA should navigate to existing screens only.

---

## Recommendation Card Content

Display:

* AI Tutor label
* recommendation title
* explanation
* recommended action
* priority badge
* CTA button

Example:

```text id="k5nbi7"
AI Tutor

Continue with Functions and Parameters

You passed the variables challenge and your Python basics are improving. Functions are the next step in your roadmap and build directly on what you just practiced.

Recommended action:
Open the next lesson and complete the practice challenge.

[Continue lesson]
```

Keep the language encouraging and direct.

Do not display long raw AI text blocks.

---

## Priority Display

Show priority as a badge or subtle label.

Supported values:

* low
* medium
* high

Do not rely on color alone.

Use text labels.

Example:

```text id="d54krt"
High priority
```

---

## Confidence Display

Confidence is optional in the UI.

Acceptable options:

1. Hide confidence from the learner.
2. Show a subtle label such as:

```text id="k2ixgf"
Tutor confidence: 86%
```

3. Use confidence only internally for fallback UI.

For MVP, prefer hiding confidence unless it helps debugging.

Do not make confidence the main focus.

---

## CTA Routing Rules

Map recommendation types to existing routes.

### start_assessment

CTA:

```text id="qkcesx"
Start assessment
```

Navigate to the assessment start flow or landing language selection.

Do not call `initialize_assessment` directly unless that is already the established flow.

---

### generate_roadmap

CTA:

```text id="q03bn8"
Generate roadmap
```

Navigate to assessment results or roadmap generation flow.

Do not call `generate_roadmap` directly from the tutor panel unless the existing UX already supports this safely.

---

### start_roadmap

CTA:

```text id="hqgqa6"
View roadmap
```

Navigate to roadmap page.

---

### continue_lesson

CTA:

```text id="h0nax4"
Continue lesson
```

Navigate to:

```text id="cbhgru"
/roadmap/:roadmapId/lesson/:relatedRoadmapLessonId
```

or the existing lesson route.

Do not call `generate_lesson` here.

The lesson viewer handles generation if needed.

---

### generate_lesson

CTA:

```text id="e9j1zr"
Open lesson
```

Navigate to the lesson viewer.

The lesson viewer triggers generation if the lesson is pending.

---

### start_challenge

CTA:

```text id="bg82c6"
Start challenge
```

Navigate to the challenge workspace if `related_challenge_id` exists.

If no challenge id exists, navigate to the lesson viewer so the existing lesson flow can generate/open a challenge.

---

### retry_challenge

CTA:

```text id="vfl65f"
Retry challenge
```

Navigate to the challenge workspace for the related challenge if available.

Do not regenerate the challenge from the tutor panel.

---

### review_lesson

CTA:

```text id="e0k2rv"
Review lesson
```

Navigate to the related lesson if available.

---

### practice_weak_skill

CTA:

```text id="oknm6k"
View skill map
```

Navigate to the skill map page.

Do not generate a new practice challenge from this panel.

---

### view_skill_map

CTA:

```text id="cl69qv"
View skill map
```

Navigate to the skill map page.

---

### completed

CTA:

```text id="dhmkol"
View roadmap
```

or:

```text id="ri29zf"
Review progress
```

Do not generate certificates.

---

## Missing Route Fallback

If the recommended CTA depends on a missing related id:

* show a safe fallback CTA
* prefer dashboard, roadmap, or skill map

Example:

```text id="u8k5gs"
View roadmap
```

Do not crash when `related_roadmap_lesson_id` or `related_challenge_id` is null.

---

## Loading State

Use a lightweight loading state.

Example:

```text id="rhxinj"
AI Tutor is reviewing your progress...
```

Use skeleton text/card if the dashboard layout is known.

Do not block the entire dashboard while the recommendation loads.

The dashboard should remain usable even if the tutor panel is loading.

---

## Error State

Handle:

* missing auth context
* failed recommendation load
* unsupported language
* roadmap not found
* malformed recommendation response

Show a friendly fallback:

```text id="fx8say"
AI Tutor is unavailable right now. You can still continue from your roadmap.
```

CTA:

```text id="hglw8f"
View roadmap
```

Do not expose raw backend stack traces.

Do not fail the whole dashboard if the tutor panel fails.

---

## Empty State

If no recommendation is available, show:

```text id="giqrq4"
No tutor recommendation yet.
Continue learning and your tutor will suggest the next best step.
```

CTA:

```text id="dxlxms"
View roadmap
```

This should be rare because the backend walker should return safe deterministic recommendations.

---

## UI Components

Create AI Tutor-specific components.

Suggested structure:

```text id="meph0d"
features/
└── tutor/
    ├── components/
    │   ├── ai-tutor-panel.cl.jac
    │   ├── tutor-recommendation-card.cl.jac
    │   ├── tutor-priority-badge.cl.jac
    │   ├── tutor-action-button.cl.jac
    │   ├── tutor-loading-state.cl.jac
    │   └── tutor-error-state.cl.jac
    ├── hooks/
    │   └── use-tutor-recommendation.cl.jac
    └── types/
        └── tutor-recommendation.cl.jac
```

Adapt paths to the project convention if needed.

Keep components presentation-focused.

---

## Design Requirements

Use existing UI primitives.

Recommended:

* Card
* Button
* Badge if available
* Skeleton if available

Use Lucide icons sparingly.

Suggested icons:

* `Sparkles`
* `Brain`
* `ArrowRight`
* `Map`
* `BookOpen`
* `Code2`
* `RefreshCcw`
* `AlertCircle`
* `CheckCircle2`

Follow the dark-only technical workspace theme.

The AI Tutor panel should feel visually distinct but consistent.

Use the AI accent style from `ui-context.md`.

Do not use hardcoded hex colors.

Do not use raw Tailwind colors like `zinc-*`, `slate-*`, or `neutral-*`.

Use tokens from `globals.css`.

---

## Accessibility

Ensure:

* panel has a clear heading
* recommendation text is readable
* CTA button has clear label
* priority is text-based, not color-only
* loading and error states are announced
* keyboard navigation works
* focus states are visible

Do not use animated effects that distract from reading.

---

## Responsive Behavior

Desktop:

* panel can sit beside current lesson/progress cards
* keep text concise

Tablet:

* panel spans full width if needed

Mobile:

* panel stacks with dashboard cards
* CTA remains visible
* avoid dense paragraphs

The panel should not push the primary dashboard progress too far down on mobile.

---

## Dashboard Integration

Update dashboard UI from Feature 22 to include the AI Tutor panel.

Recommended placement:

```text id="rcu2jd"
After dashboard header and before recent activity
```

or:

```text id="onfjry"
Beside the current lesson card
```

Do not modify dashboard aggregation logic.

Do not require the dashboard to wait for the tutor panel before rendering.

---

## Refresh Behavior

Recommendation should refresh when:

* learner opens dashboard
* roadmap id changes
* language changes
* learner manually clicks refresh if implemented

Optional button:

```text id="ifspda"
Refresh suggestion
```

If implemented, it should only re-call `recommend_next_action`.

It should not mutate learner state.

---

## Testing

Create tests for:

* recommendation loading state
* recommendation success rendering
* explanation visible
* CTA visible
* priority badge visible
* start assessment CTA routing
* roadmap CTA routing
* continue lesson CTA routing
* start challenge CTA routing
* retry challenge CTA routing
* skill map CTA routing
* completed state rendering
* missing related ids fallback
* recommendation load failure
* dashboard does not crash if tutor panel fails

Tests should not require live AI providers.

Mock the `recommend_next_action` walker response.

---

## Integration With Previous Features

This feature should work after:

1. dashboard UI loads
2. authenticated learner context exists
3. `recommend_next_action` walker exists
4. roadmap/progression/mastery data exists or is safely missing

The tutor panel should also handle early journey states:

* no assessment
* roadmap missing
* roadmap ready
* in progress
* completed

---

## Future Compatibility

This panel will later support:

* AI tutor chat
* contextual lesson help
* challenge feedback coaching
* review plans
* adaptive retry flows

Design the component so future expansions can add:

```text id="xkfo2l"
Ask tutor
Explain why
Show related skills
```

Do not implement these yet.

---

## Explicitly Out of Scope

Do not implement:

* AI tutor chat
* recommendation persistence
* mastery updates
* lesson unlocking
* roadmap generation
* lesson generation
* challenge generation
* submission evaluation
* dashboard aggregation
* notification system
* certificates

This feature only displays the tutor recommendation and routes the learner to existing screens.

---

## Check When Done

* AI Tutor panel renders on dashboard
* `recommend_next_action` is called with learner context
* Loading state appears while recommendation loads
* Recommendation title is visible
* Recommendation explanation is visible
* Recommended action is visible
* Priority displays correctly
* CTA label displays correctly
* CTA routes correctly for supported recommendation types
* Missing related ids use safe fallback routing
* Error state does not crash dashboard
* Dashboard remains usable if tutor panel fails
* Mobile layout remains readable
* Dark theme remains consistent
* No learner state is modified
* No lesson is unlocked
* No mastery is updated
