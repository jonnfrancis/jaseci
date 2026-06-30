"""Coverage for learner mastery updates from persisted evaluation evidence."""

import from edges.domain_edges {
    evidenced_by,
    mastered,
    signals,
    targets
}
import from nodes.assessment {
    Assessment,
    AssessmentAttempt,
    AssessmentAttemptLink,
    AssessmentAttemptStatus,
    AssessmentEvaluation,
    AssessmentEvaluationLink,
    AssessmentScore,
    AssessmentStatus,
    SkillSignal
}
import from nodes.challenge {
    SubmissionEvaluation,
    SubmissionSkillSignal
}
import from nodes.learner { Learner }
import from nodes.mastery {
    MasteryEvidence,
    MasteryLevel,
    MasterySourceType,
    MasteryUpdateResult,
    SkillMastery
}
import from nodes.skill { Skill }
import from walkers.update_mastery { update_mastery }

def _unique_id(prefix: str) -> str {
    return f"{prefix}-{len([root -->][?:Learner]) + 1}";
}

def _seed_learner(learner_id: str) -> Learner {
    return (root ++> Learner(
        id=learner_id,
        name="Mastery Learner",
        createdAt="2026-06-30",
        updatedAt="2026-06-30"
    ))[0];
}

def _seed_skill(skill_id: str, category: str = "python") -> Skill {
    return (root ++> Skill(
        id=skill_id,
        name=skill_id,
        description="Seeded mastery skill.",
        category=category
    ))[0];
}

def _seed_assessment_evaluation(
    prefix: str,
    learner_id: str,
    signals_in: list[SkillSignal]
) -> AssessmentEvaluation {
    assessment_id = f"{prefix}-assessment";
    attempt_id = f"{prefix}-attempt";
    evaluation_id = f"{prefix}-assessment-evaluation";
    assessment = (root ++> Assessment(
        id=assessment_id,
        learner_id=learner_id,
        title="Mastery Assessment",
        description="Seeded assessment evaluation.",
        status=AssessmentStatus.active,
        created_at="2026-06-30T00:00:00Z"
    ))[0];
    attempt = (assessment +>:AssessmentAttemptLink:+> AssessmentAttempt(
        id=attempt_id,
        learner_id=learner_id,
        assessment_id=assessment_id,
        status=AssessmentAttemptStatus.submitted,
        submitted_at="2026-06-30T01:00:00Z",
        completed_at="2026-06-30T01:00:00Z"
    ))[0];
    return (attempt +>:AssessmentEvaluationLink:+> AssessmentEvaluation(
        id=evaluation_id,
        assessment_id=assessment_id,
        assessment_attempt_id=attempt_id,
        learner_id=learner_id,
        score=AssessmentScore(
            earned_points=1,
            possible_points=1,
            percentage=100
        ),
        evaluation_version="test",
        created_at="2026-06-30T02:00:00Z",
        skill_signals=signals_in
    ))[0];
}

def _seed_submission_evaluation(
    prefix: str,
    learner_id: str,
    signals_in: list[SubmissionSkillSignal]
) -> SubmissionEvaluation {
    evaluation = (root ++> SubmissionEvaluation(
        id=f"{prefix}-submission-evaluation",
        learner_id=learner_id,
        challenge_id=f"{prefix}-challenge",
        submission_id=f"{prefix}-submission",
        language="python",
        score=82,
        passed=True,
        feedback_summary="Seeded submission evaluation.",
        suggested_next_step="Keep practicing.",
        evaluation_version="test",
        evaluated_at="2026-06-30T03:00:00Z",
        created_at="2026-06-30T03:00:00Z",
        skill_signals=signals_in
    ))[0];
    for signal in signals_in {
        evaluation +>:signals:+> signal;
    }
    return evaluation;
}

def _find_mastery(learner_id: str, skill_id: str) -> SkillMastery | None {
    for mastery in [root -->][?:SkillMastery] {
        if mastery.learner_id == learner_id and mastery.skill_id == skill_id {
            return mastery;
        }
    }
    return None;
}

