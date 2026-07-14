Read `AGENTS.md`, `context/architecture-context.md`, and `context/ui-context.md` before starting.

# 12-generate-lesson.md

We're implementing on-demand lesson generation.

Walker:

`generate_lesson`

This walker generates full lesson content for a roadmap lesson outline.

The roadmap subsystem only creates lesson titles, summaries, target skills, difficulty, estimated minutes, and ordering. This feature turns one roadmap lesson outline into a complete readable lesson.

Do not generate coding challenges.

Do not evaluate learner submissions.

Do not update mastery.

Do not unlock the next lesson.

Do not create dashboard analytics.

---

## Goal

Generate lesson content only when the learner opens or requests a specific roadmap lesson.

This keeps roadmap generation fast and avoids generating unnecessary lesson content upfront.

The generated lesson should be:

* personalized to the learner
* aligned with the roadmap lesson outline
* appropriate to the selected language
* structured for the LMS workspace
* persisted for reuse

---

## Required Inputs

The walker should accept:

* learner_id
* roadmap_id
* roadmap_lesson_id
* language

Supported language values:

* python
* jac

The walker should load:

* learner
* roadmap
* roadmap lesson outline
* roadmap week
* target skills
* assessment evaluation summary if available
* existing generated lesson if available

Do not accept raw prompt text from the frontend.

Do not accept arbitrary lesson titles from the frontend.

Use the persisted roadmap lesson as the source of truth.

---

## Required Outputs

The walker should return a generated lesson view.

The output should include:

* lesson id
* roadmap lesson id
* learner id
* language
* title
* summary
* difficulty
* estimated minutes
* sections
* examples
* mini exercises
* key takeaways
* generation status
* created timestamp

Example shape:

```json
{
  "id": "lesson_001",
  "roadmap_lesson_id": "roadmap_lesson_001",
  "language": "python",
  "title": "Variables and Data Types",
  "summary": "Learn how Python stores and works with values.",
  "difficulty": "beginner",
  "estimated_minutes": 12,
  "sections": [
    {
      "title": "What is a variable?",
      "content": "A variable is a named reference to a value."
    }
  ],
  "examples": [
    {
      "title": "Creating variables",
      "code": "name = 'Ada'\nage = 20",
      "explanation": "This creates two variables."
    }
  ],
  "mini_exercises": [
    {
      "prompt": "Create a variable called score and assign it the value 100.",
      "expected_concept": "variable assignment"
    }
  ],
  "key_takeaways": [
    "Variables store references to values.",
    "Python infers data types automatically."
  ],
  "generation_status": "generated"
}
```

---

## Lesson Domain Models

Ensure lesson content entities exist or extend the existing lesson model.

Create or update:

* GeneratedLesson
* LessonSection
* LessonExample
* LessonMiniExercise
* LessonTakeaway

GeneratedLesson should support:

* id
* learner_id
* roadmap_id
* roadmap_lesson_id
* language
* title
* summary
* difficulty
* estimated_minutes
* created_at
* updated_at

LessonSection should support:

* id
* lesson_id
* title
* content
* order_index

LessonExample should support:

* id
* lesson_id
* title
* code
* explanation
* order_index

LessonMiniExercise should support:

* id
* lesson_id
* prompt
* expected_concept
* order_index

LessonTakeaway should support:

* id
* lesson_id
* content
* order_index

Do not create Challenge entities in this feature.

Mini exercises are lightweight reading checks only. They are not graded challenges.

---

## AI Lesson Schemas

Create structured AI response objects for lesson generation.

Examples:

* LessonGenerationResult
* GeneratedLessonSection
* GeneratedLessonExample
* GeneratedLessonMiniExercise
* GeneratedLessonTakeaway

All AI-visible objects and fields must include `sem` descriptions.

Use structured outputs only.

Do not parse raw AI text.

The LLM should return objects, not nodes.

After byLLM returns structured objects, copy validated fields into persistent graph nodes.

---

## AI Lesson Generation Function

Create a reusable AI function inside the AI module.

Suggested name:

`generate_lesson_content`

Inputs should include:

* language
* lesson title
* lesson summary
* difficulty
* estimated minutes
* target skills
* learner assessment summary
* weak skills
* strong skills
* previous lesson titles if available

Output:

* LessonGenerationResult

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

Do not place large prompt text directly inside the walker.

---

## Lesson Generation Rules

Generated lessons should follow this structure:

1. Brief introduction
2. Concept explanation
3. Practical example
4. Common mistake or misconception
5. Mini exercise
6. Key takeaways

Lessons should be short and focused.

Target reading time:

* beginner: 8–12 minutes
* intermediate: 10–15 minutes
* advanced: 12–18 minutes

For Python lessons:

* examples should be valid Python
* explanations should be beginner-friendly when difficulty is beginner
* avoid unnecessary libraries unless the lesson requires them

For Jac lessons:

* examples should use Jac syntax
* explanations should emphasize graph-native thinking where relevant
* connect concepts to nodes, edges, walkers, abilities, OSP, and byLLM when appropriate

Do not include final coding challenge content.

Do not include grading rubrics.

---

## Implement generate_lesson Walker

The walker should:

