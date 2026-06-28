Read `AGENTS.md`, `context/architecture-context.md`, `context/project-overview.md`, and `context/ui-context.md` before starting.

# 10-generate-roadmap.md

We're implementing the roadmap/course outline generation system.

Walker:

`generate_roadmap`

This walker creates a personalized learning roadmap for a learner after their assessment has been evaluated.

The roadmap should define the learner's course outline, organized into weeks, topics, lessons, and milestones.

This feature must only generate and persist the roadmap structure.

Do not generate full lesson content.

Do not generate coding challenges.

Do not unlock lessons.

Do not update mastery.

Do not redirect users to the dashboard.

---

## Goal

Create a personalized course outline based on:

* selected learning language
* assessment evaluation result
* learner skill signals
* target learning path

Initial supported learning paths:

* Python
* Jac

The roadmap should represent what the learner should study and in what order.

---

## Required Inputs

The walker should accept:

* learner_id
* assessment_id
* assessment_attempt_id
* assessment_evaluation_id
* language

Supported language values:

* python
* jac

The walker should load:

* learner
* assessment
* submitted attempt
* assessment evaluation
* skill signals

Do not accept raw assessment answers directly.

Use the persisted evaluation result from Feature 08.

---

## Required Outputs

The walker should return the created roadmap.

The roadmap output should include:

* roadmap id
* learner id
* language
* title
* description
* estimated duration
* weeks
* lessons
* milestones
* created timestamp

Example shape:

```json
{
  "id": "roadmap_001",
  "learner_id": "learner_001",
  "language": "python",
  "title": "Personalized Python Foundations Roadmap",
  "estimated_weeks": 6,
  "weeks": [
    {
      "week_number": 1,
      "title": "Python Basics",
      "lessons": [
        {
          "lesson_id": "lesson_001",
          "title": "Variables and Data Types",
          "skill_ids": ["python_variables"],
          "difficulty": "beginner"
        }
      ]
    }
  ]
}
```

---

## Roadmap Domain Models

Ensure roadmap-related domain entities exist.

Create or update:

* Roadmap
* RoadmapWeek
* RoadmapLesson
* RoadmapMilestone

Roadmap should support:

* id
* learner_id
* language
* title
* description
* estimated_weeks
* status
* created_at

RoadmapWeek should support:

* id
* roadmap_id
* week_number
* title
* summary

RoadmapLesson should support:

* id
* roadmap_id
* week_id
* title
* summary
* target_skill_ids
* difficulty
* estimated_minutes
* order_index
* generation_status

RoadmapMilestone should support:

* id
* roadmap_id
* week_id
* title
* description
* required_skill_ids

Roadmap status values:

* draft
* active
* completed

RoadmapLesson generation_status values:

* pending
* generated

All roadmap lessons should start with:

```text
generation_status = pending
```

Full lesson content will be generated later by `generate_lesson`.

---

## AI Roadmap Schemas

Create structured AI response objects for roadmap generation.

Examples:

* RoadmapGenerationResult
* GeneratedRoadmapWeek
* GeneratedRoadmapLesson
* GeneratedRoadmapMilestone

All AI-visible objects and fields must include `sem` descriptions.

Use structured outputs only.

Do not parse raw AI text.

The LLM should return objects, not nodes.

After byLLM returns structured objects, copy validated fields into persistent graph nodes.

---

## AI Roadmap Generation Function

Create reusable AI function inside the AI module.

Example:

`generate_learning_roadmap_outline`

Inputs should include:

* language
* learner assessment summary
* overall score
* skill signals
* weak skills
* strong skills
* target level

Output:

* RoadmapGenerationResult

Use:

```jac
by llm(...)
```

Use complete `sem` descriptions for:

* function
* parameters
* return object
* every field on return object

Do not use free-form text generation.

---

## Roadmap Generation Rules

The roadmap should be adaptive.

If the learner shows weak beginner-level signals:

* start with fundamentals
* use shorter lessons
* include more practice-oriented milestones

If the learner shows stronger signals:

* skip unnecessary basics
* start closer to the learner's current level
* include more advanced lessons earlier

For Python roadmaps, possible skill areas include:

* syntax basics
* variables and data types
* control flow
* functions
* data structures
* modules
* error handling
* file handling
* object-oriented programming
* simple projects

For Jac roadmaps, possible skill areas include:

