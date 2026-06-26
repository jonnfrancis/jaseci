"""Assessment evaluation tests."""

import from nodes.assessment {
    Assessment,
    AssessmentAttempt,
    AssessmentAttemptLink,
    AssessmentAttemptResponseLink,
    AssessmentAttemptStatus,
    AssessmentDifficulty,
    AssessmentEvaluation,
    AssessmentEvaluationLink,
    AssessmentQuestion,
    AssessmentQuestionLink,
    AssessmentQuestionType,
    AssessmentResponse,
    AssessmentStatus
}
import from nodes.learner { Learner }
import from walkers.evaluate_assessment {
    evaluate_assessment,
    get_assessment_evaluation
}

def _unique_id(prefix: str) -> str {
    return f"{prefix}-{len([root -->][?:Assessment]) + 1}";
}

def _seed_evaluation_assessment(learner_id: str, assessment_id: str) -> Assessment {
    root ++> Learner(
        id=learner_id,
        name="Evaluate Assessment Learner",
        createdAt="2026-06-26",
        updatedAt="2026-06-26"
    );
    assessment = (root ++> Assessment(
        id=assessment_id,
        learner_id=learner_id,
        title="Evaluate Assessment",
        description="Assessment used for evaluation tests.",
        status=AssessmentStatus.active,
        created_at="2026-06-26T00:00:00Z",
        short_answer_strategy="normalized_text_match"
    ))[0];

    q1 = (assessment +>:AssessmentQuestionLink:+> AssessmentQuestion(
        id=f"{assessment_id}-q1",
        question_text="Which concept moves behavior through graph nodes?",
        question_type=AssessmentQuestionType.multiple_choice,
        skill="jac_walkers",
        difficulty=AssessmentDifficulty.beginner,
        answer_key=["walker"],
        possible_points=1
    ))[0];
    q2 = (assessment +>:AssessmentQuestionLink:+> AssessmentQuestion(
        id=f"{assessment_id}-q2",
        question_text="Select the persistence concepts.",
        question_type=AssessmentQuestionType.multi_select,
        skill="graph_modeling",
        difficulty=AssessmentDifficulty.intermediate,
        skill_ids=["graph_modeling", "durability"],
        answer_key=["node", "edge"],
        possible_points=2
    ))[0];
    q3 = (assessment +>:AssessmentQuestionLink:+> AssessmentQuestion(
        id=f"{assessment_id}-q3",
        question_text="Name the Jac graph traversal construct.",
        question_type=AssessmentQuestionType.short_answer,
        skill="jac_walkers",
        difficulty=AssessmentDifficulty.beginner,
        answer_key=["Walker"],
        possible_points=1
    ))[0];
    assessment.questions = [q1, q2, q3];
    return assessment;
}

def _seed_attempt(
    assessment: Assessment,
    learner_id: str,
    attempt_id: str,
    answers: list[str]
) -> AssessmentAttempt {
    attempt = (assessment +>:AssessmentAttemptLink:+> AssessmentAttempt(
        id=attempt_id,
        learner_id=learner_id,
        assessment_id=assessment.id,
        status=AssessmentAttemptStatus.submitted,
        submitted_at="2026-06-26T10:00:00Z",
        completed_at="2026-06-26T10:00:00Z"
    ))[0];
    question_index = 0;
    for question in assessment.questions {
        response_id = f"{attempt_id}-response-{question_index + 1}";
        attempt +>:AssessmentAttemptResponseLink:+> AssessmentResponse(
            id=response_id,
            question_id=question.id,
            answer_value=answers[question_index],
            response_type=question.question_type
        );
        question_index += 1;
    }
    return attempt;
}

test "evaluate assessment scores all correct attempt" {
    assessment_id = _unique_id("eval-all-correct-assessment");
    learner_id = f"{assessment_id}-learner";
    attempt_id = f"{assessment_id}-attempt";
    assessment = _seed_evaluation_assessment(learner_id, assessment_id);
    attempt = _seed_attempt(
        assessment,
        learner_id,
        attempt_id,
        ["walker", "edge,node", " walker "]
    );

    result = root spawn evaluate_assessment(
        assessment_id=assessment.id,
        assessment_attempt_id=attempt.id,
        evaluated_at="2026-06-26T11:00:00Z"
    );

    assert len(result.errors) == 0;
    evaluation = result.reports[0];
    assert evaluation.score.earned_points == 4;
    assert evaluation.score.possible_points == 4;
    assert evaluation.score.percentage == 100;
    assert len(evaluation.question_results) == 3;
    assert evaluation.question_results[0].correct;
    assert evaluation.question_results[1].correct;
    assert evaluation.question_results[2].correct;
    assert len(evaluation.skill_signals) == 3;
    evaluation_ids: list[str] = [];
    for persisted_evaluation in [attempt ->:AssessmentEvaluationLink:->][?:AssessmentEvaluation] {
        if persisted_evaluation.id not in evaluation_ids {
            evaluation_ids = evaluation_ids + [persisted_evaluation.id];
        }
    }
    assert len(evaluation_ids) == 1;
}

