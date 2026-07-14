Read `AGENTS.md`, `context/ui-context.md`, and `context/architecture-context.md` before starting.

# 19-skill-map-ui.md

We're implementing the skill map visualization UI.

This feature displays the learner's skill graph using data returned from the `get_skill_map` walker.

The skill map should help learners understand their current strengths, weak areas, dependencies, and mastery state.

Do not update mastery.

Do not unlock lessons.

Do not generate recommendations.

Do not mutate graph data.

Do not create dashboard analytics.

---

## Goal

Create a read-only skill map interface that displays:

* learner skills
* prerequisite relationships
* mastery scores
* mastery levels
* skill status
* weak areas
* strong areas
* roadmap-filtered skill coverage

The UI should make the learner's progress understandable at a glance.

---

## Route / Page

Create a skill map page.

Suggested route:

```text
/skill-map
```

or, if scoped to a roadmap:

```text
/roadmap/:roadmapId/skill-map
```

Use the route convention already established in the Jac Client / React + Vite app.

The page should use:

* authenticated learner id
* selected language
* roadmap id if available

Do not rely only on navigation state.

A page refresh should still load the skill map.

---

## Data Source

Load skill map data through:

```text
get_skill_map
```

Inputs:

* learner_id
* language
* roadmap_id optional

Do not compute mastery in the frontend.

Do not hardcode skill scores.

Do not create fake graph data except for temporary local development placeholders.

The backend remains the source of truth.

---

## Required Data Shape

The UI should consume the output from Feature 18.

Expected shape:

```ts
type SkillMapView = {
  learner_id: string;
  language: "python" | "jac";
  roadmap_id?: string;
  summary: SkillMapSummary;
  skills: SkillMapSkill[];
  edges: SkillMapEdge[];
  generated_at: string;
};
```

Skill summary:

```ts
type SkillMapSummary = {
  total_skills: number;
  mastered_count: number;
  proficient_count: number;
  developing_count: number;
  beginner_count: number;
  average_mastery: number;
};
```

Skill node:

```ts
type SkillMapSkill = {
  skill_id: string;
  name: string;
  description: string;
  category: string;
  mastery_score: number;
  mastery_level: "beginner" | "developing" | "proficient" | "mastered";
  status: "locked" | "available" | "in_progress" | "mastered";
  evidence_count: number;
  target_lesson_ids?: string[];
};
```

Skill edge:

```ts
type SkillMapEdge = {
  from_skill_id: string;
  to_skill_id: string;
  type: "prerequisite" | "teaches" | "reinforces";
};
```

Use existing frontend DTOs if already created.

Do not create duplicate incompatible types.

---

## Page Layout

Use the existing dark technical LMS theme.

Recommended layout:

```text
Top: skill map header
Below: summary cards
Main: graph visualization
Side panel or lower section: selected skill details
```

The graph should be readable and informative, not overly complex.

Prioritize clarity over fancy animations.

---

## Skill Map Header

Display:

* title
* selected language
* roadmap name if available
* generated timestamp if useful

Example:

```text
Python Skill Map
Your current mastery graph based on assessment and coding challenge evidence.
```

Include navigation back to:

* roadmap page
* dashboard if available later

Do not create dashboard links if dashboard route does not exist yet.

---

## Summary Cards

Display summary metrics from `SkillMapSummary`.

Cards:

* total skills
* average mastery
* mastered skills
* developing/beginner skills

Use existing design system card components.

Do not create custom UI primitives.

---

## Graph Visualization

Create a read-only skill graph.

Display:

* skills as nodes
* dependencies as edges
* mastery state visually
* selected skill details on click

The graph is informational only.

Do not allow:

* dragging to mutate graph state
* creating nodes
* deleting nodes
* editing edges
* changing mastery from UI

If using React Flow or a graph library, configure it as read-only.

If no graph library exists, use a simple custom layout first.

Acceptable MVP options:

1. Layered dependency cards
2. Timeline-style graph
3. Read-only React Flow graph
4. Category-grouped skill map

Choose the simplest option that renders reliably.

---

## Skill Node Display

Each skill node/card should show:

* skill name
* mastery score
* mastery level
* status
* category

Visual states:

* beginner
* developing
* proficient
* mastered

Status must not rely on color alone.

Include text labels or icons.

Examples:

```text
Variables
82% · Proficient
```

---

## Edge / Dependency Display

Display prerequisite relationships clearly.

For graph view:

```text
Skill A → Skill B
```

For list/card view:

```text
Prerequisites:
- Variables
- Control Flow
```

Edges should be visually secondary to skills.

Do not make the graph feel like an editor.

---

## Selected Skill Details

When a learner selects a skill, show a details panel.

Display:

* skill name
* description
* category
* mastery score
* mastery level
* evidence count
* related lessons if available
* connected prerequisite skills