def _evidence_for_source(
    learner_id: str,
    source_type: MasterySourceType,
    source_id: str
) -> list[MasteryEvidence] {
    matches: list[MasteryEvidence] = [];
    for evidence in [root -->][?:MasteryEvidence] {
        if evidence.learner_id == learner_id and evidence.source_type == source_type and evidence.source_id == source_id {
            matches = matches + [evidence];
        }
    }
    return matches;
}

test "update mastery from assessment evaluation creates mastery and evidence" {
    prefix = _unique_id("mastery-assessment");
    learner_id = f"{prefix}-learner";
    _seed_learner(learner_id);
    _seed_skill("python_variables");
    evaluation = _seed_assessment_evaluation(
        prefix,
        learner_id,
        [SkillSignal(skill_id="python_variables", correct_count=2, incorrect_count=0, accuracy=1.0)]
    );

    result = root spawn update_mastery(
        learner_id=learner_id,
        source_type="assessment_evaluation",
        source_id=evaluation.id
    );

    assert len(result.errors) == 0;
    summary = result.reports[0];
    assert summary.learner_id == learner_id;
    assert summary.source_type == "assessment_evaluation";
    assert len(summary.updated_skills) == 1;
    assert summary.updated_skills[0].previous_score == 0;
    assert summary.updated_skills[0].new_score == 26;
    assert summary.updated_skills[0].mastery_level == "beginner";
    mastery = _find_mastery(learner_id, "python_variables") as SkillMastery;
    assert mastery.score == 26;
    assert mastery.evidence_count == 1;
    assert len(_evidence_for_source(learner_id, MasterySourceType.assessment_evaluation, evaluation.id)) == 1;
}

test "update mastery from submission evaluation uses stronger weighted evidence" {
    prefix = _unique_id("mastery-submission");
    learner_id = f"{prefix}-learner";
    _seed_learner(learner_id);
    _seed_skill("python_functions");
    evaluation = _seed_submission_evaluation(
        prefix,
        learner_id,
        [
            SubmissionSkillSignal(
                id=f"{prefix}-signal-1",
                evaluation_id=f"{prefix}-submission-evaluation",
                skill_id="python_functions",
                score=0.8,
                confidence=1.0,
                evidence="Implemented a function correctly.",
                order_index=1
            )
        ]
    );

    result = root spawn update_mastery(
        learner_id=learner_id,
        source_type="submission_evaluation",
        source_id=evaluation.id
    );

    assert len(result.errors) == 0;
    assert result.reports[0].updated_skills[0].new_score == 52;
    assert result.reports[0].updated_skills[0].mastery_level == "developing";
    mastery = _find_mastery(learner_id, "python_functions") as SkillMastery;
    assert mastery.last_source_type == "submission_evaluation";
}

test "update mastery updates existing mastery record" {
    prefix = _unique_id("mastery-existing");
    learner_id = f"{prefix}-learner";
    learner = _seed_learner(learner_id);
    skill = _seed_skill("python_loops");
    mastery = (root ++> SkillMastery(
        id=f"skill-mastery-{learner_id}-python_loops",
        learner_id=learner_id,
        skill_id="python_loops",
        score=40,
        level=MasteryLevel.developing,
        evidence_count=1,
        last_source_type="assessment_evaluation",
        last_source_id="prior-source",
        updated_at="2026-06-29T00:00:00Z",
        created_at="2026-06-29T00:00:00Z"
    ))[0];
    learner +>:mastered:+> mastery;
    mastery +>:targets:+> skill;
    evaluation = _seed_submission_evaluation(
        prefix,
        learner_id,
        [
            SubmissionSkillSignal(
                id=f"{prefix}-signal-1",
                evaluation_id=f"{prefix}-submission-evaluation",
                skill_id="python_loops",
                score=0.8,
                confidence=1.0,
                evidence="Used a loop correctly.",
                order_index=1
            )
        ]
    );

    result = root spawn update_mastery(
        learner_id=learner_id,
        source_type="submission_evaluation",
        source_id=evaluation.id
    );

    assert len(result.errors) == 0;
    updated = result.reports[0].updated_skills[0];
    assert updated.previous_score == 40;
    assert updated.new_score == 66;
    assert updated.delta == 26;
    assert updated.evidence_count == 2;
    stored = _find_mastery(learner_id, "python_loops") as SkillMastery;
    assert stored.score == 66;
}

