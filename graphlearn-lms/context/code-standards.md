# Code Standards

## General

- Keep modules small and single-purpose.
- Fix root causes — do not layer workarounds.
- Do not mix unrelated concerns in one component or route.
- Respect the system boundaries defined in `architecture-context.md`.

## TypeScript

- Strict mode is required throughout the project.
- Avoid `any`; use explicit interfaces or narrowly scoped types.
- Validate unknown external input at system boundaries before trusting it.
- Use `interface` for object contracts.

## Styling

- Use CSS custom property tokens defined in `assets/globals.css` — no raw Tailwind color classes like `zinc-*` or hardcoded hex values.
- Reference tokens through their Tailwind utility names: `bg-base`, `text-copy-primary`, `border-surface-border`, `text-brand`, etc.
- Maintain the border radius scale: `rounded-xl` for small elements, `rounded-2xl` for cards, `rounded-3xl` for modals.

## API Routes

- Validate and parse request input before any logic runs.
- Enforce auth and project ownership checks before any mutation.
- Return consistent, predictable response shapes.
- Keep route handlers thin — push complexity into shared modules or background tasks.

## Data and Storage

- LMS metadata, generated structured content, and relationships belong in the Jac graph store.
- Attach every persisted node to the authenticated root or a node reachable from it.
- Use typed graph traversal for owned collections and validate ownership after direct `jobj()` lookup.
- Do not persist raw LLM responses; persist validated structured outputs only.
- Treat the server-derived authenticated root as the ownership authority. Email and client-provided learner IDs are not ownership proof.
- Evolve persisted archetypes with safe defaults, schema aliases, and idempotent upgrades; never use database deletion as a production migration.

## File Organization

- `lib/` — shared infrastructure, auth helpers, domain services, and utilities.
- `components/` — UI composition only; no business logic.
- Name files after the responsibility they contain, not the technology.
