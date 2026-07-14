"""Roadmap visualization components."""

import from "lucide-react" {
    AlertCircle,
    BookOpen,
    CheckCircle2,
    Circle,
    Clock,
    Flag,
    Map,
    Network,
    RefreshCcw,
    Sparkles,
    LayoutDashboard
}
import from "@jac/runtime" { Link }
import from "....components.ui.button" { Button }
import from "....components.ui.card" {
    Card,
    CardContent,
    CardDescription,
    CardHeader,
    CardTitle
}
sv import from ....services.roadmap {
    RoadmapLessonView,
    RoadmapLoadState,
    RoadmapMilestoneView,
    RoadmapView,
    RoadmapWeekView
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

def _lesson_count(roadmap: RoadmapView) -> int {
    total = 0;
    for week in roadmap.weeks {
        total += len(week.lessons);
    }
    return total;
}

def _milestone_count(roadmap: RoadmapView) -> int {
    total = 0;
    for week in roadmap.weeks {
        total += len(week.milestones);
    }
    return total;
}

def _estimated_minutes(roadmap: RoadmapView) -> int {
    total = 0;
    for week in roadmap.weeks {
        for lesson in week.lessons {
            total += lesson.estimated_minutes;
        }
    }
    return total;
}

def _generated_lesson_count(roadmap: RoadmapView) -> int {
    total = 0;
    for week in roadmap.weeks {
        for lesson in week.lessons {
            if lesson.generation_status == "generated" {
                total += 1;
            }
        }
    }
    return total;
}

def _difficulty_badge_class(difficulty: str) -> str {
    if difficulty == "beginner" {
        return "border-state-success text-state-success";
    }
    if difficulty == "intermediate" {
        return "border-state-warning text-state-warning";
    }
    return "border-ai-text text-ai-text";
}

def _status_badge_class(status: str) -> str {
    if status == "generated" or status == "completed" {
        return "border-state-success text-state-success";
    }
    if status == "active" or status == "pending" {
        return "border-brand text-brand";
    }
    return "border-surface-border-subtle text-copy-muted";
}

def:pub StatusBadge(label: str, tone: str) -> JsxElement {
    return
        <span className={"inline-flex items-center gap-1 rounded-xl border bg-elevated px-2.5 py-1 text-xs font-medium " + _status_badge_class(tone)}>
            {label}
        </span>;
}

def:pub RoadmapHeader(roadmap: RoadmapView) -> JsxElement {
    return
        <header className="rounded-2xl border border-surface-border bg-surface p-6">
            <div className="flex flex-col gap-6 lg:flex-row lg:items-start lg:justify-between">
                <div className="flex max-w-3xl flex-col gap-3">
                    <div className="flex w-fit items-center gap-2 rounded-xl border border-surface-border-subtle bg-elevated px-3 py-2 text-sm text-copy-secondary">
                        <Map className="size-4 text-brand" />
                        Roadmap outline
                    </div>
                    <div>
                        <h1 className="text-3xl font-semibold leading-tight text-copy-primary md:text-4xl">{roadmap.title}</h1>
                        <p className="mt-3 text-base leading-7 text-copy-secondary">{roadmap.description}</p>
                    </div>
                </div>
                <div className="flex flex-wrap gap-2 lg:justify-end">
                    <StatusBadge label={_language_label(roadmap.language)} tone={roadmap.language} />
                    <StatusBadge label={roadmap.status} tone={roadmap.status} />
                    <span className="inline-flex items-center gap-1 rounded-xl border border-surface-border-subtle bg-elevated px-2.5 py-1 text-xs font-medium text-copy-secondary">
                        <Clock className="size-3.5 text-brand" />
                        {roadmap.estimated_weeks} weeks
                    </span>
                    <Button asChild={True} variant="outline">
                        <Link to={"/roadmap/" + roadmap.id + "/skill-map"}>
                            <Network className="size-4" />
                            Skill map
                        </Link>
                    </Button>
                    <Button asChild={True} variant="default">
                        <Link to={"/dashboard"}>
                            <LayoutDashboard className="size-4" />
                            Dashboard
                        </Link>
                    </Button>
                </div>
            </div>
        </header>;
}

def:pub RoadmapSummaryCards(roadmap: RoadmapView) -> JsxElement {
    total_lessons = _lesson_count(roadmap);
    generated_lessons = _generated_lesson_count(roadmap);
    return
        <section className="grid gap-4 md:grid-cols-2 xl:grid-cols-4" aria-label="Roadmap summary">
            <SummaryCard icon="weeks" label="Total weeks" value={str(len(roadmap.weeks))} detail={f"Estimated duration: {roadmap.estimated_weeks} weeks"} />
            <SummaryCard icon="lessons" label="Lesson outlines" value={str(total_lessons)} detail="Read-only lesson metadata" />
            <SummaryCard icon="milestones" label="Milestones" value={str(_milestone_count(roadmap))} detail="Checkpoint-style outcomes" />
            <SummaryCard icon="time" label="Learning time" value={f"{_estimated_minutes(roadmap)} min"} detail={f"{generated_lessons} generated, {total_lessons - generated_lessons} pending"} />
        </section>;
}

def:pub SummaryCard(icon: str, label: str, value: str, detail: str) -> JsxElement {
    return
        <Card className="border-surface-border bg-surface">
            <CardContent className="flex items-start gap-4">
                <div className="flex size-10 shrink-0 items-center justify-center rounded-xl border border-surface-border-subtle bg-elevated">
                    {if icon == "weeks" {
                        <Map className="size-5 text-brand" />
                    } elif icon == "lessons" {
                        <BookOpen className="size-5 text-brand" />
                    } elif icon == "milestones" {
                        <Flag className="size-5 text-ai-text" />
                    } else {
                        <Clock className="size-5 text-brand" />
                    }}
                </div>
                <div className="min-w-0">
                    <p className="text-sm text-copy-muted">{label}</p>
                    <p className="mt-1 text-2xl font-semibold text-copy-primary">{value}</p>
                    <p className="mt-1 text-sm leading-5 text-copy-secondary">{detail}</p>
                </div>
            </CardContent>
        </Card>;
}

def:pub RoadmapTimeline(roadmap: RoadmapView) -> JsxElement {
    return
        <section className="flex flex-col gap-4" aria-label="Roadmap timeline">
            <div className="flex items-center gap-2">
                <Sparkles className="size-5 text-ai-text" />
                <h2 className="text-xl font-semibold text-copy-primary">Course outline</h2>
            </div>
            {for week in roadmap.weeks {
                <RoadmapWeekCard key={week.id} week={week} roadmapId={roadmap.id} />
            }}
        </section>;
}

def:pub RoadmapWeekCard(week: RoadmapWeekView, roadmapId: str) -> JsxElement {
    return
        <Card className="border-surface-border bg-surface">
            <CardHeader>
                <div className="flex flex-col gap-3 md:flex-row md:items-start md:justify-between">
                    <div>
                        <p className="text-sm font-medium text-brand">Week {week.week_number}</p>
                        <CardTitle className="mt-1 text-xl">{week.title}</CardTitle>
                        <CardDescription className="mt-2 leading-6">{week.summary}</CardDescription>
                    </div>
                    <span className="inline-flex w-fit items-center gap-1 rounded-xl border border-surface-border-subtle bg-elevated px-2.5 py-1 text-xs text-copy-secondary">
                        <BookOpen className="size-3.5 text-brand" />
                        {len(week.lessons)} lessons
                    </span>
                </div>
            </CardHeader>
            <CardContent className="grid gap-5">
                <div className="grid gap-3" aria-label={f"Week {week.week_number} lessons"}>
                    {for lesson in week.lessons {
                        <RoadmapLessonItem key={lesson.id} lesson={lesson} roadmapId={roadmapId} />
                    }}
                </div>
                {if len(week.milestones) > 0 {
                    <div className="grid gap-3 border-t border-surface-border pt-4" aria-label={f"Week {week.week_number} milestones"}>
                        <h3 className="text-sm font-semibold text-copy-primary">Milestones</h3>
                        {for milestone in week.milestones {
                            <RoadmapMilestoneItem key={milestone.id} milestone={milestone} />
                        }}
                    </div>
                }}
            </CardContent>
        </Card>;
}

def:pub RoadmapLessonItem(lesson: RoadmapLessonView, roadmapId: str) -> JsxElement {
    status_icon = <CheckCircle2 className="size-4 text-state-success" /> if lesson.generation_status == "generated" else <Circle className="size-4 text-brand" />;
    return
        <article className="rounded-xl border border-surface-border-subtle bg-elevated p-4">
            <div className="flex flex-col gap-3 lg:flex-row lg:items-start lg:justify-between">
                <div className="min-w-0">
                    <div className="flex flex-wrap items-center gap-2">
                        <span className="rounded-xl border border-surface-border-subtle bg-surface px-2 py-1 text-xs text-copy-muted">
                            Lesson {lesson.order_index}
                        </span>
                        <span className={"rounded-xl border bg-surface px-2 py-1 text-xs font-medium " + _difficulty_badge_class(lesson.difficulty)}>
                            {lesson.difficulty}
                        </span>
                        <span className="inline-flex items-center gap-1 rounded-xl border border-surface-border-subtle bg-surface px-2 py-1 text-xs text-copy-secondary">
                            <Clock className="size-3.5 text-brand" />
                            {lesson.estimated_minutes} min
                        </span>
                    </div>
                    <h3 className="mt-3 text-base font-semibold text-copy-primary">{lesson.title}</h3>
                    <p className="mt-2 text-sm leading-6 text-copy-secondary">{lesson.summary}</p>
                </div>
                <div className="flex shrink-0 flex-col gap-2">
                    <div className="inline-flex w-fit items-center gap-2 rounded-xl border border-surface-border-subtle bg-surface px-3 py-2 text-sm text-copy-secondary">
                        {status_icon}
                        {lesson.generation_status}
                    </div>
                    <Button asChild={True} variant="outline" className="w-fit">
                        <Link to={"/roadmap/" + roadmapId + "/lesson/" + lesson.id}>
                            <BookOpen className="size-4" />
                            Open lesson
                        </Link>
                    </Button>
                </div>
            </div>
            <div className="mt-4 flex flex-wrap gap-2" aria-label="Target skills">
                {for skill_id in lesson.target_skill_ids {
                    <span key={skill_id} className="rounded-xl border border-surface-border-subtle bg-surface px-2.5 py-1 text-xs text-copy-secondary">
                        {skill_id}
                    </span>
                }}
            </div>
        </article>;
}

def:pub RoadmapMilestoneItem(milestone: RoadmapMilestoneView) -> JsxElement {
    return
        <article className="rounded-xl border border-surface-border-subtle bg-elevated p-4">
            <div className="flex items-start gap-3">
                <div className="flex size-8 shrink-0 items-center justify-center rounded-xl border border-surface-border-subtle bg-surface">
                    <Flag className="size-4 text-ai-text" />
                </div>
                <div className="min-w-0">
                    <h4 className="font-semibold text-copy-primary">{milestone.title}</h4>
                    <p className="mt-1 text-sm leading-6 text-copy-secondary">{milestone.description}</p>
                    <div className="mt-3 flex flex-wrap gap-2" aria-label="Required skills">
                        {for skill_id in milestone.required_skill_ids {
                            <span key={skill_id} className="rounded-xl border border-surface-border-subtle bg-surface px-2.5 py-1 text-xs text-copy-secondary">
                                {skill_id}
                            </span>
                        }}
                    </div>
                </div>
            </div>
        </article>;
}

def:pub RoadmapLoadingState() -> JsxElement {
    return
        <div className="flex flex-col gap-4" aria-label="Loading roadmap">
            <div className="h-48 animate-pulse rounded-2xl border border-surface-border bg-surface" />
            <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
                {for index in [1, 2, 3, 4] {
                    <div key={str(index)} className="h-28 animate-pulse rounded-2xl border border-surface-border bg-surface" />
                }}
            </div>
            <div className="grid gap-4">
                {for index in [1, 2] {
                    <div key={str(index)} className="h-64 animate-pulse rounded-2xl border border-surface-border bg-surface" />
                }}
            </div>
        </div>;
}

def:pub RoadmapStateCard(
    title: str,
    message: str,
    action_label: str,
    onAction: Callable[[], None],
    retry_label: str = "",
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
                    <Button onClick={lambda (e: MouseEvent) -> None { onAction(); }}>
                        <Map className="size-4" />
                        {action_label}
                    </Button>
                    {if onRetry is not None and retry_label != "" {
                        <Button variant="outline" onClick={lambda (e: MouseEvent) -> None { onRetry(); }}>
                            <RefreshCcw className="size-4" />
                            {retry_label}
                        </Button>
                    }}
                </CardContent>
            </Card>
        </div>;
}