test "update mastery clamps final score and assigns mastered level" {
    prefix = _unique_id("mastery-clamp");
    learner_id = f"{prefix}-learner";
    learner = _seed_learner(learner_id);
    skill = _seed_skill("python_oop");
    mastery = (root ++> SkillMastery(
        id=f"skill-mastery-{learner_id}-python_oop",
        learner_id=learner_id,
        skill_id="python_oop",
        score=150,
        level=MasteryLevel.mastered,
        evidence_count=1,
        last_source_type="submission_evaluation",
        last_source_id="prior-source",
        updated_at="2026-06-29T00:00:00Z",
        created_at="2026-06-29T00:00:00Z"
    ))[0];
    learner +>:mastered:+> mastery;
    mastery +>:targets:+> skill;
    evaluation = _seed_submission_evaluation(
        prefix,
        learner_id,
        [
            SubmissionSkillSignal(
                id=f"{prefix}-signal-1",
                evaluation_id=f"{prefix}-submission-evaluation",
                skill_id="python_oop",
                score=1.0,
                confidence=1.0,
                evidence="Perfect object-oriented solution.",
                order_index=1
            )
        ]
    );

    result = root spawn update_mastery(
        learner_id=learner_id,
        source_type="submission_evaluation",
        source_id=evaluation.id
    );

    assert len(result.errors) == 0;
    assert result.reports[0].updated_skills[0].previous_score == 100;
    assert result.reports[0].updated_skills[0].new_score == 100;
    assert result.reports[0].updated_skills[0].mastery_level == "mastered";
}

test "update mastery applies confidence weighted updates" {
    prefix = _unique_id("mastery-confidence");
    learner_id = f"{prefix}-learner";
    _seed_learner(learner_id);
    _seed_skill("python_lists");
    evaluation = _seed_submission_evaluation(
        prefix,
        learner_id,
        [
            SubmissionSkillSignal(
                id=f"{prefix}-signal-1",
                evaluation_id=f"{prefix}-submission-evaluation",
                skill_id="python_lists",
                score=1.0,
                confidence=0.5,
                evidence="Partially confident list evidence.",
                order_index=1
            )
        ]
    );

    result = root spawn update_mastery(
        learner_id=learner_id,
        source_type="submission_evaluation",
        source_id=evaluation.id
    );

    assert len(result.errors) == 0;
    assert result.reports[0].updated_skills[0].new_score == 33;
}

test "update mastery handles multiple skill signals" {
    prefix = _unique_id("mastery-multiple");
    learner_id = f"{prefix}-learner";
    _seed_learner(learner_id);
    _seed_skill("python_variables");
    _seed_skill("python_strings");
    evaluation = _seed_assessment_evaluation(
        prefix,
        learner_id,
        [
            SkillSignal(skill_id="python_variables", correct_count=1, incorrect_count=0, accuracy=1.0),
            SkillSignal(skill_id="python_strings", correct_count=0, incorrect_count=1, accuracy=0.0)
        ]
    );

    result = root spawn update_mastery(
        learner_id=learner_id,
        source_type="assessment_evaluation",
        source_id=evaluation.id
    );

    assert len(result.errors) == 0;
    assert len(result.reports[0].updated_skills) == 2;
    assert len(_evidence_for_source(learner_id, MasterySourceType.assessment_evaluation, evaluation.id)) == 2;
}

