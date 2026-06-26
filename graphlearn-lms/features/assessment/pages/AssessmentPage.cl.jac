"""Assessment-taking page."""

import from "..hooks.useAssessmentState" { useAssessmentState }
import from "..types.response_models" { QuestionResponse }
import from "..components.AssessmentComponents" {
    AssessmentContainer,
    AssessmentHeader,
    AssessmentProgress,
    AssessmentQuestion,
    AssessmentQuestionList,
    AssessmentNavigation,
    AssessmentLoadingState,
    AssessmentUnavailableState,
    AssessmentSuccessState
}
sv import from "....services.assessment" {
    AssessmentSubmissionReceipt,
    AssessmentView
}

def _contains_id(ids: list[str], target_id: str) -> bool {
    for item in ids {
        if item == target_id {
            return True;
        }
    }
    return False;
}

def:pub AssessmentPage() -> JsxElement {
    has current_index: int = 0;

    state = useAssessmentState("demo-learner");
    assessment: AssessmentView | None = state["assessment"] as AssessmentView | None;
    responses: list[QuestionResponse] = state["responses"] as list[QuestionResponse];
    invalid_question_ids: list[str] = state["invalid_question_ids"] as list[str];
    loading: bool = state["loading"] as bool;
    load_error: str = state["load_error"] as str;
    submitting: bool = state["submitting"] as bool;
    submission_error: str = state["submission_error"] as str;
    submission_receipt: AssessmentSubmissionReceipt | None = state["submission_receipt"] as AssessmentSubmissionReceipt | None;
    answered_count: int = state["answered_count"] as int;
    completion_percentage: int = state["completion_percentage"] as int;
    answer_multiple_choice: Callable[[str, str], None] = state["answer_multiple_choice"] as Callable[[str, str], None];
    answer_short: Callable[[str, str], None] = state["answer_short"] as Callable[[str, str], None];
    submit_assessment: Callable[[], None] = state["submit"] as Callable[[], None];
    question_count: int = 0;

    if assessment is not None {
        question_count = len(assessment.questions);
    }

    def previous_question() -> None {
        if current_index > 0 {
            current_index -= 1;
        }
    }

    def next_question() -> None {
        if current_index < question_count - 1 {
            current_index += 1;
        }
    }

    def select_question(index: int) -> None {
        current_index = index;
    }

    def submit_current() -> None {
        submit_assessment();
    }

    if loading {
        return
            <AssessmentContainer>
                <AssessmentLoadingState />
            </AssessmentContainer>;
    }

    if assessment is None {
        return
            <AssessmentContainer>
                <AssessmentUnavailableState
                    message={load_error if load_error != "" else "No assessment is currently assigned to this learner."}
                />
            </AssessmentContainer>;
    }

    if question_count == 0 {
        return
            <AssessmentContainer>
                <AssessmentHeader assessment={assessment} />
                <AssessmentUnavailableState message="This assessment does not contain any questions." />
            </AssessmentContainer>;
    }

    if submission_receipt is not None {
        return
            <AssessmentContainer>
                <AssessmentHeader assessment={assessment} />
                <AssessmentSuccessState
                    submission_id={submission_receipt.submission_id}
                    response_count={submission_receipt.response_count}
                />
            </AssessmentContainer>;
    }

    current_question = assessment.questions[current_index];
    current_response: QuestionResponse | None = None;
    for response in responses {
        if response.question_id == current_question.id {
            current_response = response;
        }
    }

    return
        <AssessmentContainer>
            <AssessmentHeader assessment={assessment} />
            <AssessmentProgress
                answered_count={answered_count}
                total_count={question_count}
                completion_percentage={completion_percentage}
                current_index={current_index}
            />
            {submission_error != "" and
                <div className="rounded-2xl border border-state-error bg-surface p-4 text-sm text-state-error">
                    {submission_error}
                </div>
            }
            <div className="grid flex-1 gap-6 lg:grid-cols-[16rem_1fr]">
                <AssessmentQuestionList
                    assessment={assessment}
                    responses={responses}
                    invalid_question_ids={invalid_question_ids}
                    current_index={current_index}
                    onSelectQuestion={select_question}
                />
                <main className="flex min-w-0 flex-col gap-4">
                    <AssessmentQuestion
                        question={current_question}
                        question_number={current_index + 1}
                        response={current_response}
                        invalid={_contains_id(invalid_question_ids, current_question.id)}
                        onMultipleChoice={answer_multiple_choice}
                        onShortAnswer={answer_short}
                    />
                    <AssessmentNavigation
                        current_index={current_index}
                        total_count={question_count}
                        submitting={submitting}
                        onPrevious={previous_question}
                        onNext={next_question}
                        onSubmit={submit_current}
                    />
                </main>
            </div>
        </AssessmentContainer>;
}
