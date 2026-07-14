Read `AGENTS.md`, and `context/architecture-context.md` before starting.

# 21-get-dashboard.md

We're implementing dashboard aggregation.

Walker:

`get_dashboard`

This walker collects the learner's current LMS state and returns a structured dashboard DTO.

The dashboard should summarize roadmap progress, mastery state, lesson status, challenge status, and next available learning item.

Do not render dashboard UI.

Do not update mastery.

Do not unlock lessons.

Do not generate recommendations.

Do not generate lessons.

Do not generate challenges.

---

## Goal

Create a single backend/read model that the frontend dashboard can consume.

The dashboard should answer:

* What roadmap is the learner currently following?
* How far has the learner progressed?
* What lesson is currently available?
* Which lessons are completed, available, or locked?
* What are the learner's strongest and weakest skills?
* What challenge/submission/evaluation state exists?
* What should the dashboard display as the learner's current learning status?

This walker should aggregate existing graph data only.

---

## Required Inputs

The walker should accept:

* learner_id
* language optional
* roadmap_id optional

Supported language values:

```text id="b92k6e"
python
jac
```

If `roadmap_id` is provided:

* return dashboard data for that roadmap

If `roadmap_id` is not provided:

* resolve the active roadmap for the learner and selected language

If `language` is not provided:

* use the learner's most recent active roadmap if available

Do not accept raw dashboard data from the frontend.

Do not accept raw mastery scores from the frontend.

Do not accept raw lesson status from the frontend.

Use persisted graph data only.

---

## Required Outputs

The walker should return a `DashboardView`.

The output should include:

* learner summary
* active roadmap summary
* roadmap progress
* mastery summary
* lesson status summary
* challenge status summary
* current lesson
* recent activity
* dashboard state

Example shape:

```json id="gz7l6o"
{
  "learner": {
    "learner_id": "learner_001",
    "name": "John"
  },
  "active_roadmap": {
    "roadmap_id": "roadmap_001",
    "language": "python",
    "title": "Python Foundations Roadmap",
    "status": "in_progress"
  },
  "roadmap_progress": {
    "total_lessons": 12,
    "completed_lessons": 4,
    "available_lessons": 1,
    "locked_lessons": 7,
    "percent_complete": 33,
    "current_roadmap_lesson_id": "roadmap_lesson_005"
  },
  "mastery_summary": {
    "average_mastery": 64,
    "mastered_count": 2,
    "proficient_count": 3,
    "developing_count": 4,
    "beginner_count": 1,
    "strongest_skills": [
      {
        "skill_id": "python_variables",
        "name": "Variables",
        "score": 88,
        "level": "proficient"
      }
    ],
    "weakest_skills": [
      {
        "skill_id": "python_functions",
        "name": "Functions",
        "score": 42,
        "level": "developing"
      }
    ]
  },
  "lesson_summary": {
    "generated_lessons": 5,
    "pending_lessons": 7,
    "completed_lessons": 4
  },
  "challenge_summary": {
    "generated_challenges": 4,
    "submitted_challenges": 3,
    "evaluated_submissions": 3,
    "passed_challenges": 2,
    "failed_challenges": 1
  },
  "current_lesson": {
    "roadmap_lesson_id": "roadmap_lesson_005",
    "title": "Functions and Parameters",
    "status": "available",
    "generation_status": "pending"
  },
  "recent_activity": [
    {
      "type": "submission_evaluated",
      "title": "Variables challenge evaluated",
      "timestamp": "2026-06-30T00:00:00Z"
    }
  ],
  "dashboard_state": "ready"
}
```

---

## Dashboard DTOs

Create or update dashboard view objects.

Suggested objects:

* DashboardView
* DashboardLearnerSummary
* DashboardRoadmapSummary
* DashboardRoadmapProgress
* DashboardMasterySummary
* DashboardSkillSummary
* DashboardLessonSummary
* DashboardChallengeSummary
* DashboardCurrentLesson
* DashboardRecentActivity

Do not create persistent Dashboard nodes unless absolutely necessary.

The dashboard is a read model built from existing graph state.

---

## Dashboard State

The dashboard should include a top-level state.

