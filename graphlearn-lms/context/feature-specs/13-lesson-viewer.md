Read `AGENTS.md`, `context/ui-context.md`, `context/domain-context.md`, `context/roadmap-context.md`, and `context/lesson-context.md` before starting.

# 13-lesson-viewer.md

We're implementing the lesson reading experience.

This feature displays generated lesson content created by the `generate_lesson` walker.

The learner should be able to open a roadmap lesson, generate or load the full lesson content, read through the lesson sections, view examples, complete lightweight mini exercises, and mark the lesson as read.

Do not generate coding challenges.

Do not evaluate submissions.

Do not calculate mastery.

Do not unlock the next lesson.

Do not implement the full coding workspace yet.

---

## Goal

Create a focused lesson viewer for generated LMS lessons.

The lesson viewer should support:

* loading generated lessons
* triggering lesson generation if content does not exist
* readable lesson sections
* code examples
* mini exercises
* key takeaways
* section navigation
* completion tracking

This feature should make generated lessons readable and testable before the challenge subsystem begins.

---

## Route / Page

Create a lesson page.

Suggested route:

```text
/roadmap/:roadmapId/lesson/:roadmapLessonId
```

or use the routing convention already established in the Jac Client / React + Vite app.

The page should use:

* learner id from authenticated user context
* roadmap id from route params
* roadmap lesson id from route params
* selected language from roadmap/lesson data

Do not rely only on navigation state.

A page refresh should still load the lesson correctly.

---

## Data Loading Behavior

When the lesson page opens:

1. Check whether the roadmap lesson already has generated lesson content.
2. If generated content exists, load and display it.
3. If generated content does not exist, call `generate_lesson`.
4. Display a helpful generation loading state.
5. Persist and display the generated lesson returned by the walker.

Do not call `generate_lesson` repeatedly if the lesson already exists.

Do not generate content on the roadmap page.

Lesson generation should happen only when the learner opens a specific lesson.

---

## Required Data Shape

The UI should consume the generated lesson result from Feature 12.

Expected lesson shape:

```ts
type GeneratedLessonView = {
  id: string;
  learner_id: string;
  roadmap_id: string;
  roadmap_lesson_id: string;
  language: "python" | "jac";
  title: string;
  summary: string;
  difficulty: "beginner" | "intermediate" | "advanced";
  estimated_minutes: number;
  sections: LessonSectionView[];
  examples: LessonExampleView[];
  mini_exercises: LessonMiniExerciseView[];
  key_takeaways: LessonTakeawayView[];
  created_at: string;
  updated_at?: string;
};
```

Use existing frontend DTOs if already created.

Do not create duplicate incompatible types.

---

## Page Layout

Use a focused reading layout.

Recommended desktop layout:

```text
Left sidebar: section navigation
Center: lesson content
Right sidebar: lesson metadata and takeaways
```

Recommended mobile layout:

```text
Top: lesson metadata
Main: lesson content
Bottom: navigation actions
```

Keep the content readable.

Avoid full-width text blocks.

Use the dark technical workspace theme from `ui-context.md`.

---

## Lesson Header

Display:

* lesson title
* summary
* language badge
* difficulty badge
* estimated minutes
* generation status if relevant

Include a back link to the roadmap page.

Example:

```text
Variables and Data Types
Learn how Python stores and works with values.
Beginner · Python · 12 min
```

---

## Section Navigation

Create section navigation based on generated lesson sections.

Requirements:

* display section titles
* highlight active section
* allow jumping between sections
* support keyboard navigation
* remain usable on mobile

Do not implement complex scroll spy if it creates unnecessary complexity.

A simple clickable outline is acceptable.

---

## Lesson Sections

Render each lesson section in order.

Each section should show:

* title
* content
* order index

The content may be plain text or markdown-like text.

Support markdown rendering if the project already has a markdown renderer.

If adding markdown support, keep it minimal.

Do not introduce a heavy rich text editor.

---

## Code Examples

Render generated examples clearly.

Each example should show:

* title
* code block
* explanation

Requirements:

* preserve code formatting
* use mono font
* support copy-to-clipboard
* visually separate examples from prose

Use language-aware labels:

* Python examples: `python`
* Jac examples: `jac`

Do not implement code execution in this feature.

Do not add Monaco Editor yet unless already installed and required.

Static code blocks are enough for the lesson viewer.

---

## Mini Exercises

Display mini exercises as lightweight reading checks.

Each mini exercise should show:

* prompt
* expected concept

For this feature, mini exercises are not graded.

Optional simple interaction:

* checkbox: "I understand this"
* local completion state

Do not persist exercise scores.

Do not call evaluation walkers.

Do not calculate mastery.

---

## Key Takeaways

Display key takeaways near the end of the lesson or in a side panel.

Each takeaway should be short and scannable.

Use a card or list pattern consistent with the existing design system.

---

## Completion Tracking

Allow the learner to mark the lesson as read.

