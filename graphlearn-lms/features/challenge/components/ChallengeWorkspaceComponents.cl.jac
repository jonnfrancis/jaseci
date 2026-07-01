"""Presentation components for the coding challenge workspace."""

import from "lucide-react" {
    AlertCircle,
    BookOpen,
    CheckCircle2,
    ChevronLeft,
    Code2,
    Lightbulb,
    RefreshCcw,
    Send
}
import from "....components.ui.button" { Button }
import from "....components.ui.card" {
    Card,
    CardContent,
    CardDescription,
    CardHeader,
    CardTitle
}
import from "....components.ui.textarea" { Textarea }
sv import from ....services.challenge {
    GeneratedChallengeView
}

def _language_label(language: str) -> str {
    if language == "python" {
        return "Python";
    }
    if language == "jac" {
        return "Jac";
    }
    return "Unsupported";
}

def _badge_class(tone: str) -> str {
    if tone == "beginner" or tone == "submitted" {
        return "border-state-success text-state-success";
    }
    if tone == "intermediate" {
        return "border-state-warning text-state-warning";
    }
    if tone == "advanced" {
        return "border-ai-text text-ai-text";
    }
    return "border-brand text-brand";
}

def:pub ChallengeBadge(label: str, tone: str) -> JsxElement {
    return
        <span className={"inline-flex items-center gap-1 rounded-xl border bg-elevated px-2.5 py-1 text-xs font-medium " + _badge_class(tone)}>
            {label}
        </span>;
}

def:pub ChallengeHeader(
    challenge: GeneratedChallengeView,
    lessonTitle: str,
    onBack: Callable[[], None]
) -> JsxElement {
    language: str = str(challenge.language);
    difficulty: str = str(challenge.difficulty);
    return
        <header className="rounded-2xl border border-surface-border bg-surface p-5">
            <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
                <div className="flex max-w-4xl flex-col gap-3">
                    <Button variant="ghost" className="w-fit text-copy-secondary" onClick={lambda (_e: MouseEvent) { onBack(); }}>
                        <ChevronLeft className="size-4" />
                        Back to lesson
                    </Button>
                    <div>
                        <h1 className="text-2xl font-semibold leading-tight text-copy-primary md:text-3xl">{challenge.title}</h1>
                        {if lessonTitle != "" {
                            <p className="mt-2 inline-flex items-center gap-2 text-sm text-copy-muted">
                                <BookOpen className="size-4 text-brand" />
                                {lessonTitle}
                            </p>
                        }}
                    </div>
                </div>
                <div className="flex flex-wrap gap-2 lg:justify-end">
                    <ChallengeBadge label={_language_label(language)} tone={language} />
                    <ChallengeBadge label={difficulty} tone={difficulty} />
                    <span className="inline-flex items-center gap-1 rounded-xl border border-surface-border-subtle bg-elevated px-2.5 py-1 text-xs font-medium text-copy-secondary">
                        <Code2 className="size-3.5 text-brand" />
                        No execution yet
                    </span>
                </div>
            </div>
        </header>;
}

def:pub ChallengeInstructionsPanel(challenge: GeneratedChallengeView) -> JsxElement {
    return
        <aside className="flex flex-col gap-4 rounded-2xl border border-surface-border bg-surface p-4" aria-label="Challenge instructions">
            <div>
                <p className="text-sm font-semibold text-brand">Prompt</p>
                <p className="mt-2 text-sm leading-6 text-copy-secondary">{challenge.prompt}</p>
            </div>
            <div>
                <h2 className="text-sm font-semibold text-copy-primary">Instructions</h2>
                <ol className="mt-3 grid gap-2">
                    {for item in challenge.instructions {
                        <li key={item.id} className="rounded-xl border border-surface-border-subtle bg-elevated p-3 text-sm leading-6 text-copy-secondary">
                            <span className="mr-2 text-brand">{item.order_index}.</span>
                            {item.content}
                        </li>
                    }}
                </ol>
            </div>
            <div>
                <h2 className="text-sm font-semibold text-copy-primary">Expected outcomes</h2>
                <ul className="mt-3 grid gap-2">
                    {for outcome in challenge.expected_outcomes {
                        <li key={outcome.id} className="flex gap-2 rounded-xl border border-surface-border-subtle bg-elevated p-3 text-sm leading-6 text-copy-secondary">
                            <CheckCircle2 className="mt-0.5 size-4 shrink-0 text-state-success" />
                            <span>{outcome.content}</span>
                        </li>
                    }}
                </ul>
            </div>
            <div>
                <h2 className="text-sm font-semibold text-copy-primary">Constraints</h2>
                <ul className="mt-3 grid gap-2">
                    {for constraint in challenge.constraints {
                        <li key={constraint.id} className="rounded-xl border border-surface-border-subtle bg-elevated p-3 text-sm leading-6 text-copy-secondary">
                            {constraint.content}
                        </li>
                    }}
                </ul>
            </div>
        </aside>;
}

