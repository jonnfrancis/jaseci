"""MockLLM coverage for reusable AI schemas and utilities."""

import lib.ai.utilities as ai_utilities;
import from byllm.lib { MockLLM }
import from lib.ai.schemas {
    ExtractedSkill,
    LearningRecommendation,
    LearningSummary,
    RecommendationPriority,
    SkillAnalysis,
    SkillConfidence
}
import from lib.ai.utilities {
    AIErrorKind,
    extract_skill_analysis,
    generate_learning_recommendation,
    standard_ai_error_policy,
    summarize_learner_goal
}
import from byllm.lib { OutputConversionError, RateLimitError }

test "skill analysis uses structured mock output" {
    expected = SkillAnalysis(
        learner_level="developing",
        strengths=[
            ExtractedSkill(
                name="Python functions",
                category="language fundamentals",
                evidence="The learner described writing reusable functions.",
                confidence=SkillConfidence.HIGH
            )
        ],
        gaps=[
            ExtractedSkill(
                name="Jac walkers",
                category="Jac OSP",
                evidence="The learner asked for help understanding traversal.",
                confidence=SkillConfidence.MEDIUM
            )
        ],
        next_focus=["Jac walkers", "OSP graph traversal"],
        summary="The learner has programming foundations and should focus on Jac traversal concepts."
    );
    ai_utilities.llm = MockLLM(model_name="mockllm", config={"outputs": [expected]});

    result = extract_skill_analysis(
        "I can write Python functions but I am confused by Jac walkers.",
        "Jaseci"
    );

    assert result.learner_level == "developing";
    assert result.strengths[0].confidence == SkillConfidence.HIGH;
    assert result.gaps[0].name == "Jac walkers";
}

test "learner summary uses structured mock output" {
    expected = LearningSummary(
        goal="Learn Jaseci well enough to build adaptive LMS features.",
        current_context="The learner has backend experience and is new to OSP.",
        constraints=["Needs practical examples", "Prefers incremental practice"],
        success_criteria=["Can explain walkers", "Can model skills as graph nodes"],
        summary="The learner wants practical Jaseci mastery for LMS development."
    );
    ai_utilities.llm = MockLLM(model_name="mockllm", config={"outputs": [expected]});

    result = summarize_learner_goal(
        "I know backend development and want to learn Jaseci for an LMS."
    );

    assert result.goal == expected.goal;
    assert len(result.success_criteria) == 2;
}

test "learning recommendation uses structured mock output" {
    learner_summary = LearningSummary(
        goal="Learn Jaseci OSP.",
        current_context="Comfortable with Python and new to graph traversal.",
        constraints=[],
        success_criteria=["Build a small walker-driven feature"],
        summary="The learner needs OSP practice."
    );
    skill_analysis = SkillAnalysis(
        learner_level="developing",
        strengths=[],
        gaps=[],
        next_focus=["Jac walkers"],
        summary="Focus on walker traversal."
    );
    expected = LearningRecommendation(
        title="Practice Walker Traversal",
        recommendation="Work through a small graph traversal exercise before adding LMS workflows.",
        reason="Walker traversal is the learner's next stated gap.",
        suggested_next_action="Create a learner node and report connected skill nodes.",
        priority=RecommendationPriority.HIGH,
        related_skills=["Jac walkers", "OSP graph traversal"]
    );
    ai_utilities.llm = MockLLM(model_name="mockllm", config={"outputs": [expected]});

    result = generate_learning_recommendation(learner_summary, skill_analysis);

    assert result.priority == RecommendationPriority.HIGH;
    assert "Walker" in result.title;
}

test "standard ai error policy classifies retryable byllm errors" {
    rate_limit_policy = standard_ai_error_policy(RateLimitError("limited"));
    output_policy = standard_ai_error_policy(OutputConversionError("bad output"));

    assert rate_limit_policy.kind == AIErrorKind.RATE_LIMIT;
    assert rate_limit_policy.retryable;
    assert output_policy.kind == AIErrorKind.OUTPUT_CONVERSION;
    assert output_policy.retryable;
}