Supported values:

```text id="yjugjn"
no_assessment
assessment_started
assessment_completed
roadmap_missing
roadmap_ready
in_progress
completed
ready
```

Suggested state logic:

* no assessment exists → `no_assessment`
* assessment exists but no evaluation → `assessment_started`
* assessment evaluation exists but no roadmap → `roadmap_missing`
* roadmap exists but no progression → `roadmap_ready`
* roadmap progress exists and not completed → `in_progress`
* roadmap progress completed → `completed`
* normal loaded dashboard → `ready`

Choose a consistent mapping and document it.

Do not trigger missing actions from this walker.

For example, if roadmap is missing, return `roadmap_missing`; do not call `generate_roadmap`.

---

## Data Sources

Aggregate from existing graph data:

* Learner
* Assessment
* AssessmentAttempt
* AssessmentEvaluation
* Roadmap
* RoadmapWeek
* RoadmapLesson
* GeneratedLesson
* GeneratedChallenge
* ChallengeSubmission
* SubmissionEvaluation
* SkillMastery
* MasteryEvidence
* LessonProgress
* RoadmapProgress
* ProgressionEvent

Read only.

Do not mutate graph state.

---

## Roadmap Progress Aggregation

Use `RoadmapProgress` if it exists.

If `RoadmapProgress` is missing but roadmap lessons exist:

* calculate a safe derived summary
* return state indicating progression has not started yet

Suggested fallback:

```text id="me16w5"
total_lessons = count roadmap lessons
completed_lessons = 0
available_lessons = 0
locked_lessons = total_lessons
percent_complete = 0
```

Do not automatically call `unlock_next_lesson`.

---

## Mastery Summary Aggregation

Use `SkillMastery` records for the learner.

Return:

* average mastery
* mastered count
* proficient count
* developing count
* beginner count
* strongest skills
* weakest skills

Strongest skills:

* top 3 skills by score

Weakest skills:

* bottom 3 skills by score

Only include skills relevant to the active roadmap where possible.

If no mastery records exist:

* average mastery should be 0
* counts should be 0
* strongest skills should be empty
* weakest skills should be empty

Do not create mastery records here.

---

## Lesson Status Aggregation

Collect lesson-related state from:

* RoadmapLesson
* GeneratedLesson
* LessonProgress

Return:

* total lessons
* generated lessons
* pending lessons
* completed lessons
* available lessons
* locked lessons
* in-progress lessons

Use persisted state where available.

If lesson progress does not exist, infer only generation status from roadmap lesson metadata.

Do not mark a lesson completed based only on generated content.

---

## Challenge Status Aggregation

Collect challenge-related state from:

* GeneratedChallenge
* ChallengeSubmission
* SubmissionEvaluation

Return:

* generated challenges
* draft submissions if supported
* submitted challenges
* evaluated submissions
* passed challenges
* failed challenges

Do not evaluate missing submissions.

Do not generate missing challenges.

Do not calculate mastery from challenge state.

---

## Current Lesson

Determine current lesson from:

1. `RoadmapProgress.current_roadmap_lesson_id` if available
2. first available `LessonProgress`
3. first roadmap lesson by order if no progression exists

Return:

* roadmap lesson id
* title
* summary
* week number
* order index
* status
* generation status
* generated lesson id if available
* challenge id if available

Do not unlock anything to produce a current lesson.

If no current lesson exists, return null.

---

## Recent Activity

Return a small recent activity list.

Possible activity sources:

* assessment submitted
* assessment evaluated
* roadmap generated
* lesson generated
* challenge generated
* challenge submitted
* submission evaluated
* mastery updated
* lesson unlocked
* lesson completed

Limit to the most recent:

```text id="yq5zvz"
5
```

Each activity item should include:

* type
* title
* description optional
* timestamp
* related entity id optional

Do not create new activity events in this walker.

Only read existing events/records.

---

## Implement get_dashboard Walker

The walker should:

1. Receive learner_id, optional language, and optional roadmap_id

2. Validate learner exists

3. Resolve active roadmap if needed

4. Load assessment/evaluation state

5. Load roadmap structure

6. Load roadmap progress

7. Load lesson progress records

