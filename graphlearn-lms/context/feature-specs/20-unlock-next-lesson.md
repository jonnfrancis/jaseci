Read `AGENTS.md`, and `context/architecture-context.md` before starting.

# 20-unlock-next-lesson.md

We're implementing the progression engine.

Walker:

`unlock_next_lesson`

This walker determines which roadmap lessons should be available to the learner based on roadmap order, completion state, and mastery requirements.

The mastery engine already updates learner mastery values.

The roadmap subsystem already creates ordered lessons.

This feature connects those systems to control lesson availability.

Do not generate lessons.

Do not generate challenges.

Do not evaluate submissions.

Do not update mastery.

Do not generate recommendations.

Do not build dashboard UI.

---

## Goal

Implement lesson progression logic.

The learner should be able to progress through their roadmap in a controlled way.

The walker should answer:

* Which lesson is currently available?
* Which lesson was just completed?
* Which lesson should unlock next?
* Which lessons are locked?
* Why is a lesson locked?
* Has the learner completed the full roadmap?

This feature should make roadmap progression graph-aware and mastery-aware.

---

## Required Inputs

The walker should accept:

* learner_id
* roadmap_id
* completed_roadmap_lesson_id optional
* source_type optional
* source_id optional

The optional `completed_roadmap_lesson_id` is used when a learner has just completed a lesson/challenge cycle.

The optional `source_type` and `source_id` can reference the evidence that caused progression.

Possible source types:

```text
lesson_completion
submission_evaluation
manual_check
```

For this feature, progression should primarily use persisted roadmap, lesson, challenge, and mastery data.

Do not accept raw mastery scores from the frontend.

Do not accept raw completion state from the frontend.

---

## Required Outputs

The walker should return a progression result.

The result should include:

* learner id
* roadmap id
* current lesson
* newly unlocked lessons
* locked lessons
* completed lessons
* roadmap completion state
* progression message

Example shape:

```json
{
  "learner_id": "learner_001",
  "roadmap_id": "roadmap_001",
  "current_lesson": {
    "roadmap_lesson_id": "lesson_003",
    "title": "Functions and Parameters",
    "status": "available"
  },
  "newly_unlocked_lessons": [
    {
      "roadmap_lesson_id": "lesson_004",
      "title": "Return Values",
      "status": "available",
      "unlock_reason": "Previous lesson completed and required skills are developing or higher."
    }
  ],
  "locked_lessons": [
    {
      "roadmap_lesson_id": "lesson_005",
      "title": "Modules",
      "status": "locked",
      "locked_reason": "Complete Return Values first."
    }
  ],
  "completed_lessons": [
    {
      "roadmap_lesson_id": "lesson_001",
      "title": "Variables and Data Types",
      "status": "completed"
    }
  ],
  "roadmap_completed": false,
  "message": "Your next lesson is Return Values."
}
```

---

## Progression Domain Models

Create or update:

* LessonProgress
* LessonUnlockState
* RoadmapProgress
* ProgressionEvent

LessonProgress should support:

* id
* learner_id
* roadmap_id
* roadmap_lesson_id
* status
* completed_at
* unlocked_at
* updated_at

Lesson status values:

```text
locked
available
in_progress
completed
```

RoadmapProgress should support:

* id
* learner_id
* roadmap_id
* total_lessons
* completed_lessons
* available_lessons
* locked_lessons
* percent_complete
* current_roadmap_lesson_id
* status
* updated_at

Roadmap progress status values:

```text
not_started
in_progress
completed
```

ProgressionEvent should support:

* id
* learner_id
* roadmap_id
* roadmap_lesson_id
* event_type
* source_type
* source_id
* message
* created_at

Progression event types:

```text
lesson_unlocked
lesson_completed
roadmap_started
roadmap_completed
```

Do not add recommendation fields.

Do not add AI tutor fields.

---

## Progression Rules

Use deterministic progression rules.

### First Lesson Rule

If a roadmap has no progress yet:

* unlock the first lesson by `week_number` then `order_index`
* set roadmap status to `in_progress`
* create a `roadmap_started` event
* return the first lesson as current lesson

Do not unlock every lesson at once.

---

### Completion Rule

A lesson can be marked completed when:

* the learner has generated/read the lesson, and
* the learner has a passing submission evaluation for that lesson's challenge

For this feature, use the persisted records that already exist:

* GeneratedLesson
* GeneratedChallenge
* ChallengeSubmission
* SubmissionEvaluation

Suggested passing rule:

```text
submission_evaluation.passed = true
```

Do not recalculate the evaluation score.

Do not call `evaluate_submission`.

---

### Next Lesson Rule

After a lesson is completed:

* find the next roadmap lesson by order
* check prerequisites if available
* check required skill mastery if available
* unlock the next eligible lesson

If the next lesson has no explicit prerequisite data yet, use roadmap order only.

---

### Mastery Requirement Rule

A roadmap lesson may require target skills.

If the lesson has required prerequisite skills:

* each prerequisite skill should meet the minimum mastery threshold

Suggested minimum:

```text
40
```

Meaning:

```text
developing or higher
```

Do not require full mastery unless the roadmap lesson explicitly says so.

Keep this threshold centralized in progression config/constants.

---

### Locked Reason Rule

