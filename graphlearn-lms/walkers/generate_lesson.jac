"""On-demand generated lesson content walker."""

import from datetime { datetime }
import from byllm.lib { ByLLMError }
import from edges.domain_edges { assigned, contains, targets }
import from lib.ai.utilities {
    LessonContentContext,
    LessonGenerationResult,
    generate_lesson_content,
    standard_ai_error_policy
}
import from nodes.assessment {
    Assessment,
    AssessmentAttempt,
    AssessmentAttemptLink,
    AssessmentEvaluation,
    AssessmentEvaluationLink,
    SkillSignal
}
import from nodes.learner { Learner }
import from nodes.lesson {
    GeneratedLesson,
    LessonExample,
    LessonGenerationStatus,
    LessonMiniExercise,
    LessonSection,
    LessonTakeaway
}
import from nodes.roadmap {
    Roadmap,
    RoadmapLesson,
    RoadmapLessonGenerationStatus,
    RoadmapWeek
}
import from nodes.skill { Skill }

obj LessonGenerationError {
    has code: str;
    has message: str;
}

obj LessonSectionView {
    has id: str;
    has title: str;
    has content: str;
    has order_index: int;
}

obj LessonExampleView {
    has id: str;
    has title: str;
    has code: str;
    has explanation: str;
    has order_index: int;
}

obj LessonMiniExerciseView {
    has id: str;
    has prompt: str;
    has expected_concept: str;
    has order_index: int;
}

obj LessonTakeawayView {
    has id: str;
    has content: str;
    has order_index: int;
}

obj GeneratedLessonView {
    has id: str;
    has roadmap_lesson_id: str;
    has learner_id: str;
    has language: str;
    has title: str;
    has summary: str;
    has difficulty: str;
    has estimated_minutes: int;
    has generation_status: str;
    has created_at: str;
    has sections: list[LessonSectionView] = [];
    has examples: list[LessonExampleView] = [];
    has mini_exercises: list[LessonMiniExerciseView] = [];
    has key_takeaways: list[LessonTakeawayView] = [];
}

obj LessonAssessmentContext {
    has summary: str;
    has weak_skills: list[str];
    has strong_skills: list[str];
}

def _current_timestamp -> str {
    return datetime.utcnow().isoformat() + "Z";
}

def _find_learner(learner_id: str) -> Learner | None {
    for learner in [root -->][?:Learner, id == learner_id] {
        return learner;
    }
    return None;
}

def _find_roadmap(roadmap_id: str) -> Roadmap | None {
    for roadmap in [root -->][?:Roadmap, id == roadmap_id] {
        return roadmap;
    }
    return None;
}

def _find_roadmap_lesson(roadmap: Roadmap, roadmap_lesson_id: str) -> RoadmapLesson | None {
    for lesson in roadmap.lessons {
        if lesson.id == roadmap_lesson_id {
            return lesson;
        }
    }
    for week in [roadmap ->:contains:->][?:RoadmapWeek] {
        for lesson in [week ->:contains:->][?:RoadmapLesson] {
            if lesson.id == roadmap_lesson_id {
                return lesson;
            }
        }
    }
    return None;
}

def _find_assessment(assessment_id: str) -> Assessment | None {
    for assessment in [root -->][?:Assessment, id == assessment_id] {
        return assessment;
    }
    return None;
}

def _find_attempt(assessment: Assessment, attempt_id: str) -> AssessmentAttempt | None {
    for attempt in [assessment ->:AssessmentAttemptLink:->][?:AssessmentAttempt] {
        if attempt.id == attempt_id {
            return attempt;
        }
    }
    return None;
}

def _find_evaluation(
    attempt: AssessmentAttempt,
    evaluation_id: str
) -> AssessmentEvaluation | None {
    for evaluation in [attempt ->:AssessmentEvaluationLink:->][?:AssessmentEvaluation] {
        if evaluation.id == evaluation_id {
            return evaluation;
        }
    }
    return None;
}

def get_generated_lesson(
    learner_id: str,
    roadmap_lesson_id: str
) -> GeneratedLesson | None {
    for lesson in [root -->][?:GeneratedLesson] {
        if lesson.learner_id == learner_id and lesson.roadmap_lesson_id == roadmap_lesson_id {
            return lesson;
        }
    }
    return None;
}

