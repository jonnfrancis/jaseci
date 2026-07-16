# Feature 30 programming-track migration inventory

This inventory was produced before the Feature 30 implementation. The migration
is additive: legacy language fields and request parameters remain available
during the rollback window.

## Supported persisted values

The complete learner flow currently supports only Python and Jaseci/Jac.
Canonical registry values are `python` and `jaseci`; exact accepted aliases are
`python`, `python3`, `py`, `jaseci`, `jac`, and `jaclang`. Blank values are
classified as `BLANK`. Every other value is `UNKNOWN` unless an authoritative
track reference makes it a `CONFLICT`.

Runtime distinct-value counts are produced by the dry-run migration report.
Persisted values are scoped to authenticated roots, so a production-wide count
must be run through the administrative migration procedure against every root;
it must not infer global counts from one caller's graph.

## Backend inventory

| Location | Field or parameter | Purpose | Migration action | Risk | Existing coverage |
|---|---|---|---|---|---|
| `services/assessment_journey.sv.jac` | `selected_language`, language track list | Journey selection and recovery | Generate options from canonical registry; return track/version IDs while retaining labels | High | Assessment journey tests |
| `walkers/initialize_assessment.jac` | `selected_language` | Select deterministic assessment templates | Add optional track/version input and dual-write assessment | High | Assessment generation tests |
| `nodes/assessment.jac` | no direct legacy language | Historical assessment graph | Add optional track/version fields; inherit only from an unambiguous roadmap | High | Assessment and migration tests |
| `walkers/generate_roadmap.jac`, `nodes/roadmap.jac` | `language` | Curriculum identity, prompt context, idempotency | Resolve track first, retain language, dual-write track/version to roadmap hierarchy | Critical | Roadmap tests |
| `walkers/generate_lesson.jac`, `nodes/lesson.jac` | `language` | Prompt and generated lesson identity | Inherit track/version from roadmap; retain language | High | Lesson tests |
| `walkers/generate_challenge.jac`, `nodes/challenge.jac` | `language` | Prompt, starter code, grading identity | Inherit track/version through roadmap/challenge chain | High | Challenge and submission tests |
| `walkers/update_mastery.jac`, `nodes/mastery.jac` | evaluation-derived context | Mastery evidence identity | Inherit track/version from source evaluation; never infer ambiguous historical mastery | Critical | Mastery tests |
| `walkers/unlock_next_lesson.jac`, `nodes/progression.jac` | roadmap relationship | Progression context | Inherit track/version from authoritative roadmap | High | Progression tests |
| Dashboard, skill-map, tutor walkers/services | `language` filters and display | Compatibility reads and labels | Retain language parameters; roadmap track references are now available for later final walker-contract migration | Medium | Dashboard, skill-map, tutor tests |
| `lib/ai/utilities.jac` | language prompt fields | Programming syntax and display context | Preserve prompt behavior; compatibility adapter supplies canonical legacy language | High | MockLLM suites |

## Frontend inventory

| Location | Current state | Migration action | Risk | Coverage |
|---|---|---|---|---|
| `lib/journey/journey_state.cl.jac` | `graphlearn.journey.language` | Add `selectedTrackId` and `selectedTrackVersionId`; read track first and migrate exact old values while retaining the old key | High | Compiler and journey regression |
| `AssessmentJourneyPage.cl.jac` | language-labelled track cards | Persist track/version returned by the server; retain existing labels and request compatibility | Medium | Journey tests/manual UI |
| Dashboard, roadmap, lesson, challenge and skill-map pages | language display | Keep display metadata; final track-only UI contracts are deferred | Low | Existing client checks |
| `lib/types/index.ts` | language unions | Add `LearningTrackOption`; retain language fields | Medium | TypeScript check |
| Challenge draft storage | challenge-ID cache key | No migration required: key is challenge-identity based, not language based | Low | Challenge UI tests |

## Persistence and relationship rules

- `Roadmap.language` is the strongest direct legacy source currently persisted.
- Assessments and assessment attempts inherit only through matching historical
  roadmap assessment IDs.
- Generated lessons, challenges, submissions, evaluations and progression
  records inherit through their persisted roadmap/challenge relationships.
- Learner selection is updated only when all resolved historical roadmaps agree.
- Ambiguous mastery without a source evaluation remains unresolved.
- Unknown values are reported and never fuzzy-matched or used to create tracks.
- A valid track reference conflicting with language is preserved as `CONFLICT`.

## Cache-key inventory

No server-side language-keyed cache exists in the current repository. Generated
content is persisted as graph nodes. The only relevant browser cache is the
challenge draft key, which is already keyed by stable challenge ID. Future
curriculum-sensitive caches must use
`graphlearn:v2:<resource>:<track-version>:...`.

## Dual-write locations

During the compatibility period, new Assessment, AssessmentAttempt,
AssessmentEvaluation, Roadmap hierarchy, GeneratedLesson, GeneratedChallenge,
ChallengeSubmission, SubmissionEvaluation, Mastery, and Progression records
retain their legacy language/display behavior while also carrying optional
`track_id` and `track_version_id`. Removal is deferred until the rollback window
closes.

## Operational safeguards

- The HTTP migration and rollback operations are authenticated and disabled
  unless `PROGRAMMING_TRACK_MIGRATION_ENABLED=true`.
- Run dry-run first and review unresolved values/conflicts.
- Back up the configured Jac persistence backend before apply.
- Apply uses bounded roadmap-journey batches (`MIGRATION_BATCH_SIZE`, default
  operational value 100).
- Rollback restores recorded optional references and never deletes learner data
  or seeded tracks. Once lecturer data exists, prefer forward correction.
