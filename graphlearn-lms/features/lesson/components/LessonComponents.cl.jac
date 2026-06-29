"""Presentation components for the generated lesson viewer."""

import from "lucide-react" {
    AlertCircle,
    BookOpen,
    CheckCircle2,
    ChevronLeft,
    ChevronRight,
    Clock,
    Code2,
    Copy,
    RefreshCcw,
    Sparkles
}
import from "....components.ui.button" { Button }
import from "....components.ui.card" {
    Card,
    CardContent,
    CardDescription,
    CardHeader,
    CardTitle
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
    if tone == "beginner" or tone == "generated" {
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

def:pub LessonBadge(label: str, tone: str) -> JsxElement {
    return
        <span className={"inline-flex items-center gap-1 rounded-xl border bg-elevated px-2.5 py-1 text-xs font-medium " + _badge_class(tone)}>
            {label}
        </span>;
}

def:pub LessonHeader(
    lesson: any,
    onBack: Callable[[], None],
    readComplete: bool
) -> JsxElement {
    language: str = str(lesson.language);
    difficulty: str = str(lesson.difficulty);
    generation_status: str = str(lesson.generation_status);
    return
        <header className="rounded-2xl border border-surface-border bg-surface p-6">
            <div className="flex flex-col gap-5 lg:flex-row lg:items-start lg:justify-between">
                <div className="flex max-w-3xl flex-col gap-3">
                    <Button variant="ghost" className="w-fit text-copy-secondary" onClick={lambda (_e: MouseEvent) { onBack(); }}>
                        <ChevronLeft className="size-4" />
                        Back to roadmap
                    </Button>
                    <div>
                        <h1 className="text-3xl font-semibold leading-tight text-copy-primary md:text-4xl">{lesson.title}</h1>
                        <p className="mt-3 text-base leading-7 text-copy-secondary">{lesson.summary}</p>
                    </div>
                </div>
                <div className="flex flex-wrap gap-2 lg:justify-end">
                    <LessonBadge label={_language_label(language)} tone={language} />
                    <LessonBadge label={difficulty} tone={difficulty} />
                    <LessonBadge label={generation_status} tone={generation_status} />
                    {if readComplete {
                        <span className="inline-flex items-center gap-1 rounded-xl border border-state-success bg-elevated px-2.5 py-1 text-xs font-medium text-state-success">
                            <CheckCircle2 className="size-3.5" />
                            Read
                        </span>
                    }}
                    <span className="inline-flex items-center gap-1 rounded-xl border border-surface-border-subtle bg-elevated px-2.5 py-1 text-xs font-medium text-copy-secondary">
                        <Clock className="size-3.5 text-brand" />
                        {lesson.estimated_minutes} min
                    </span>
                </div>
            </div>
        </header>;
}

def:pub LessonSectionNav(
    sections: list[any],
    activeSectionId: str,
    onSelect: Callable[[str], None]
) -> JsxElement {
    return
        <nav className="rounded-2xl border border-surface-border bg-surface p-4" aria-label="Lesson sections">
            <div className="mb-3 flex items-center gap-2 text-sm font-semibold text-copy-primary">
                <BookOpen className="size-4 text-brand" />
                Sections
            </div>
            <div className="flex gap-2 overflow-x-auto lg:flex-col lg:overflow-visible">
                {for section in sections {
                    section_id: str = str(section.id);
                    active = section_id == activeSectionId;
                    <button
                        key={section_id}
                        type="button"
                        onClick={lambda (_e: MouseEvent) { onSelect(section_id); }}
                        className={"min-w-fit rounded-xl border px-3 py-2 text-left text-sm transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand " + ("border-brand bg-accent-dim text-brand" if active else "border-surface-border-subtle bg-elevated text-copy-secondary hover:text-copy-primary")}
                    >
                        <span className="text-xs text-copy-muted">Section {section.order_index}</span>
                        <span className="block font-medium">{section.title}</span>
                    </button>
                }}
            </div>
        </nav>;
}

def:pub LessonSectionCard(section: any) -> JsxElement {
    return
        <section id={section.id} className="rounded-2xl border border-surface-border bg-surface p-6">
            <p className="text-sm font-medium text-brand">Section {section.order_index}</p>
            <h2 className="mt-2 text-2xl font-semibold text-copy-primary">{section.title}</h2>
            <p className="mt-4 whitespace-pre-line text-base leading-8 text-copy-secondary">{section.content}</p>
        </section>;
}

def:pub LessonCodeExample(
    example: any,
    language: str,
    copiedId: str,
    onCopy: Callable[[str, str], None]
) -> JsxElement {
    example_id: str = str(example.id);
    code: str = str(example.code);
    title: str = str(example.title);
    copied = copiedId == example_id;
    return
        <article className="rounded-2xl border border-surface-border bg-surface">
            <div className="flex items-start justify-between gap-3 border-b border-surface-border px-4 py-3">
                <div>
                    <div className="flex items-center gap-2 text-sm font-semibold text-copy-primary">
                        <Code2 className="size-4 text-brand" />
                        {title}
                    </div>
                    <p className="mt-1 text-xs text-copy-muted">{language}</p>
                </div>
                <Button
                    variant="outline"
                    size="sm"
                    aria-label={"Copy code for " + title}
                    onClick={lambda (_e: MouseEvent) { onCopy(example_id, code); }}
                >
                    <Copy className="size-4" />
                    {"Copied" if copied else "Copy"}
                </Button>
            </div>
            <pre className="overflow-x-auto bg-elevated p-4 text-sm leading-6 text-copy-primary">
                <code className="font-mono">{code}</code>
            </pre>
            <p className="px-4 pt-3 text-sm leading-6 text-copy-secondary">{example.explanation}</p>
        </article>;
}

def:pub LessonMiniExercise(
    exercise: any,
    checked: bool,
    onToggle: Callable[[str], None]
) -> JsxElement {
    exercise_id: str = str(exercise.id);
    expected_concept: str = str(exercise.expected_concept);
    return
        <article className="rounded-2xl border border-surface-border bg-surface p-4">
            <div className="flex items-start gap-3">
                <input
                    type="checkbox"
                    checked={checked}
                    onChange={lambda (_e: ChangeEvent) { onToggle(exercise_id); }}
                    className="mt-1 size-4 rounded border-surface-border-subtle bg-elevated accent-brand focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
                    aria-label={"Mark understood: " + expected_concept}
                />
                <div>
                    <h3 className="font-semibold text-copy-primary">{exercise.prompt}</h3>
                    <p className="mt-2 text-sm text-copy-muted">Expected concept: {expected_concept}</p>
                </div>
            </div>
        </article>;
}

def:pub LessonTakeaways(takeaways: list[any]) -> JsxElement {
    return
        <aside className="rounded-2xl border border-surface-border bg-surface p-4" aria-label="Key takeaways">
            <div className="mb-3 flex items-center gap-2 text-sm font-semibold text-copy-primary">
                <Sparkles className="size-4 text-ai-text" />
                Key takeaways
            </div>
            <div className="grid gap-2">
                {for takeaway in takeaways {
                    <div key={takeaway.id} className="rounded-xl border border-surface-border-subtle bg-elevated p-3 text-sm leading-6 text-copy-secondary">
                        {takeaway.content}
                    </div>
                }}
            </div>
        </aside>;
}

def:pub LessonMetadataPanel(lesson: any, readComplete: bool, onComplete: Callable[[], None]) -> JsxElement {
    language: str = str(lesson.language);
    return
        <aside className="rounded-2xl border border-surface-border bg-surface p-4">
            <div className="flex items-center gap-2 text-sm font-semibold text-copy-primary">
                <BookOpen className="size-4 text-brand" />
                Lesson details
            </div>
            <dl className="mt-4 grid gap-3 text-sm">
                <div className="flex justify-between gap-3">
                    <dt className="text-copy-muted">Language</dt>
                    <dd className="text-copy-primary">{_language_label(language)}</dd>
                </div>
                <div className="flex justify-between gap-3">
                    <dt className="text-copy-muted">Difficulty</dt>
                    <dd className="text-copy-primary">{lesson.difficulty}</dd>
                </div>
                <div className="flex justify-between gap-3">
                    <dt className="text-copy-muted">Reading time</dt>
                    <dd className="text-copy-primary">{lesson.estimated_minutes} min</dd>
                </div>
            </dl>
            <Button className="mt-5 w-full" variant={"secondary" if readComplete else "default"} onClick={lambda (_e: MouseEvent) { onComplete(); }}>
                <CheckCircle2 className="size-4" />
                {"Lesson marked read" if readComplete else "Mark lesson as complete"}
            </Button>
        </aside>;
}

def:pub LessonNavigationActions(
    previousLesson: any,
    nextLesson: any,
    onNavigate: Callable[[str], None],
    onBack: Callable[[], None]
) -> JsxElement {
    return
        <div className="grid gap-3 rounded-2xl border border-surface-border bg-surface p-4 md:grid-cols-3">
            <Button variant="outline" onClick={lambda (_e: MouseEvent) { onBack(); }}>
                <ChevronLeft className="size-4" />
                Back to roadmap
            </Button>
            {if previousLesson is not None {
                prev = previousLesson;
                prev_id: str = str(prev.roadmap_lesson_id);
                <Button variant="outline" onClick={lambda (_e: MouseEvent) { onNavigate(prev_id); }}>
                    <ChevronLeft className="size-4" />
                    <span className="truncate">{prev.title}</span>
                </Button>
            } else {
                <Button variant="outline" disabled={True}>
                    <ChevronLeft className="size-4" />
                    First lesson
                </Button>
            }}
            {if nextLesson is not None {
                next = nextLesson;
                next_id: str = str(next.roadmap_lesson_id);
                <Button onClick={lambda (_e: MouseEvent) { onNavigate(next_id); }}>
                    <span className="truncate">{next.title}</span>
                    <ChevronRight className="size-4" />
                </Button>
            } else {
                <Button variant="outline" disabled={True}>
                    Last lesson
                    <ChevronRight className="size-4" />
                </Button>
            }}
        </div>;
}

def:pub LessonLoadingState(message: str) -> JsxElement {
    return
        <div className="flex min-h-[70vh] items-center justify-center">
            <div className="w-full max-w-3xl rounded-2xl border border-surface-border bg-surface p-6" role="status" aria-live="polite">
                <div className="flex items-center gap-3">
                    <div className="size-4 animate-spin rounded-full border-2 border-surface-border-subtle border-t-brand" />
                    <p className="font-semibold text-copy-primary">{message}</p>
                </div>
                <div className="mt-6 grid gap-3">
                    <div className="h-8 animate-pulse rounded-xl bg-elevated" />
                    <div className="h-24 animate-pulse rounded-xl bg-elevated" />
                    <div className="h-40 animate-pulse rounded-xl bg-elevated" />
                </div>
            </div>
        </div>;
}

def:pub LessonErrorState(
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