def _weak_skills(signals: list[SkillSignal]) -> list[str] {
    weak: list[str] = [];
    for signal in signals {
        if signal.accuracy < 0.6 {
            weak = weak + [signal.skill_id];
        }
    }
    return weak;
}

def _strong_skills(signals: list[SkillSignal]) -> list[str] {
    strong: list[str] = [];
    for signal in signals {
        if signal.accuracy >= 0.75 {
            strong = strong + [signal.skill_id];
        }
    }
    return strong;
}

def _assessment_context(roadmap: Roadmap) -> LessonAssessmentContext {
    assessment = _find_assessment(roadmap.assessment_id);
    if assessment is None {
        return LessonAssessmentContext(
            summary="No assessment evaluation summary is available.",
            weak_skills=[],
            strong_skills=[]
        );
    }
    attempt = _find_attempt(assessment, roadmap.assessment_attempt_id);
    if attempt is None {
        return LessonAssessmentContext(
            summary="No assessment evaluation summary is available.",
            weak_skills=[],
            strong_skills=[]
        );
    }
    evaluation = _find_evaluation(attempt, roadmap.assessment_evaluation_id);
    if evaluation is None {
        return LessonAssessmentContext(
            summary="No assessment evaluation summary is available.",
            weak_skills=[],
            strong_skills=[]
        );
    }

    weak = _weak_skills(evaluation.skill_signals);
    strong = _strong_skills(evaluation.skill_signals);
    summary = (
        f"Assessment: {assessment.title}. Score: {evaluation.score.percentage}%. "
        + f"Weak skills: {', '.join(weak)}. "
        + f"Strong skills: {', '.join(strong)}."
    );
    return LessonAssessmentContext(
        summary=summary,
        weak_skills=weak,
        strong_skills=strong
    );
}

def _previous_lesson_titles(roadmap: Roadmap, current_lesson: RoadmapLesson) -> list[str] {
    titles: list[str] = [];
    for lesson in roadmap.lessons {
        if lesson.order_index < current_lesson.order_index {
            titles = titles + [lesson.title];
        }
    }
    return titles;
}

def _get_or_create_skill(skill_id: str, language: str) -> Skill {
    for skill in [root -->][?:Skill, id == skill_id] {
        return skill;
    }
    return (root ++> Skill(
        id=skill_id,
        name=skill_id,
        description="Generated lesson target skill placeholder.",
        category=language
    ))[0];
}

def _lesson_output_errors(result: LessonGenerationResult) -> list[LessonGenerationError] {
    errors: list[LessonGenerationError] = [];
    if len(result.sections) == 0 {
        errors = errors + [LessonGenerationError(code="invalid_ai_output", message="Generated lesson needs at least one section.")];
    }
    if len(result.examples) == 0 {
        errors = errors + [LessonGenerationError(code="invalid_ai_output", message="Generated lesson needs at least one example.")];
    }
    if len(result.mini_exercises) == 0 {
        errors = errors + [LessonGenerationError(code="invalid_ai_output", message="Generated lesson needs at least one mini exercise.")];
    }
    if len(result.key_takeaways) == 0 {
        errors = errors + [LessonGenerationError(code="invalid_ai_output", message="Generated lesson needs at least one key takeaway.")];
    }
    for section in result.sections {
        if section.title.strip() == "" or section.content.strip() == "" {
            errors = errors + [LessonGenerationError(code="invalid_ai_output", message="Each lesson section needs a title and content.")];
        }
    }
    for example in result.examples {
        if example.title.strip() == "" or example.code.strip() == "" or example.explanation.strip() == "" {
            errors = errors + [LessonGenerationError(code="invalid_ai_output", message="Each lesson example needs a title, code, and explanation.")];
        }
    }
    for exercise in result.mini_exercises {
        if exercise.prompt.strip() == "" or exercise.expected_concept.strip() == "" {
            errors = errors + [LessonGenerationError(code="invalid_ai_output", message="Each mini exercise needs a prompt and expected concept.")];
        }
    }
    for takeaway in result.key_takeaways {
        if takeaway.content.strip() == "" {
            errors = errors + [LessonGenerationError(code="invalid_ai_output", message="Each takeaway needs content.")];
        }
    }
    return errors;
}

def _section_order(section: LessonSection) -> int {
    return section.order_index;
}

def _example_order(example: LessonExample) -> int {
    return example.order_index;
}

def _exercise_order(exercise: LessonMiniExercise) -> int {
    return exercise.order_index;
}

