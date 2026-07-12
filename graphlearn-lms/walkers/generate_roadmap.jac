"""Personalized roadmap generation walker."""

import from datetime { datetime }
import from byllm.lib { ByLLMError }
import from edges.domain_edges { assigned, contains, requires, targets }
import from lib.ai.utilities {
    GeneratedRoadmapLesson,
    GeneratedRoadmapMilestone,
    GeneratedRoadmapWeek,
    RoadmapGenerationResult,
    RoadmapSkillSignalContext,
    generate_learning_roadmap_outline,
    standard_ai_error_policy
}
import from lib.graph.assessment_queries { assessment_attempt_for, attempt_evaluation_for }
import from lib.graph.roadmap_queries { roadmap_for }
import from nodes.assessment {
    Assessment,
    AssessmentAttempt,
    AssessmentAttemptLink,
    AssessmentEvaluation,
    AssessmentEvaluationLink,
    SkillSignal
}
import from nodes.learner { Learner }
import from nodes.roadmap {
    Roadmap,
    RoadmapLesson,
    RoadmapLessonGenerationStatus,
    RoadmapMilestone,
    RoadmapStatus,
    RoadmapWeek
}
import from nodes.skill { Skill }

obj RoadmapGenerationError {
    has code: str;
    has message: str;
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

def _find_assessment(assessment_id: str) -> Assessment | None {
    for assessment in [root -->][?:Assessment, id == assessment_id] {
        return assessment;
    }
    return None;
}

def get_roadmap(roadmap_id: str) -> Roadmap | None {
    return roadmap_for(roadmap_id);
}

def get_existing_active_roadmap(
    learner_id: str,
    language: str,
    assessment_id: str,
    attempt_id: str,
    evaluation_id: str
) -> Roadmap | None {
    for roadmap in [root -->][?:Roadmap] {
        if (
            roadmap.learner_id == learner_id
            and roadmap.language == language
            and roadmap.assessment_id == assessment_id
            and roadmap.assessment_attempt_id == attempt_id
            and roadmap.assessment_evaluation_id == evaluation_id
            and roadmap.status == RoadmapStatus.active
        ) {
            return roadmap;
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

def _skill_context(signals: list[SkillSignal]) -> list[RoadmapSkillSignalContext] {
    context: list[RoadmapSkillSignalContext] = [];
    for signal in signals {
        context = context + [
            RoadmapSkillSignalContext(
                skill_id=signal.skill_id,
                correct_count=signal.correct_count,
                incorrect_count=signal.incorrect_count,
                accuracy=signal.accuracy
            )
        ];
    }
    return context;
}

def _target_level(score: int) -> str {
    if score < 40 {
        return "beginner foundations";
    }
    if score < 75 {
        return "intermediate applied fluency";
    }
    return "advanced practical mastery";
}

def _assessment_summary(
    language: str,
    assessment: Assessment,
    attempt: AssessmentAttempt,
    evaluation: AssessmentEvaluation,
    weak_skills: list[str],
    strong_skills: list[str]
) -> str {
    return (
        f"Language: {language}. Assessment: {assessment.title}. "
        + f"Attempt: {attempt.id}. Score: {evaluation.score.percentage}%. "
        + f"Weak skills: {', '.join(weak_skills)}. "
        + f"Strong skills: {', '.join(strong_skills)}."
    );
}

def _roadmap_output_errors(result: RoadmapGenerationResult) -> list[RoadmapGenerationError] {
    errors: list[RoadmapGenerationError] = [];
    if result.title.strip() == "" {
        errors = errors + [RoadmapGenerationError(code="invalid_ai_output", message="Roadmap title is required.")];
    }
    if result.description.strip() == "" {
        errors = errors + [RoadmapGenerationError(code="invalid_ai_output", message="Roadmap description is required.")];
    }
    if result.estimated_weeks <= 0 {
        errors = errors + [RoadmapGenerationError(code="invalid_ai_output", message="Estimated weeks must be positive.")];
    }
    if len(result.weeks) == 0 {
        errors = errors + [RoadmapGenerationError(code="invalid_ai_output", message="At least one roadmap week is required.")];
    }
    for week in result.weeks {
        if week.week_number <= 0 or week.title.strip() == "" {
            errors = errors + [RoadmapGenerationError(code="invalid_ai_output", message="Each roadmap week needs a positive number and title.")];
        }
        if len(week.lessons) == 0 {
            errors = errors + [RoadmapGenerationError(code="invalid_ai_output", message=f"Week {week.week_number} needs lesson outlines.")];
        }
        for lesson in week.lessons {
            if lesson.title.strip() == "" or lesson.summary.strip() == "" {
                errors = errors + [RoadmapGenerationError(code="invalid_ai_output", message="Each roadmap lesson needs a title and summary.")];
            }
            if len(lesson.target_skill_ids) == 0 {
                errors = errors + [RoadmapGenerationError(code="invalid_ai_output", message=f"Lesson {lesson.title} needs target skills.")];
            }
            if lesson.estimated_minutes <= 0 or lesson.order_index <= 0 {
                errors = errors + [RoadmapGenerationError(code="invalid_ai_output", message=f"Lesson {lesson.title} has invalid ordering or duration.")];
            }
        }
        for milestone in week.milestones {
            if milestone.title.strip() == "" or milestone.description.strip() == "" {
                errors = errors + [RoadmapGenerationError(code="invalid_ai_output", message="Each milestone needs a title and description.")];
            }
            if len(milestone.required_skill_ids) == 0 {
                errors = errors + [RoadmapGenerationError(code="invalid_ai_output", message=f"Milestone {milestone.title} needs required skills.")];
            }
        }
    }
    return errors;
}

def _get_or_create_skill(skill_id: str, language: str) -> Skill {
    for skill in [root -->][?:Skill, id == skill_id] {
        return skill;
    }
    return (root ++> Skill(
        id=skill_id,
        name=skill_id,
        description="Roadmap target skill placeholder for later lesson generation.",
        category=language
    ))[0];
}

walker generate_roadmap {
    has learner_id: str;
    has assessment_id: str;
    has assessment_attempt_id: str;
    has assessment_evaluation_id: str;
    has language: str;
    has errors: list[RoadmapGenerationError] = [];
    has reports: list[Roadmap] = [];

    can generate with Root entry {
        language_normalized = self.language.strip().lower();
        if language_normalized not in ["python", "jac"] {
            self.errors = self.errors + [
                RoadmapGenerationError(
                    code="unsupported_language",
                    message="Roadmaps currently support python and jac only."
                )
            ];
            return;
        }

        learner = _find_learner(self.learner_id);
        if learner is None {
            self.errors = self.errors + [RoadmapGenerationError(code="missing_learner", message="Learner does not exist.")];
            return;
        }
        assessment = _find_assessment(self.assessment_id);
        if assessment is None {
            self.errors = self.errors + [RoadmapGenerationError(code="missing_assessment", message="Assessment does not exist.")];
            return;
        }
        attempt = assessment_attempt_for(assessment, self.assessment_attempt_id);
        if attempt is None {
            self.errors = self.errors + [RoadmapGenerationError(code="missing_attempt", message="Assessment attempt does not exist.")];
            return;
        }
        evaluation = attempt_evaluation_for(attempt, self.assessment_evaluation_id);
        if evaluation is None {
            self.errors = self.errors + [RoadmapGenerationError(code="missing_evaluation", message="Assessment evaluation does not exist.")];
            return;
        }
        if evaluation.learner_id != self.learner_id or attempt.learner_id != self.learner_id {
            self.errors = self.errors + [RoadmapGenerationError(code="learner_mismatch", message="Assessment data does not belong to this learner.")];
            return;
        }
        if len(evaluation.skill_signals) == 0 {
            self.errors = self.errors + [RoadmapGenerationError(code="invalid_skill_signals", message="Assessment evaluation has no skill signals.")];
            return;
        }

        # Idempotency: return the existing active roadmap for this learner/language/evaluation.
        existing = get_existing_active_roadmap(
            self.learner_id,
            language_normalized,
            self.assessment_id,
            self.assessment_attempt_id,
            self.assessment_evaluation_id
        );
        if existing is not None {
            report existing;
            return;
        }

        weak = _weak_skills(evaluation.skill_signals);
        strong = _strong_skills(evaluation.skill_signals);
        target_level = _target_level(evaluation.score.percentage);
        summary = _assessment_summary(language_normalized, assessment, attempt, evaluation, weak, strong);

        try {
            generated = generate_learning_roadmap_outline(
                language_normalized,
                summary,
                evaluation.score.percentage,
                _skill_context(evaluation.skill_signals),
                weak,
                strong,
                target_level
            );
        } except ByLLMError as e {
            policy = standard_ai_error_policy(e);
            self.errors = self.errors + [
                RoadmapGenerationError(
                    code=f"ai_{policy.kind}",
                    message=policy.user_message
                )
            ];
            return;
        }

        self.errors = _roadmap_output_errors(generated);
        if len(self.errors) > 0 {
            return;
        }

        roadmap_id = f"roadmap-{self.learner_id}-{language_normalized}-{self.assessment_evaluation_id}";
        roadmap = (root ++> Roadmap(
            id=roadmap_id,
            learner_id=self.learner_id,
            language=language_normalized,
            title=generated.title,
            description=generated.description,
            estimated_weeks=generated.estimated_weeks,
            status=RoadmapStatus.active,
            created_at=_current_timestamp(),
            assessment_id=self.assessment_id,
            assessment_attempt_id=self.assessment_attempt_id,
            assessment_evaluation_id=self.assessment_evaluation_id
        ))[0];
        learner +>:assigned:+> roadmap;

        for generated_week in generated.weeks {
            week_id = f"{roadmap.id}-week-{generated_week.week_number}";
            week = (roadmap +>:contains:+> RoadmapWeek(
                id=week_id,
                roadmap_id=roadmap.id,
                week_number=generated_week.week_number,
                title=generated_week.title,
                summary=generated_week.summary
            ))[0];
            roadmap.weeks.append(week);

            for generated_lesson in generated_week.lessons {
                lesson_id = f"{week.id}-lesson-{generated_lesson.order_index}";
                lesson = (week +>:contains:+> RoadmapLesson(
                    id=lesson_id,
                    roadmap_id=roadmap.id,
                    week_id=week.id,
                    title=generated_lesson.title,
                    summary=generated_lesson.summary,
                    target_skill_ids=generated_lesson.target_skill_ids,
                    difficulty=generated_lesson.difficulty,
                    estimated_minutes=generated_lesson.estimated_minutes,
                    order_index=generated_lesson.order_index,
                    generation_status=RoadmapLessonGenerationStatus.pending
                ))[0];
                week.lessons.append(lesson);
                roadmap.lessons.append(lesson);
                for skill_id in generated_lesson.target_skill_ids {
                    lesson +>:targets:+> _get_or_create_skill(skill_id, language_normalized);
                }
            }

            milestone_index = 1;
            for generated_milestone in generated_week.milestones {
                milestone = (week +>:contains:+> RoadmapMilestone(
                    id=f"{week.id}-milestone-{milestone_index}",
                    roadmap_id=roadmap.id,
                    week_id=week.id,
                    title=generated_milestone.title,
                    description=generated_milestone.description,
                    required_skill_ids=generated_milestone.required_skill_ids
                ))[0];
                week.milestones.append(milestone);
                roadmap.milestones.append(milestone);
                for skill_id in generated_milestone.required_skill_ids {
                    milestone +>:requires:+> _get_or_create_skill(skill_id, language_normalized);
                }
                milestone_index += 1;
            }
        }

        report roadmap;
    }
}
