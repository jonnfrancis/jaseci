Read `AGENTS.md`, `context/ui-context.md`, and `context/architecture-context.md` before starting.

# 22-dashboard-ui.md

We're implementing the learner dashboard UI.

This feature displays the dashboard data returned by the `get_dashboard` walker.

The dashboard should become the learner's main home screen after login and after completing the assessment-to-roadmap flow.

Do not update mastery.

Do not unlock lessons.

Do not generate recommendations.

Do not generate lessons.

Do not generate challenges.

Do not evaluate submissions.

---

## Goal

Create a read-only dashboard experience that helps the learner understand:

* current roadmap
* learning progress
* current lesson
* mastery summary
* strongest and weakest skills
* lesson status
* challenge status
* recent activity
* next available navigation option

The dashboard should make the LMS feel connected and alive without mutating backend state.

---

## Route / Page

Create a dashboard page.

Suggested route:

```text id="b3cbfd"
/dashboard
```

or use the existing route convention in the React + Vite app.

The page should use:

* authenticated learner id
* selected language if available
* active roadmap id if available

Do not rely only on navigation state.

A page refresh should still load dashboard data correctly.

---

## Data Source

Load dashboard data through:

```text id="x93lf4"
get_dashboard
```

Inputs:

* learner_id
* language optional
* roadmap_id optional

Do not compute dashboard aggregates in the frontend.

Do not hardcode progress values.

Do not create fake dashboard state except temporary local development placeholders.

The backend DTO is the source of truth.

---

## Required Data Shape

The UI should consume the output from Feature 21.

Expected shape:

```ts id="kbs8he"
type DashboardView = {
  learner: DashboardLearnerSummary;
  active_roadmap?: DashboardRoadmapSummary;
  roadmap_progress?: DashboardRoadmapProgress;
  mastery_summary?: DashboardMasterySummary;
  lesson_summary?: DashboardLessonSummary;
  challenge_summary?: DashboardChallengeSummary;
  current_lesson?: DashboardCurrentLesson | null;
  recent_activity: DashboardRecentActivity[];
  dashboard_state:
    | "no_assessment"
    | "assessment_started"
    | "assessment_completed"
    | "roadmap_missing"
    | "roadmap_ready"
    | "in_progress"
    | "completed"
    | "ready";
};
```

Use existing frontend DTOs if already created.

Do not create duplicate incompatible types.

---

## Page Layout

Use the existing dark technical LMS workspace theme.

Recommended layout:

```text id="urcz2i"
Top: dashboard header and learner greeting
Main grid:
- Current roadmap/progress card
- Current lesson card
- Mastery summary card
- Challenge summary card
Lower section:
- Roadmap snapshot
- Strongest/weakest skills
- Recent activity
```

Keep the dashboard scannable.

Avoid overwhelming the learner with every detail from the graph.

---

## Dashboard Header

Display:

* learner greeting
* active roadmap title
* selected language badge
* dashboard state if useful

Example:

```text id="pn0in3"
Welcome back, John.
Continue your Python Foundations roadmap.
```

If no roadmap exists, display state-specific messaging.

Do not show raw learner ids.

---

## Dashboard State Handling

The dashboard must render useful screens for each state.

### `no_assessment`

Display:

```text id="t6xl0r"
Start your assessment to build a personalized roadmap.
```

CTA:

```text id="1mtmn8"
Start assessment
```

Navigate to the existing landing/assessment start flow.

Do not call `initialize_assessment` directly unless the existing app flow already does that from this CTA.

---

### `assessment_started`

Display:

```text id="fzqz4h"
Your assessment is in progress.
```

CTA:

```text id="o3bser"
Continue assessment
```

Navigate to the assessment page if the assessment id exists.

---

### `roadmap_missing`

Display:

```text id="yeskyq"
Your assessment is complete. Generate your roadmap to continue.
```

CTA:

```text id="zn7dq6"
Go to results
```

or

```text id="k0zr7h"
Generate roadmap
```

Only call roadmap generation here if that workflow already exists and has the required ids.

Prefer navigating to the existing results/roadmap generation flow.

---

### `roadmap_ready`

Display:

```text id="bw37nt"
Your roadmap is ready.
```

CTA:

