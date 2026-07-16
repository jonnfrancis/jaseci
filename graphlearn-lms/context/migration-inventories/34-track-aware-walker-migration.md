# Feature 34 walker migration inventory

The compatibility-stage contract is additive: legacy language fields and report shapes remain while stable track identifiers are accepted. Existing-entity operations treat the parent entity as authoritative and reject conflicting supplied context.

| Walker | Current authority and graph access | Mutation / idempotency | Feature 34 action |
|---|---|---|---|
| `initialize_assessment` | learner root; explicit track or legacy language | creates assessment/question graph; existing journey layer prevents duplicate starts | Resolve the common track envelope and persist the normalized built-in track/version. |
| `submit_assessment` | assessment parent and learner id | creates one attempt and response graph | Add common context/idempotency fields; assessment remains authoritative. |
| `evaluate_assessment` | assessment and attempt parent | creates one evaluation; existing evaluation is reused | Resolve from assessment, reject learner/track conflicts, retain legacy report. |
| `generate_roadmap` | evaluated assessment chain | creates roadmap aggregate; active matching roadmap is reused | Resolve from assessment before generation and pin every created record to that version. |
| `generate_lesson` | roadmap and roadmap lesson | persists generated lesson; existing lesson is reused | Resolve from roadmap, reject conflicts, isolate response/content by version. |
| `generate_challenge` | roadmap and generated lesson | persists generated challenge; existing challenge is reused | Resolve from parents, reject conflicts, retain programming compatibility only when supported. |
| `submit_challenge` | challenge parent | persists submission; current draft/retry rules retained | Add common context/idempotency fields; challenge remains authoritative. |
| `evaluate_submission` | challenge and submission parents | persists one evaluation; completed evaluation is reused | Resolve from the activity/submission and reject cross-track or learner conflicts. |
| `update_mastery` | assessment/submission evaluation source | mastery evidence/update result guards duplicate evidence | Resolve from the evaluation source; client context cannot select another version. |
| `unlock_next_lesson` | roadmap and persisted evidence | updates bounded roadmap progression | Add common context envelope; roadmap remains the authoritative boundary. |
| `get_dashboard` | selected/explicit roadmap or active learner roadmap | read-only | Add track/version/enrollment selection fields; legacy language remains available. |
| `get_skill_map` | selected/explicit roadmap | read-only | Add track/version/enrollment selection fields; legacy language remains available. |
| `recommend_next_action` | selected/explicit roadmap and its evidence | read-only, optional AI projection | Add track/version/enrollment selection fields; recommendations stay roadmap-scoped. |

Supporting service functions (`load_assessment_journey`, `load_roadmap`, `open_lesson`, `open_challenge`, dashboard, skill-map, and tutor loaders) continue to wrap these existing names. Client recovery already stores `selectedTrackId` and `selectedTrackVersionId`; legacy language storage remains during compatibility.

Stable resolver errors include `TRACK_CONTEXT_MISSING`, `TRACK_NOT_FOUND`, `TRACK_VERSION_NOT_FOUND`, `TRACK_VERSION_MISMATCH`, `TRACK_CONTEXT_CONFLICT`, `LEARNER_CONTEXT_MISMATCH`, and `ENROLLMENT_NOT_FOUND`.
