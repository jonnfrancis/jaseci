"""MockLLM coverage for initial assessment generation and persistence."""

import lib.ai.utilities as ai_utilities;
import from byllm.lib { MockLLM }
import from lib.ai.schemas {
    AssessmentDescriptionResult,
    AssessmentTitleResult,
    GeneratedOption,
    GeneratedQuestion,
    GeneratedQuestionDifficulty,
    GeneratedQuestionType
}
import from lib.ai.utilities { generate_initial_assessment }
import from nodes.assessment {
    Assessment,
    AssessmentOptionLink,
    AssessmentQuestion,
    AssessmentQuestionLink,
    AssessmentQuestionType,
    AssessmentStatus
}
import from nodes.learner { Learner }
import from walkers.initialize_assessment { initialize_assessment }

def _mock_questions() -> list[GeneratedQuestion] {
    return [
        GeneratedQuestion(
            question_text="Which Jac feature moves behavior through graph nodes?",
            question_type=GeneratedQuestionType.MULTIPLE_CHOICE,
            skill="Jac walkers",
            difficulty=GeneratedQuestionDifficulty.BEGINNER,
            options=[
                GeneratedOption(label="Walker", value="walker"),
                GeneratedOption(label="Theme token", value="theme_token")
            ]
        ),
        GeneratedQuestion(
            question_text="Briefly explain why a learner skill graph is useful.",
            question_type=GeneratedQuestionType.SHORT_ANSWER,
            skill="OSP graph modeling",
            difficulty=GeneratedQuestionDifficulty.INTERMEDIATE,
            options=[]
        )
    ];
}

test "assessment generation uses structured mock output" {
    ai_utilities.llm = MockLLM(
        model_name="mockllm",
        config={
            "outputs": [
                AssessmentTitleResult(title="Jaseci Readiness Check"),
                AssessmentDescriptionResult(description="A short check of Jac and OSP readiness."),
                _mock_questions()
            ]
        }
    );

    result = generate_initial_assessment(
        "Learn Jaseci for adaptive LMS features.",
        ["education technology"],
        "beginner",
        ["Jac walkers", "OSP graph modeling"],
        "Backend engineer",
        2
    );

    assert result.title == "Jaseci Readiness Check";
    assert len(result.questions) == 2;
    assert result.questions[0].question_type == GeneratedQuestionType.MULTIPLE_CHOICE;
    assert result.questions[1].options == [];
}

test "initialize assessment creates assessment entities" {
    learner = (root ++> Learner(
        id="feature05-creation",
        name="Feature Five Learner",
        createdAt="2026-06-25",
        updatedAt="2026-06-25"
    ))[0];
    ai_utilities.llm = MockLLM(
        model_name="mockllm",
        config={
            "outputs": [
                AssessmentTitleResult(title="GraphLearn Initial Assessment"),
                AssessmentDescriptionResult(description="Checks readiness for Jac graph learning."),
                _mock_questions()
            ]
        }
    );

    result = root spawn initialize_assessment(
        learner_id=learner.id,
        learner_goals="Build graph-native LMS workflows.",
        learner_interests=["adaptive learning"],
        learner_experience_level="beginner",
        target_skills=["Jac walkers", "OSP graph modeling"],
        target_role="Jaseci developer",
        assessment_length=2,
        created_at="2026-06-25T00:00:00Z"
    );

    assert len(result.reports) == 1;
    assessment = result.reports[0];
    assert assessment.learner_id == learner.id;
    assert assessment.status == AssessmentStatus.draft;
    assert assessment.title == "GraphLearn Initial Assessment";
    assert len(assessment.questions) == 2;
    assert assessment.questions[0].question_type == AssessmentQuestionType.multiple_choice;
    assert len(assessment.questions[0].options) == 2;
}

test "initialize assessment persists retrievable graph links" {
    root ++> Learner(
        id="feature05-persistence",
        name="Persistence Learner",
        createdAt="2026-06-25",
        updatedAt="2026-06-25"
    );
    ai_utilities.llm = MockLLM(
        model_name="mockllm",
        config={
            "outputs": [
                AssessmentTitleResult(title="Persistence Assessment"),
                AssessmentDescriptionResult(description="Persists questions and options."),
                _mock_questions()
            ]
        }
    );

    result = root spawn initialize_assessment(
        learner_id="feature05-persistence",
        learner_goals="Persist initial assessments.",
        learner_interests=[],
        learner_experience_level="beginner",
        target_skills=["Jac walkers", "OSP graph modeling"],
        target_role="Developer",
        assessment_length=2,
        created_at="2026-06-25T00:00:00Z"
    );
    created = result.reports[0];

    retrieved = [root -->[?:Assessment, id == created.id]];
    assert len(retrieved) == 1;
    questions = [retrieved[0] ->:AssessmentQuestionLink:->][?:AssessmentQuestion];
    assert len(questions) == 2;
    options = [questions[0] ->:AssessmentOptionLink:->];
    assert len(options) == 2;
    assert retrieved[0].questions[0].skill == "Jac walkers";
}

test "selected language assessment rotates repeat template" {
    learner_id = "feature05-rotation";
    root ++> Learner(
        id=learner_id,
        name="Rotation Learner",
        createdAt="2026-06-25",
        updatedAt="2026-06-25"
    );

    first = root spawn initialize_assessment(
        learner_id=learner_id,
        learner_goals="Assess Python readiness.",
        learner_interests=["Python"],
        learner_experience_level="beginner",
        target_skills=[],
        target_role="Python learner",
        assessment_length=3,
        created_at="2026-06-25T00:00:00Z",
        selected_language="Python"
    );
    second = root spawn initialize_assessment(
        learner_id=learner_id,
        learner_goals="Reassess Python readiness.",
        learner_interests=["Python"],
        learner_experience_level="beginner",
        target_skills=[],
        target_role="Python learner",
        assessment_length=3,
        created_at="2026-06-25T01:00:00Z",
        selected_language="Python"
    );

    assert len(first.reports) == 1;
    assert len(second.reports) == 1;
    assert first.reports[0].questions[0].question_text != second.reports[0].questions[0].question_text;
    assert second.reports[0].questions[0].skill == "Python Data Structures";
}