* Jac syntax basics
* nodes and edges
* walkers
* object-spatial programming
* graph traversal
* abilities
* byLLM integration
* Jac Client integration
* adaptive graph workflows
* LMS-style graph agents

Do not hardcode the final roadmap for every learner.

Static skill lists may guide generation, but the final roadmap should come from assessment results and skill signals.

---

## Implement generate_roadmap Walker

The walker should:

1. Receive learner_id, assessment_id, attempt_id, evaluation_id, and language

2. Validate the learner exists

3. Validate the assessment exists

4. Validate the attempt exists

5. Validate the evaluation exists

6. Extract score and skill signals from the evaluation

7. Build roadmap generation context

8. Call the AI roadmap generation function

9. Validate the structured roadmap output

10. Create Roadmap node

11. Create RoadmapWeek nodes

12. Create RoadmapLesson nodes

13. Create RoadmapMilestone nodes

14. Connect roadmap graph relationships

15. Return the created roadmap summary

The walker should orchestrate only.

Do not place large prompt logic directly inside the walker.

---

## Graph Relationships

Persist relationships between:

Learner → Roadmap

Roadmap → RoadmapWeek

RoadmapWeek → RoadmapLesson

RoadmapWeek → RoadmapMilestone

RoadmapLesson → Skill

RoadmapMilestone → Skill

Use existing graph edge patterns where possible.

If new edges are required, add only the minimum needed.

Suggested relationships:

* assigned
* contains
* targets
* requires

Do not use unlock/progression edges yet.

---

## Persistence Requirements

The roadmap must persist successfully.

Weeks must persist successfully.

Roadmap lessons must persist successfully.

Milestones must persist successfully.

Relationships must persist successfully.

The roadmap must be retrievable after generation.

Do not store raw LLM output.

Only store validated structured roadmap data.

---

## Idempotency

A learner should not accidentally receive duplicate active roadmaps for the same language and assessment evaluation.

Choose one strategy:

* return existing active roadmap if it already exists
* archive old roadmap before creating a new one

Document the chosen behavior in code comments.

For this feature, prefer:

```text
return existing active roadmap for same learner + language + evaluation
```

---

## Error Handling

Handle:

* missing learner
* missing assessment
* missing assessment attempt
* missing assessment evaluation
* unsupported language
* invalid skill signals
* invalid AI output
* persistence failure

Return structured errors.

Do not silently create incomplete roadmaps.

---

## MockLLM Test Coverage

Create MockLLM tests for:

* Python roadmap generation
* Jac roadmap generation
* weak beginner assessment result
* stronger intermediate assessment result
* roadmap persistence
* week creation
* lesson outline creation
* milestone creation
* duplicate roadmap prevention
* unsupported language rejection

Tests must run without API keys.

Use structured MockLLM outputs.

Do not rely on live providers.

---

## Frontend Contract

Create or update frontend DTOs for roadmap results.

The frontend should be able to consume:

* RoadmapSummary
* RoadmapWeek
* RoadmapLessonOutline
* RoadmapMilestone

Do not create roadmap UI in this feature.

Do not create dashboard UI in this feature.

---

## Future Compatibility

This roadmap will feed future features:

* roadmap UI
* generate_lesson
* get_dashboard
* get_skill_map
* unlock_next_lesson
* recommend_next_action

Design the roadmap so lessons can be generated on demand later.

RoadmapLesson should contain enough metadata to generate full lesson content later:

* title
* summary
* target skills
* difficulty
* estimated minutes
* order index

Do not generate full lesson content yet.

---

## Explicitly Out of Scope

Do not implement:

* roadmap UI
* dashboard UI
* lesson content generation
* challenge generation
* mastery updates
* lesson unlocking
* progress tracking
* AI tutor recommendations
* certificate logic
* authentication

This feature only creates the personalized roadmap/course outline.

---

## Check When Done

* `generate_roadmap` walker compiles
* Python roadmap can be generated
* Jac roadmap can be generated
* Roadmap uses assessment evaluation results
* Roadmap contains ordered weeks
* Roadmap contains ordered lesson outlines
* Roadmap contains milestones
* Roadmap lessons start with `generation_status = pending`
* Roadmap is persisted to the graph
* Roadmap can be retrieved after generation
* Duplicate roadmap generation is prevented
* Structured AI outputs validate correctly
* MockLLM tests pass without API keys
* No full lesson content is generated
* No lesson is unlocked
* No mastery update occurs
* No dashboard UI is created