test "update mastery is idempotent for duplicate source" {
    prefix = _unique_id("mastery-idempotent");
    learner_id = f"{prefix}-learner";
    _seed_learner(learner_id);
    _seed_skill("python_sets");
    evaluation = _seed_submission_evaluation(
        prefix,
        learner_id,
        [
            SubmissionSkillSignal(
                id=f"{prefix}-signal-1",
                evaluation_id=f"{prefix}-submission-evaluation",
                skill_id="python_sets",
                score=0.8,
                confidence=1.0,
                evidence="Used set operations.",
                order_index=1
            )
        ]
    );

    first = root spawn update_mastery(
        learner_id=learner_id,
        source_type="submission_evaluation",
        source_id=evaluation.id
    );
    second = root spawn update_mastery(
        learner_id=learner_id,
        source_type="submission_evaluation",
        source_id=evaluation.id
    );

    assert len(first.errors) == 0;
    assert len(second.errors) == 0;
    assert first.reports[0].updated_at == second.reports[0].updated_at;
    mastery = _find_mastery(learner_id, "python_sets") as SkillMastery;
    assert mastery.evidence_count == 1;
    assert len(_evidence_for_source(learner_id, MasterySourceType.submission_evaluation, evaluation.id)) == 1;
}

test "update mastery rejects missing learner" {
    result = root spawn update_mastery(
        learner_id="missing-mastery-learner",
        source_type="assessment_evaluation",
        source_id="missing-source"
    );

    assert len(result.reports) == 0;
    assert result.errors[0].code == "missing_learner";
}

test "update mastery rejects missing evaluation" {
    prefix = _unique_id("mastery-missing-eval");
    learner_id = f"{prefix}-learner";
    _seed_learner(learner_id);

    result = root spawn update_mastery(
        learner_id=learner_id,
        source_type="assessment_evaluation",
        source_id="missing-assessment-evaluation"
    );

    assert len(result.reports) == 0;
    assert result.errors[0].code == "missing_assessment_evaluation";
}

test "update mastery rejects unsupported source type" {
    prefix = _unique_id("mastery-unsupported");
    learner_id = f"{prefix}-learner";
    _seed_learner(learner_id);

    result = root spawn update_mastery(
        learner_id=learner_id,
        source_type="lesson_complete",
        source_id="some-source"
    );

    assert len(result.reports) == 0;
    assert result.errors[0].code == "unsupported_source_type";
}

test "update mastery rejects invalid signal score" {
    prefix = _unique_id("mastery-invalid-score");
    learner_id = f"{prefix}-learner";
    _seed_learner(learner_id);
    _seed_skill("python_invalid");
    evaluation = _seed_assessment_evaluation(
        prefix,
        learner_id,
        [SkillSignal(skill_id="python_invalid", correct_count=1, incorrect_count=0, accuracy=1.2)]
    );

    result = root spawn update_mastery(
        learner_id=learner_id,
        source_type="assessment_evaluation",
        source_id=evaluation.id
    );

    assert len(result.reports) == 0;
    assert result.errors[0].code == "invalid_signal_score";
}

test "update mastery rejects invalid confidence" {
    prefix = _unique_id("mastery-invalid-confidence");
    learner_id = f"{prefix}-learner";
    _seed_learner(learner_id);
    _seed_skill("python_confidence");
    evaluation = _seed_submission_evaluation(
        prefix,
        learner_id,
        [
            SubmissionSkillSignal(
                id=f"{prefix}-signal-1",
                evaluation_id=f"{prefix}-submission-evaluation",
                skill_id="python_confidence",
                score=0.8,
                confidence=1.5,
                evidence="Invalid confidence.",
                order_index=1
            )
        ]
    );

    result = root spawn update_mastery(
        learner_id=learner_id,
        source_type="submission_evaluation",
        source_id=evaluation.id
    );

    assert len(result.reports) == 0;
    assert result.errors[0].code == "invalid_confidence";
}

test "update mastery rejects missing referenced skill" {
    prefix = _unique_id("mastery-missing-skill");
    learner_id = f"{prefix}-learner";
    _seed_learner(learner_id);
    evaluation = _seed_assessment_evaluation(
        prefix,
        learner_id,
        [SkillSignal(skill_id="missing_skill_for_mastery", correct_count=1, incorrect_count=0, accuracy=0.5)]
    );

    result = root spawn update_mastery(
        learner_id=learner_id,
        source_type="assessment_evaluation",
        source_id=evaluation.id
    );

    assert len(result.reports) == 0;
    assert result.errors[0].code == "missing_skill";
}