Every locked lesson should include a clear reason.

Examples:

```text
Complete the previous lesson first.
```

```text
Build more confidence in Python Functions before starting this lesson.
```

```text
This lesson unlocks after you pass the previous coding challenge.
```

Do not return locked lessons without an explanation.

---

### Roadmap Completion Rule

If all roadmap lessons are completed:

* set roadmap progress status to `completed`
* create `roadmap_completed` event
* return `roadmap_completed = true`

Do not generate certificates.

Do not create badges.

Do not redirect automatically.

---

## Implement unlock_next_lesson Walker

The walker should:

1. Receive learner_id, roadmap_id, and optional completed_roadmap_lesson_id

2. Validate learner exists

3. Validate roadmap exists

4. Validate roadmap belongs to learner

5. Load roadmap weeks and lessons in order

6. Load existing LessonProgress records

7. Load learner SkillMastery records

8. Load challenge submission evaluations linked to roadmap lessons

9. Initialize progress if none exists

10. If completed_roadmap_lesson_id is provided:

* validate lesson belongs to roadmap
* validate completion requirements are met
* mark lesson as completed
* create lesson_completed event

11. Determine next eligible lesson

12. Unlock next eligible lesson if needed

13. Update RoadmapProgress summary

14. Create progression events where needed

15. Return progression result

The walker should orchestrate progression only.

Do not put frontend navigation logic inside the walker.

---

## Graph Relationships

Persist relationships between:

Learner → LessonProgress

Roadmap → LessonProgress

RoadmapLesson → LessonProgress

Learner → RoadmapProgress

Roadmap → RoadmapProgress

Learner → ProgressionEvent

Roadmap → ProgressionEvent

RoadmapLesson → ProgressionEvent

Use existing graph edge patterns where possible.

Suggested relationships:

* progresses
* tracks
* unlocked
* completed
* belongs_to

Do not create recommendation edges.

Do not create mastery evidence edges.

---

## Idempotency

Repeated calls must not duplicate unlocks or completion events.

If the same lesson is already completed:

* return existing completed state
* do not create duplicate completion events

If the next lesson is already available:

* return existing available state
* do not create duplicate unlock events

This prevents repeated clicks and page refreshes from corrupting progression.

---

## Persistence Requirements

The walker must persist:

* LessonProgress records
* RoadmapProgress record
* ProgressionEvent records

The updated progression state must be retrievable after creation.

Do not store derived UI-only state as source of truth.

---

## Error Handling

Handle:

* missing learner
* missing roadmap
* roadmap does not belong to learner
* roadmap has no lessons
* completed lesson not found
* completed lesson does not belong to roadmap
* completion requirements not met
* missing challenge evaluation
* failed persistence
* malformed roadmap order

Return structured errors.

Do not silently unlock lessons when requirements are missing.

If completion requirements are not met, return a clear blocked state.

---

## Testing

Create tests for:

* first lesson unlock
* roadmap progress initialization
* completing a lesson
* unlocking the next lesson
* blocked completion without passing challenge
* blocked unlock when prerequisite mastery is too low
* unlock when prerequisite mastery is sufficient
* completing final lesson
* roadmap completed state
* idempotent repeated unlock call
* idempotent repeated completion call
* missing roadmap rejection
* roadmap with no lessons handling

Tests should not require live AI providers.

This feature reads existing graph state and updates progression only.

---

## Frontend Contract

Create or update frontend DTOs for progression results.

The frontend should be able to consume:

* ProgressionResult
* LessonProgressView
* RoadmapProgressView
* ProgressionEventView

Do not create progression UI in this feature unless a minimal debug/test display is required.

Dashboard and roadmap UI updates belong in later features.

---

## Integration With Previous Features

This feature should work after:

1. roadmap is generated
2. lesson is generated
3. challenge is generated
4. challenge submission is evaluated
5. mastery is updated

Expected future flow:

```text
evaluate_submission
→ update_mastery
→ unlock_next_lesson
```

For this feature, it is acceptable to manually call `unlock_next_lesson` during testing.

---

## Future Compatibility

This walker will feed:

* get_dashboard
* roadmap UI progress states
* lesson viewer navigation
* recommend_next_action
* completion page

Design the result so the UI can answer:

* what lesson is next
* what lesson is locked
* what lesson is complete
* why something is locked
* whether the roadmap is complete

Do not implement those UI features now.

---

## Explicitly Out of Scope

Do not implement:

* AI recommendations
* dashboard UI
* skill map UI changes
* lesson generation
* challenge generation
* submission evaluation
* mastery updates
* certificates
* badges
* notifications

This feature only handles deterministic lesson unlocking and roadmap progression.

---

## Check When Done

* `unlock_next_lesson` walker compiles
* First roadmap lesson unlocks correctly
* RoadmapProgress initializes correctly
* Completed lesson can be marked completed
* Next eligible lesson unlocks correctly
* Locked lessons include reasons
* Lessons do not unlock without required completion
* Mastery threshold is respected where prerequisites exist
* Final lesson completion marks roadmap as completed
* Repeated calls are idempotent
* Progression events persist correctly
* Progression state can be retrieved after update
* Tests pass
* No recommendations are generated
* No mastery update occurs
* No dashboard UI is created
