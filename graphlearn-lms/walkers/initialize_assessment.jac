"""Initial assessment creation walker."""

import from edges.domain_edges { assigned }
import from lib.observability.instrumentation { ai_call_completed, ai_call_started, observe_walker_finish, observe_walker_start }
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
    has selected_language: str = "";
    has track_id: str | None = None;
    has track_version_id: str | None = None;
    has reports: list[Assessment] = [];
    has request_id: str = "";
    has correlation_id: str = "";

    can observability_start with Root entry { observe_walker_start(self); }
    can observability_finish with Root exit { observe_walker_finish(self); }

    can create with Root entry {
        prior_count = len([root -->[?:Assessment, learner_id == self.learner_id]]);
        assessment_id = f"{self.learner_id}-assessment-{prior_count + 1}";
        created_at_value = self.created_at if self.created_at != "" else "generated";

        if self.selected_language == "Python" or self.selected_language == "Jac" {
            language = self.selected_language;
            assessment = (root ++> Assessment(
                id=assessment_id,
                learner_id=self.learner_id,
                title=f"{language} readiness assessment",
                description=f"A short assessment covering foundational {language} concepts.",
                status=AssessmentStatus.active,
                created_at=created_at_value,
                short_answer_strategy="normalized_text_match"
                , track_id=self.track_id
                , track_version_id=self.track_version_id
            ))[0];

            for learner in [root -->[?:Learner, id == self.learner_id]] {
                learner +>:assigned:+> assessment;
            }

            if language == "Python" {
                if prior_count % 2 == 1 {
                    q1 = (assessment +>:AssessmentQuestionLink:+> AssessmentQuestion(
                        id=f"{assessment_id}-q1",
                        question_text="Which Python collection stores key-value pairs?",
                        question_type=AssessmentQuestionType.multiple_choice,
                        skill="Python Data Structures",
                        difficulty=AssessmentDifficulty.beginner,
                        possible_points=1
                    ))[0];
                    q1 +>:AssessmentOptionLink:+> AssessmentOption(id=f"{q1.id}-o1", label="list", value="list");
                    q1o2 = (q1 +>:AssessmentOptionLink:+> AssessmentOption(id=f"{q1.id}-o2", label="dict", value="dict"))[0];
                    q1 +>:AssessmentOptionLink:+> AssessmentOption(id=f"{q1.id}-o3", label="tuple", value="tuple");
                    q1.options = [q1 ->:AssessmentOptionLink:->][?:AssessmentOption];
                    q1.answer_key = [q1o2.id];

                    q2 = (assessment +>:AssessmentQuestionLink:+> AssessmentQuestion(
                        id=f"{assessment_id}-q2",
                        question_text="Which statement repeats a block while a condition remains true?",
                        question_type=AssessmentQuestionType.multiple_choice,
                        skill="Python Control Flow",
                        difficulty=AssessmentDifficulty.beginner,
                        possible_points=1
                    ))[0];
                    q2o1 = (q2 +>:AssessmentOptionLink:+> AssessmentOption(id=f"{q2.id}-o1", label="while", value="while"))[0];
                    q2 +>:AssessmentOptionLink:+> AssessmentOption(id=f"{q2.id}-o2", label="match", value="match");
                    q2 +>:AssessmentOptionLink:+> AssessmentOption(id=f"{q2.id}-o3", label="import", value="import");
                    q2.options = [q2 ->:AssessmentOptionLink:->][?:AssessmentOption];
                    q2.answer_key = [q2o1.id];

                    q3 = (assessment +>:AssessmentQuestionLink:+> AssessmentQuestion(
                        id=f"{assessment_id}-q3",
                        question_text="Name the Python keyword used to send a value back from a function.",
                        question_type=AssessmentQuestionType.short_answer,
                        skill="Python Functions",
                        difficulty=AssessmentDifficulty.beginner,
                        answer_key=["return"],
                        possible_points=1,
                        short_answer_strategy="normalized_text_match"
                    ))[0];
                    assessment.questions = [q1, q2, q3];
                    report assessment;
                    return;
                }

                q1 = (assessment +>:AssessmentQuestionLink:+> AssessmentQuestion(
                    id=f"{assessment_id}-q1",
                    question_text="Which keyword defines a function in Python?",
                    question_type=AssessmentQuestionType.multiple_choice,
                    skill="Python Functions",
                    difficulty=AssessmentDifficulty.beginner,
                    possible_points=1
                ))[0];
                q1o1 = (q1 +>:AssessmentOptionLink:+> AssessmentOption(id=f"{q1.id}-o1", label="def", value="def"))[0];
                q1 +>:AssessmentOptionLink:+> AssessmentOption(id=f"{q1.id}-o2", label="func", value="func");
                q1 +>:AssessmentOptionLink:+> AssessmentOption(id=f"{q1.id}-o3", label="let", value="let");
                q1.options = [q1o1] + [q1 ->:AssessmentOptionLink:->][?:AssessmentOption, id != q1o1.id];
                q1.answer_key = [q1o1.id];

                q2 = (assessment +>:AssessmentQuestionLink:+> AssessmentQuestion(
                    id=f"{assessment_id}-q2",
                    question_text="What value does range(3) produce when iterated?",
                    question_type=AssessmentQuestionType.multiple_choice,
                    skill="Python Control Flow",
                    difficulty=AssessmentDifficulty.beginner,
                    possible_points=1
                ))[0];
                q2 +>:AssessmentOptionLink:+> AssessmentOption(id=f"{q2.id}-o1", label="1, 2, 3", value="1, 2, 3");
                q2o2 = (q2 +>:AssessmentOptionLink:+> AssessmentOption(id=f"{q2.id}-o2", label="0, 1, 2", value="0, 1, 2"))[0];
                q2 +>:AssessmentOptionLink:+> AssessmentOption(id=f"{q2.id}-o3", label="0, 1, 2, 3", value="0, 1, 2, 3");
                q2.options = [q2 ->:AssessmentOptionLink:->][?:AssessmentOption];
                q2.answer_key = [q2o2.id];

                q3 = (assessment +>:AssessmentQuestionLink:+> AssessmentQuestion(
                    id=f"{assessment_id}-q3",
                    question_text="Name the Python data type used for true or false values.",
                    question_type=AssessmentQuestionType.short_answer,
                    skill="Python Fundamentals",
                    difficulty=AssessmentDifficulty.beginner,
                    answer_key=["bool", "boolean"],
                    possible_points=1,
                    short_answer_strategy="normalized_text_match"
                ))[0];
                assessment.questions = [q1, q2, q3];
            } else {
                if prior_count % 2 == 1 {
                    q1 = (assessment +>:AssessmentQuestionLink:+> AssessmentQuestion(
                        id=f"{assessment_id}-q1",
                        question_text="Which Jac syntax declares persistent graph data?",
                        question_type=AssessmentQuestionType.multiple_choice,
                        skill="Jac Nodes",
                        difficulty=AssessmentDifficulty.beginner,
                        possible_points=1
                    ))[0];
                    q1 +>:AssessmentOptionLink:+> AssessmentOption(id=f"{q1.id}-o1", label="obj", value="obj");
                    q1o2 = (q1 +>:AssessmentOptionLink:+> AssessmentOption(id=f"{q1.id}-o2", label="node", value="node"))[0];
                    q1 +>:AssessmentOptionLink:+> AssessmentOption(id=f"{q1.id}-o3", label="glob", value="glob");
                    q1.options = [q1 ->:AssessmentOptionLink:->][?:AssessmentOption];
                    q1.answer_key = [q1o2.id];

                    q2 = (assessment +>:AssessmentQuestionLink:+> AssessmentQuestion(
                        id=f"{assessment_id}-q2",
                        question_text="Which Jac statement sends a walker to connected nodes?",
                        question_type=AssessmentQuestionType.multiple_choice,
                        skill="Jac Traversal",
                        difficulty=AssessmentDifficulty.beginner,
                        possible_points=1
                    ))[0];
                    q2o1 = (q2 +>:AssessmentOptionLink:+> AssessmentOption(id=f"{q2.id}-o1", label="visit", value="visit"))[0];
                    q2 +>:AssessmentOptionLink:+> AssessmentOption(id=f"{q2.id}-o2", label="report", value="report");
                    q2 +>:AssessmentOptionLink:+> AssessmentOption(id=f"{q2.id}-o3", label="import", value="import");
                    q2.options = [q2 ->:AssessmentOptionLink:->][?:AssessmentOption];
                    q2.answer_key = [q2o1.id];

                    q3 = (assessment +>:AssessmentQuestionLink:+> AssessmentQuestion(
                        id=f"{assessment_id}-q3",
                        question_text="Name the Jac statement used by walkers to emit a result.",
                        question_type=AssessmentQuestionType.short_answer,
                        skill="Jac Walkers",
                        difficulty=AssessmentDifficulty.beginner,
                        answer_key=["report"],
                        possible_points=1,
                        short_answer_strategy="normalized_text_match"
                    ))[0];
                    assessment.questions = [q1, q2, q3];
                    report assessment;
                    return;
                }

                q1 = (assessment +>:AssessmentQuestionLink:+> AssessmentQuestion(
                    id=f"{assessment_id}-q1",
                    question_text="Which Jac construct moves behavior through graph nodes?",
                    question_type=AssessmentQuestionType.multiple_choice,
                    skill="Jac Walkers",
                    difficulty=AssessmentDifficulty.beginner,
                    possible_points=1
                ))[0];
                q1o1 = (q1 +>:AssessmentOptionLink:+> AssessmentOption(id=f"{q1.id}-o1", label="Walker", value="walker"))[0];
                q1 +>:AssessmentOptionLink:+> AssessmentOption(id=f"{q1.id}-o2", label="Enum", value="enum");
                q1 +>:AssessmentOptionLink:+> AssessmentOption(id=f"{q1.id}-o3", label="Package", value="package");
                q1.options = [q1 ->:AssessmentOptionLink:->][?:AssessmentOption];
                q1.answer_key = [q1o1.id];

                q2 = (assessment +>:AssessmentQuestionLink:+> AssessmentQuestion(
                    id=f"{assessment_id}-q2",
                    question_text="What Jac archetype represents persistent graph data?",
                    question_type=AssessmentQuestionType.multiple_choice,
                    skill="Jac Nodes",
                    difficulty=AssessmentDifficulty.beginner,
                    possible_points=1
                ))[0];
                q2 +>:AssessmentOptionLink:+> AssessmentOption(id=f"{q2.id}-o1", label="Walker", value="walker");
                q2o2 = (q2 +>:AssessmentOptionLink:+> AssessmentOption(id=f"{q2.id}-o2", label="Node", value="node"))[0];
                q2 +>:AssessmentOptionLink:+> AssessmentOption(id=f"{q2.id}-o3", label="Ability", value="ability");
                q2.options = [q2 ->:AssessmentOptionLink:->][?:AssessmentOption];
                q2.answer_key = [q2o2.id];

                q3 = (assessment +>:AssessmentQuestionLink:+> AssessmentQuestion(
                    id=f"{assessment_id}-q3",
                    question_text="Name the graph relationship construct used to connect Jac nodes.",
                    question_type=AssessmentQuestionType.short_answer,
                    skill="Jac Edges",
                    difficulty=AssessmentDifficulty.beginner,
                    answer_key=["edge", "edges"],
                    possible_points=1,
                    short_answer_strategy="normalized_text_match"
                ))[0];
                assessment.questions = [q1, q2, q3];
            }

            report assessment;
            return;
        }

        ai_started = ai_call_started("initialize_assessment", "generate_initial_assessment", self.request_id, self.correlation_id, {"assessment_length": self.assessment_length});
        generated = generate_initial_assessment(
            self.learner_goals,
            self.learner_interests,
            self.learner_experience_level,
            self.target_skills,
            self.target_role,
            self.assessment_length
        );
        ai_call_completed("initialize_assessment", "generate_initial_assessment", self.request_id, self.correlation_id, ai_started);

        assessment = (root ++> Assessment(
            id=assessment_id,
            learner_id=self.learner_id,
            title=generated.title,
            description=generated.description,
            status=AssessmentStatus.draft,
            created_at=created_at_value
            , track_id=self.track_id
            , track_version_id=self.track_version_id
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
