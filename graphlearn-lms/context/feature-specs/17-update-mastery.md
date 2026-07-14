Read `AGENTS.md`, and `context/architecture-context.md` before starting.

# 17-update-mastery.md

We're implementing the mastery engine.

Walker:

`update_mastery`

This walker updates learner mastery values using evidence from completed assessments and evaluated coding challenges.

The assessment subsystem produces assessment skill signals.

The submission evaluation subsystem produces challenge skill signals.

This feature consumes those signals and updates the learner's mastery graph.

Do not unlock lessons.

Do not update roadmap progression.

Do not generate recommendations.

Do not regenerate challenges.

Do not create dashboard UI.

---

## Goal

Update learner mastery for skills based on structured evidence.

The mastery graph should answer:

* Which skills is the learner weak in?
* Which skills is the learner developing?
* Which skills is the learner proficient in?
* Which skills is the learner close to mastering?
* Which skills has the learner demonstrated through assessment or practice?

Mastery should be evidence-based, not based only on whether the learner clicked “complete”.

---

## Required Inputs

The walker should accept:

* learner_id
* source_type
* source_id

Supported `source_type` values:

```text
assessment_evaluation
submission_evaluation
```

For `assessment_evaluation`, `source_id` should reference an assessment evaluation record.

For `submission_evaluation`, `source_id` should reference a submission evaluation record.

The walker should load:

* learner
* source evaluation
* skill signals from the evaluation
* existing mastery records for affected skills
* related assessment/challenge metadata if needed

Do not accept raw scores directly from the frontend.

Do not accept unvalidated skill signals directly from the frontend.

Use persisted evaluation records as the source of truth.

---

## Required Outputs

The walker should return a mastery update summary.

The output should include:

* learner id
* source type
* source id
* updated skills
* previous mastery score
* new mastery score
* delta
* mastery level
* evidence count
* updated timestamp

Example shape:

```json
{
  "learner_id": "learner_001",
  "source_type": "submission_evaluation",
  "source_id": "submission_eval_001",
  "updated_skills": [
    {
      "skill_id": "python_variables",
      "previous_score": 42,
      "new_score": 58,
      "delta": 16,
      "mastery_level": "developing",
      "evidence_count": 3
    }
  ]
}
```

---

## Mastery Domain Models

Create or update:

* SkillMastery
* MasteryEvidence
* MasteryUpdateResult

SkillMastery should support:

* id
* learner_id
* skill_id
* score
* level
* evidence_count
* last_source_type
* last_source_id
* updated_at
* created_at

Score range:

```text
0-100
```

Mastery level values:

```text
beginner
developing
proficient
mastered
```

Suggested thresholds:

```text
0-39 beginner
40-69 developing
70-89 proficient
90-100 mastered
```

MasteryEvidence should support:

* id
* learner_id
* skill_id
* source_type
* source_id
* signal_score
* confidence
* weighted_score
* evidence_summary
* created_at

Do not add unlock state to mastery records.

Do not add roadmap progress fields to mastery records.

---

## Evidence Sources

The mastery engine should support two evidence sources.

### Assessment Evidence

Use skill signals from `AssessmentEvaluation`.

Assessment evidence represents initial diagnostic ability.

Assessment evidence should influence mastery, but should usually have lower weight than successful hands-on coding evidence.

Suggested default weight:

```text
assessment_evaluation = 0.35
```

---

### Challenge Evidence

Use skill signals from `SubmissionEvaluation`.

Challenge evidence represents practical application.

Challenge evidence should usually carry more weight than assessment evidence.

Suggested default weight:

```text
submission_evaluation = 0.65
```

Do not hardcode these weights in multiple files.

Centralize them in a mastery config or constants module.

---

## Mastery Calculation Rules

Convert skill signal values into 0-100 mastery scores.

Expected signal format:

```text
0.0-1.0
```

Converted score:

```text
signal_score * 100
```

Update mastery using weighted blending.

Suggested formula:

```text
new_score = (previous_score * previous_weight + signal_score_100 * evidence_weight) / (previous_weight + evidence_weight)
```

Alternative acceptable formula:

```text
new_score = previous_score + ((signal_score_100 - previous_score) * evidence_weight)
```

Choose one formula and document it clearly in code comments.

The calculation must be deterministic.

The same inputs must produce the same mastery update.

Clamp final score to:

```text
0-100
```

---

## Confidence Handling

If skill signals include confidence:

* higher confidence should have stronger influence
* lower confidence should have weaker influence

Suggested effective weight:

```text
effective_weight = source_weight * confidence
```

If confidence is missing, default to:

```text
0.75
```

Do not allow missing confidence to break updates.

---

## Implement update_mastery Walker

The walker should:

1. Receive learner_id, source_type, and source_id

2. Validate learner exists

3. Validate supported source_type

4. Load source evaluation

5. Validate evaluation belongs to learner

6. Extract skill signals