def _takeaway_order(takeaway: LessonTakeaway) -> int {
    return takeaway.order_index;
}

def _generated_lesson_to_view(lesson: GeneratedLesson) -> GeneratedLessonView {
    section_views: list[LessonSectionView] = [];
    for section in sorted(lesson.sections, key=_section_order) {
        section_views = section_views + [
            LessonSectionView(
                id=section.id,
                title=section.title,
                content=section.content,
                order_index=section.order_index
            )
        ];
    }

    example_views: list[LessonExampleView] = [];
    for example in sorted(lesson.examples, key=_example_order) {
        example_views = example_views + [
            LessonExampleView(
                id=example.id,
                title=example.title,
                code=example.code,
                explanation=example.explanation,
                order_index=example.order_index
            )
        ];
    }

    exercise_views: list[LessonMiniExerciseView] = [];
    for exercise in sorted(lesson.mini_exercises, key=_exercise_order) {
        exercise_views = exercise_views + [
            LessonMiniExerciseView(
                id=exercise.id,
                prompt=exercise.prompt,
                expected_concept=exercise.expected_concept,
                order_index=exercise.order_index
            )
        ];
    }

    takeaway_views: list[LessonTakeawayView] = [];
    for takeaway in sorted(lesson.key_takeaways, key=_takeaway_order) {
        takeaway_views = takeaway_views + [
            LessonTakeawayView(
                id=takeaway.id,
                content=takeaway.content,
                order_index=takeaway.order_index
            )
        ];
    }

    return GeneratedLessonView(
        id=lesson.id,
        roadmap_lesson_id=lesson.roadmap_lesson_id,
        learner_id=lesson.learner_id,
        language=lesson.language,
        title=lesson.title,
        summary=lesson.summary,
        difficulty=lesson.difficulty,
        estimated_minutes=lesson.estimated_minutes,
        sections=section_views,
        examples=example_views,
        mini_exercises=exercise_views,
        key_takeaways=takeaway_views,
        generation_status=lesson.generation_status.value,
        created_at=lesson.created_at
    );
}