Do not show raw internal ids unless needed for debugging.

Do not show graph implementation details.

---

## Mastery State Rules

Use mastery values from the backend.

Frontend should only display:

* score
* level
* status

Do not recalculate mastery.

Do not infer mastery from completed lessons.

Do not update mastery from UI actions.

---

## Filters

Add simple filters if straightforward.

Possible filters:

* all skills
* beginner
* developing
* proficient
* mastered

Optional category filter:

* Python Basics
* Functions
* Data Structures
* Jac OSP
* Walkers
* byLLM

Do not add complex search/filter logic if it delays the main visualization.

---

## Empty State

Handle empty skill maps.

Show:

```text
No skill map yet.
Complete an assessment and coding challenge to start building your mastery graph.
```

Include CTA back to:

* landing page
* roadmap page
* assessment page

Use whichever route exists.

Do not call assessment or roadmap walkers from this page.

---

## Loading State

Use skeleton loaders for:

* header
* summary cards
* graph area
* details panel

Avoid blank screens.

Example message:

```text
Loading your skill map...
```

---

## Error State

Handle:

* missing auth context
* missing learner id
* unsupported language
* roadmap not found
* failed skill map load
* malformed skill map response

Each error should provide a clear action:

* retry
* return to roadmap
* log in again

Do not expose raw backend stack traces.

---

## UI Components

Create skill-map-specific components.

Suggested structure:

```text
features/
└── skill-map/
    ├── components/
    │   ├── skill-map-page.tsx
    │   ├── skill-map-header.tsx
    │   ├── skill-map-summary-cards.tsx
    │   ├── skill-graph-view.tsx
    │   ├── skill-node-card.tsx
    │   ├── skill-edge-label.tsx
    │   ├── selected-skill-panel.tsx
    │   ├── skill-map-filters.tsx
    │   ├── skill-map-loading-state.tsx
    │   └── skill-map-error-state.tsx
    ├── hooks/
    │   └── use-skill-map.ts
    └── types/
        └── skill-map-view.ts
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
* Tabs if filtering by category
* ScrollArea

Use Lucide icons sparingly.

Suggested icons:

* `Network`
* `Brain`
* `Target`
* `CheckCircle2`
* `Circle`
* `Lock`
* `TrendingUp`
* `AlertCircle`

Follow the dark-only technical workspace theme.

Do not use hardcoded hex colors.

Do not use raw Tailwind colors like `zinc-*`, `slate-*`, or `neutral-*`.

Use tokens from `globals.css`.

---

## Accessibility

Ensure:

* page has one clear `h1`
* graph data has an accessible list fallback
* nodes/cards are keyboard selectable
* selected skill details are announced clearly
* filters are keyboard usable
* color is not the only mastery indicator
* focus states are visible

If using a canvas/graph library, provide a semantic fallback list of skills below or beside the graph.

---

## Responsive Behavior

Desktop:

* summary cards in a grid
* graph as main area
* selected skill panel on the side

Tablet:

* graph above details panel
* cards remain readable

Mobile:

* graph can become a vertical skill list
* selected skill details appear below selected node/card
* avoid horizontal scrolling where possible

The mobile experience does not need to mimic the desktop graph exactly.

It only needs to communicate the same information clearly.

---

## Integration With Previous Features

This feature should work after:

1. assessment is evaluated
2. challenge submission is evaluated
3. `update_mastery` has run
4. `get_skill_map` returns learner skill data

Add navigation entry points where appropriate:

* roadmap page may link to skill map
* results/feedback page may link to skill map
* future dashboard will link to skill map

Do not create the dashboard in this feature.

---

## Future Compatibility

This UI will later connect to:

* get_dashboard
* unlock_next_lesson
* recommend_next_action
* progress visualization
* AI tutor guidance

Design selected skill details so future CTAs can be added:

```text
Review related lesson
Practice this skill
Ask AI tutor
```

Do not implement these actions yet.

---

## Explicitly Out of Scope

Do not implement:

* mastery updates
* lesson unlocking
* dashboard analytics
* AI recommendations
* challenge regeneration
* lesson generation
* assessment generation
* graph editing
* certificates

This feature only visualizes the skill map.

---

## Check When Done

* Skill map page route works
* `get_skill_map` is called with learner context
* Skill map loads by language and optional roadmap id
* Summary cards render correctly
* Skills render correctly
* Mastery scores display correctly
* Mastery levels display correctly
* Skill statuses display correctly
* Prerequisite/dependency relationships display clearly
* Selecting a skill shows details
* Filters work if implemented
* Empty state works
* Loading state works
* Error state works
* Mobile layout remains readable
* UI uses existing design system primitives
* Dark theme remains consistent
* No mastery update occurs
* No lesson unlock logic exists
* No graph mutation is possible
