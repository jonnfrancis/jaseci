"""Reusable assessment-taking UI components."""

import from "....components.ui.button" { Button }
import from "....components.ui.card" {
    Card,
    CardContent,
    CardDescription,
    CardFooter,
    CardHeader,
    CardTitle
}
import from "....components.ui.dialog" {
    Dialog,
    DialogTrigger,
    DialogContent,
    DialogHeader,
    DialogTitle,
    DialogDescription,
    DialogFooter
}
import from "....components.ui.input" { Input }
import from "....components.ui.textarea" { Textarea }
import from "....components.ui.scroll_area" { ScrollArea }
import from "lucide-react" {
    AlertCircle,
    ArrowLeft,
    ArrowRight,
    CheckCircle2,
    Circle,
    Send
}
import from "..types.response_models" { QuestionResponse }
sv import from ....services.assessment { AssessmentQuestionView, AssessmentView }

def _response_for_question(responses: list[QuestionResponse], question_id: str) -> QuestionResponse | None {
    for response in responses {
        if response.question_id == question_id {
            return response;
        }
    }
    return None;
}

def _question_answered(responses: list[QuestionResponse], question_id: str) -> bool {
    response = _response_for_question(responses, question_id);
    if response is None {
        return False;
    }
    if response.question_type == "multiple_choice" {
        return response.selected_option_id != "";
    }
    return response.short_answer.strip() != "";
}

def _contains_id(ids: list[str], target_id: str) -> bool {
    for item in ids {
        if item == target_id {
            return True;
        }
    }
    return False;
}

def:pub MultipleChoiceOption(
    question_id: str,
    option_id: str,
    label: str,
    value: str,
    selected_option_id: str,
    onMultipleChoice: Callable[[str, str], None]
) -> JsxElement {
    selected = selected_option_id == option_id;

    def handle_change(e: ChangeEvent) {
        onMultipleChoice(question_id, option_id);
    }

    return
        <label
            className={"flex cursor-pointer items-start gap-3 rounded-xl border p-4 transition-colors focus-within:ring-2 focus-within:ring-brand " + ("border-brand bg-accent-dim" if selected else "border-surface-border-subtle bg-elevated")}
        >
            <input
                type="radio"
                name={question_id}
                value={option_id}
                checked={selected}
                onChange={handle_change}
                className="mt-1 size-4 accent-brand"
            />
            <span className="flex flex-col gap-1">
                <span className="text-sm font-medium text-copy-primary">{label}</span>
                <span className="text-sm text-copy-secondary">{value}</span>
            </span>
        </label>;
}

def:pub ShortAnswerResponseField(
    question_id: str,
    answer_text: str,
    invalid: bool,
    onShortAnswer: Callable[[str, str], None]
) -> JsxElement {
    def handle_change(e: ChangeEvent) {
        onShortAnswer(question_id, e.target.value);
    }

    return
        <div className="flex flex-col gap-2">
            <label htmlFor={question_id} className="text-sm font-medium text-copy-secondary">
                Response
            </label>
            <Textarea
                id={question_id}
                value={answer_text}
                onChange={handle_change}
                placeholder="Write your answer here."
                aria-invalid={invalid}
                className="min-h-36 bg-elevated text-copy-primary caret-brand placeholder:text-copy-muted"
            />
        </div>;
}

def:pub AssessmentQuestionIndexButton(
    index: int,
    question_type: str,
    answered: bool,
    invalid: bool,
    active: bool,
    onSelectQuestion: Callable[[int], None]
) -> JsxElement {
    def handle_click(e: MouseEvent) {
        onSelectQuestion(index);
    }

    return
        <button
            type="button"
            onClick={handle_click}
            className={"flex items-center justify-between rounded-xl border px-3 py-2 text-left text-sm transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand " + ("border-brand bg-accent-dim" if active else "border-surface-border-subtle bg-elevated")}
        >
            <span className="flex items-center gap-2">
                {answered and not invalid
                    and <CheckCircle2 className="size-4 text-state-success" />}
                {not answered and not invalid
                    and <Circle className="size-4 text-copy-faint" />}
                {invalid
                    and <AlertCircle className="size-4 text-state-error" />}
                <span>Question {index + 1}</span>
            </span>
            <span className="text-xs text-copy-muted">{question_type}</span>
        </button>;
}

def:pub AssessmentContainer(children: any = None) -> JsxElement {
    return
        <section className="min-h-screen bg-base text-copy-primary">
            <div className="mx-auto flex min-h-screen max-w-7xl flex-col gap-6 px-6 py-6">
                {children}
            </div>
        </section>;
}

