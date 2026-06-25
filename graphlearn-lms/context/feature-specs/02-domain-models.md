# 02-domain-models.md

Read `AGENTS.md`, `context/domain-context.md`, and `context/ui-context.md` before starting.

We need the core domain entities that every walker and UI feature will depend on.

This feature only establishes the domain model layer.

Do not create walkers.
Do not create repositories.
Do not create API routes.
Do not create persistence logic.

---

## Domain Folder Structure

Create:

```text
lib/domain/
├── learner.ts
├── assessment.ts
├── lesson.ts
├── challenge.ts
├── skill.ts
├── mastery.ts
├── roadmap.ts
└── index.ts
```

---

## Validation

Install and configure `zod`.

Every domain entity must provide:

* TypeScript type
* Zod schema
* exported validation helper

Pattern:

```ts
export const LearnerSchema = ...
export type Learner = ...
```

---

## Learner

Create learner entity.

Fields:

* id
* name
* createdAt
* updatedAt

Do not add authentication fields.

---

## Assessment

Create assessment entity.

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

Create lesson entity.

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

Create challenge entity.

Fields:

* id
* title
* description
* skillId
* difficulty

Do not add starter code or grading fields yet.

---

## Skill

Create skill entity.

Fields:

* id
* name
* description
* category

Do not implement graph relationships yet.

---

## Mastery

Create mastery entity.

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

Create roadmap entity.

Fields:

* id
* learnerId
* title
* lessonIds
* createdAt

Roadmap should reference lessons by id only.

---

## Barrel Export

Create:

```text
lib/domain/index.ts
```

Export all domain entities from a single location.

---

### Check when done

* All schemas compile
* Validation works
* Barrel exports work
* Sample entities can be instantiated
* No walker code exists
* No persistence code exists