```text id="w73vfa"
View roadmap
```

Do not automatically unlock lessons from this page.

---

### `in_progress` or `ready`

Display the full dashboard.

Primary CTA should point to the current lesson if available.

```text id="jgs87m"
Continue learning
```

---

### `completed`

Display:

```text id="g6kx06"
Roadmap completed.
```

Show completed roadmap summary.

Do not generate certificates in this feature.

---

## Current Roadmap Card

Display:

* roadmap title
* language
* roadmap status
* total lessons
* percent complete
* completed lesson count

Include CTA:

```text id="zz41dc"
View roadmap
```

This should navigate to the existing roadmap page.

Do not regenerate roadmap.

---

## Progress Display

Display roadmap progress clearly.

Use:

* progress bar
* percent complete
* completed / total lessons

Example:

```text id="w0cjwy"
4 of 12 lessons completed
33%
```

Use persisted values from `roadmap_progress`.

Do not recalculate progress unless DTO is missing and the app already has a safe fallback.

---

## Current Lesson Card

If `current_lesson` exists, display:

* lesson title
* summary if available
* week number if available
* status
* generation status
* challenge status if available

CTA behavior:

If current lesson has a generated lesson id:

```text id="d79klu"
Continue lesson
```

Navigate to lesson viewer.

If current lesson generation status is pending:

```text id="i0pc72"
Open lesson
```

Navigate to lesson viewer, where Feature 13 handles generation.

Do not call `generate_lesson` from the dashboard.

---

## Mastery Summary Card

Display:

* average mastery
* mastered count
* proficient count
* developing count
* beginner count

Include link:

```text id="y8ubn4"
View skill map
```

Navigate to the skill map page from Feature 19.

Do not call `update_mastery`.

Do not recalculate mastery in the frontend.

---

## Strongest And Weakest Skills

Display two compact lists:

* strongest skills
* weakest skills

Each skill row should show:

* skill name
* score
* level

Examples:

```text id="fzyw0t"
Variables · 88% · Proficient
Functions · 42% · Developing
```

Do not show raw internal ids unless no name exists.

---

## Lesson Summary Card

Display:

* generated lessons
* pending lessons
* completed lessons
* available lessons if included

This should help the learner understand what content is ready and what remains.

Do not generate missing lessons from this card.

---

## Challenge Summary Card

Display:

* generated challenges
* submitted challenges
* evaluated submissions
* passed challenges
* failed challenges

Use a simple card or compact stats grid.

Do not evaluate missing submissions.

Do not generate missing challenges.

---

## Roadmap Snapshot

Display a short read-only snapshot of roadmap progress.

Options:

* compact list of current/next lessons
* week cards with status indicators
* timeline of lesson states

Use whichever data is available from `DashboardView`.

If more detail is needed, link to the roadmap page instead of duplicating full roadmap UI.

---

## Recent Activity

Display recent activity returned by the dashboard DTO.

Each item should show:

* title
* type
* timestamp
* optional description

Examples:

```text id="ecywp2"
Challenge submitted · Variables practice
Submission evaluated · Score 82%
Lesson unlocked · Functions and Parameters
```

Limit to the number returned by the backend.

Do not create new activity events in the frontend.

---

## Navigation Actions

The dashboard may include links to existing pages:

* roadmap
* current lesson
* skill map
* assessment flow
* results page

Do not link to routes that do not exist yet.

Do not create new feature flows inside the dashboard.

---

## Loading State

Use skeleton loaders for:

* dashboard header
* progress cards
* current lesson card
* mastery card
* activity list

Example message:

```text id="y4pkfc"
Loading your dashboard...
```

Avoid blank screens.

---

## Error State

Handle:

* missing auth context
* missing learner id
* failed dashboard load
* unsupported language
* malformed dashboard response

Each error should provide a clear action:

* retry
* log in again
* return to landing page

Do not expose raw backend stack traces.

---

## Empty State

If dashboard data is valid but incomplete, show state-specific empty UI.

Examples:

No mastery:

```text id="yv8sfn"
Mastery data will appear after your first evaluated challenge.
```

No recent activity:

```text id="lx1ydo"
Your activity history will appear here as you learn.
```

No current lesson:

