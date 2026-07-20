# Architecture Context

## System Vision

JAC LMS is an AI-native adaptive learning platform.

The system uses Object Spatial Programming (OSP) as the primary intelligence layer for representing learner knowledge, topic relationships, mastery scores, prerequisite structures, and learning progression.

The OSP graph is the source of truth for learner progression.

---

## Technology Stack

| Layer             | Technology                | Purpose                   |
| ----------------- | ------------------------- | ------------------------- |
| Frontend          | Jac Client + React + Vite | User interface            |
| Styling           | Tailwind CSS + shadcn/ui  | UI components             |
| Backend           | JacLang                   | Business logic            |
| Graph Engine      | Jaseci OSP                | Knowledge graph           |
| AI Layer          | byLLM                     | Generation and evaluation |
| Database          | Jac graph store (SQLite locally, MongoDB when scaled) | Durable OSP persistence |
| Data Access       | Jac nodes, edges, and typed traversal | Graph-native reads and writes |
| Authentication    | Clerk/ Inbuilt Jaseci Auth| Identity management       |
| Code Editor       | Monaco Editor             | Coding workspace          |
| Execution Sandbox | Future Integration        | Code execution            |
| Deployment        | Docker + Cloud Provider   | Production hosting        |

---

## High Level Architecture

```text
Frontend

Landing Page
Dashboard
Roadmap
Workspace
Skill Map

       ↓

Jac Client

       ↓ Spawn()

Jac Walkers

       ↓

Track application services

       ↓

Focused graph repositories + domain services

       ↓

OSP Learning Graph

       ↓

byLLM Agents

       ↓

Database
```

## Track Repository And Service Boundary

Track-aware features use `lib/learning_track/repositories.jac` for focused,
bounded graph access and `lib/learning_track/application_services.jac` for
authorization, lifecycle, idempotency, publication, enrollment, and progress
coordination. Curriculum repository calls require a validated track version;
learner-progress calls begin at one enrollment. Scalar track/version fields are
index and compatibility data only: named graph relationships prove ownership.

Mutating application operations persist an `ApplicationOperation` marker under
`root.shared`. A marker is scoped by operation and idempotency key, returns the
original logical result after success, and exposes `INCOMPLETE` state for repair
after partial failure. Published or superseded curriculum is immutable through
repository/domain mutation paths. Walkers remain transport adapters and are
migrated to this boundary in Feature 34.

## Authorization Policy Boundary

Lecturer and administrator operations use `lib/authorization/` after private
endpoint authentication. The authorization actor is rebuilt from the current
root-owned role/profile graph for each operation; final authorization decisions
are not cached. Resource contexts are constructed from repository-loaded graph
relationships, including ownership, version, enrollment, and submission scope.
Policies default to denial, map private ownership denials to safe not-found
errors, and audit allow/deny outcomes without protected content.

The initial publication model requires reviewer or administrator approval.
Owner publication additionally requires the server-controlled profile capability
and `ALLOW_LECTURER_SELF_PUBLISH`; owner self-approval is disabled by default.
Application administrators manage cross-root lecturer onboarding and publishing
capabilities through private, policy-gated endpoints. Blueprint approval authority
is a revocable course-scoped `REVIEWER` access edge, never a global lecturer flag.
Development administrator bootstrap is explicitly environment-gated, bound to one
configured root ID, and disabled in production.

---

## Core Domain Models

### User

Represents one authenticated account that may hold learner, lecturer, and
administrator application roles. Authentication remains owned by Jac Scale;
the stable domain `user_id` is derived from the authenticated persistent root.

Stores:

* Profile
* Learning paths
* Progress
* Statistics

### Learning Path

Represents a language track.

Examples:

* Jaseci
* Python
* JavaScript

### Learning Track

Represents the stable, shared curriculum identity used by both built-in
programming paths and lecturer-created courses. A `LearningTrack` is connected
through the deployment-wide `LearningCatalogue`, owns immutable curriculum
`TrackVersion` snapshots and one `TrackConfiguration`, and never stores
learner-specific progression. Public catalogue data lives under `root.shared`;
learner assessments, roadmaps, lessons, submissions, and mastery remain under
the authenticated learner root.

### Roadmap

Personalized learning plan.

Contains:

* Weeks
* Topics
* Lessons
* Milestones

### Topic

Represents a knowledge area.

Examples:

* Variables
* Functions
* Walkers
* OSP

### Lesson

Generated learning content.

Contains:

* Content
* Examples
* Exercises
* Metadata

### Challenge

Practical coding assessment.

Contains:

* Prompt
* Difficulty
* Evaluation criteria

### Mastery

Represents user proficiency for a topic.

Stored as graph relationships.

### Progression

Represents deterministic roadmap availability and completion state.

Stores:

* Per-lesson unlock state
* Roadmap progress summary
* Progression events
* Current available lesson
* Completion state

---

## OSP Graph Design

### Node Types

```text
User
LearningCatalogue
LearningTrack
TrackVersion
TrackConfiguration
LearningPath
Roadmap
Week
Topic
Lesson
Challenge
Skill
LessonProgress
RoadmapProgress
ProgressionEvent
```

### Edge Types

```text
HAS_ROADMAP
HAS_LEARNING_TRACK
HAS_TRACK_VERSION
HAS_TRACK_CONFIGURATION
HAS_WEEK
HAS_TOPIC
HAS_LESSON
HAS_CHALLENGE

PREREQUISITE

COMPLETED
PROGRESSES
TRACKS
UNLOCKED
BELONGS_TO

ATTEMPTED

MASTERED

RECOMMENDS

WEAK_IN

STRONG_IN
```