def:pub AssessmentHeader(assessment: AssessmentView) -> JsxElement {
    return
        <header className="rounded-2xl border border-surface-border bg-surface p-5">
            <div className="flex flex-col gap-3 lg:flex-row lg:items-start lg:justify-between">
                <div className="flex max-w-3xl flex-col gap-2">
                    <p className="text-sm font-medium text-brand">Initial assessment</p>
                    <h1 className="text-2xl font-semibold leading-tight">{assessment.title}</h1>
                    <p className="text-sm leading-6 text-copy-secondary">{assessment.description}</p>
                </div>
                <div className="rounded-xl border border-surface-border-subtle bg-elevated px-3 py-2 text-sm text-copy-secondary">
                    <div className="flex min-w-56 flex-col gap-2">
                        <span>{len(assessment.questions)} questions</span>
                        <Input
                            aria-label="Learner identifier"
                            value={assessment.learner_id}
                            readOnly={True}
                            className="h-8 bg-surface text-xs text-copy-primary caret-brand placeholder:text-copy-muted"
                        />
                    </div>
                </div>
            </div>
        </header>;
}

def:pub AssessmentProgress(
    answered_count: int,
    total_count: int,
    completion_percentage: int,
    current_index: int
) -> JsxElement {
    return
        <div className="rounded-2xl border border-surface-border bg-surface p-4">
            <div className="flex flex-col gap-3">
                <div className="flex flex-wrap items-center justify-between gap-3 text-sm">
                    <span className="text-copy-secondary">
                        Question {current_index + 1} of {total_count}
                    </span>
                    <span className="text-copy-secondary">
                        {answered_count} answered | {completion_percentage}%
                    </span>
                </div>
                <div
                    className="h-2 overflow-hidden rounded-xl bg-elevated"
                    role="progressbar"
                    aria-valuemin={0}
                    aria-valuemax={100}
                    aria-valuenow={completion_percentage}
                    aria-label="Assessment completion"
                >
                    <div
                        className="h-full rounded-xl bg-brand transition-all"
                        style={{"width": f"{completion_percentage}%"}}
                    />
                </div>
            </div>
        </div>;
}

def:pub AssessmentQuestion(
    question: AssessmentQuestionView,
    question_number: int,
    response: QuestionResponse | None,
    invalid: bool,
    onMultipleChoice: Callable[[str, str], None],
    onShortAnswer: Callable[[str, str], None]
) -> JsxElement {
    selected_option_id = response.selected_option_id if response is not None else "";
    short_answer = response.short_answer if response is not None else "";

    return
        <Card className={"border-state-error bg-surface" if invalid else "border-surface-border bg-surface"}>
            <CardHeader className="gap-3">
                <div className="flex flex-wrap items-center gap-2 text-xs text-copy-muted">
                    <span className="rounded-xl border border-surface-border-subtle bg-elevated px-2 py-1">
                        Question {question_number}
                    </span>
                    <span className="rounded-xl border border-surface-border-subtle bg-elevated px-2 py-1">
                        {question.skill}
                    </span>
                    <span className="rounded-xl border border-surface-border-subtle bg-elevated px-2 py-1">
                        {question.difficulty}
                    </span>
                </div>
                <CardTitle className="text-xl leading-8">{question.question_text}</CardTitle>
                {invalid and
                    <CardDescription className="flex items-center gap-2 text-state-error">
                        <AlertCircle className="size-4" />
                        This question is required.
                    </CardDescription>
                }
            </CardHeader>
            <CardContent className="flex flex-col gap-3">
                {if question.question_type == "multiple_choice" {
                    for option in question.options {
                        <MultipleChoiceOption
                            key={option.id}
                            question_id={question.id}
                            option_id={option.id}
                            label={option.label}
                            value={option.value}
                            selected_option_id={selected_option_id}
                            onMultipleChoice={onMultipleChoice}
                        />
                    }
                } elif question.question_type == "short_answer" {
                    <ShortAnswerResponseField
                        question_id={question.id}
                        answer_text={short_answer}
                        invalid={invalid}
                        onShortAnswer={onShortAnswer}
                    />
                } else {
                    <p className="rounded-xl border border-state-warning bg-elevated p-4 text-sm text-copy-secondary">
                        This question type is not available in the current assessment UI.
                    </p>
                }}
            </CardContent>
        </Card>;
}

