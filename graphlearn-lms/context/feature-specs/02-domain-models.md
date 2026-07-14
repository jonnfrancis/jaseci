# 02-domain-models.md

Read `AGENTS.md`, `context/architecture-context.md`, and `context/ui-context.md` before starting.

We need the core domain entities that every walker and UI feature will depend on. The graph schema must become the source of truth for:

learner progress
skill mastery
lesson dependencies
roadmap generation
assessment tracking

Frontend types should mirror backend entities but must not contain business logic.

This feature only establishes the domain model layer.

Do not create walkers.
Do not create byLLM agents.
Do not create Spawn() calls.
Do not create API wrappers.
Do not create persistence logic.

---

## Domain Folder Structure

Create:

```text
nodes/
├── learner.jac
├── assessment.jac
├── lesson.jac
├── challenge.jac
├── skill.jac
├── mastery.jac
├── roadmap.jac
└── index.jac
```

---

## Backend Domain Nodes

Use Jac node definitinos
Only define fields
Do not add abilities
Do not add walkers
---

## Learner

Create learner Node.

Fields:

* id
* name
* createdAt
* updatedAt

Do not add authentication fields.

---

## Assessment

Create assessment Node.

Fields:

* id
* title
* description
* status
* questions
* createdAt

Status values:

* draft
* active
* completed

Questions can remain simple placeholder structures for now.

---

## Lesson

Create lesson node.

Fields:

* id
* title
* summary
* skillId
* difficulty
* estimatedMinutes

Difficulty values:

* beginner
* intermediate
* advanced

Do not add lesson content generation fields yet.

---

## Challenge

Create challenge node.

Fields:

* id
* title
* description
* skillId
* difficulty

Do not add starter code or grading fields yet.

---

## Skill

Create skill node.

Fields:

* id
* name
* description
* category

Do not implement graph relationships yet.

---

## Mastery

Create mastery node.

Fields:

* learnerId
* skillId
* score
* updatedAt

Score range:

* 0–100

Validation should enforce range limits.

---

## Roadmap

Create roadmap node.

Fields:

* id
* learnerId
* title
* lessonIds
* createdAt

Roadmap should reference lessons by id only.

---

## Graph Relationships
Create edge definitions in `edges/edges.jac`
- Only define edge types
- No traversal logic

### Prerequisite
Represents
` Skill -> Skill
  Lesson -> Lesson
`
Used Later for unlocking progression

### teaches

Represents:
`
Lesson -> Skill
Challenge -> Skill
`

### mastered

Represents:
`
Learner -> Skill
`
Will later reference mastery scores.

### assigned

Represents:
`
Learner -> Roadmap
Roadmap -> Lesson
`

### completed

Represents:
`
Learner -> Lesson
Learner -> Challenge
Learner -> Assessment
`

## Frontend Type Definitions

Create TypeScript interfaces mirroring backend nodes.

Example:
`
export interface Learner {
  id: string;
  name: string;
  created_at: string;
  updated_at: string;
}
`
Use TypeScript only.

Do not add zod yet.

Validation belongs in form features, not domain graph definitions.

### Barrel Exports

Backend:

`nodes/index.jac`

Frontend:

`lib/types/index.ts`

Export all entities from a single location.

### Check when done

* All Jac node definitions compile
* All edge definitions compile
* Frontend TypeScript types compile
* Backend graph schema is isolated from business logic
* Barrel exports work
* No walkers exist
* No byLLM code exists
* No persistence code exists
* No Spawn() calls exist
