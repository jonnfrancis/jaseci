# UI Context

## Theme

Dark only. No light mode. The visual language is a dark technical workspace — near-black backgrounds, layered surfaces, and vivid accent colors for interactive elements.

All colors are defined as CSS custom properties in `globals.css` and mapped to Tailwind tokens via `@theme inline`. Components must use these tokens — no hardcoded hex values or raw Tailwind color classes like `zinc-*`.

| Role             | CSS Variable           | Hex / Value               |
| ---------------- | ---------------------- | ------------------------- |
| Page background  | `--bg-base`            | `#080809`                 |
| Surface          | `--bg-surface`         | `#111114`                 |
| Elevated surface | `--bg-elevated`        | `#18181c`                 |
| Subtle surface   | `--bg-subtle`          | `#1e1e23`                 |
| Default border   | `--border-default`     | `#2a2a30`                 |
| Subtle border    | `--border-subtle`      | `#3a3a42`                 |
| Primary text     | `--text-primary`       | `#f0f0f4`                 |
| Secondary text   | `--text-secondary`     | `#c0c0cc`                 |
| Muted text       | `--text-muted`         | `#808090`                 |
| Faint text       | `--text-faint`         | `#505060`                 |
| Brand accent     | `--accent-primary`     | `#00c8d4` (cyan)          |
| Brand dim        | `--accent-primary-dim` | `rgba(0, 200, 212, 0.12)` |
| AI accent        | `--accent-ai`          | `#6457f9` (indigo-purple) |
| AI text          | `--accent-ai-text`     | `#8b82ff`                 |
| Error            | `--state-error`        | `#ff4d4f`                 |
| Success          | `--state-success`      | `#34d399`                 |
| Warning          | `--state-warning`      | `#fbbf24`                 |

Tailwind utility names map to these variables. Use `bg-base`, `bg-surface`, `text-copy-primary`, `text-copy-muted`, `border-surface-border`, `text-brand`, `bg-accent-dim`, etc.

## Typography

| Role      | Font       | CSS Variable        |
| --------- | ---------- | ------------------- |
| UI text   | Geist Sans | `--font-geist-sans` |
| Code/mono | Geist Mono | `--font-geist-mono` |

Both fonts are loaded via `next/font/google` and applied as CSS variables on the `<html>` element. The base `body` uses Geist Sans with `antialiased`.

## Design Principles

The interface should feel like an AI-powered developer workspace.

Prioritize:

- Information density over decorative spacing
- Fast scanning over visual novelty
- Progressive disclosure over large pages
- Consistency over custom component variations

Every screen should answer:

1. What am I working on?
2. What is my current progress?
3. What should I do next?

Avoid marketing-style layouts, oversized hero sections, and large empty spaces.

## Border Radius

Radius increases with surface depth — smaller for inner elements, larger for outer containers.

| Context           | Class         |
| ----------------- | ------------- |
| Inline / small UI | `rounded-xl`  |
| Cards / panels    | `rounded-2xl` |
| Modal / overlay   | `rounded-3xl` |

## Spacing

Use consistent spacing throughout the application.

| Context | Spacing |
|----------|----------|
| Element gap | `gap-2` |
| Form controls | `gap-3` |
| Section content | `gap-4` |
| Panel content | `gap-6` |
| Major page sections | `gap-8` |

Avoid arbitrary spacing values.

## Surface Hierarchy

Use surface depth consistently.

Level 0:
- Page background
- `bg-base`

Level 1:
- Standard panels
- `bg-surface`

Level 2:
- Interactive cards
- `bg-elevated`

Level 3:
- Dialogs
- overlays
- AI panels
- `bg-subtle`

Do not skip levels.

## Status Colors

Status indicators must use semantic colors.

Success:
- `--state-success`

Warning:
- `--state-warning`

Error:
- `--state-error`

In Progress:
- `--accent-primary`

AI Generated:
- `--accent-ai`

Status should always be accompanied by text or an icon.
Do not rely on color alone.

## Component Library

shadcn/ui on top of Tailwind. No custom design system. Components live in `components/ui/`. Use the `shadcn` CLI to add new components rather than writing them from scratch.

## Layout Patterns

- Editor workspace: full-viewport layout — floating sidebar overlay on the left, center canvas, slide-over AI sidebar on the right.
- Sidebars: floating overlay with dark semi-transparent background and subtle border.
- Modals and dialogs: centered overlay, `rounded-3xl`, dark background with backdrop blur.
- Navbar: top bar with dark background and bottom border.

## Icons

Lucide React. Stroke-based icons only — no filled variants. Icon sizes: `h-4 w-4` for inline, `h-5 w-5` for buttons, `h-8 w-8` for feature icons in empty states.

## Dashboard Patterns

Dashboard cards should follow a consistent structure:

- Title
- Primary metric
- Supporting detail
- Optional trend or status

Avoid charts unless they communicate information unavailable through simpler UI.

## Assessment UI

Assessment screens should focus attention on the current question.

Guidelines:

- One primary question per view
- Clear progress indicator
- Persistent submit action
- Minimal surrounding distractions

Question text should be visually dominant.

## Lesson UI

Lessons are reading-first experiences.

Support:

- Section navigation
- Code examples
- Callouts
- Embedded exercises

Content width should remain readable.
Avoid full-width text blocks.
## Coding Challenges

Challenge layouts should resemble lightweight IDEs.

Structure:

- Instructions panel
- Code editor
- Submission controls
- Feedback panel

Editor space should receive visual priority.

Do not place critical challenge information inside collapsible UI.

## AI Tutor

AI-generated content should be visually distinct.

Use:

- AI accent colors
- AI iconography
- subtle AI surface treatment

AI recommendations should include:

- recommendation
- explanation
- suggested next action

Never present AI output without context.

## Progress Visualization

Progress indicators should be simple and immediately understandable.

Preferred:

- progress bars
- completion rings
- mastery percentages

Avoid complex charts unless they provide additional insight.

Mastery values should always display both:

- visual representation
- numeric value

## Loading States

Use skeleton loaders instead of spinners whenever content structure is known.

Use spinners only for:

- AI generation
- long-running evaluation
- background processing

Loading states should preserve final layout dimensions.

## Empty States

Empty states should contain:

- icon
- concise explanation
- primary action

Avoid generic messages such as "No data found."

## Skill Graph Visualization
Skills are displayed as graph nodes.
Node state:

- Locked
- Available
- In Progress
- Mastered

Edges represent prerequisites.

Graph visuals should emphasize learner progress over graph complexity.

The graph is informational and not a full graph editor.

### Node Color Palette

8 defined color pairs. Each pair specifies a dark node fill and a vivid contrasting text color tuned for readability on the dark canvas. Defined in `types/canvas.ts` as `NODE_COLORS`.

| Node fill | Text color | Character              |
| --------- | ---------- | ---------------------- |
| `#1F1F1F` | `#EDEDED`  | Neutral dark (default) |
| `#10233D` | `#52A8FF`  | Blue                   |
| `#2E1938` | `#BF7AF0`  | Purple                 |
| `#331B00` | `#FF990A`  | Orange                 |
| `#3C1618` | `#FF6166`  | Red                    |
| `#3A1726` | `#F75F8F`  | Pink                   |
| `#0F2E18` | `#62C073`  | Green                  |
| `#062822` | `#0AC7B4`  | Teal                   |

Default node color: `#1F1F1F` with `#EDEDED` text.


