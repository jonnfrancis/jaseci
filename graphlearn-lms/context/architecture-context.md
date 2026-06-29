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
| Database          | PostgreSQL                | Persistence               |
| ORM               | Prisma                    | Data access               |
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

OSP Learning Graph

       ↓

byLLM Agents

       ↓

Database
```

---

## Core Domain Models

### User

Represents a learner.

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

---

## OSP Graph Design

### Node Types

```text
User
LearningPath
Roadmap
Week
Topic
Lesson
Challenge
Skill
```

### Edge Types

```text
HAS_ROADMAP
HAS_WEEK
HAS_TOPIC
HAS_LESSON
HAS_CHALLENGE

PREREQUISITE

COMPLETED

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
