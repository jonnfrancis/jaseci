"""MockLLM coverage for on-demand challenge generation."""

import lib.ai.utilities as ai_utilities;
import from byllm.lib { MockLLM }
import from edges.domain_edges { assigned, contains, evaluates, targets }
import from lib.ai.schemas {
    ChallengeGenerationResult,
    GeneratedChallengeConstraint,
    GeneratedChallengeEvaluationCriterion,
    GeneratedChallengeExpectedOutcome,
    GeneratedChallengeHint,
    GeneratedChallengeInstruction
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
    ChallengeConstraint,
    ChallengeEvaluationCriterion,
    ChallengeExpectedOutcome,
    ChallengeHint,
    ChallengeInstruction,
    GeneratedChallenge
}
import from nodes.learner { Learner }
import from nodes.lesson {
    GeneratedLesson,
    LessonExample,
    LessonGenerationStatus,
    LessonMiniExercise,
    LessonSection
}
import from nodes.roadmap {
    Roadmap,
    RoadmapLesson,
    RoadmapLessonGenerationStatus,
    RoadmapStatus,
    RoadmapWeek
}
import from nodes.skill { Skill }
import from walkers.generate_challenge { generate_challenge, get_generated_challenge }

def _unique_id(prefix: str) -> str {
    return f"{prefix}-{len([root -->][?:Learner]) + 1}";
}

def _python_challenge_result(difficulty: str) -> ChallengeGenerationResult {
    return ChallengeGenerationResult(
        title="Practice Variables and Data Types",
        prompt="Create variables for a learner profile and print a formatted summary.",
        difficulty=difficulty,
        starter_code="# Write your code here\n",
        instructions=[
            GeneratedChallengeInstruction(content="Create a variable called name."),
            GeneratedChallengeInstruction(content="Create variables called age and score."),
            GeneratedChallengeInstruction(content="Print a sentence that uses all three variables.")
        ],
        expected_outcomes=[
            GeneratedChallengeExpectedOutcome(content="Learner creates valid Python variables."),
            GeneratedChallengeExpectedOutcome(content="Learner uses the variables in formatted output.")
        ],
        constraints=[
            GeneratedChallengeConstraint(content="Do not hardcode the full output as one string."),
            GeneratedChallengeConstraint(content="Do not use external packages, files, or network calls.")
        ],
        hints=[
            GeneratedChallengeHint(content="Use assignment with the equals sign."),
            GeneratedChallengeHint(content="Use an f-string for formatted output.")
        ],
        evaluation_criteria=[
            GeneratedChallengeEvaluationCriterion(
                skill_id="python_variables",
                description="Uses variables with appropriate values.",
                weight=0.6
            ),
            GeneratedChallengeEvaluationCriterion(
                skill_id="python_variables",
                description="Uses variables in the final printed output.",
                weight=0.4
            )
        ]
    );
}

def _jac_challenge_result() -> ChallengeGenerationResult {
    return ChallengeGenerationResult(
        title="Build a Tiny Walker Traversal",
        prompt="Create a small Jac graph node and walker that visits connected nodes and reports their names.",
        difficulty="intermediate",
        starter_code="node Topic {\n    has name: str;\n}\n\nwalker CollectTopics {\n    has reports: list[list[str]] = [];\n}\n",
        instructions=[
            GeneratedChallengeInstruction(content="Add a walker entry point that starts from Root."),
            GeneratedChallengeInstruction(content="Visit outgoing Topic nodes."),
            GeneratedChallengeInstruction(content="Report the visited topic names.")
        ],
        expected_outcomes=[
            GeneratedChallengeExpectedOutcome(content="The solution uses Jac node and walker syntax."),
            GeneratedChallengeExpectedOutcome(content="The walker visits connected graph nodes.")
        ],
        constraints=[
            GeneratedChallengeConstraint(content="Do not use filesystem, shell, network, or package installation.")
        ],
        hints=[
            GeneratedChallengeHint(content="Use visit [-->] from a Root entry point.")
        ],
        evaluation_criteria=[
            GeneratedChallengeEvaluationCriterion(
                skill_id="jac_walkers",
                description="Defines a walker entry point that traverses graph nodes.",
                weight=1.0
            )
        ]
    );
}