def:pub ChallengeEditor(
    code: str,
    language: str,
    validationMessage: str,
    onCodeChange: Callable[[str], None]
) -> JsxElement {
    def handle_change(e: ChangeEvent) {
        onCodeChange(str(e.target.value));
    }

    return
        <section className="flex min-h-[560px] flex-col rounded-2xl border border-surface-border bg-surface" aria-label="Code editor">
            <div className="flex items-center justify-between gap-3 border-b border-surface-border px-4 py-3">
                <div className="flex items-center gap-2 text-sm font-semibold text-copy-primary">
                    <Code2 className="size-4 text-brand" />
                    Solution editor
                </div>
                <span className="rounded-xl border border-surface-border-subtle bg-elevated px-2.5 py-1 text-xs text-copy-secondary">
                    {_language_label(language)}
                </span>
            </div>
            <label className="sr-only" htmlFor="challenge-code-editor">Challenge solution code</label>
            <Textarea
                id="challenge-code-editor"
                value={code}
                onChange={handle_change}
                spellCheck={False}
                aria-invalid={validationMessage != ""}
                aria-describedby={"challenge-code-error" if validationMessage != "" else ""}
                className="min-h-[500px] flex-1 resize-none rounded-none border-0 bg-elevated p-4 font-mono text-sm leading-6 text-copy-primary caret-brand placeholder:text-copy-muted focus-visible:ring-0"
            />
            {if validationMessage != "" {
                <p id="challenge-code-error" className="border-t border-surface-border px-4 py-3 text-sm text-state-error">
                    {validationMessage}
                </p>
            }}
        </section>;
}

def:pub ChallengeHintsPanel(
    challenge: GeneratedChallengeView,
    revealedCount: int,
    onReveal: Callable[[], None]
) -> JsxElement {
    total = len(challenge.hints);
    can_reveal = revealedCount < total;
    return
        <aside className="flex flex-col gap-4 rounded-2xl border border-surface-border bg-surface p-4" aria-label="Challenge hints">
            <div className="flex items-center justify-between gap-3">
                <div className="flex items-center gap-2 text-sm font-semibold text-copy-primary">
                    <Lightbulb className="size-4 text-state-warning" />
                    Hints
                </div>
                <span className="text-xs text-copy-muted">{revealedCount} / {total} shown</span>
            </div>
            <div className="grid gap-2">
                {for (index, hint) in enumerate(challenge.hints) {
                    shown = index < revealedCount;
                    <div key={hint.id} className="rounded-xl border border-surface-border-subtle bg-elevated p-3 text-sm leading-6 text-copy-secondary">
                        <p className="font-medium text-copy-primary">Hint {index + 1}</p>
                        <p className="mt-1">{hint.content if shown else "Reveal this hint when you want a nudge."}</p>
                    </div>
                }}
            </div>
            <Button variant="outline" disabled={not can_reveal} onClick={lambda (_e: MouseEvent) { onReveal(); }}>
                <Lightbulb className="size-4" />
                {"Reveal next hint" if can_reveal else "All hints shown"}
            </Button>
        </aside>;
}

