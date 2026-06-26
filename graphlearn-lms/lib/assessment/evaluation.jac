"""Assessment evaluation domain services."""

import from nodes.assessment {
    Assessment,
    AssessmentQuestion,
    AssessmentQuestionType,
    AssessmentResponse,
    AssessmentScore,
    QuestionResult,
    SkillSignal
}

obj AssessmentEvaluationError {
    has code: str;
    has message: str;
}

obj AssessmentEvaluationOutcome {
    has score: AssessmentScore;
    has question_results: list[QuestionResult] = [];
    has skill_signals: list[SkillSignal] = [];
}

def _normalize_text(value: str) -> str {
    return value.strip().lower();
}

def _selected_values(answer_value: str) -> list[str] {
    values: list[str] = [];
    for raw_value in answer_value.split(",") {
        selected = raw_value.strip();
        if selected != "" {
            values = values + [selected];
        }
    }
    return values;
}

def _same_selection_set(selected: list[str], expected: list[str]) -> bool {
    if len(selected) != len(expected) {
        return False;
    }
    for value in selected {
        if value not in expected {
            return False;
        }
    }
    for value in expected {
        if value not in selected {
            return False;
        }
    }
    return True;
}

def _answer_key_valid(question: AssessmentQuestion) -> bool {
    if question.possible_points < 0 {
        return False;
    }
    if (
        question.question_type == AssessmentQuestionType.multiple_choice
        or question.question_type == AssessmentQuestionType.multi_select
        or question.question_type == AssessmentQuestionType.short_answer
    ) and len(question.answer_key) == 0 {
        return False;
    }
    return True;
}

def validate_evaluation_inputs(
    assessment: Assessment | None,
    responses: list[AssessmentResponse]
) -> list[AssessmentEvaluationError] {
    errors: list[AssessmentEvaluationError] = [];
    if assessment is None {
        return [
            AssessmentEvaluationError(
                code="missing_assessment",
                message="Assessment does not exist."
            )
        ];
    }

    response_question_ids: list[str] = [];
    for response in responses {
        response_question_ids = response_question_ids + [response.question_id];
    }

    for question in assessment.questions {
        if not _answer_key_valid(question) {
            errors = errors + [
                AssessmentEvaluationError(
                    code="invalid_answer_key",
                    message=f"Question {question.id} has an invalid answer key."
                )
            ];
        }
        if question.question_type not in [
            AssessmentQuestionType.multiple_choice,
            AssessmentQuestionType.multi_select,
            AssessmentQuestionType.short_answer
        ] {
            errors = errors + [
                AssessmentEvaluationError(
                    code="unsupported_question_type",
                    message=f"Question {question.id} uses an unsupported question type."
                )
            ];
        }
        if question.id not in response_question_ids {
            errors = errors + [
                AssessmentEvaluationError(
                    code="missing_response",
                    message=f"Question {question.id} does not have a submitted response."
                )
            ];
        }
    }
    return errors;
}

def _response_for_question(
    responses: list[AssessmentResponse],
    question_id: str
) -> AssessmentResponse | None {
    for response in responses {
        if response.question_id == question_id {
            return response;
        }
    }
    return None;
}

def _question_skill_ids(question: AssessmentQuestion) -> list[str] {
    if len(question.skill_ids) > 0 {
        return question.skill_ids;
    }
    if question.skill != "" {
        return [question.skill];
    }
    return [];
}

def _evaluate_question(
    assessment: Assessment,
    question: AssessmentQuestion,
    response: AssessmentResponse
) -> QuestionResult {
    correct = False;
    if question.question_type == AssessmentQuestionType.multiple_choice {
        correct = len(question.answer_key) == 1 and response.answer_value == question.answer_key[0];
    } elif question.question_type == AssessmentQuestionType.multi_select {
        correct = _same_selection_set(_selected_values(response.answer_value), question.answer_key);
    } elif question.question_type == AssessmentQuestionType.short_answer {
        strategy = question.short_answer_strategy if question.short_answer_strategy != "" else assessment.short_answer_strategy;
        if strategy == "normalized_text_match" {
            for expected in question.answer_key {
                if _normalize_text(response.answer_value) == _normalize_text(expected) {
                    correct = True;
                }
            }
        } else {
            for expected in question.answer_key {
                if response.answer_value == expected {
                    correct = True;
                }
            }
        }
    }
    earned_points = question.possible_points if correct else 0;
    return QuestionResult(
        question_id=question.id,
        correct=correct,
        earned_points=earned_points,
        possible_points=question.possible_points
    );
}

def _percentage(earned_points: int, possible_points: int) -> int {
    if possible_points == 0 {
        return 0;
    }
    return int((earned_points * 100) / possible_points);
}

def _aggregate_skill_signals(
    assessment: Assessment,
    question_results: list[QuestionResult]
) -> list[SkillSignal] {
    skill_ids: list[str] = [];
    correct_counts: list[int] = [];
    incorrect_counts: list[int] = [];

    for result in question_results {
        for question in assessment.questions {
            if question.id == result.question_id {
                for skill_id in _question_skill_ids(question) {
                    skill_index = -1;
                    index = 0;
                    for existing_skill_id in skill_ids {
                        if existing_skill_id == skill_id {
                            skill_index = index;
                        }
                        index += 1;
                    }
                    if skill_index == -1 {
                        skill_ids = skill_ids + [skill_id];
                        correct_counts = correct_counts + [0];
                        incorrect_counts = incorrect_counts + [0];
                        skill_index = len(skill_ids) - 1;
                    }
                    if result.correct {
                        correct_counts[skill_index] = correct_counts[skill_index] + 1;
                    } else {
                        incorrect_counts[skill_index] = incorrect_counts[skill_index] + 1;
                    }
                }
            }
        }
    }

    signals: list[SkillSignal] = [];
    index = 0;
    for skill_id in skill_ids {
        total = correct_counts[index] + incorrect_counts[index];
        accuracy = 0.0 if total == 0 else correct_counts[index] / total;
        signals = signals + [
            SkillSignal(
                skill_id=skill_id,
                correct_count=correct_counts[index],
                incorrect_count=incorrect_counts[index],
                accuracy=accuracy
            )
        ];
        index += 1;
    }
    return signals;
}

def evaluate_assessment_responses(
    assessment: Assessment,
    responses: list[AssessmentResponse]
) -> AssessmentEvaluationOutcome {
    question_results: list[QuestionResult] = [];
    earned_points = 0;
    possible_points = 0;

    for question in assessment.questions {
        response = _response_for_question(responses, question.id);
        if response is not None {
            result = _evaluate_question(assessment, question, response);
            question_results = question_results + [result];
            earned_points += result.earned_points;
            possible_points += result.possible_points;
        }
    }

    score = AssessmentScore(
        earned_points=earned_points,
        possible_points=possible_points,
        percentage=_percentage(earned_points, possible_points)
    );
    return AssessmentEvaluationOutcome(
        score=score,
        question_results=question_results,
        skill_signals=_aggregate_skill_signals(assessment, question_results)
    );
}