---

## Mastery Model

Each topic contains:

```text
mastery_score
attempt_count
success_rate
last_activity
confidence_score
```

Mastery levels:

```text
0.0 - 0.3 Beginner
0.3 - 0.6 Developing
0.6 - 0.8 Proficient
0.8 - 1.0 Mastered
```

---

## Agent Architecture

### Agent 1: Assessment Agent

Responsibilities:

* Evaluate onboarding assessment
* Determine starting level
* Estimate knowledge gaps

Output:

* Initial mastery graph

---

### Agent 2: Roadmap Agent

Responsibilities:

* Generate personalized roadmap
* Organize weeks and lessons
* Define progression sequence

Output:

* User roadmap

---

### Agent 3: Lesson Generator Agent

Responsibilities:

* Generate lesson content
* Generate examples
* Generate coding tasks

Output:

* Lesson record

---

### Agent 4: Challenge Generator Agent

Responsibilities:

* Generate coding challenges
* Adapt difficulty
* Create retry assessments

Output:

* Challenge record

---

### Agent 5: Evaluation Agent

Responsibilities:

* Evaluate learner submissions
* Score mastery
* Generate feedback

Output:

```json
{
  "score": 0.84,
  "mastery": 0.81,
  "feedback": "Strong understanding of loops and functions."
}
```

---

### Agent 6: Recommendation Agent

Responsibilities:

* Analyze graph state
* Detect weaknesses
* Recommend next actions

Output:

* Personalized suggestions

---

## Existing Walkers (Found at previous-walkers.jac.md)

Current walkers to retain and extend:

### progress_tracker

Updates:

* Lesson completion
* Topic mastery
* User statistics

### unlock_next_lesson

Controls progression.

Persists LessonProgress, RoadmapProgress, and ProgressionEvent records. Uses roadmap order, persisted generated lesson records, passing submission evaluations, and existing SkillMastery values to unlock the next eligible lesson. Does not generate content, evaluate submissions, or update mastery.

### generate_quiz

Will evolve into:

generate_challenge

### evaluate_answer

Will evolve into:

evaluate_submission

### get_skill_map

Returns graph visualization data.



---

## Dynamic Content Strategy

Roadmaps generated once.

Lessons generated on demand.

Challenges generated on demand.

Advantages:

* Lower AI cost
* Faster onboarding
* Better personalization
* Easier updates

---

## Critical Invariants

1. OSP graph is the source of truth for progression.
2. No lesson unlocks without prerequisite mastery.
3. Lessons are generated only when requested.
4. Generated lessons must be persisted.
5. Generated challenges must be persisted.
6. Every submission updates mastery scores.
7. AI evaluation never directly modifies graph state.
8. Walkers remain responsible for graph mutations.
9. Every learner has a unique roadmap.
10. Progress survives across sessions and devices.
11. Authenticated learner data is stored on and resolved from the caller's persistent Jac root.
12. The server-derived root identifier is the canonical ownership binding; email and browser storage are not ownership authorities.
13. Jac's graph store is the only LMS domain database. PostgreSQL/Prisma is not part of the current persistence architecture.
14. Shared curriculum identity is represented by stable `LearningTrack.track_id` values; legacy language strings are compatibility inputs, not primary curriculum identifiers.
15. Published `TrackVersion` nodes are immutable, and a track's active version must be a published version belonging to that same track.
16. The global learning catalogue is anchored under `root.shared`; learner-specific state must not be attached to catalogue tracks or versions.
17. Application roles are authoritative only through root-owned `UserRoleAssignment` nodes; client role strings and cached workspace selection never grant permission.
18. Lecturer operations require an ACTIVE lecturer assignment, an ACTIVE `LecturerProfile`, the relevant server-controlled capability, and resource authorization.
19. Lecturer course ownership uses the server-resolved `lecturer_id`; email, username, display name, and caller-provided owner identifiers are never ownership authorities.
20. Lecturer-owner authorization requires matching scalar ownership and `OWNS_TRACK`; a missing-edge scalar fallback is disabled by default, feature-flagged, and observable during migration.
21. Published and superseded curriculum versions remain immutable for owners, collaborators, and administrators; changes require a new draft version.
22. Lecturer learner/submission access must prove the complete same-track enrollment and version scope; identifier possession alone grants no access.
23. Course source bytes live behind `CourseDocumentStorageService` and Jac `store()`; graph nodes retain metadata only, canonical object keys are server-generated and immutable, and no walker or client receives backend paths or credentials.
24. A stored course source is usable only when its graph metadata, byte size, SHA-256, track/version scope, lifecycle state, and authorization context agree. Published source objects are protected from physical deletion by default.
25. Replicated deployments must use a shared durable Jac storage backend. Local storage is development/single-server only and fails course-storage readiness when explicitly configured as multi-instance.
26. Course publication is represented by an immutable `CoursePublication` snapshot binding the exact blueprint revision, approval, validation report, curriculum graph generation, source document checksum, extraction, and chunk set.
27. At most one `TrackVersion` per track may be `PUBLISHED`; activating a newer version supersedes the prior version without changing any existing enrollment's pinned `track_version_id`.
28. Published and superseded versions are sealed. Curriculum mutation must begin from a distinct draft version, and rollback reactivates an intact historical snapshot rather than modifying it.
