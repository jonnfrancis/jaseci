"""MockLLM coverage for personalized roadmap generation."""

import lib.ai.utilities as ai_utilities;
import from byllm.lib { MockLLM }
import from edges.domain_edges { assigned, contains, requires, targets }
import from lib.ai.schemas {
    GeneratedRoadmapLesson,
    GeneratedRoadmapMilestone,
    GeneratedRoadmapWeek,
    RoadmapGenerationResult
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
import from nodes.learner { Learner }
import from nodes.roadmap {
    Roadmap,
    RoadmapLesson,
    RoadmapLessonGenerationStatus,
    RoadmapMilestone,
    RoadmapWeek
}
import from nodes.skill { Skill }
import from services.assessment_journey { generate_roadmap_for_journey }
import from services.roadmap { load_roadmap }
import from walkers.generate_roadmap {
    generate_roadmap,
    get_existing_active_roadmap,
    get_roadmap
}

def _unique_id(prefix: str) -> str {
    return f"{prefix}-{len([root -->][?:Assessment]) + 1}";
}

def _seed_evaluated_attempt(
    prefix: str,
    score_percentage: int,
    signals: list[SkillSignal]
) -> AssessmentEvaluation {
    learner_id = f"{prefix}-learner";
    assessment_id = f"{prefix}-assessment";
    attempt_id = f"{prefix}-attempt";
    root ++> Learner(
        id=learner_id,
        name="Roadmap Learner",
        createdAt="2026-06-27",
        updatedAt="2026-06-27"
    );
    assessment = (root ++> Assessment(
        id=assessment_id,
        learner_id=learner_id,
        title="Roadmap Assessment",
        description="Assessment used for roadmap generation tests.",
        status=AssessmentStatus.active,
        created_at="2026-06-27T00:00:00Z"
    ))[0];
    attempt = (assessment +>:AssessmentAttemptLink:+> AssessmentAttempt(
        id=attempt_id,
        learner_id=learner_id,
        assessment_id=assessment_id,
        status=AssessmentAttemptStatus.submitted,
        submitted_at="2026-06-27T10:00:00Z",
        completed_at="2026-06-27T10:00:00Z"
    ))[0];
    return (attempt +>:AssessmentEvaluationLink:+> AssessmentEvaluation(
        id=f"{prefix}-evaluation",
        assessment_id=assessment_id,
        assessment_attempt_id=attempt_id,
        learner_id=learner_id,
        score=AssessmentScore(
            earned_points=score_percentage,
            possible_points=100,
            percentage=score_percentage
        ),
        evaluation_version="test",
        created_at="2026-06-27T11:00:00Z",
        skill_signals=signals
    ))[0];
}

def _python_beginner_result() -> RoadmapGenerationResult {
    return RoadmapGenerationResult(
        title="Personalized Python Foundations Roadmap",
        description="A fundamentals-first Python outline guided by weak beginner signals.",
        estimated_weeks=2,
        target_level="beginner foundations",
        weeks=[
            GeneratedRoadmapWeek(
                week_number=1,
                title="Python Basics",
                summary="Build confidence with syntax and variables.",
                lessons=[
                    GeneratedRoadmapLesson(
                        title="Variables and Data Types",
                        summary="Practice naming values and choosing basic data types.",
                        target_skill_ids=["python_variables"],
                        difficulty="beginner",
                        estimated_minutes=25,
                        order_index=1
                    ),
                    GeneratedRoadmapLesson(
                        title="Control Flow Foundations",
                        summary="Use conditionals and loops to guide program behavior.",
                        target_skill_ids=["python_control_flow"],
                        difficulty="beginner",
                        estimated_minutes=30,
                        order_index=2
                    )
                ],
                milestones=[
                    GeneratedRoadmapMilestone(
                        title="Basics Practice Check",
                        description="Explain and apply variables, types, and simple branches.",
                        required_skill_ids=["python_variables", "python_control_flow"]
                    )
                ]
            )
        ]
    );
}

def _jac_intermediate_result() -> RoadmapGenerationResult {
    return RoadmapGenerationResult(
        title="Applied Jac OSP Roadmap",
        description="A Jac roadmap that starts near graph traversal and adaptive workflows.",
        estimated_weeks=3,
        target_level="advanced practical mastery",
        weeks=[
            GeneratedRoadmapWeek(
                week_number=1,
                title="Graph-Native Jac",
                summary="Move quickly into nodes, edges, and walkers.",
                lessons=[
                    GeneratedRoadmapLesson(
                        title="Walkers and Traversal",
                        summary="Shape behavior that moves across graph nodes.",
                        target_skill_ids=["jac_walkers", "graph_traversal"],
                        difficulty="intermediate",
                        estimated_minutes=35,
                        order_index=1
                    )
                ],
                milestones=[
                    GeneratedRoadmapMilestone(
                        title="Traversal Design Check",
                        description="Design a small traversal plan using walkers and graph state.",
                        required_skill_ids=["jac_walkers"]
                    )
                ]
            )
        ]
    );
}

test "generate roadmap creates python roadmap from weak beginner result" {
    prefix = _unique_id("roadmap-python-weak");
    evaluation = _seed_evaluated_attempt(
        prefix,
        25,
        [
            SkillSignal(skill_id="python_variables", correct_count=0, incorrect_count=2, accuracy=0.0),
            SkillSignal(skill_id="python_control_flow", correct_count=1, incorrect_count=2, accuracy=0.33)
        ]
    );
    ai_utilities.llm = MockLLM(model_name="mockllm", config={"outputs": [_python_beginner_result()]});

    result = root spawn generate_roadmap(
        learner_id=evaluation.learner_id,
        assessment_id=evaluation.assessment_id,
        assessment_attempt_id=evaluation.assessment_attempt_id,
        assessment_evaluation_id=evaluation.id,
        language="python"
    );

    assert len(result.errors) == 0;
    roadmap = result.reports[0];
    assert roadmap.language == "python";
    assert roadmap.estimated_weeks == 2;
    assert len(roadmap.weeks) == 1;
    assert len(roadmap.lessons) == 2;
    assert roadmap.lessons[0].generation_status == RoadmapLessonGenerationStatus.pending;
    assert roadmap.lessons[0].target_skill_ids == ["python_variables"];
    assert get_roadmap(roadmap.id) is not None;
}

test "generate roadmap creates jac roadmap from stronger intermediate result" {
    prefix = _unique_id("roadmap-jac-strong");
    evaluation = _seed_evaluated_attempt(
        prefix,
        82,
        [
            SkillSignal(skill_id="jac_syntax_basics", correct_count=3, incorrect_count=0, accuracy=1.0),
            SkillSignal(skill_id="jac_walkers", correct_count=2, incorrect_count=1, accuracy=0.67)
        ]
    );
    ai_utilities.llm = MockLLM(model_name="mockllm", config={"outputs": [_jac_intermediate_result()]});

    result = root spawn generate_roadmap(
        learner_id=evaluation.learner_id,
        assessment_id=evaluation.assessment_id,
        assessment_attempt_id=evaluation.assessment_attempt_id,
        assessment_evaluation_id=evaluation.id,
        language="jac"
    );

    assert len(result.errors) == 0;
    roadmap = result.reports[0];
    assert roadmap.title == "Applied Jac OSP Roadmap";
    assert roadmap.lessons[0].difficulty == "intermediate";
    assert "graph_traversal" in roadmap.lessons[0].target_skill_ids;
}

test "generate roadmap persists weeks lessons milestones and skill edges" {
    prefix = _unique_id("roadmap-persistence");
    evaluation = _seed_evaluated_attempt(
        prefix,
        40,
        [SkillSignal(skill_id="python_variables", correct_count=1, incorrect_count=1, accuracy=0.5)]
    );
    ai_utilities.llm = MockLLM(model_name="mockllm", config={"outputs": [_python_beginner_result()]});

    result = root spawn generate_roadmap(
        learner_id=evaluation.learner_id,
        assessment_id=evaluation.assessment_id,
        assessment_attempt_id=evaluation.assessment_attempt_id,
        assessment_evaluation_id=evaluation.id,
        language="python"
    );

    roadmap = result.reports[0];
    learner = [root -->][?:Learner, id == evaluation.learner_id][0];
    assert len([learner ->:assigned:->][?:Roadmap]) == 1;
    weeks = [roadmap ->:contains:->][?:RoadmapWeek];
    assert len(weeks) == 1;
    lessons = [weeks[0] ->:contains:->][?:RoadmapLesson];
    milestones = [weeks[0] ->:contains:->][?:RoadmapMilestone];
    assert len(lessons) == 2;
    assert len(milestones) == 1;
    assert len([lessons[0] ->:targets:->][?:Skill]) == 1;
    assert len([milestones[0] ->:requires:->][?:Skill]) == 2;
}

test "generate roadmap prevents duplicate active roadmap" {
    prefix = _unique_id("roadmap-duplicate");
    evaluation = _seed_evaluated_attempt(
        prefix,
        60,
        [SkillSignal(skill_id="python_functions", correct_count=1, incorrect_count=1, accuracy=0.5)]
    );
    ai_utilities.llm = MockLLM(model_name="mockllm", config={"outputs": [_python_beginner_result()]});

    first = root spawn generate_roadmap(
        learner_id=evaluation.learner_id,
        assessment_id=evaluation.assessment_id,
        assessment_attempt_id=evaluation.assessment_attempt_id,
        assessment_evaluation_id=evaluation.id,
        language="python"
    );
    second = root spawn generate_roadmap(
        learner_id=evaluation.learner_id,
        assessment_id=evaluation.assessment_id,
        assessment_attempt_id=evaluation.assessment_attempt_id,
        assessment_evaluation_id=evaluation.id,
        language="python"
    );

    assert len(first.errors) == 0;
    assert len(second.errors) == 0;
    assert first.reports[0].id == second.reports[0].id;
    assert get_existing_active_roadmap(
        evaluation.learner_id,
        "python",
        evaluation.assessment_id,
        evaluation.assessment_attempt_id,
        evaluation.id
    ) is not None;
    matching: list[Roadmap] = [];
    for roadmap in [root -->][?:Roadmap] {
        if roadmap.assessment_evaluation_id == evaluation.id {
            matching = matching + [roadmap];
        }
    }
    assert len(matching) == 1;
}

test "assessment journey service generates roadmap id for results handoff" {
    prefix = _unique_id("roadmap-journey-handoff");
    evaluation = _seed_evaluated_attempt(
        prefix,
        55,
        [SkillSignal(skill_id="python_functions", correct_count=1, incorrect_count=1, accuracy=0.5)]
    );
    ai_utilities.llm = MockLLM(model_name="mockllm", config={"outputs": [_python_beginner_result()]});

    state = generate_roadmap_for_journey(
        evaluation.learner_id,
        evaluation.assessment_id,
        evaluation.assessment_attempt_id,
        evaluation.id,
        "python"
    );
    repeated = generate_roadmap_for_journey(
        evaluation.learner_id,
        evaluation.assessment_id,
        evaluation.assessment_attempt_id,
        evaluation.id,
        "python"
    );

    assert state.status == "results";
    assert state.roadmap_id != "";
    assert state.roadmap_id == repeated.roadmap_id;
    assert load_roadmap(state.roadmap_id).status == "ready";
}

test "assessment journey derives roadmap track from persisted assessment" {
    prefix = _unique_id("roadmap-track-handoff");
    evaluation = _seed_evaluated_attempt(
        prefix,
        55,
        [SkillSignal(skill_id="python_functions", correct_count=1, incorrect_count=1, accuracy=0.5)]
    );
    assessments = [root -->][?:Assessment, id == evaluation.assessment_id];
    assessment = assessments[0];
    assessment.title = "Python readiness assessment";
    assessment.track_id = "trk_builtin_python";
    assessment.track_version_id = "trv_builtin_python_v1";
    ai_utilities.llm = MockLLM(model_name="mockllm", config={"outputs": [_python_beginner_result()]});

    state = generate_roadmap_for_journey(
        evaluation.learner_id,
        evaluation.assessment_id,
        evaluation.assessment_attempt_id,
        evaluation.id,
        ""
    );

    assert state.roadmap_id != "";
    roadmaps = [root -->][?:Roadmap, id == state.roadmap_id];
    assert roadmaps[0].track_id == "trk_builtin_python";
    assert roadmaps[0].track_version_id == "trv_builtin_python_v1";
}

test "generate roadmap rejects unsupported language" {
    prefix = _unique_id("roadmap-invalid-language");
    evaluation = _seed_evaluated_attempt(
        prefix,
        50,
        [SkillSignal(skill_id="python_variables", correct_count=1, incorrect_count=1, accuracy=0.5)]
    );

    result = root spawn generate_roadmap(
        learner_id=evaluation.learner_id,
        assessment_id=evaluation.assessment_id,
        assessment_attempt_id=evaluation.assessment_attempt_id,
        assessment_evaluation_id=evaluation.id,
        language="typescript"
    );

    assert len(result.reports) == 0;
    assert result.errors[0].code == "unsupported_language";
}