def:pub AssessmentQuestionList(
    assessment: AssessmentView,
    responses: list[QuestionResponse],
    invalid_question_ids: list[str],
    current_index: int,
    onSelectQuestion: Callable[[int], None]
) -> JsxElement {
    return
        <aside className="rounded-2xl border border-surface-border bg-surface p-4">
            <div className="flex flex-col gap-4">
                <div>
                    <h2 className="text-sm font-semibold">Questions</h2>
                    <p className="mt-1 text-sm text-copy-muted">Answered state updates as you work.</p>
                </div>
                <ScrollArea className="max-h-[28rem]">
                    <div className="flex flex-col gap-2 pr-3">
                        {for (index, question) in enumerate(assessment.questions) {
                            answered = _question_answered(responses, question.id);
                            invalid = _contains_id(invalid_question_ids, question.id);
                            <AssessmentQuestionIndexButton
                                key={question.id}
                                index={index}
                                question_type={question.question_type}
                                answered={answered}
                                invalid={invalid}
                                active={index == current_index}
                                onSelectQuestion={onSelectQuestion}
                            />
                        }}
                    </div>
                </ScrollArea>
            </div>
        </aside>;
}

def:pub AssessmentNavigation(
    current_index: int,
    total_count: int,
    submitting: bool,
    onPrevious: Callable[[], None],
    onNext: Callable[[], None],
    onSubmit: Callable[[], None]
) -> JsxElement {
    return
        <div className="sticky bottom-4 z-10 rounded-2xl border border-surface-border bg-surface/95 p-3 backdrop-blur">
            <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                <div className="flex items-center gap-2">
                    <Button
                        variant="outline"
                        onClick={lambda (e: MouseEvent) -> None { onPrevious(); }}
                        disabled={current_index == 0}
                    >
                        <ArrowLeft className="size-4" />
                        Previous
                    </Button>
                    <Button
                        variant="outline"
                        onClick={lambda (e: MouseEvent) -> None { onNext(); }}
                        disabled={current_index >= total_count - 1}
                    >
                        Next
                        <ArrowRight className="size-4" />
                    </Button>
                </div>
                <AssessmentSubmitDialog submitting={submitting} onSubmit={onSubmit} />
            </div>
        </div>;
}

def:pub AssessmentSubmitDialog(
    submitting: bool,
    onSubmit: Callable[[], None]
) -> JsxElement {
    return
        <Dialog>
            <DialogTrigger asChild={True}>
                <Button>
                    <Send className="size-4" />
                    Submit assessment
                </Button>
            </DialogTrigger>
            <DialogContent className="rounded-3xl bg-subtle">
                <DialogHeader>
                    <DialogTitle className="text-lg font-semibold">
                        Submit assessment
                    </DialogTitle>
                    <DialogDescription>
                        Your answers will be saved for later learner-outcome workflows.
                    </DialogDescription>
                </DialogHeader>
                <DialogFooter>
                    <Button
                        onClick={lambda (e: MouseEvent) -> None { onSubmit(); }}
                        disabled={submitting}
                    >
                        { "Submitting..." if submitting else "Save responses" }
                    </Button>
                </DialogFooter>
            </DialogContent>
        </Dialog>;
}

def:pub AssessmentLoadingState() -> JsxElement {
    return
        <Card className="border-surface-border bg-surface">
            <CardHeader>
                <CardTitle>Loading assessment</CardTitle>
                <CardDescription>Preparing the assessment workspace.</CardDescription>
            </CardHeader>
            <CardContent className="grid gap-3">
                <div className="h-5 rounded-xl bg-elevated" />
                <div className="h-28 rounded-xl bg-elevated" />
                <div className="h-10 rounded-xl bg-elevated" />
            </CardContent>
        </Card>;
}

def:pub AssessmentUnavailableState(message: str) -> JsxElement {
    return
        <Card className="border-surface-border bg-surface">
            <CardHeader>
                <CardTitle>Assessment unavailable</CardTitle>
                <CardDescription>{message}</CardDescription>
            </CardHeader>
            <CardContent>
                <p className="rounded-xl border border-surface-border-subtle bg-elevated p-4 text-sm text-copy-secondary">
                    Create an assessment with the initialization walker, then return here to take it.
                </p>
            </CardContent>
        </Card>;
}

def:pub AssessmentSuccessState(
    submission_id: str,
    response_count: int
) -> JsxElement {
    return
        <Card className="border-state-success bg-surface">
            <CardHeader>
                <CardTitle className="flex items-center gap-2">
                    <CheckCircle2 className="size-5 text-state-success" />
                    Assessment submitted
                </CardTitle>
                <CardDescription>
                    {response_count} responses were saved. Submission {submission_id}.
                </CardDescription>
            </CardHeader>
        </Card>;
}