def _seed_context(
    prefix: str,
    language: str,
    difficulty: str,
    skill_id: str
) -> GeneratedLesson {
    learner_id = f"{prefix}-learner";
    assessment_id = f"{prefix}-assessment";
    attempt_id = f"{prefix}-attempt";
    evaluation_id = f"{prefix}-evaluation";
    roadmap_id = f"{prefix}-roadmap";
    week_id = f"{roadmap_id}-week-1";
    roadmap_lesson_id = f"{week_id}-lesson-1";
    generated_lesson_id = f"generated-{learner_id}-{roadmap_lesson_id}";

    learner = (root ++> Learner(
        id=learner_id,
        name="Challenge Learner",
        createdAt="2026-06-29",
        updatedAt="2026-06-29"
    ))[0];
    assessment = (root ++> Assessment(
        id=assessment_id,
        learner_id=learner_id,
        title="Challenge Assessment",
        description="Assessment used for challenge generation tests.",
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
            earned_points=60,
            possible_points=100,
            percentage=60
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
        title="Generated Challenge Test Roadmap",
        description="A seeded roadmap for challenge generation tests.",
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

    roadmap_lesson = (week +>:contains:+> RoadmapLesson(
        id=roadmap_lesson_id,
        roadmap_id=roadmap_id,
        week_id=week_id,
        title="Variables and Data Types" if language == "python" else "Walkers and Traversal",
        summary="Learn the core lesson concept from the roadmap outline.",
        target_skill_ids=[skill_id],
        difficulty=difficulty,
        estimated_minutes=12,
        order_index=1,
        generation_status=RoadmapLessonGenerationStatus.generated
    ))[0];
    week.lessons.append(roadmap_lesson);
    roadmap.lessons.append(roadmap_lesson);

    skill = (root ++> Skill(
        id=skill_id,
        name=skill_id,
        description="Seeded target skill.",
        category=language
    ))[0];
    roadmap_lesson +>:targets:+> skill;

    generated_lesson = (root ++> GeneratedLesson(
        id=generated_lesson_id,
        learner_id=learner_id,
        roadmap_id=roadmap_id,
        roadmap_lesson_id=roadmap_lesson_id,
        language=language,
        title=roadmap_lesson.title,
        summary=roadmap_lesson.summary,
        difficulty=difficulty,
        estimated_minutes=12,
        created_at="2026-06-29T13:00:00Z",
        updated_at="2026-06-29T13:00:00Z",
        generation_status=LessonGenerationStatus.generated
    ))[0];
    learner +>:assigned:+> generated_lesson;
    roadmap +>:contains:+> generated_lesson;
    roadmap_lesson +>:contains:+> generated_lesson;

    section = (generated_lesson +>:contains:+> LessonSection(
        id=f"{generated_lesson_id}-section-1",
        lesson_id=generated_lesson_id,
        title="Core idea",
        content="This lesson explains the target skill through practical code.",
        order_index=1
    ))[0];
    generated_lesson.sections.append(section);
    example = (generated_lesson +>:contains:+> LessonExample(
        id=f"{generated_lesson_id}-example-1",
        lesson_id=generated_lesson_id,
        title="Code example",
        code="name = 'Ada'\nprint(name)" if language == "python" else "walker Visit {\n    can start with Root entry {\n        visit [-->];\n    }\n}",
        explanation="This example demonstrates the lesson concept.",
        order_index=1
    ))[0];
    generated_lesson.examples.append(example);
    exercise = (generated_lesson +>:contains:+> LessonMiniExercise(
        id=f"{generated_lesson_id}-mini-exercise-1",
        lesson_id=generated_lesson_id,
        prompt="Practice the concept in a tiny example.",
        expected_concept=skill_id,
        order_index=1
    ))[0];
    generated_lesson.mini_exercises.append(exercise);
    generated_lesson +>:targets:+> skill;
    return generated_lesson;
}

test "generate challenge creates python beginner challenge" {
    prefix = _unique_id("challenge-python");
    lesson = _seed_context(prefix, "python", "beginner", "python_variables");
    ai_utilities.llm = MockLLM(model_name="mockllm", config={"outputs": [_python_challenge_result("beginner")]});

    result = root spawn generate_challenge(
        learner_id=f"{prefix}-learner",
        roadmap_id=f"{prefix}-roadmap",
        roadmap_lesson_id=lesson.roadmap_lesson_id,
        generated_lesson_id=lesson.id,
        language="python"
    );

    assert len(result.errors) == 0;
    view = result.reports[0];
    assert view.language == "python";
    assert view.difficulty == "beginner";
    assert view.title == "Practice Variables and Data Types";
    assert view.starter_code == "# Write your code here\n";
    assert len(view.instructions) == 3;
    assert len(view.expected_outcomes) == 2;
    assert len(view.constraints) == 2;
    assert len(view.hints) == 2;
    assert len(view.evaluation_criteria) == 2;
}

test "generate challenge normalizes criterion skill id to persisted target" {
    prefix = _unique_id("challenge-skill-normalization");
    lesson = _seed_context(prefix, "python", "beginner", "python_variables");
    generated = _python_challenge_result("beginner");
    for criterion in generated.evaluation_criteria {
        criterion.skill_id = "Python Variables";
    }
    ai_utilities.llm = MockLLM(model_name="mockllm", config={"outputs": [generated]});

    result = root spawn generate_challenge(
        learner_id=f"{prefix}-learner",
        roadmap_id=f"{prefix}-roadmap",
        roadmap_lesson_id=lesson.roadmap_lesson_id,
        generated_lesson_id=lesson.id,
        language="python"
    );

    assert len(result.errors) == 0;
    assert result.reports[0].evaluation_criteria[0].skill_id == "python_variables";
}

test "generate challenge creates jac intermediate challenge" {
    prefix = _unique_id("challenge-jac");
    lesson = _seed_context(prefix, "jac", "intermediate", "jac_walkers");
    ai_utilities.llm = MockLLM(model_name="mockllm", config={"outputs": [_jac_challenge_result()]});

    result = root spawn generate_challenge(
        learner_id=f"{prefix}-learner",
        roadmap_id=f"{prefix}-roadmap",
        roadmap_lesson_id=lesson.roadmap_lesson_id,
        generated_lesson_id=lesson.id,
        language="jac"
    );

    assert len(result.errors) == 0;
    view = result.reports[0];
    assert view.language == "jac";
    assert view.difficulty == "intermediate";
    assert "walker" in view.starter_code;
    assert view.evaluation_criteria[0].skill_id == "jac_walkers";
}

test "generate challenge persists child nodes and relationships" {
    prefix = _unique_id("challenge-persistence");
    lesson = _seed_context(prefix, "python", "beginner", "python_variables");
    ai_utilities.llm = MockLLM(model_name="mockllm", config={"outputs": [_python_challenge_result("beginner")]});

    result = root spawn generate_challenge(
        learner_id=f"{prefix}-learner",
        roadmap_id=f"{prefix}-roadmap",
        roadmap_lesson_id=lesson.roadmap_lesson_id,
        generated_lesson_id=lesson.id,
        language="python"
    );

    assert len(result.errors) == 0;
    challenge = get_generated_challenge(f"{prefix}-learner", lesson.id);
    assert challenge is not None;
    stored = challenge as GeneratedChallenge;
    assert len([stored ->:contains:->][?:ChallengeInstruction]) == 3;
    assert len([stored ->:contains:->][?:ChallengeExpectedOutcome]) == 2;
    assert len([stored ->:contains:->][?:ChallengeConstraint]) == 2;
    assert len([stored ->:contains:->][?:ChallengeHint]) == 2;
    assert len([stored ->:contains:->][?:ChallengeEvaluationCriterion]) == 2;
    assert len([stored ->:targets:->][?:Skill]) == 1;
    assert len([stored ->:evaluates:->][?:Skill]) >= 1;
}

test "generate challenge reuses existing generated challenge" {
    prefix = _unique_id("challenge-reuse");
    lesson = _seed_context(prefix, "python", "beginner", "python_variables");
    ai_utilities.llm = MockLLM(model_name="mockllm", config={"outputs": [_python_challenge_result("beginner")]});

    first = root spawn generate_challenge(
        learner_id=f"{prefix}-learner",
        roadmap_id=f"{prefix}-roadmap",
        roadmap_lesson_id=lesson.roadmap_lesson_id,
        generated_lesson_id=lesson.id,
        language="python"
    );
    second = root spawn generate_challenge(
        learner_id=f"{prefix}-learner",
        roadmap_id=f"{prefix}-roadmap",
        roadmap_lesson_id=lesson.roadmap_lesson_id,
        generated_lesson_id=lesson.id,
        language="python"
    );

    assert len(first.errors) == 0;
    assert len(second.errors) == 0;
    assert first.reports[0].id == second.reports[0].id;

    matches: list[GeneratedChallenge] = [];
    for challenge in [root -->][?:GeneratedChallenge] {
        if challenge.learner_id == f"{prefix}-learner" and challenge.generated_lesson_id == lesson.id {
            matches = matches + [challenge];
        }
    }
    assert len(matches) == 1;
}

test "generate challenge supports intermediate difficulty" {
    prefix = _unique_id("challenge-intermediate");
    lesson = _seed_context(prefix, "python", "intermediate", "python_variables");
    ai_utilities.llm = MockLLM(model_name="mockllm", config={"outputs": [_python_challenge_result("intermediate")]});

    result = root spawn generate_challenge(
        learner_id=f"{prefix}-learner",
        roadmap_id=f"{prefix}-roadmap",
        roadmap_lesson_id=lesson.roadmap_lesson_id,
        generated_lesson_id=lesson.id,
        language="python"
    );

    assert len(result.errors) == 0;
    assert result.reports[0].difficulty == "intermediate";
}

test "generate challenge rejects invalid generated lesson" {
    prefix = _unique_id("challenge-invalid-lesson");
    lesson = _seed_context(prefix, "python", "beginner", "python_variables");

    result = root spawn generate_challenge(
        learner_id=f"{prefix}-learner",
        roadmap_id=f"{prefix}-roadmap",
        roadmap_lesson_id=lesson.roadmap_lesson_id,
        generated_lesson_id="missing-generated-lesson",
        language="python"
    );

    assert len(result.reports) == 0;
    assert result.errors[0].code == "missing_generated_lesson";
}

test "generate challenge rejects unsupported language" {
    prefix = _unique_id("challenge-invalid-language");
    lesson = _seed_context(prefix, "python", "beginner", "python_variables");

    result = root spawn generate_challenge(
        learner_id=f"{prefix}-learner",
        roadmap_id=f"{prefix}-roadmap",
        roadmap_lesson_id=lesson.roadmap_lesson_id,
        generated_lesson_id=lesson.id,
        language="typescript"
    );

    assert len(result.reports) == 0;
    assert result.errors[0].code == "unsupported_language";
}