1. Receive learner_id, roadmap_id, roadmap_lesson_id, and language

2. Validate learner exists

3. Validate roadmap exists

4. Validate roadmap belongs to learner

5. Validate roadmap lesson exists

6. Validate roadmap lesson belongs to roadmap

7. Check if a generated lesson already exists for this roadmap lesson

8. If generated lesson exists, return it

9. Build lesson generation context

10. Call the AI lesson generation function

11. Validate structured lesson output

12. Create GeneratedLesson node

13. Create LessonSection nodes

14. Create LessonExample nodes

15. Create LessonMiniExercise nodes

16. Create LessonTakeaway nodes

17. Connect generated lesson to roadmap lesson

18. Mark roadmap lesson generation_status as generated

19. Return generated lesson view

The walker should orchestrate only.

Do not put prompt construction or scoring logic directly inside the walker.

---

## Graph Relationships

Persist relationships between:

Learner → GeneratedLesson

Roadmap → GeneratedLesson

RoadmapLesson → GeneratedLesson

GeneratedLesson → LessonSection

GeneratedLesson → LessonExample

GeneratedLesson → LessonMiniExercise

GeneratedLesson → LessonTakeaway

GeneratedLesson → Skill

Use existing graph edge patterns where possible.

If new edges are required, add only the minimum needed.

Suggested relationships:

* generated_for
* contains
* targets

Do not add unlock edges yet.

Do not add mastery edges yet.

---

## Persistence Requirements

The generated lesson must persist successfully.

Sections must persist successfully.

Examples must persist successfully.

Mini exercises must persist successfully.

Takeaways must persist successfully.

Relationships must persist successfully.

The generated lesson must be retrievable after generation.

Do not store raw LLM output.

Only store validated structured lesson data.

---

## Idempotency

Generating the same lesson repeatedly should not create duplicates.

If a generated lesson already exists for the same learner and roadmap_lesson_id:

* return the existing generated lesson
* do not call byLLM again
* do not create duplicate sections/examples/exercises

This is important because users may refresh the lesson page.

---

## Loading State Compatibility

This walker may take longer than normal graph operations.

The frontend should be able to display loading states such as:

* Generating your lesson...
* Building examples...
* Preparing practice prompts...
* Saving lesson content...

Do not implement the frontend loading UI in this feature unless needed for local testing.

The walker should return clear success or structured error states.

---

## Error Handling

Handle:

* missing learner
* missing roadmap
* roadmap does not belong to learner
* missing roadmap lesson
* unsupported language
* invalid roadmap lesson state
* invalid target skills
* invalid AI output
* byLLM failure
* persistence failure

Return structured errors.

Do not silently create partial lessons.

If persistence fails after partial creation, document the cleanup strategy or ensure partial records cannot be returned as complete lessons.

---

## MockLLM Test Coverage

Create MockLLM tests for:

* Python lesson generation
* Jac lesson generation
* beginner lesson
* intermediate lesson
* existing generated lesson reuse
* roadmap lesson status update
* section creation
* example creation
* mini exercise creation
* takeaway creation
* invalid roadmap lesson rejection
* unsupported language rejection

Tests must run without API keys.

Use structured MockLLM outputs.

Do not rely on live providers.

---

## Frontend Contract

Create or update frontend DTOs for generated lesson results.

The frontend should be able to consume:

* GeneratedLessonView
* LessonSectionView
* LessonExampleView
* LessonMiniExerciseView
* LessonTakeawayView

Do not create lesson workspace UI in this feature.

Do not create coding editor UI in this feature.

---

## Integration With Previous Features

This feature should work after:

1. learner completes assessment
2. assessment is evaluated
3. roadmap is generated
4. roadmap UI displays lesson outlines
5. learner requests a roadmap lesson

The roadmap lesson should begin with:

```text
generation_status = pending
```

After this walker succeeds, it should become:

```text
generation_status = generated
```

---

## Future Compatibility

This generated lesson will feed future features:

* lesson viewer
* lesson workspace
* generate_challenge
* evaluate_submission
* update_mastery
* unlock_next_lesson
* get_dashboard
* recommend_next_action

Design lesson content so the challenge generator can later use:

* lesson title
* lesson summary
* target skills
* examples
* mini exercises
* difficulty

Do not implement those features now.

---

## Explicitly Out of Scope

Do not implement:

* lesson viewer UI
* coding workspace
* challenge generation
* answer evaluation
* mastery updates
* unlock logic
* dashboard analytics
* skill map visualization
* AI tutor recommendations
* certificates
* authentication changes

This feature only generates and persists lesson content.

---

## Check When Done

* `generate_lesson` walker compiles
* Python lesson can be generated
* Jac lesson can be generated
* Generated lesson uses roadmap lesson outline
* Generated lesson includes sections
* Generated lesson includes examples
* Generated lesson includes mini exercises
* Generated lesson includes key takeaways
* Generated lesson is persisted to the graph
* Roadmap lesson `generation_status` updates to `generated`
* Existing generated lesson is reused on repeat calls
* Structured AI outputs validate correctly
* MockLLM tests pass without API keys
* No coding challenge is generated
* No submission evaluation exists
* No mastery update occurs
* No unlock logic exists
