"""On-demand coding challenge generation walker."""

import from datetime { datetime }
import from byllm.lib { ByLLMError }
import from edges.domain_edges { assigned, contains, evaluates, targets }
import from lib.observability.instrumentation { ai_call_completed, ai_call_failed, ai_call_started, observe_walker_finish, observe_walker_start }
import from lib.ai.utilities {
    ChallengeGenerationContext,
    ChallengeGenerationResult,
    generate_coding_challenge,
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
    LessonMiniExercise,
    LessonSection
}
import from nodes.roadmap {
    Roadmap,
    RoadmapLesson,
    RoadmapWeek
}
import from nodes.skill { Skill }

obj ChallengeGenerationError {
    has code: str;
    has message: str;
}

obj ChallengeInstructionView {
    has id: str;
    has content: str;
    has order_index: int;
}

obj ChallengeExpectedOutcomeView {
    has id: str;
    has content: str;
    has order_index: int;
}

obj ChallengeConstraintView {
    has id: str;
    has content: str;
    has order_index: int;
}

obj ChallengeHintView {
    has id: str;
    has content: str;
    has order_index: int;
}

obj ChallengeEvaluationCriterionView {
    has id: str;
    has skill_id: str;
    has description: str;
    has weight: float;
    has order_index: int;
}

obj GeneratedChallengeView {
    has id: str;
    has learner_id: str;
    has roadmap_id: str;
    has roadmap_lesson_id: str;
    has generated_lesson_id: str;
    has language: str;
    has title: str;
    has prompt: str;
    has difficulty: str;
    has starter_code: str;
    has created_at: str;
    has updated_at: str;
    has instructions: list[ChallengeInstructionView] = [];
    has expected_outcomes: list[ChallengeExpectedOutcomeView] = [];
    has constraints: list[ChallengeConstraintView] = [];
    has hints: list[ChallengeHintView] = [];
    has evaluation_criteria: list[ChallengeEvaluationCriterionView] = [];
}