walker generate_lesson {
    has learner_id: str;
    has roadmap_id: str;
    has roadmap_lesson_id: str;
    has language: str;
    has errors: list[LessonGenerationError] = [];
    has reports: list[GeneratedLessonView] = [];

    can generate with Root entry {
        language_normalized = self.language.strip().lower();
        if language_normalized not in ["python", "jac"] {
            self.errors = self.errors + [
                LessonGenerationError(
                    code="unsupported_language",
                    message="Generated lessons currently support python and jac only."
                )
            ];
            return;
        }

        learner = _find_learner(self.learner_id);
        if learner is None {
            self.errors = self.errors + [LessonGenerationError(code="missing_learner", message="Learner does not exist.")];
            return;
        }

        roadmap = _find_roadmap(self.roadmap_id);
        if roadmap is None {
            self.errors = self.errors + [LessonGenerationError(code="missing_roadmap", message="Roadmap does not exist.")];
            return;
        }
        if roadmap.learner_id != self.learner_id {
            self.errors = self.errors + [LessonGenerationError(code="learner_mismatch", message="Roadmap does not belong to this learner.")];
            return;
        }
        if roadmap.language != language_normalized {
            self.errors = self.errors + [LessonGenerationError(code="language_mismatch", message="Requested language does not match the roadmap language.")];
            return;
        }

        roadmap_lesson = _find_roadmap_lesson(roadmap, self.roadmap_lesson_id);
        if roadmap_lesson is None {
            self.errors = self.errors + [LessonGenerationError(code="missing_roadmap_lesson", message="Roadmap lesson does not exist.")];
            return;
        }
        if roadmap_lesson.roadmap_id != roadmap.id {
            self.errors = self.errors + [LessonGenerationError(code="roadmap_lesson_mismatch", message="Roadmap lesson does not belong to this roadmap.")];
            return;
        }
        if roadmap_lesson.title.strip() == "" or roadmap_lesson.summary.strip() == "" {
            self.errors = self.errors + [LessonGenerationError(code="invalid_roadmap_lesson_state", message="Roadmap lesson needs a title and summary before content generation.")];
            return;
        }
        if roadmap_lesson.estimated_minutes <= 0 or roadmap_lesson.difficulty.strip() == "" {
            self.errors = self.errors + [LessonGenerationError(code="invalid_roadmap_lesson_state", message="Roadmap lesson has invalid difficulty or duration.")];
            return;
        }
        if len(roadmap_lesson.target_skill_ids) == 0 {
            self.errors = self.errors + [LessonGenerationError(code="invalid_target_skills", message="Roadmap lesson must target at least one skill.")];
            return;
        }

        existing = get_generated_lesson(self.learner_id, self.roadmap_lesson_id);
        if existing is not None {
            report _generated_lesson_to_view(existing);
            return;
        }

        context = _assessment_context(roadmap);
        try {
            generated = generate_lesson_content(
                LessonContentContext(
                    language=language_normalized,
                    lesson_title=roadmap_lesson.title,
                    lesson_summary=roadmap_lesson.summary,
                    difficulty=roadmap_lesson.difficulty,
                    estimated_minutes=roadmap_lesson.estimated_minutes,
                    target_skills=roadmap_lesson.target_skill_ids,
                    learner_assessment_summary=context.summary,
                    weak_skills=context.weak_skills,
                    strong_skills=context.strong_skills,
                    previous_lesson_titles=_previous_lesson_titles(roadmap, roadmap_lesson)
                )
            );
        } except ByLLMError as e {
            policy = standard_ai_error_policy(e);
            self.errors = self.errors + [
                LessonGenerationError(
                    code=f"ai_{policy.kind}",
                    message=policy.user_message
                )
            ];
            return;
        }

        self.errors = _lesson_output_errors(generated);
        if len(self.errors) > 0 {
            return;
        }

        timestamp = _current_timestamp();
        generated_lesson_id = f"generated-{self.learner_id}-{roadmap_lesson.id}";
        generated_lesson = (root ++> GeneratedLesson(
            id=generated_lesson_id,
            learner_id=self.learner_id,
            roadmap_id=roadmap.id,
            roadmap_lesson_id=roadmap_lesson.id,
            language=language_normalized,
            title=roadmap_lesson.title,
            summary=roadmap_lesson.summary,
            difficulty=roadmap_lesson.difficulty,
            estimated_minutes=roadmap_lesson.estimated_minutes,
            created_at=timestamp,
            updated_at=timestamp,
            generation_status=LessonGenerationStatus.generated
        ))[0];
        learner +>:assigned:+> generated_lesson;
        roadmap +>:contains:+> generated_lesson;
        roadmap_lesson +>:contains:+> generated_lesson;

        section_index = 1;
        for section in generated.sections {
            section_node = (generated_lesson +>:contains:+> LessonSection(
                id=f"{generated_lesson.id}-section-{section_index}",
                lesson_id=generated_lesson.id,
                title=section.title,
                content=section.content,
                order_index=section_index
            ))[0];
            generated_lesson.sections.append(section_node);
            section_index += 1;
        }

        example_index = 1;
        for example in generated.examples {
            example_node = (generated_lesson +>:contains:+> LessonExample(
                id=f"{generated_lesson.id}-example-{example_index}",
                lesson_id=generated_lesson.id,
                title=example.title,
                code=example.code,
                explanation=example.explanation,
                order_index=example_index
            ))[0];
            generated_lesson.examples.append(example_node);
            example_index += 1;
        }

        exercise_index = 1;
        for exercise in generated.mini_exercises {
            exercise_node = (generated_lesson +>:contains:+> LessonMiniExercise(
                id=f"{generated_lesson.id}-mini-exercise-{exercise_index}",
                lesson_id=generated_lesson.id,
                prompt=exercise.prompt,
                expected_concept=exercise.expected_concept,
                order_index=exercise_index
            ))[0];
            generated_lesson.mini_exercises.append(exercise_node);
            exercise_index += 1;
        }

        takeaway_index = 1;
        for takeaway in generated.key_takeaways {
            takeaway_node = (generated_lesson +>:contains:+> LessonTakeaway(
                id=f"{generated_lesson.id}-takeaway-{takeaway_index}",
                lesson_id=generated_lesson.id,
                content=takeaway.content,
                order_index=takeaway_index
            ))[0];
            generated_lesson.key_takeaways.append(takeaway_node);
            takeaway_index += 1;
        }

        for skill_id in roadmap_lesson.target_skill_ids {
            generated_lesson +>:targets:+> _get_or_create_skill(skill_id, language_normalized);
        }

        roadmap_lesson.generation_status = RoadmapLessonGenerationStatus.generated;
        report _generated_lesson_to_view(generated_lesson);
    }
}