Create a simple completion action:

```text
Mark lesson as complete
```

This action may persist a basic completion state if a completion relationship/entity already exists.

If no backend completion walker exists yet, keep completion local or create a minimal placeholder that does not affect mastery.

Do not call `update_mastery`.

Do not call `unlock_next_lesson`.

Do not unlock content.

Completion here means:

```text
The learner has finished reading this lesson.
```

It does not mean:

```text
The learner has mastered the skill.
```

---

## Navigation Actions

Add basic navigation actions:

* Back to roadmap
* Previous lesson outline if available
* Next lesson outline if available

Important:

* Previous/Next should navigate between roadmap lesson pages only.
* If the next lesson has not been generated yet, its page can trigger generation when opened.
* Do not implement unlock restrictions yet.
* Do not infer mastery from navigation.

---

## Loading States

Handle lesson generation/loading with helpful messages.

Examples:

```text
Generating your lesson...
Building examples...
Preparing mini exercises...
Saving lesson content...
```

Use skeletons where layout is known.

Use spinner/progress treatment only during AI generation.

Do not leave the learner on a blank page.

---

## Error States

Handle:

* missing learner context
* missing roadmap id
* missing roadmap lesson id
* failed lesson generation
* failed lesson load
* unsupported language
* malformed lesson response

Each error state should provide a clear action:

* Retry generation
* Return to roadmap
* Log in again

Do not expose raw backend stack traces.

---

## UI Components

Create lesson-specific components.

Suggested structure:

```text
features/
└── lesson/
    ├── components/
    │   ├── lesson-header.tsx
    │   ├── lesson-layout.tsx
    │   ├── lesson-section-nav.tsx
    │   ├── lesson-section.tsx
    │   ├── lesson-code-example.tsx
    │   ├── lesson-mini-exercise.tsx
    │   ├── lesson-takeaways.tsx
    │   ├── lesson-navigation-actions.tsx
    │   ├── lesson-loading-state.tsx
    │   └── lesson-error-state.tsx
    ├── hooks/
    │   └── use-generated-lesson.ts
    └── types/
        └── lesson-view.ts
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
* Dialog only if needed
* Textarea only if mini exercise reflection is added

Use Lucide icons sparingly.

Suggested icons:

* `BookOpen`
* `Clock`
* `Code2`
* `CheckCircle2`
* `ChevronLeft`
* `ChevronRight`
* `Copy`
* `Sparkles`

Do not use hardcoded hex colors.

Do not use raw Tailwind colors like `zinc-*`, `slate-*`, or `neutral-*`.

Use tokens from `globals.css`.

---

## Accessibility

Ensure:

* lesson page has one clear `h1`
* sections use semantic headings
* code copy buttons have accessible labels
* navigation controls are keyboard usable
* focus states are visible
* status messages are readable by assistive technologies

Do not rely on color alone to indicate status.

---

## Responsive Behavior

Desktop:

* section navigation can sit beside the lesson
* content stays readable
* metadata/takeaways may sit in a side panel

Mobile:

* sidebars collapse above or below content
* section navigation becomes a compact list
* code blocks scroll horizontally if needed
* action buttons remain reachable

---

## Integration With Roadmap UI

Update roadmap lesson items if needed so each lesson can navigate to the lesson page.

For now, lesson cards may expose a CTA:

```text
Open lesson
```

This CTA should navigate to the lesson viewer.

If the lesson has `generation_status = pending`, the lesson viewer should generate it.

If the lesson has `generation_status = generated`, the lesson viewer should load it.

Do not call `generate_lesson` directly from the roadmap page unless already generated data is required.

---

## Future Compatibility

This feature will later connect to:

* generate_challenge
* challenge workspace
* evaluate_submission
* update_mastery
* unlock_next_lesson
* get_dashboard
* recommend_next_action

Design the lesson viewer so a future CTA can be added:

```text
Start coding challenge
```

Do not add challenge behavior yet.

---

## Explicitly Out of Scope

Do not implement:

* coding challenge generation
* Monaco editor workspace
* code execution
* submission evaluation
* mastery updates
* unlock logic
* dashboard analytics
* skill map updates
* AI tutor chat
* certificates

This feature only displays generated lessons and tracks reading completion.

---

## Check When Done

* Lesson page route works
* Lesson loads by roadmap lesson id
* Pending lesson triggers `generate_lesson`
* Existing generated lesson is reused
* Lesson title and summary render correctly
* Lesson sections render in order
* Section navigation works
* Code examples render correctly
* Copy-to-clipboard works for code examples
* Mini exercises display correctly
* Key takeaways display correctly
* Back to roadmap navigation works
* Previous/Next lesson navigation works
* Loading state appears during generation
* Error state works
* Responsive layout works
* Dark theme remains consistent
* Roadmap lesson cards can open the lesson viewer
* No coding challenge is generated
* No mastery update occurs
* No unlock logic exists