def:pub ChallengeSubmitPanel(
    submissionId: str,
    saving: bool,
    successMessage: str,
    errorMessage: str,
    evaluationScore: int,
    evaluationPassed: bool,
    evaluationSummary: str,
    evaluationNextStep: str,
    onSubmit: Callable[[], None],
    onBack: Callable[[], None]
) -> JsxElement {
    has_evaluation = evaluationScore >= 0 or evaluationSummary != "";
    return
        <aside className="flex flex-col gap-4 rounded-2xl border border-surface-border bg-surface p-4" aria-label="Submit solution">
            <div>
                <h2 className="text-sm font-semibold text-copy-primary">Submit state</h2>
                <p className="mt-2 text-sm leading-6 text-copy-secondary">
                    Submit your solution for static evaluation. Passing feedback updates mastery and unlocks the next lesson.
                </p>
            </div>
            {if successMessage != "" {
                <div className="rounded-xl border border-state-success bg-elevated p-3 text-sm leading-6 text-state-success" role="status" aria-live="polite">
                    <CheckCircle2 className="mr-2 inline size-4" />
                    {successMessage}
                    {if submissionId != "" {
                        <span className="mt-1 block text-xs text-copy-muted">Submission id: {submissionId}</span>
                    }}
                </div>
            }}
            {if has_evaluation {
                <div className="rounded-xl border border-surface-border-subtle bg-elevated p-3 text-sm leading-6">
                    <div className="flex items-center justify-between gap-3">
                        <p className="font-medium text-copy-primary">Evaluation</p>
                        {if evaluationScore >= 0 {
                            <span className={"rounded-xl border px-2.5 py-1 text-xs font-medium " + ("border-state-success text-state-success" if evaluationPassed else "border-state-warning text-state-warning")}>
                                {evaluationScore}%
                            </span>
                        }}
                    </div>
                    {if evaluationSummary != "" {
                        <p className="mt-2 text-copy-secondary">{evaluationSummary}</p>
                    }}
                    {if evaluationNextStep != "" {
                        <p className="mt-2 text-copy-muted">{evaluationNextStep}</p>
                    }}
                </div>
            }}
            {if errorMessage != "" {
                <div className="rounded-xl border border-state-error bg-elevated p-3 text-sm leading-6 text-state-error" role="alert">
                    <AlertCircle className="mr-2 inline size-4" />
                    {errorMessage}
                </div>
            }}
            <Button disabled={saving} onClick={lambda (_e: MouseEvent) { onSubmit(); }}>
                <Send className="size-4" />
                {"Evaluating solution..." if saving else "Submit for evaluation"}
            </Button>
            <Button variant="outline" onClick={lambda (_e: MouseEvent) { onBack(); }}>
                <ChevronLeft className="size-4" />
                Return to lesson
            </Button>
        </aside>;
}

def:pub ChallengeCriteriaPanel(challenge: GeneratedChallengeView) -> JsxElement {
    return
        <aside className="rounded-2xl border border-surface-border bg-surface p-4" aria-label="What this challenge checks">
            <h2 className="text-sm font-semibold text-copy-primary">What this challenge checks</h2>
            <div className="mt-3 grid gap-2">
                {for criterion in challenge.evaluation_criteria {
                    <div key={criterion.id} className="rounded-xl border border-surface-border-subtle bg-elevated p-3">
                        <p className="text-sm font-medium text-copy-primary">{criterion.skill_id}</p>
                        <p className="mt-1 text-sm leading-6 text-copy-secondary">{criterion.description}</p>
                    </div>
                }}
            </div>
        </aside>;
}

def:pub ChallengeLoadingState(message: str) -> JsxElement {
    return
        <div className="flex min-h-[70vh] items-center justify-center">
            <div className="w-full max-w-4xl rounded-2xl border border-surface-border bg-surface p-6" role="status" aria-live="polite">
                <div className="flex items-center gap-3">
                    <div className="size-4 animate-spin rounded-full border-2 border-surface-border-subtle border-t-brand" />
                    <p className="font-semibold text-copy-primary">{message}</p>
                </div>
                <div className="mt-6 grid gap-4 lg:grid-cols-[280px_minmax(0,1fr)_280px]">
                    <div className="h-72 animate-pulse rounded-2xl bg-elevated" />
                    <div className="h-96 animate-pulse rounded-2xl bg-elevated" />
                    <div className="h-72 animate-pulse rounded-2xl bg-elevated" />
                </div>
            </div>
        </div>;
}

def:pub ChallengeErrorState(
    title: str,
    message: str,
    actionLabel: str,
    onAction: Callable[[], None],
    retryLabel: str = "",
    onRetry: Callable[[], None] | None = None
) -> JsxElement {
    return
        <div className="flex min-h-[70vh] items-center justify-center">
            <Card className="w-full max-w-2xl border-surface-border bg-surface">
                <CardHeader>
                    <div className="flex items-start gap-3">
                        <div className="flex size-10 shrink-0 items-center justify-center rounded-xl border border-surface-border-subtle bg-elevated">
                            <AlertCircle className="size-5 text-state-warning" />
                        </div>
                        <div>
                            <CardTitle className="text-xl">{title}</CardTitle>
                            <CardDescription className="mt-2 leading-6">{message}</CardDescription>
                        </div>
                    </div>
                </CardHeader>
                <CardContent className="flex flex-wrap gap-3">
                    <Button onClick={lambda (_e: MouseEvent) { onAction(); }}>
                        {actionLabel}
                    </Button>
                    {if onRetry is not None and retryLabel != "" {
                        <Button variant="outline" onClick={lambda (_e: MouseEvent) { onRetry(); }}>
                            <RefreshCcw className="size-4" />
                            {retryLabel}
                        </Button>
                    }}
                </CardContent>
            </Card>
        </div>;
}
