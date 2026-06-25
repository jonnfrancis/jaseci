# Progress Tracker

Update this file whenever the current phase, active feature, or implementation state changes.
## Current Phase
- Domain models

## Current Goal

- Implement `02-domain-models.md` next, after the completed design-system foundation.

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

## In Progress

- Not started.

## Next Up

- Read `context/feature-specs/02-domain-models.md` and implement the domain model foundation.

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
