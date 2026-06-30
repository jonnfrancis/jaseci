Read `AGENTS.md`,  `context/architecture-context.md`, and `context/ui-context.md` before starting.

# 18-get-skill-map.md

We're implementing the skill map retrieval subsystem.

Walker:

`get_skill_map`

This walker returns the learner's skill graph with mastery overlays.

The mastery engine has already created and updated learner mastery records. This feature exposes that graph data so the frontend can later visualize learner strengths, weak areas, prerequisites, and learning progress.

Do not update mastery.

Do not unlock lessons.

Do not generate recommendations.

Do not create skill map UI.

Do not create dashboard UI.

---

## Goal

Return a structured skill map for a learner.

The skill map should show:

* skills
* prerequisite relationships
* mastery scores
* mastery levels
* weak skills
* strong skills
* roadmap skill coverage
* lesson relationships where available

This walker should provide the data needed for the future visual skill map UI.

---

## Required Inputs

The walker should accept:

* learner_id
* language
* roadmap_id optional

Supported language values:

* python
* jac

If `roadmap_id` is provided, return the skill map for that roadmap.

If `roadmap_id` is not provided, return the learner's active roadmap skill map for the selected language.

Do not accept raw mastery values from the frontend.

Use persisted graph data only.

---

## Required Outputs

The walker should return a skill map view.

The output should include:

* learner id
* language
* roadmap id if available
* skills
* edges
* summary
* generated timestamp

Example shape:

```json
{
  "learner_id": "learner_001",
  "language": "python",
  "roadmap_id": "roadmap_001",
  "summary": {
    "total_skills": 8,
    "mastered_count": 2,
    "proficient_count": 3,
    "developing_count": 2,
    "beginner_count": 1,
    "average_mastery": 68
  },
  "skills": [
    {
      "skill_id": "python_variables",
      "name": "Variables",
      "description": "Store and reuse values in Python.",
      "category": "Python Basics",
      "mastery_score": 82,
      "mastery_level": "proficient",
      "status": "in_progress",
      "evidence_count": 4
    }
  ],
  "edges": [
    {
      "from_skill_id": "python_variables",
      "to_skill_id": "python_functions",
      "type": "prerequisite"
    }
  ]
}
```

---

## Skill Map Domain Models

Create or update frontend/backend view objects as needed.

Suggested output objects:

* SkillMapView
* SkillMapSummary
* SkillMapSkill
* SkillMapEdge

SkillMapView should support:

* learner_id
* language
* roadmap_id
* summary
* skills
* edges
* generated_at

SkillMapSummary should support:

* total_skills
* mastered_count
* proficient_count
* developing_count
* beginner_count
* average_mastery

SkillMapSkill should support:

* skill_id
* name
* description
* category
* mastery_score
* mastery_level
* status
* evidence_count
* target_lesson_ids

SkillMapEdge should support:

* from_skill_id
* to_skill_id
* type

Supported edge types:

* prerequisite
* teaches
* reinforces

Do not create persistent duplicate skill map nodes.

The skill map is a view built from existing graph data.

---

## Skill Status Rules

Skill status should be derived from mastery and roadmap context.

Supported status values:

* locked
* available
* in_progress
* mastered

For this feature, keep status simple.

Suggested mapping:

```text
mastery_score >= 90 → mastered
mastery_score >= 40 → in_progress
mastery_score < 40 → available
no mastery record → available
```

Do not implement lesson unlock logic.

Do not block access based on status yet.

Status is informational only in this feature.

---

## Mastery Level Rules

Use the same mastery levels from `update_mastery`.

Expected levels:

```text
beginner
developing
proficient
mastered
```

The level should come from existing `SkillMastery` records when available.

If no mastery record exists, default to:

```text
beginner
```

with score:

```text
0
```

---

## Implement get_skill_map Walker

The walker should:

1. Receive learner_id, language, and optional roadmap_id

2. Validate learner exists

3. Validate supported language

4. Resolve active roadmap if roadmap_id is not provided

5. Load roadmap skills if roadmap exists

6. Load learner SkillMastery records

7. Load prerequisite relationships between skills

8. Load lesson-to-skill relationships where available

9. Merge skill definitions with mastery values

10. Calculate summary counts

11. Return SkillMapView

The walker should read and aggregate graph data only.

Do not mutate graph state.

---

## Graph Data Sources

Use existing graph relationships where possible.

Read from:

* Learner
* Skill
* SkillMastery
* MasteryEvidence
* Roadmap
* RoadmapLesson
* GeneratedLesson
* GeneratedChallenge

Relevant relationships may include:

* mastered
* evidenced_by
* prerequisite
* teaches
* reinforces
* targets
* assigned
* contains

Do not create new relationships unless absolutely required.

This feature should primarily query existing graph structure.

---

## Summary Calculation

Calculate:

* total skills
* mastered count
* proficient count
* developing count
* beginner count
* average mastery

Average mastery should be based on skills included in the map.

If there are no skills, average mastery should be:

```text
0
```

Do not crash on empty skill maps.

---

## Roadmap Filtering

If roadmap_id is provided:

* include only skills targeted by that roadmap

If roadmap_id is not provided:

* include skills from the active roadmap for the selected language

If no active roadmap exists:

* return an empty skill map with a clear summary

Do not generate a roadmap in this walker.

Do not call `generate_roadmap`.

---

## Error Handling

Handle:

* missing learner
* unsupported language
* roadmap not found
* roadmap does not belong to learner
* malformed skill relationships
* missing mastery records
* empty skill graph

Return structured errors where appropriate.

Missing mastery records should not be treated as fatal.

Default missing mastery to score `0`.

---

## Testing

Create tests for:

* skill map with no mastery records
* skill map with assessment mastery
* skill map with challenge mastery
* mastered skill count
* proficient skill count
* developing skill count
* beginner skill count
* average mastery calculation
* prerequisite edge retrieval
* roadmap filtering
* missing roadmap rejection
* unsupported language rejection
* empty skill map behavior

Tests should not require live AI providers.

This feature only reads persisted graph state.

---

## Frontend Contract

Create or update frontend DTOs for skill map data.

The frontend should be able to consume:

* SkillMapView
* SkillMapSummary
* SkillMapSkill
* SkillMapEdge

Do not create skill map visualization UI in this feature.

That belongs to the next feature.

---

## Future Compatibility

This walker will feed:

* skill map UI
* dashboard summary
* recommend_next_action
* unlock_next_lesson
* progress visualization

Design output so the frontend can render graph-style progress later.

Each skill should include enough information for UI state:

* label
* mastery score
* mastery level
* status
* category
* connected skills

Do not implement visualization now.

---

## Explicitly Out of Scope

Do not implement:

* skill map UI
* dashboard UI
* mastery updates
* lesson unlocking
* roadmap generation
* recommendations
* AI tutor
* challenge regeneration
* certificates

This feature only retrieves and formats the learner skill map.

---

## Check When Done

* `get_skill_map` walker compiles
* Skill map returns learner skills
* Skill map includes mastery scores
* Skill map includes mastery levels
* Skill map includes prerequisite edges
* Skill map includes roadmap-filtered skills
* Summary counts calculate correctly
* Missing mastery records default to score 0
* Empty skill map returns safely
* Tests pass
* No mastery update occurs
* No lesson unlock occurs
* No UI visualization is created
