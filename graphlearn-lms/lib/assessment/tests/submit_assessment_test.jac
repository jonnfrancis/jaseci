"""Assessment submission persistence tests."""

import from nodes.assessment {
    Assessment,
    AssessmentAttempt,
    AssessmentAttemptLink,
    AssessmentAttemptResponseLink,
    AssessmentAttemptStatus,
    AssessmentDifficulty,
    AssessmentOption,
    AssessmentOptionLink,
    AssessmentQuestion,
    AssessmentQuestionLink,
    AssessmentQuestionType,
    AssessmentResponse,
    AssessmentResponseQuestionLink,
    AssessmentStatus,
    LearnerAssessmentAttemptLink
}
import from nodes.learner { Learner }
import from walkers.submit_assessment {
    AssessmentResponseInput,
    get_assessment_attempts,
    get_attempt,
    get_attempt_responses,
    get_learner_attempts,
    submit_assessment
}

def _unique_id(prefix: str) -> str {
    return f"{prefix}-{len([root -->][?:Assessment]) + 1}";
}

def _seed_assessment(learner_id: str, assessment_id: str) -> Assessment {
    root ++> Learner(
        id=learner_id,
        name="Submit Assessment Learner",
        createdAt="2026-06-26",
        updatedAt="2026-06-26"
    );
    assessment = (root ++> Assessment(
        id=assessment_id,
        learner_id=learner_id,
        title="Submit Assessment",
        description="Assessment used for submission persistence tests.",
        status=AssessmentStatus.active,
        created_at="2026-06-26T00:00:00Z"
    ))[0];
    mc_question = (assessment +>:AssessmentQuestionLink:+> AssessmentQuestion(
        id=f"{assessment_id}-q1",
        question_text="Which Jac concept moves behavior through graph nodes?",
        question_type=AssessmentQuestionType.multiple_choice,
        skill="Jac walkers",
        difficulty=AssessmentDifficulty.beginner
    ))[0];
    mc_option = (mc_question +>:AssessmentOptionLink:+> AssessmentOption(
        id=f"{mc_question.id}-o1",
        label="Walker",
        value="walker"
    ))[0];
    mc_question.options.append(mc_option);

    short_question = (assessment +>:AssessmentQuestionLink:+> AssessmentQuestion(
        id=f"{assessment_id}-q2",
        question_text="Briefly explain why graph persistence matters.",
        question_type=AssessmentQuestionType.short_answer,
        skill="OSP graph modeling",
        difficulty=AssessmentDifficulty.intermediate
    ))[0];
    assessment.questions.append(mc_question);
    assessment.questions.append(short_question);
    return assessment;
}

test "submit assessment creates attempt responses and graph links" {
    assessment_id = _unique_id("submit-success-assessment");
    learner_id = f"{assessment_id}-learner";
    assessment = _seed_assessment(learner_id, assessment_id);

    result = root spawn submit_assessment(
        learner_id=learner_id,
        assessment_id=assessment.id,
        submitted_at="2026-06-26T10:00:00Z",
        responses=[
            AssessmentResponseInput(
                question_id=f"{assessment.id}-q1",
                answer_value=f"{assessment.id}-q1-o1",
                response_type=AssessmentQuestionType.multiple_choice
            ),
            AssessmentResponseInput(
                question_id=f"{assessment.id}-q2",
                answer_value="Graph persistence keeps learner state durable.",
                response_type=AssessmentQuestionType.short_answer
            )
        ]
    );

    assert len(result.errors) == 0;
    assert len(result.reports) == 1;
    attempt = result.reports[0];
    assert attempt.status == AssessmentAttemptStatus.submitted;
    assert attempt.submitted_at == "2026-06-26T10:00:00Z";
    assert attempt.completed_at == "2026-06-26T10:00:00Z";

    retrieved_attempt = get_attempt(attempt.id);
    assert retrieved_attempt is not None;
    responses = get_attempt_responses(attempt.id);
    assert len(responses) == 2;
    assert responses[0].question_id == f"{assessment.id}-q1";
    assert responses[0].answer_value == f"{assessment.id}-q1-o1";
    assert len([attempt ->:AssessmentAttemptResponseLink:->][?:AssessmentResponse]) == 2;
    assert len([responses[0] ->:AssessmentResponseQuestionLink:->][?:AssessmentQuestion]) == 1;
    assert len([assessment ->:AssessmentAttemptLink:->][?:AssessmentAttempt]) == 1;
    learner = [root -->][?:Learner, id == learner_id][0];
    assert len([learner ->:LearnerAssessmentAttemptLink:->][?:AssessmentAttempt]) == 1;
    assert len(get_learner_attempts(learner_id)) == 1;
    assert len(get_assessment_attempts(assessment.id)) == 1;
}

test "submit assessment rejects invalid assessment" {
    assessment_id = _unique_id("submit-invalid-assessment");
    learner_id = f"{assessment_id}-learner";
    root ++> Learner(
        id=learner_id,
        name="Invalid Assessment Learner",
        createdAt="2026-06-26",
        updatedAt="2026-06-26"
    );

    result = root spawn submit_assessment(
        learner_id=learner_id,
        assessment_id="missing-assessment",
        submitted_at="2026-06-26T10:00:00Z",
        responses=[]
    );

    assert len(result.reports) == 0;
    assert result.errors[0].code == "invalid_assessment";
}

test "submit assessment rejects invalid learner" {
    assessment_id = _unique_id("submit-invalid-learner-assessment");
    assessment = _seed_assessment(f"{assessment_id}-owner", assessment_id);

    result = root spawn submit_assessment(
        learner_id="missing-learner",
        assessment_id=assessment.id,
        submitted_at="2026-06-26T10:00:00Z",
        responses=[]
    );

    assert len(result.reports) == 0;
    assert result.errors[0].code == "invalid_learner";
}

test "submit assessment rejects invalid question references" {
    assessment_id = _unique_id("submit-invalid-question-assessment");
    learner_id = f"{assessment_id}-learner";
    assessment = _seed_assessment(learner_id, assessment_id);

    result = root spawn submit_assessment(
        learner_id=learner_id,
        assessment_id=assessment.id,
        submitted_at="2026-06-26T10:00:00Z",
        responses=[
            AssessmentResponseInput(
                question_id="not-on-assessment",
                answer_value="walker",
                response_type=AssessmentQuestionType.multiple_choice
            )
        ]
    );

    assert len(result.reports) == 0;
    assert len([assessment ->:AssessmentAttemptLink:->][?:AssessmentAttempt]) == 0;
    assert result.errors[0].code == "invalid_question";
}
