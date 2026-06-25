# Progress Tracker

Update this file whenever the current phase, active feature, or implementation state changes.
## Current Phase
- Domain models

## Current Goal

- Implement `02-domain-models.md`: add isolated backend graph domain nodes, edge type definitions, and frontend mirror TypeScript interfaces without walkers, byLLM, Spawn calls, API wrappers, or persistence logic.

## Completed

- Read `AGENTS.md`, `context/ui-context.md`, and supporting architecture/workflow context.
- Confirmed Tailwind v4 is configured through `assets/globals.css` and the Jac Vite plugin.
- Added shadcn/ui configuration scaffolding, `components/ui/`, and shared `lib/utils.cl.jac`.
- Installed the required generated shadcn/ui primitives: Button, Card, Dialog, Input, Tabs, Textarea, and ScrollArea.
- Confirmed `lucide-react` is declared and installed for client use.
- Added strict root `tsconfig.json`.
- Added environment variable example file and ignored local `.env` files.
- Added basic dark app shell and global layout without business logic.
- Removed generated guestbook UI from the active app entry.
- Created `walkers/`, `nodes/`, `edges/`, `lib/`, `components/`, and `features/` structure.
- Verified Vite production build passes with the generated client config.
- Verified the built app starts through Vite preview at `http://127.0.0.1:4173/`, then stopped the preview server.
- Confirmed `01-design-system.md` is complete: `components.json` is present, required shadcn/ui primitives exist, `lucide-react` is installed, `lib/utils.cl.jac` exports `cn()`, and `assets/globals.css` maps shadcn tokens to the dark GraphLearn theme.
- Added the required design-system primitives to `AppShell` imports/usages so Button, Card, Dialog, Input, Tabs, Textarea, ScrollArea, Lucide icons, and `cn()` are validated through the active Jac client build.
- Updated the static app shell status from setup/design-system-next to design-system/domain-models-next.
- Read `context/feature-specs/02-domain-models.md` and implemented the isolated domain model foundation.
- Added backend domain nodes under `nodes/`: Learner, Assessment, Lesson, Challenge, Skill, Mastery, and Roadmap.
- Added domain enum/type definitions for assessment status, lesson/challenge difficulty, placeholder assessment questions, and bounded `MasteryScore` values from 0 through 100.
- Added `edges/domain_edges.jac` with the requested relationship edge types: Prerequisite, teaches, mastered, assigned, and completed.
- Added backend barrel exports in `lib/domain/index.jac` and verified a type-only barrel import from `main.jac`.
- Added frontend mirror TypeScript exports in `lib/types/index.ts`.
- Verified the domain layer contains no walkers, byLLM code, Spawn calls, API wrappers, persistence logic, or edge/node abilities.
- Moved graph archetype files out of `lib/domain/` into the existing `nodes/` and `edges/` folders, keeping `lib/domain/index.jac` as the stable backend barrel.

## In Progress

- Not started.

## Next Up

- Choose the next feature spec and keep it isolated from the completed foundation layers.

## Open Questions

- The system `jac` shim at `C:\Python\Python39\Scripts\jac.exe` still returns non-zero without diagnostics; use the project venv `.\.jac\venv\Scripts\jac.exe` with UTF-8 output enabled.
- `jac install` can time out during npm install; direct Bun install from `.jac/client/configs` completed after package extraction/linking.

## Architecture Decisions

- Keep this phase foundation-only: no learner, roadmap, assessment, graph, or AI business logic.
- Use Jac Client + Tailwind token classes for the app shell.
- Treat `components/ui/` as managed shadcn/ui space and avoid hand-writing primitives there.

## Session Notes

- Replaced the generated guestbook UI entry with a static GraphLearn LMS shell so the foundation matches product context without introducing domain behavior.
- Jac regenerated `.jac/client/compiled/components/AppShell.js`; Vite build and preview verification passed via the project-local Bun binary.
- `jac check main.jac` passed with the project venv Jac executable.
- Vite production build passed through `.jac/client/configs/node_modules/.bin/vite.exe`; Rollup emitted third-party `@hugeicons/core-free-icons` pure annotation warnings only.
- For `02-domain-models.md`, `jac check main.jac`, `jac check lib/domain/index.jac`, TypeScript `tsc --noEmit`, forbidden-pattern scan, and quiet Vite production build all passed.
- Jac edge endpoint syntax does not support union endpoints, so the relationship edge names are declared as untyped edge archetypes with endpoint intent documented in `edges/domain_edges.jac`.