7. Reject update if no skill signals exist

8. For each skill signal:

   * validate skill exists
   * load existing SkillMastery if present
   * create SkillMastery if missing
   * calculate weighted mastery update
   * create MasteryEvidence record
   * update SkillMastery score
   * update SkillMastery level
   * update evidence count
   * update last source metadata

9. Return mastery update summary

The walker should orchestrate only.

Keep mastery calculation logic in reusable helper functions or abilities.

Do not put complex scoring formulas directly in UI code.

---

## Graph Relationships

Persist relationships between:

Learner → SkillMastery

SkillMastery → Skill

Learner → MasteryEvidence

MasteryEvidence → Skill

MasteryEvidence → AssessmentEvaluation

MasteryEvidence → SubmissionEvaluation

Use existing graph edge patterns where possible.

Suggested relationships:

* mastered
* evidenced_by
* signals
* targets

Do not create lesson unlock edges.

Do not create roadmap progress edges.

---

## Idempotency

Mastery updates must not double-count the same evaluation.

If `update_mastery` is called twice with the same:

```text
learner_id + source_type + source_id
```

the second call should not apply the same signal again.

Choose one strategy:

1. Return existing mastery update summary if evidence already exists.
2. Recalculate mastery from all evidence records for affected skills.

Preferred for this feature:

```text
Do not double-count. Return existing evidence/update result for the same source.
```

This prevents repeated button clicks or page refreshes from inflating mastery.

---

## Mastery Level Rules

Use score thresholds to assign level.

Suggested mapping:

```text
0-39 beginner
40-69 developing
70-89 proficient
90-100 mastered
```

The level should always be derived from score.

Do not let level and score drift.

Do not manually set level without recalculating it from score.

---

## Persistence Requirements

The mastery update must persist successfully.

SkillMastery records must persist successfully.

MasteryEvidence records must persist successfully.

Relationships must persist successfully.

The updated mastery state must be retrievable after update.

Do not store raw AI output.

Only store structured evaluation signals and derived mastery values.

---

## Error Handling

Handle:

* missing learner
* unsupported source type
* missing assessment evaluation
* missing submission evaluation
* evaluation does not belong to learner
* evaluation has no skill signals
* referenced skill does not exist
* invalid signal score
* invalid confidence value
* persistence failure
* duplicate update source

Return structured errors.

Do not silently ignore invalid skill signals unless explicitly documented.

---

## Testing

Create tests for:

* mastery update from assessment evaluation
* mastery update from submission evaluation
* new mastery record creation
* existing mastery record update
* score clamping to 0-100
* mastery level assignment
* confidence-weighted updates
* multiple skill signals
* duplicate source idempotency
* missing learner rejection
* missing evaluation rejection
* unsupported source type rejection
* invalid skill signal rejection

Tests should not require live AI providers.

This feature consumes persisted evaluation records only.

MockLLM should not be needed unless existing test fixtures depend on byLLM outputs.

---

## Frontend Contract

Create or update frontend DTOs for mastery update results.

The frontend should be able to consume:

* MasteryUpdateSummary
* UpdatedSkillMastery
* SkillMasteryView
* MasteryEvidenceView

Do not create mastery UI in this feature.

Do not create dashboard UI in this feature.

Do not create skill map UI in this feature.

---

## Integration With Previous Features

This feature should work after:

1. assessment is evaluated
2. assessment skill signals exist
3. challenge submission is evaluated
4. submission skill signals exist

Expected future flow:

```text
evaluate_assessment
→ update_mastery

evaluate_submission
→ update_mastery
```

For this feature, it is acceptable to call `update_mastery` manually after evaluation during testing.

Do not automatically unlock lessons after mastery update.

---

## Future Compatibility

This mastery engine will feed future features:

* get_skill_map
* unlock_next_lesson
* get_dashboard
* recommend_next_action
* adaptive challenge retry logic
* progress visualization

Design mastery data so future walkers can answer:

* which skills are weak
* which skills improved
* which skills are mastered
* which lessons are eligible to unlock
* which topic should be recommended next

Do not implement those features now.

---

## Explicitly Out of Scope

Do not implement:

* unlock_next_lesson
* roadmap progress updates
* dashboard aggregation
* skill map UI
* recommendations
* challenge regeneration
* lesson generation
* AI tutor feedback
* certificates

This feature only updates the learner mastery graph.

---

## Check When Done

* `update_mastery` walker compiles
* Assessment evaluation signals update mastery
* Submission evaluation signals update mastery
* SkillMastery records are created when missing
* Existing SkillMastery records update correctly
* MasteryEvidence records are created
* Duplicate update sources are not double-counted
* Scores remain within 0-100
* Mastery levels derive from score
* Updated mastery values persist to the graph
* Updated mastery can be retrieved after update
* Tests pass
* No lesson unlock logic exists
* No roadmap progress update exists
* No dashboard UI exists