obj ChallengeAssessmentContext {
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

def _find_generated_lesson(generated_lesson_id: str) -> GeneratedLesson | None {
    for lesson in [root -->][?:GeneratedLesson, id == generated_lesson_id] {
        return lesson;
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

def get_generated_challenge(
    learner_id: str,
    generated_lesson_id: str
) -> GeneratedChallenge | None {
    for challenge in [root -->][?:GeneratedChallenge] {
        if challenge.learner_id == learner_id and challenge.generated_lesson_id == generated_lesson_id {
            return challenge;
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

def _assessment_context(roadmap: Roadmap) -> ChallengeAssessmentContext {
    assessment = _find_assessment(roadmap.assessment_id);
    if assessment is None {
        return ChallengeAssessmentContext(weak_skills=[], strong_skills=[]);
    }
    attempt = _find_attempt(assessment, roadmap.assessment_attempt_id);
    if attempt is None {
        return ChallengeAssessmentContext(weak_skills=[], strong_skills=[]);
    }
    evaluation = _find_evaluation(attempt, roadmap.assessment_evaluation_id);
    if evaluation is None {
        return ChallengeAssessmentContext(weak_skills=[], strong_skills=[]);
    }
    return ChallengeAssessmentContext(
        weak_skills=_weak_skills(evaluation.skill_signals),
        strong_skills=_strong_skills(evaluation.skill_signals)
    );
}

def _get_or_create_skill(skill_id: str, language: str) -> Skill {
    for skill in [root -->][?:Skill, id == skill_id] {
        return skill;
    }
    return (root ++> Skill(
        id=skill_id,
        name=skill_id,
        description="Generated challenge target skill placeholder.",
        category=language
    ))[0];
}

def _section_context(sections: list[LessonSection]) -> list[str] {
    values: list[str] = [];
    for section in sections {
        values = values + [f"{section.title}: {section.content}"];
    }
    return values;
}

def _example_context(examples: list[LessonExample]) -> list[str] {
    values: list[str] = [];
    for example in examples {
        values = values + [f"{example.title}\nCode:\n{example.code}\nExplanation: {example.explanation}"];
    }
    return values;
}

def _mini_exercise_context(exercises: list[LessonMiniExercise]) -> list[str] {
    values: list[str] = [];
    for exercise in exercises {
        values = values + [f"{exercise.prompt} Expected concept: {exercise.expected_concept}"];
    }
    return values;
}

def _previous_challenge_titles(roadmap: Roadmap, generated_lesson_id: str) -> list[str] {
    titles: list[str] = [];
    for challenge in [roadmap ->:contains:->][?:GeneratedChallenge] {
        if challenge.generated_lesson_id != generated_lesson_id {
            titles = titles + [challenge.title];
        }
    }
    return titles;
}

def _challenge_output_errors(
    result: ChallengeGenerationResult,
    target_skills: list[str]
) -> list[ChallengeGenerationError] {
    errors: list[ChallengeGenerationError] = [];
    if result.title.strip() == "" or result.prompt.strip() == "" {
        errors = errors + [ChallengeGenerationError(code="invalid_ai_output", message="Generated challenge needs a title and prompt.")];
    }
    if result.difficulty.strip() not in ["beginner", "intermediate", "advanced"] {
        errors = errors + [ChallengeGenerationError(code="invalid_ai_output", message="Generated challenge difficulty must be beginner, intermediate, or advanced.")];
    }
    if result.starter_code.strip() == "" {
        errors = errors + [ChallengeGenerationError(code="invalid_ai_output", message="Generated challenge needs starter code.")];
    }
    if len(result.instructions) == 0 {
        errors = errors + [ChallengeGenerationError(code="invalid_ai_output", message="Generated challenge needs at least one instruction.")];
    }
    if len(result.expected_outcomes) == 0 {
        errors = errors + [ChallengeGenerationError(code="invalid_ai_output", message="Generated challenge needs at least one expected outcome.")];
    }
    if len(result.constraints) == 0 {
        errors = errors + [ChallengeGenerationError(code="invalid_ai_output", message="Generated challenge needs at least one constraint.")];
    }
    if len(result.hints) == 0 {
        errors = errors + [ChallengeGenerationError(code="invalid_ai_output", message="Generated challenge needs at least one hint.")];
    }
    if len(result.evaluation_criteria) == 0 {
        errors = errors + [ChallengeGenerationError(code="invalid_ai_output", message="Generated challenge needs at least one evaluation criterion.")];
    }
    for instruction in result.instructions {
        if instruction.content.strip() == "" {
            errors = errors + [ChallengeGenerationError(code="invalid_ai_output", message="Each challenge instruction needs content.")];
        }
    }
    for outcome in result.expected_outcomes {
        if outcome.content.strip() == "" {
            errors = errors + [ChallengeGenerationError(code="invalid_ai_output", message="Each expected outcome needs content.")];
        }
    }
    for constraint in result.constraints {
        if constraint.content.strip() == "" {
            errors = errors + [ChallengeGenerationError(code="invalid_ai_output", message="Each challenge constraint needs content.")];
        }
    }
    for hint in result.hints {
        if hint.content.strip() == "" {
            errors = errors + [ChallengeGenerationError(code="invalid_ai_output", message="Each challenge hint needs content.")];
        }
    }
    for criterion in result.evaluation_criteria {
        if criterion.skill_id.strip() == "" or criterion.description.strip() == "" {
            errors = errors + [ChallengeGenerationError(code="invalid_ai_output", message="Each evaluation criterion needs a skill id and description.")];
        }
        if criterion.weight <= 0.0 {
            errors = errors + [ChallengeGenerationError(code="invalid_ai_output", message="Each evaluation criterion needs a positive weight.")];
        }
        if criterion.skill_id not in target_skills {
            errors = errors + [ChallengeGenerationError(code="invalid_ai_output", message="Evaluation criteria must target persisted roadmap lesson skills.")];
        }
    }
    return errors;
}

def _canonical_skill_id(skill_id: str) -> str {
    return skill_id.strip().lower().replace("-", "_").replace(" ", "_");
}

def _persisted_skill_id(skill_id: str, target_skills: list[str]) -> str | None {
    candidate = _canonical_skill_id(skill_id);
    for target in target_skills {
        if _canonical_skill_id(target) == candidate {
            return target;
        }
    }
    if len(target_skills) == 1 {
        return target_skills[0];
    }
    return None;
}

def _normalize_criterion_skill_ids(result: ChallengeGenerationResult, target_skills: list[str]) {
    for criterion in result.evaluation_criteria {
        persisted = _persisted_skill_id(criterion.skill_id, target_skills);
        if persisted is not None {
            criterion.skill_id = persisted;
        }
    }
}

def _instruction_order(instruction: ChallengeInstruction) -> int {
    return instruction.order_index;
}

def _outcome_order(outcome: ChallengeExpectedOutcome) -> int {
    return outcome.order_index;
}

def _constraint_order(constraint: ChallengeConstraint) -> int {
    return constraint.order_index;
}

def _hint_order(hint: ChallengeHint) -> int {
    return hint.order_index;
}

def _criterion_order(criterion: ChallengeEvaluationCriterion) -> int {
    return criterion.order_index;
}

def generated_challenge_to_view(challenge: GeneratedChallenge) -> GeneratedChallengeView {
    instruction_views: list[ChallengeInstructionView] = [];
    for instruction in sorted(challenge.instructions, key=_instruction_order) {
        instruction_views = instruction_views + [
            ChallengeInstructionView(
                id=instruction.id,
                content=instruction.content,
                order_index=instruction.order_index
            )
        ];
    }

    outcome_views: list[ChallengeExpectedOutcomeView] = [];
    for outcome in sorted(challenge.expected_outcomes, key=_outcome_order) {
        outcome_views = outcome_views + [
            ChallengeExpectedOutcomeView(
                id=outcome.id,
                content=outcome.content,
                order_index=outcome.order_index
            )
        ];
    }

    constraint_views: list[ChallengeConstraintView] = [];
    for constraint in sorted(challenge.constraints, key=_constraint_order) {
        constraint_views = constraint_views + [
            ChallengeConstraintView(
                id=constraint.id,
                content=constraint.content,
                order_index=constraint.order_index
            )
        ];
    }

    hint_views: list[ChallengeHintView] = [];
    for hint in sorted(challenge.hints, key=_hint_order) {
        hint_views = hint_views + [
            ChallengeHintView(
                id=hint.id,
                content=hint.content,
                order_index=hint.order_index
            )
        ];
    }

    criterion_views: list[ChallengeEvaluationCriterionView] = [];
    for criterion in sorted(challenge.evaluation_criteria, key=_criterion_order) {
        criterion_views = criterion_views + [
            ChallengeEvaluationCriterionView(
                id=criterion.id,
                skill_id=criterion.skill_id,
                description=criterion.description,
                weight=criterion.weight,
                order_index=criterion.order_index
            )
        ];
    }

    return GeneratedChallengeView(
        id=challenge.id,
        learner_id=challenge.learner_id,
        roadmap_id=challenge.roadmap_id,
        roadmap_lesson_id=challenge.roadmap_lesson_id,
        generated_lesson_id=challenge.generated_lesson_id,
        language=challenge.language,
        title=challenge.title,
        prompt=challenge.prompt,
        difficulty=challenge.difficulty,
        starter_code=challenge.starter_code,
        created_at=challenge.created_at,
        updated_at=challenge.updated_at,
        instructions=instruction_views,
        expected_outcomes=outcome_views,
        constraints=constraint_views,
        hints=hint_views,
        evaluation_criteria=criterion_views
    );
}

walker generate_challenge {
    has learner_id: str;
    has roadmap_id: str;
    has roadmap_lesson_id: str;
    has generated_lesson_id: str;
    has language: str;
    has errors: list[ChallengeGenerationError] = [];
    has reports: list[GeneratedChallengeView] = [];
    has request_id: str = "";
    has correlation_id: str = "";

    can observability_start with Root entry { observe_walker_start(self); }
    can observability_finish with Root exit { observe_walker_finish(self); }

    can generate with Root entry {
        language_normalized = self.language.strip().lower();
        if language_normalized not in ["python", "jac"] {
            self.errors = self.errors + [
                ChallengeGenerationError(
                    code="unsupported_language",
                    message="Generated challenges currently support python and jac only."
                )
            ];
            return;
        }

        learner = _find_learner(self.learner_id);
        if learner is None {
            self.errors = self.errors + [ChallengeGenerationError(code="missing_learner", message="Learner does not exist.")];
            return;
        }

        roadmap = _find_roadmap(self.roadmap_id);
        if roadmap is None {
            self.errors = self.errors + [ChallengeGenerationError(code="missing_roadmap", message="Roadmap does not exist.")];
            return;
        }
        if roadmap.learner_id != self.learner_id {
            self.errors = self.errors + [ChallengeGenerationError(code="learner_mismatch", message="Roadmap does not belong to this learner.")];
            return;
        }
        if roadmap.language != language_normalized {
            self.errors = self.errors + [ChallengeGenerationError(code="language_mismatch", message="Requested language does not match the roadmap language.")];
            return;
        }

        roadmap_lesson = _find_roadmap_lesson(roadmap, self.roadmap_lesson_id);
        if roadmap_lesson is None {
            self.errors = self.errors + [ChallengeGenerationError(code="missing_roadmap_lesson", message="Roadmap lesson does not exist.")];
            return;
        }
        if roadmap_lesson.roadmap_id != roadmap.id {
            self.errors = self.errors + [ChallengeGenerationError(code="roadmap_lesson_mismatch", message="Roadmap lesson does not belong to this roadmap.")];
            return;
        }
        if len(roadmap_lesson.target_skill_ids) == 0 {
            self.errors = self.errors + [ChallengeGenerationError(code="invalid_target_skills", message="Roadmap lesson must target at least one skill.")];
            return;
        }

        generated_lesson = _find_generated_lesson(self.generated_lesson_id);
        if generated_lesson is None {
            self.errors = self.errors + [ChallengeGenerationError(code="missing_generated_lesson", message="Generated lesson does not exist.")];
            return;
        }
        if generated_lesson.learner_id != self.learner_id or generated_lesson.roadmap_id != roadmap.id or generated_lesson.roadmap_lesson_id != roadmap_lesson.id {
            self.errors = self.errors + [
                ChallengeGenerationError(
                    code="generated_lesson_mismatch",
                    message="Generated lesson does not belong to this learner, roadmap, and roadmap lesson."
                )
            ];
            return;
        }
        if generated_lesson.language != language_normalized {
            self.errors = self.errors + [ChallengeGenerationError(code="language_mismatch", message="Requested language does not match the generated lesson language.")];
            return;
        }
        if len(generated_lesson.sections) == 0 or len(generated_lesson.examples) == 0 or len(generated_lesson.mini_exercises) == 0 {
            self.errors = self.errors + [ChallengeGenerationError(code="invalid_generated_lesson", message="Generated lesson needs sections, examples, and mini exercises before challenge generation.")];
            return;
        }

        existing = get_generated_challenge(self.learner_id, generated_lesson.id);
        if existing is not None {
            report generated_challenge_to_view(existing);
            return;
        }

        assessment = _assessment_context(roadmap);
        ai_started = ai_call_started("generate_challenge", "generate_coding_challenge", self.request_id, self.correlation_id, {"language": language_normalized, "lesson_title": roadmap_lesson.title});
        try {
            generated = generate_coding_challenge(
                ChallengeGenerationContext(
                    language=language_normalized,
                    lesson_title=generated_lesson.title,
                    lesson_summary=generated_lesson.summary,
                    lesson_difficulty=generated_lesson.difficulty,
                    lesson_sections=_section_context(generated_lesson.sections),
                    lesson_examples=_example_context(generated_lesson.examples),
                    lesson_mini_exercises=_mini_exercise_context(generated_lesson.mini_exercises),
                    target_skills=roadmap_lesson.target_skill_ids,
                    learner_weak_skills=assessment.weak_skills,
                    learner_strong_skills=assessment.strong_skills,
                    previous_challenge_titles=_previous_challenge_titles(roadmap, generated_lesson.id)
                )
            );
            ai_call_completed("generate_challenge", "generate_coding_challenge", self.request_id, self.correlation_id, ai_started);
        } except ByLLMError as e {
            ai_call_failed("generate_challenge", "generate_coding_challenge", self.request_id, self.correlation_id, ai_started, e.__class__.__name__);
            policy = standard_ai_error_policy(e);
            self.errors = self.errors + [
                ChallengeGenerationError(
                    code=f"ai_{policy.kind}",
                    message=policy.user_message
                )
            ];
            return;
        }

        _normalize_criterion_skill_ids(generated, roadmap_lesson.target_skill_ids);
        self.errors = _challenge_output_errors(generated, roadmap_lesson.target_skill_ids);
        if len(self.errors) > 0 {
            return;
        }

        timestamp = _current_timestamp();
        challenge_id = f"challenge-{self.learner_id}-{generated_lesson.id}";
        challenge = (root ++> GeneratedChallenge(
            id=challenge_id,
            learner_id=self.learner_id,
            roadmap_id=roadmap.id,
            roadmap_lesson_id=roadmap_lesson.id,
            generated_lesson_id=generated_lesson.id,
            language=language_normalized,
            title=generated.title,
            prompt=generated.prompt,
            difficulty=generated.difficulty,
            starter_code=generated.starter_code,
            created_at=timestamp,
            updated_at=timestamp
        ))[0];
        learner +>:assigned:+> challenge;
        roadmap +>:contains:+> challenge;
        roadmap_lesson +>:contains:+> challenge;
        generated_lesson +>:contains:+> challenge;

        instruction_index = 1;
        for instruction in generated.instructions {
            instruction_node = (challenge +>:contains:+> ChallengeInstruction(
                id=f"{challenge.id}-instruction-{instruction_index}",
                challenge_id=challenge.id,
                content=instruction.content,
                order_index=instruction_index
            ))[0];
            challenge.instructions.append(instruction_node);
            instruction_index += 1;
        }

        outcome_index = 1;
        for outcome in generated.expected_outcomes {
            outcome_node = (challenge +>:contains:+> ChallengeExpectedOutcome(
                id=f"{challenge.id}-outcome-{outcome_index}",
                challenge_id=challenge.id,
                content=outcome.content,
                order_index=outcome_index
            ))[0];
            challenge.expected_outcomes.append(outcome_node);
            outcome_index += 1;
        }

        constraint_index = 1;
        for constraint in generated.constraints {
            constraint_node = (challenge +>:contains:+> ChallengeConstraint(
                id=f"{challenge.id}-constraint-{constraint_index}",
                challenge_id=challenge.id,
                content=constraint.content,
                order_index=constraint_index
            ))[0];
            challenge.constraints.append(constraint_node);
            constraint_index += 1;
        }

        hint_index = 1;
        for hint in generated.hints {
            hint_node = (challenge +>:contains:+> ChallengeHint(
                id=f"{challenge.id}-hint-{hint_index}",
                challenge_id=challenge.id,
                content=hint.content,
                order_index=hint_index
            ))[0];
            challenge.hints.append(hint_node);
            hint_index += 1;
        }

        criterion_index = 1;
        for criterion in generated.evaluation_criteria {
            criterion_node = (challenge +>:contains:+> ChallengeEvaluationCriterion(
                id=f"{challenge.id}-criterion-{criterion_index}",
                challenge_id=challenge.id,
                skill_id=criterion.skill_id,
                description=criterion.description,
                weight=criterion.weight,
                order_index=criterion_index
            ))[0];
            challenge.evaluation_criteria.append(criterion_node);
            challenge +>:evaluates:+> _get_or_create_skill(criterion.skill_id, language_normalized);
            criterion_index += 1;
        }

        for skill_id in roadmap_lesson.target_skill_ids {
            challenge +>:targets:+> _get_or_create_skill(skill_id, language_normalized);
        }

        report generated_challenge_to_view(challenge);
    }
}
