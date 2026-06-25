"""Initial assessment creation walker."""

import from edges.domain_edges { assigned }
import from lib.ai.utilities {
    GeneratedOption,
    GeneratedQuestion,
    GeneratedQuestionDifficulty,
    GeneratedQuestionType,
    generate_answer_options,
    generate_initial_assessment
}
import from nodes.assessment {
    Assessment,
    AssessmentDifficulty,
    AssessmentOption,
    AssessmentOptionLink,
    AssessmentQuestion,
    AssessmentQuestionLink,
    AssessmentQuestionType,
    AssessmentStatus
}
import from nodes.learner { Learner }

def _question_type_from_generated(question_type: GeneratedQuestionType) -> AssessmentQuestionType {
    if question_type == GeneratedQuestionType.MULTIPLE_CHOICE {
        return AssessmentQuestionType.multiple_choice;
    }
    return AssessmentQuestionType.short_answer;
}

def _difficulty_from_generated(difficulty: GeneratedQuestionDifficulty) -> AssessmentDifficulty {
    if difficulty == GeneratedQuestionDifficulty.ADVANCED {
        return AssessmentDifficulty.advanced;
    }
    if difficulty == GeneratedQuestionDifficulty.INTERMEDIATE {
        return AssessmentDifficulty.intermediate;
    }
    return AssessmentDifficulty.beginner;
}

def _option_values(question: GeneratedQuestion) -> list[GeneratedOption] {
    if question.question_type == GeneratedQuestionType.MULTIPLE_CHOICE and len(question.options) == 0 {
        return generate_answer_options(
            question.question_text,
            question.skill,
            question.difficulty
        );
    }
    return question.options;
}

walker initialize_assessment {
    has learner_id: str;
    has learner_goals: str;
    has learner_interests: list[str] = [];
    has learner_experience_level: str = "beginner";
    has target_skills: list[str] = [];
    has target_role: str = "";
    has assessment_length: int = 5;
    has created_at: str = "";
    has reports: list[Assessment] = [];

    can create with Root entry {
        prior_count = len([root -->[?:Assessment, learner_id == self.learner_id]]);
        assessment_id = f"{self.learner_id}-assessment-{prior_count + 1}";
        created_at_value = self.created_at if self.created_at != "" else "generated";
        generated = generate_initial_assessment(
            self.learner_goals,
            self.learner_interests,
            self.learner_experience_level,
            self.target_skills,
            self.target_role,
            self.assessment_length
        );

        assessment = (root ++> Assessment(
            id=assessment_id,
            learner_id=self.learner_id,
            title=generated.title,
            description=generated.description,
            status=AssessmentStatus.draft,
            created_at=created_at_value
        ))[0];

        for learner in [root -->[?:Learner, id == self.learner_id]] {
            learner +>:assigned:+> assessment;
        }

        question_index = 0;
        for generated_question in generated.questions {
            question_index += 1;
            question = (assessment +>:AssessmentQuestionLink:+> AssessmentQuestion(
                id=f"{assessment_id}-q{question_index}",
                question_text=generated_question.question_text,
                question_type=_question_type_from_generated(generated_question.question_type),
                skill=generated_question.skill,
                difficulty=_difficulty_from_generated(generated_question.difficulty)
            ))[0];
            assessment.questions.append(question);

            option_index = 0;
            for generated_option in _option_values(generated_question) {
                option_index += 1;
                option = (question +>:AssessmentOptionLink:+> AssessmentOption(
                    id=f"{question.id}-o{option_index}",
                    label=generated_option.label,
                    value=generated_option.value
                ))[0];
                question.options.append(option);
            }
        }

        report assessment;
    }
}
