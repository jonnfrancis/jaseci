"""MockLLM coverage for on-demand lesson generation."""

import lib.ai.utilities as ai_utilities;
import from byllm.lib { MockLLM }
import from edges.domain_edges { assigned, contains, targets }
import from lib.ai.schemas {
    GeneratedLessonExample,
    GeneratedLessonMiniExercise,
    GeneratedLessonSection,
    GeneratedLessonTakeaway,
    LessonGenerationResult
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
import from nodes.lesson {
    GeneratedLesson,
    LessonExample,
    LessonMiniExercise,
    LessonSection,
    LessonTakeaway
}
import from nodes.roadmap {
    Roadmap,
    RoadmapLesson,
    RoadmapLessonGenerationStatus,
    RoadmapStatus,
    RoadmapWeek
}
import from nodes.skill { Skill }
import from walkers.generate_lesson { generate_lesson, get_generated_lesson }

def _unique_id(prefix: str) -> str {
    return f"{prefix}-{len([root -->][?:Learner]) + 1}";
}

def _python_lesson_result() -> LessonGenerationResult {
    return LessonGenerationResult(
        sections=[
            GeneratedLessonSection(
                title="Why variables matter",
                content="Variables give names to values so a Python program can reuse them clearly."
            ),
            GeneratedLessonSection(
                title="Common mistake",
                content="Beginners often confuse the variable name with the value it refers to."
            )
        ],
        examples=[
            GeneratedLessonExample(
                title="Creating variables",
                code="name = 'Ada'\nage = 20",
                explanation="This stores two values behind clear names."
            )
        ],
        mini_exercises=[
            GeneratedLessonMiniExercise(
                prompt="Create a variable called score and assign it the value 100.",
                expected_concept="variable assignment"
            )
        ],
        key_takeaways=[
            GeneratedLessonTakeaway(content="Variables store references to values."),
            GeneratedLessonTakeaway(content="Python infers basic data types from assigned values.")
        ]
    );
}

def _jac_lesson_result() -> LessonGenerationResult {
    return LessonGenerationResult(
        sections=[
            GeneratedLessonSection(
                title="Walkers move through graph state",
                content="A Jac walker carries behavior across nodes and lets graph structure guide the program."
            )
        ],
        examples=[
            GeneratedLessonExample(
                title="Visiting connected nodes",
                code="walker FindItems {\n    can start with Root entry {\n        visit [-->];\n    }\n}",
                explanation="The walker starts at root and visits outgoing graph nodes."
            )
        ],
        mini_exercises=[
            GeneratedLessonMiniExercise(
                prompt="Describe when a walker should visit connected nodes instead of reading a list directly.",
                expected_concept="graph traversal"
            )
        ],
        key_takeaways=[
            GeneratedLessonTakeaway(content="Walkers express graph-native behavior in Jac.")
        ]
    );
}

def _seed_context(
    prefix: str,
    language: str,
    difficulty: str,
    skill_id: str,
    score_percentage: int
) -> RoadmapLesson {
    learner_id = f"{prefix}-learner";
    assessment_id = f"{prefix}-assessment";
    attempt_id = f"{prefix}-attempt";
    evaluation_id = f"{prefix}-evaluation";
    roadmap_id = f"{prefix}-roadmap";
    week_id = f"{roadmap_id}-week-1";
    lesson_id = f"{week_id}-lesson-1";

    learner = (root ++> Learner(
        id=learner_id,
        name="Lesson Learner",
        createdAt="2026-06-29",
        updatedAt="2026-06-29"
    ))[0];
    assessment = (root ++> Assessment(
        id=assessment_id,
        learner_id=learner_id,
        title="Lesson Assessment",
        description="Assessment used for lesson generation tests.",
        status=AssessmentStatus.active,
        created_at="2026-06-29T00:00:00Z"
    ))[0];
    attempt = (assessment +>:AssessmentAttemptLink:+> AssessmentAttempt(
        id=attempt_id,
        learner_id=learner_id,
        assessment_id=assessment_id,
        status=AssessmentAttemptStatus.submitted,
        submitted_at="2026-06-29T10:00:00Z",
        completed_at="2026-06-29T10:00:00Z"
    ))[0];
    attempt +>:AssessmentEvaluationLink:+> AssessmentEvaluation(
        id=evaluation_id,
        assessment_id=assessment_id,
        assessment_attempt_id=attempt_id,
        learner_id=learner_id,
        score=AssessmentScore(
            earned_points=score_percentage,
            possible_points=100,
            percentage=score_percentage
        ),
        evaluation_version="test",
        created_at="2026-06-29T11:00:00Z",
        skill_signals=[
            SkillSignal(skill_id=skill_id, correct_count=1, incorrect_count=1, accuracy=0.5)
        ]
    );
    roadmap = (root ++> Roadmap(
        id=roadmap_id,
        learner_id=learner_id,
        language=language,
        title="Generated Lesson Test Roadmap",
        description="A seeded roadmap for lesson generation tests.",
        estimated_weeks=1,
        status=RoadmapStatus.active,
        created_at="2026-06-29T12:00:00Z",
        assessment_id=assessment_id,
        assessment_attempt_id=attempt_id,
        assessment_evaluation_id=evaluation_id
    ))[0];
    learner +>:assigned:+> roadmap;

    week = (roadmap +>:contains:+> RoadmapWeek(
        id=week_id,
        roadmap_id=roadmap_id,
        week_number=1,
        title="Week One",
        summary="Seeded week."
    ))[0];
    roadmap.weeks.append(week);

    lesson = (week +>:contains:+> RoadmapLesson(
        id=lesson_id,
        roadmap_id=roadmap_id,
        week_id=week_id,
        title="Variables and Data Types" if language == "python" else "Walkers and Traversal",
        summary="Learn the core lesson concept from the roadmap outline.",
        target_skill_ids=[skill_id],
        difficulty=difficulty,
        estimated_minutes=12,
        order_index=1,
        generation_status=RoadmapLessonGenerationStatus.pending
    ))[0];
    week.lessons.append(lesson);
    roadmap.lessons.append(lesson);

    skill = (root ++> Skill(
        id=skill_id,
        name=skill_id,
        description="Seeded target skill.",
        category=language
    ))[0];
    lesson +>:targets:+> skill;
    return lesson;
}

test "generate lesson creates python beginner lesson content" {
    prefix = _unique_id("lesson-python");
    lesson = _seed_context(prefix, "python", "beginner", "python_variables", 35);
    ai_utilities.llm = MockLLM(model_name="mockllm", config={"outputs": [_python_lesson_result()]});

    result = root spawn generate_lesson(
        learner_id=f"{prefix}-learner",
        roadmap_id=f"{prefix}-roadmap",
        roadmap_lesson_id=lesson.id,
        language="python"
    );

    assert len(result.errors) == 0;
    view = result.reports[0];
    assert view.language == "python";
    assert view.difficulty == "beginner";
    assert view.title == "Variables and Data Types";
    assert len(view.sections) == 2;
    assert len(view.examples) == 1;
    assert view.examples[0].code == "name = 'Ada'\nage = 20";
    assert len(view.mini_exercises) == 1;
    assert len(view.key_takeaways) == 2;
}

test "generate lesson creates jac intermediate lesson content" {
    prefix = _unique_id("lesson-jac");
    lesson = _seed_context(prefix, "jac", "intermediate", "jac_walkers", 70);
    ai_utilities.llm = MockLLM(model_name="mockllm", config={"outputs": [_jac_lesson_result()]});

    result = root spawn generate_lesson(
        learner_id=f"{prefix}-learner",
        roadmap_id=f"{prefix}-roadmap",
        roadmap_lesson_id=lesson.id,
        language="jac"
    );

    assert len(result.errors) == 0;
    view = result.reports[0];
    assert view.language == "jac";
    assert view.difficulty == "intermediate";
    assert "walker" in view.examples[0].code;
    assert view.key_takeaways[0].content == "Walkers express graph-native behavior in Jac.";
}

test "generate lesson persists relationships and updates roadmap lesson status" {
    prefix = _unique_id("lesson-persistence");
    lesson = _seed_context(prefix, "python", "beginner", "python_variables", 45);
    ai_utilities.llm = MockLLM(model_name="mockllm", config={"outputs": [_python_lesson_result()]});

    result = root spawn generate_lesson(
        learner_id=f"{prefix}-learner",
        roadmap_id=f"{prefix}-roadmap",
        roadmap_lesson_id=lesson.id,
        language="python"
    );

    assert len(result.errors) == 0;
    generated = get_generated_lesson(f"{prefix}-learner", lesson.id);
    assert generated is not None;
    stored = generated as GeneratedLesson;
    assert lesson.generation_status == RoadmapLessonGenerationStatus.generated;
    assert len([stored ->:contains:->][?:LessonSection]) == 2;
    assert len([stored ->:contains:->][?:LessonExample]) == 1;
    assert len([stored ->:contains:->][?:LessonMiniExercise]) == 1;
    assert len([stored ->:contains:->][?:LessonTakeaway]) == 2;
    assert len([stored ->:targets:->][?:Skill]) == 1;
}

test "generate lesson reuses existing generated lesson" {
    prefix = _unique_id("lesson-reuse");
    lesson = _seed_context(prefix, "python", "beginner", "python_variables", 50);
    ai_utilities.llm = MockLLM(model_name="mockllm", config={"outputs": [_python_lesson_result()]});

    first = root spawn generate_lesson(
        learner_id=f"{prefix}-learner",
        roadmap_id=f"{prefix}-roadmap",
        roadmap_lesson_id=lesson.id,
        language="python"
    );
    second = root spawn generate_lesson(
        learner_id=f"{prefix}-learner",
        roadmap_id=f"{prefix}-roadmap",
        roadmap_lesson_id=lesson.id,
        language="python"
    );

    assert len(first.errors) == 0;
    assert len(second.errors) == 0;
    assert first.reports[0].id == second.reports[0].id;

    matches: list[GeneratedLesson] = [];
    for generated in [root -->][?:GeneratedLesson] {
        if generated.roadmap_lesson_id == lesson.id and generated.learner_id == f"{prefix}-learner" {
            matches = matches + [generated];
        }
    }
    assert len(matches) == 1;
}

test "generate lesson rejects unsupported language" {
    prefix = _unique_id("lesson-invalid-language");
    lesson = _seed_context(prefix, "python", "beginner", "python_variables", 50);

    result = root spawn generate_lesson(
        learner_id=f"{prefix}-learner",
        roadmap_id=f"{prefix}-roadmap",
        roadmap_lesson_id=lesson.id,
        language="typescript"
    );

    assert len(result.reports) == 0;
    assert result.errors[0].code == "unsupported_language";
}

test "generate lesson rejects invalid roadmap lesson" {
    prefix = _unique_id("lesson-invalid-outline");
    lesson = _seed_context(prefix, "python", "beginner", "python_variables", 50);
    lesson.target_skill_ids = [];

    result = root spawn generate_lesson(
        learner_id=f"{prefix}-learner",
        roadmap_id=f"{prefix}-roadmap",
        roadmap_lesson_id=lesson.id,
        language="python"
    );

    assert len(result.reports) == 0;
    assert result.errors[0].code == "invalid_target_skills";
}