test "evaluate assessment scores all incorrect attempt" {
    assessment_id = _unique_id("eval-all-wrong-assessment");
    learner_id = f"{assessment_id}-learner";
    attempt_id = f"{assessment_id}-attempt";
    assessment = _seed_evaluation_assessment(learner_id, assessment_id);
    attempt = _seed_attempt(
        assessment,
        learner_id,
        attempt_id,
        ["node", "node", "graph"]
    );

    result = root spawn evaluate_assessment(
        assessment_id=assessment.id,
        assessment_attempt_id=attempt.id,
        evaluated_at="2026-06-26T11:00:00Z"
    );

    assert len(result.errors) == 0;
    evaluation = result.reports[0];
    assert evaluation.score.earned_points == 0;
    assert evaluation.score.possible_points == 4;
    assert evaluation.score.percentage == 0;
    assert not evaluation.question_results[0].correct;
    assert not evaluation.question_results[1].correct;
    assert not evaluation.question_results[2].correct;
}

test "evaluate assessment aggregates mixed skill signals" {
    assessment_id = _unique_id("eval-mixed-assessment");
    learner_id = f"{assessment_id}-learner";
    attempt_id = f"{assessment_id}-attempt";
    assessment = _seed_evaluation_assessment(learner_id, assessment_id);
    attempt = _seed_attempt(
        assessment,
        learner_id,
        attempt_id,
        ["walker", "node", "runner"]
    );

    result = root spawn evaluate_assessment(
        assessment_id=assessment.id,
        assessment_attempt_id=attempt.id,
        evaluated_at="2026-06-26T11:00:00Z"
    );

    assert len(result.errors) == 0;
    evaluation = result.reports[0];
    assert evaluation.score.earned_points == 1;
    assert evaluation.score.possible_points == 4;
    assert evaluation.score.percentage == 25;
    assert evaluation.skill_signals[0].skill_id == "jac_walkers";
    assert evaluation.skill_signals[0].correct_count == 1;
    assert evaluation.skill_signals[0].incorrect_count == 1;
    assert evaluation.skill_signals[1].skill_id == "graph_modeling";
    assert evaluation.skill_signals[1].incorrect_count == 1;
    assert evaluation.skill_signals[2].skill_id == "durability";
    assert evaluation.skill_signals[2].incorrect_count == 1;
}

test "evaluate assessment returns existing evaluation on repeated attempt" {
    assessment_id = _unique_id("eval-idempotent-assessment");
    learner_id = f"{assessment_id}-learner";
    attempt_id = f"{assessment_id}-attempt";
    assessment = _seed_evaluation_assessment(learner_id, assessment_id);
    attempt = _seed_attempt(
        assessment,
        learner_id,
        attempt_id,
        ["walker", "node,edge", "Walker"]
    );

    first_result = root spawn evaluate_assessment(
        assessment_id=assessment.id,
        assessment_attempt_id=attempt.id,
        evaluated_at="2026-06-26T11:00:00Z"
    );
    second_result = root spawn evaluate_assessment(
        assessment_id=assessment.id,
        assessment_attempt_id=attempt.id,
        evaluated_at="2026-06-26T12:00:00Z"
    );

    assert len(first_result.errors) == 0;
    assert len(second_result.errors) == 0;
    assert first_result.reports[0].id == second_result.reports[0].id;
    assert second_result.reports[0].created_at == "2026-06-26T11:00:00Z";
    evaluation_ids: list[str] = [];
    for evaluation in [attempt ->:AssessmentEvaluationLink:->][?:AssessmentEvaluation] {
        if evaluation.id not in evaluation_ids {
            evaluation_ids = evaluation_ids + [evaluation.id];
        }
        assert evaluation.id == first_result.reports[0].id;
        assert evaluation.created_at == "2026-06-26T11:00:00Z";
    }
    assert len(evaluation_ids) == 1;
    assert get_assessment_evaluation(attempt.id) is not None;
}

test "evaluate assessment rejects invalid assessment" {
    result = root spawn evaluate_assessment(
        assessment_id="missing-evaluation-assessment",
        assessment_attempt_id="missing-evaluation-attempt",
        evaluated_at="2026-06-26T11:00:00Z"
    );

    assert len(result.reports) == 0;
    assert result.errors[0].code == "missing_assessment";
}