8. Load generated lessons

9. Load generated challenges

10. Load challenge submissions

11. Load submission evaluations

12. Load skill mastery records

13. Load recent progression/evaluation events if available

14. Build dashboard summaries

15. Determine dashboard state

16. Return DashboardView

The walker should aggregate only.

No graph mutation should happen inside this walker.

---

## Idempotency

Repeated calls to `get_dashboard` should return the same result if underlying graph state has not changed.

This walker should not create new records.

This walker should not update timestamps.

This walker should not call other mutating walkers.

---

## Empty States

The dashboard should return useful data even when the learner is early in the journey.

Examples:

### No assessment

```text id="s7z4k3"
dashboard_state = no_assessment
```

### Assessment completed but no roadmap

```text id="s4ww8i"
dashboard_state = roadmap_missing
```

### Roadmap exists but progression not initialized

```text id="inmzcx"
dashboard_state = roadmap_ready
```

### Fully completed roadmap

```text id="yl66gz"
dashboard_state = completed
```

Do not throw errors for normal incomplete states.

---

## Error Handling

Handle:

* missing learner
* unsupported language
* roadmap not found
* roadmap does not belong to learner
* malformed progress records
* malformed mastery records
* inconsistent challenge/submission state

Return structured errors for invalid references.

Normal incomplete journey states should return valid dashboard states.

Do not expose raw backend stack traces.

---

## Testing

Create tests for:

* learner with no assessment
* learner with assessment but no roadmap
* learner with roadmap but no progress
* learner with initialized progression
* learner with completed lessons
* learner with generated lessons
* learner with generated challenges
* learner with submitted challenges
* learner with evaluated submissions
* learner with mastery records
* strongest skills calculation
* weakest skills calculation
* current lesson resolution
* recent activity ordering
* completed roadmap state
* missing learner rejection
* invalid roadmap rejection
* unsupported language rejection

Tests should not require live AI providers.

This feature only reads persisted graph state.

---

## Frontend Contract

Create or update frontend DTOs for dashboard data.

The frontend should be able to consume:

* DashboardView
* DashboardLearnerSummary
* DashboardRoadmapSummary
* DashboardRoadmapProgress
* DashboardMasterySummary
* DashboardSkillSummary
* DashboardLessonSummary
* DashboardChallengeSummary
* DashboardCurrentLesson
* DashboardRecentActivity

Do not create dashboard UI in this feature.

That belongs to the next feature.

---

## Integration With Previous Features

This feature should work after:

1. learner registers/logs in
2. assessment is initialized
3. assessment is submitted
4. assessment is evaluated
5. roadmap is generated
6. lesson is generated
7. challenge is generated
8. challenge is submitted
9. submission is evaluated
10. mastery is updated
11. lesson progression is updated

But it should also return safe dashboard states if only some of these steps exist.

---

## Future Compatibility

This walker will feed:

* dashboard UI
* recommend_next_action
* AI tutor summary
* progress widgets
* learner home page
* completion page

Design output so the dashboard UI can render without making many extra walker calls.

The frontend should not need to separately call:

* get_skill_map
* unlock_next_lesson
* update_mastery
* evaluate_submission

just to display the dashboard.

---

## Explicitly Out of Scope

Do not implement:

* dashboard UI
* recommendations
* AI tutor summary
* mastery updates
* lesson unlocking
* roadmap generation
* lesson generation
* challenge generation
* submission evaluation
* certificates
* notifications

This feature only returns dashboard DTOs.

---

## Check When Done

* `get_dashboard` walker compiles
* Dashboard DTO returns for authenticated learner
* Dashboard state handles no assessment
* Dashboard state handles assessment without roadmap
* Dashboard state handles roadmap without progression
* Roadmap progress summary returns correctly
* Mastery summary returns correctly
* Strongest skills return correctly
* Weakest skills return correctly
* Lesson status summary returns correctly
* Challenge status summary returns correctly
* Current lesson resolves correctly
* Recent activity returns in correct order
* Empty/incomplete states do not crash
* Invalid roadmap is rejected
* Tests pass
* No graph mutation occurs
* No UI is rendered
* No recommendations are generated