```text id="jogyr5"
No current lesson is available yet.
```

Do not treat normal incomplete journey states as crashes.

---

## UI Components

Create dashboard-specific components.

Suggested structure:

```text id="h3wcyi"
features/
└── dashboard/
    ├── components/
    │   ├── dashboard-page.cl.jac
    │   ├── dashboard-header.cl.jac
    │   ├── dashboard-state-panel.cl.jac
    │   ├── roadmap-progress-card.cl.jac
    │   ├── current-lesson-card.cl.jac
    │   ├── mastery-summary-card.cl.jac
    │   ├── skill-summary-list.cl.jac
    │   ├── lesson-summary-card.cl.jac
    │   ├── challenge-summary-card.cl.jac
    │   ├── roadmap-snapshot.cl.jac
    │   ├── recent-activity-list.cl.jac
    │   ├── dashboard-loading-state.cl.jac
    │   └── dashboard-error-state.cl.jac
    ├── hooks/
    │   └── use-dashboard
    └── types/
        └── dashboard-view
```

Adapt paths to the existing project convention if needed.

Keep components presentation-focused.

---

## Design Requirements

Use existing UI primitives.

Recommended:

* Button
* Card
* Badge if available
* Progress if available
* Tabs only if needed
* ScrollArea for longer sections

Use Lucide icons sparingly.

Suggested icons:

* `LayoutDashboard`
* `Map`
* `BookOpen`
* `Brain`
* `Code2`
* `Activity`
* `Clock`
* `CheckCircle2`
* `AlertCircle`
* `ArrowRight`

Follow the dark-only technical workspace theme.

Do not use hardcoded hex colors.

Do not use raw Tailwind colors like `zinc-*`, `slate-*`, or `neutral-*`.

Use tokens from `globals.css`.

---

## Accessibility

Ensure:

* page has one clear `h1`
* progress values have text equivalents
* cards have meaningful headings
* CTAs have clear labels
* keyboard navigation works
* focus states are visible
* status is not communicated by color alone

Recent activity should be readable as a semantic list.

---

## Responsive Behavior

Desktop:

* multi-column card grid
* progress and current lesson visible above the fold
* recent activity and roadmap snapshot below

Tablet:

* two-column grid where possible

Mobile:

* single-column stack
* primary CTA near the top
* cards remain readable
* avoid horizontal scrolling

---

## Integration With Auth

Dashboard requires an authenticated learner.

If user is not authenticated:

* redirect to login
* or show login prompt using the existing auth flow

Do not call `get_dashboard` without learner context.

---

## Integration With Previous Features

This feature should work after:

1. user registers/logs in
2. assessment is completed
3. roadmap is generated
4. lesson/challenge workflow exists
5. mastery and progression states exist
6. `get_dashboard` returns a dashboard DTO

But it must also handle early states:

* no assessment
* no roadmap
* no progression
* no mastery
* no activity

---

## Future Compatibility

This dashboard will later connect to:

* recommend_next_action
* AI tutor summary
* notification cards
* completion page
* certificate flow

Design the dashboard so a future recommendation card can be added without rewriting the layout.

Do not implement recommendations now.

---

## Explicitly Out of Scope

Do not implement:

* get_dashboard walker
* recommendations
* AI tutor
* lesson generation
* challenge generation
* submission evaluation
* mastery updates
* lesson unlocking
* roadmap generation
* certificates
* notifications

This feature only renders dashboard data.

---

## Check When Done

* Dashboard route works
* Dashboard requires authenticated learner context
* `get_dashboard` is called correctly
* Dashboard loading state works
* Dashboard error state works
* Dashboard handles no assessment state
* Dashboard handles assessment started state
* Dashboard handles roadmap missing state
* Dashboard handles roadmap ready state
* Dashboard handles in-progress state
* Dashboard handles completed state
* Roadmap progress displays correctly
* Current lesson card displays correctly
* Continue learning navigation works
* Mastery summary displays correctly
* Strongest skills display correctly
* Weakest skills display correctly
* Lesson summary displays correctly
* Challenge summary displays correctly
* Recent activity displays correctly
* Empty dashboard sections render safely
* Dashboard is responsive
* Dark theme remains consistent
* No backend mutation occurs
* No recommendations are generated
