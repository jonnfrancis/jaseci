"""Presentation components for the learner dashboard."""

import from "lucide-react" {
    Activity,
    AlertCircle,
    ArrowRight,
    BookOpen,
    Brain,
    CheckCircle2,
    Clock,
    Code2,
    LayoutDashboard,
    Map,
    RefreshCcw
}
import from "@jac/runtime" { Link }
import from "....lib.utils" { format_datetime }
import from "....components.ui.button" { Button }
import from "....components.ui.card" {
    Card,
    CardContent,
    CardDescription,
    CardHeader,
    CardTitle
}
sv import from ....services.dashboard {
    DashboardChallengeSummary,
    DashboardCurrentLesson,
    DashboardLessonSummary,
    DashboardLoadState,
    DashboardMasterySummary,
    DashboardRecentActivity,
    DashboardRoadmapProgress,
    DashboardSkillSummary,
    DashboardView
}

def _language_label(language: str) -> str {
    if language == "python" {
        return "Python";
    }
    if language == "jac" {
        return "Jac";
    }
    return "Learning path";
}

def _state_label(state: str) -> str {
    if state == "no_assessment" {
        return "Assessment needed";
    }
    if state == "assessment_started" {
        return "Assessment in progress";
    }
    if state == "roadmap_missing" {
        return "Roadmap pending";
    }
    if state == "roadmap_ready" {
        return "Roadmap ready";
    }
    if state == "completed" {
        return "Completed";
    }
    return "In progress";
}

def _status_class(status: str) -> str {
    if status == "completed" or status == "generated" or status == "mastered" {
        return "border-state-success text-state-success";
    }
    if status == "failed" or status == "missing_learner" {
        return "border-state-error text-state-error";
    }
    if status == "pending" or status == "roadmap_ready" {
        return "border-state-warning text-state-warning";
    }
    return "border-brand text-brand";
}

def _title_case(value: str) -> str {
    clean = value.replace("_", " ").strip();
    if clean == "" {
        return "Unknown";
    }
    return clean.title();
}

def _progress_width(percent: int) -> str {
    if percent < 0 {
        return "0%";
    }
    if percent > 100 {
        return "100%";
    }
    return f"{percent}%";
}

def _roadmap_id(dashboard: DashboardView) -> str {
    if dashboard.active_roadmap is None {
        return "";
    }
    return (dashboard.active_roadmap as any).roadmap_id as str;
}

def _roadmap_title(dashboard: DashboardView) -> str {
    if dashboard.active_roadmap is None {
        return "No active roadmap";
    }
    return (dashboard.active_roadmap as any).title as str;
}

def _roadmap_language(dashboard: DashboardView) -> str {
    if dashboard.active_roadmap is None {
        return "";
    }
    return (dashboard.active_roadmap as any).language as str;
}

def:pub DashboardHeader(dashboard: DashboardView) -> JsxElement {
    language = _roadmap_language(dashboard);
    roadmap_title = _roadmap_title(dashboard);
    return
        <header className="rounded-2xl border border-surface-border bg-surface p-6">
            <div className="flex flex-col gap-5 lg:flex-row lg:items-start lg:justify-between">
                <div className="flex max-w-3xl flex-col gap-3">
                    <div className="flex w-fit items-center gap-2 rounded-xl border border-surface-border-subtle bg-elevated px-3 py-2 text-sm text-copy-secondary">
                        <LayoutDashboard className="size-4 text-brand" />
                        Learner dashboard
                    </div>
                    <div>
                        <h1 className="text-3xl font-semibold leading-tight text-copy-primary md:text-4xl">
                            Welcome back, {dashboard.learner.name}.
                        </h1>
                        <p className="mt-3 text-base leading-7 text-copy-secondary">
                            {("Continue your " + _language_label(language) + " roadmap: " + roadmap_title + ".") if dashboard.active_roadmap is not None else "Start your assessment to build a personalized roadmap."}
                        </p>
                    </div>
                </div>
                <div className="flex flex-wrap gap-2 lg:justify-end">
                    {language != "" and <StatusPill label={_language_label(language)} tone={language} />}
                    <StatusPill label={_state_label(dashboard.dashboard_state)} tone={dashboard.dashboard_state} />
                    {dashboard.active_roadmap is not None and
                        <StatusPill label={(dashboard.active_roadmap as any).status as str} tone={(dashboard.active_roadmap as any).status as str} />
                    }
                </div>
            </div>
        </header>;
}

def:pub StatusPill(label: str, tone: str) -> JsxElement {
    return
        <span className={"inline-flex items-center gap-1 rounded-xl border bg-elevated px-2.5 py-1 text-xs font-medium " + _status_class(tone)}>
            {label}
        </span>;
}

def:pub DashboardStatePanel(dashboard: DashboardView) -> JsxElement {
    state = dashboard.dashboard_state;
    title = "Continue learning";
    message = "Your dashboard is ready.";
    action_label = "Continue learning";
    action_to = "/assessment";
    icon = "dashboard";
    roadmap_id = _roadmap_id(dashboard);

    if state == "no_assessment" {
        title = "Start your assessment";
        message = "Start your assessment to build a personalized roadmap.";
        action_label = "Start assessment";
        action_to = "/assessment";
        icon = "assessment";
    } elif state == "assessment_started" {
        title = "Your assessment is in progress";
        message = "Continue your assessment so GraphLearn can finish your learner profile.";
        action_label = "Continue assessment";
        action_to = "/assessment";
        icon = "assessment";
    } elif state == "roadmap_missing" {
        title = "Your assessment is complete";
        message = "Generate your roadmap from the existing assessment results flow to continue.";
        action_label = "Go to results";
        action_to = "/assessment";
        icon = "roadmap";
    } elif state == "roadmap_ready" {
        title = "Your roadmap is ready";
        message = "View the roadmap outline and open the first lesson when you are ready.";
        action_label = "View roadmap";
        action_to = "/roadmap/" + roadmap_id if roadmap_id != "" else "/assessment";
        icon = "roadmap";
    } elif state == "completed" {
        title = "Roadmap completed";
        message = "You completed this roadmap. Certificates are intentionally out of scope for this dashboard.";
        action_label = "View roadmap";
        action_to = "/roadmap/" + roadmap_id if roadmap_id != "" else "/assessment";
        icon = "complete";
    }

    return
        <Card className="border-surface-border bg-surface">
            <CardHeader>
                <div className="flex items-start gap-3">
                    <div className="flex size-10 shrink-0 items-center justify-center rounded-xl border border-surface-border-subtle bg-elevated">
                        {if icon == "assessment" {
                            <Brain className="size-5 text-ai-text" />
                        } elif icon == "roadmap" {
                            <Map className="size-5 text-brand" />
                        } elif icon == "complete" {
                            <CheckCircle2 className="size-5 text-state-success" />
                        } else {
                            <LayoutDashboard className="size-5 text-brand" />
                        }}
                    </div>
                    <div>
                        <CardTitle className="text-lg font-semibold">{title}</CardTitle>
                        <CardDescription className="mt-2 leading-6">{message}</CardDescription>
                    </div>
                </div>
            </CardHeader>
            <CardContent className="flex flex-wrap gap-3">
                <Button asChild={True}>
                    <Link to={action_to}>
                        {action_label}
                        <ArrowRight className="size-4" />
                    </Link>
                </Button>
            </CardContent>
        </Card>;
}

def:pub RoadmapProgressCard(dashboard: DashboardView) -> JsxElement {
    progress = dashboard.roadmap_progress;
    roadmap_id = _roadmap_id(dashboard);
    return
        <Card className="border-surface-border bg-surface">
            <CardHeader>
                <div className="flex items-start justify-between gap-3">
                    <div>
                        <CardTitle className="text-lg font-semibold">Current roadmap</CardTitle>
                        <CardDescription className="mt-2">{_roadmap_title(dashboard)}</CardDescription>
                    </div>
                    <Map className="size-5 text-brand" />
                </div>
            </CardHeader>
            <CardContent className="grid gap-4">
                <div className="flex items-end justify-between gap-3">
                    <div>
                        <p className="text-sm text-copy-muted">Progress</p>
                        <p className="mt-1 text-3xl font-semibold text-copy-primary">{progress.percent_complete}%</p>
                    </div>
                    <p className="text-sm text-copy-secondary">{progress.completed_lessons} of {progress.total_lessons} lessons completed</p>
                </div>
                <div className="h-2 overflow-hidden rounded-xl bg-elevated" aria-label={f"{progress.percent_complete}% roadmap complete"}>
                    <div className="h-full rounded-xl bg-brand" style={{"width": _progress_width(progress.percent_complete)}} />
                </div>
                <div className="grid grid-cols-3 gap-2 text-sm">
                    <MiniStat label="Available" value={str(progress.available_lessons)} />
                    <MiniStat label="Locked" value={str(progress.locked_lessons)} />
                    <MiniStat label="Total" value={str(progress.total_lessons)} />
                </div>
                {roadmap_id != "" and
                    <Button asChild={True} variant="outline" className="w-fit">
                        <Link to={"/roadmap/" + roadmap_id}>
                            <Map className="size-4" />
                            View roadmap
                        </Link>
                    </Button>
                }
            </CardContent>
        </Card>;
}

def:pub CurrentLessonCard(dashboard: DashboardView) -> JsxElement {
    current = dashboard.current_lesson;
    roadmap_id = _roadmap_id(dashboard);
    if current is None {
        return
            <Card className="border-surface-border bg-surface">
                <CardHeader>
                    <CardTitle className="text-lg font-semibold">Current lesson</CardTitle>
                    <CardDescription>No current lesson is available yet.</CardDescription>
                </CardHeader>
                <CardContent>
                    <Button asChild={True} variant="outline">
                        <Link to={"/roadmap/" + roadmap_id if roadmap_id != "" else "/assessment"}>
                            <Map className="size-4" />
                            { "View roadmap" if roadmap_id != "" else "Go to assessment" }
                        </Link>
                    </Button>
                </CardContent>
            </Card>;
    }
    lesson = current as DashboardCurrentLesson;
    lesson_to = "/roadmap/" + roadmap_id + "/lesson/" + lesson.roadmap_lesson_id if roadmap_id != "" else "/assessment";
    action_label = "Continue lesson" if lesson.generated_lesson_id != "" else "Open lesson";
    return
        <Card className="border-surface-border bg-surface">
            <CardHeader>
                <div className="flex items-start justify-between gap-3">
                    <div>
                        <CardTitle className="text-lg font-semibold">Current lesson</CardTitle>
                        <CardDescription className="mt-2">Week {lesson.week_number} - Lesson {lesson.order_index}</CardDescription>
                    </div>
                    <BookOpen className="size-5 text-brand" />
                </div>
            </CardHeader>
            <CardContent className="grid gap-4">
                <div>
                    <h2 className="text-xl font-semibold text-copy-primary">{lesson.title}</h2>
                    <p className="mt-2 text-sm leading-6 text-copy-secondary">{lesson.summary if lesson.summary != "" else "Open this lesson to continue your learning path."}</p>
                </div>
                <div className="flex flex-wrap gap-2">
                    <StatusPill label={_title_case(lesson.status)} tone={lesson.status} />
                    <StatusPill label={"Lesson " + _title_case(lesson.generation_status)} tone={lesson.generation_status} />
                    {lesson.challenge_id != "" and <StatusPill label="Challenge ready" tone="generated" />}
                </div>
                <Button asChild={True} className="w-fit">
                    <Link to={lesson_to}>
                        <BookOpen className="size-4" />
                        {action_label}
                    </Link>
                </Button>
            </CardContent>
        </Card>;
}

def:pub MasterySummaryCard(summary: DashboardMasterySummary, roadmapId: str) -> JsxElement {
    return
        <Card className="border-surface-border bg-surface">
            <CardHeader>
                <div className="flex items-start justify-between gap-3">
                    <div>
                        <CardTitle className="text-lg font-semibold">Mastery summary</CardTitle>
                        <CardDescription className="mt-2">Persisted skill mastery only.</CardDescription>
                    </div>
                    <Brain className="size-5 text-ai-text" />
                </div>
            </CardHeader>
            <CardContent className="grid gap-4">
                <div className="flex items-end justify-between gap-3">
                    <div>
                        <p className="text-sm text-copy-muted">Average mastery</p>
                        <p className="mt-1 text-3xl font-semibold text-copy-primary">{summary.average_mastery}%</p>
                    </div>
                    <p className="text-sm text-copy-secondary">{summary.mastered_count} mastered</p>
                </div>
                <div className="grid grid-cols-2 gap-2 text-sm">
                    <MiniStat label="Proficient" value={str(summary.proficient_count)} />
                    <MiniStat label="Developing" value={str(summary.developing_count)} />
                    <MiniStat label="Beginner" value={str(summary.beginner_count)} />
                    <MiniStat label="Mastered" value={str(summary.mastered_count)} />
                </div>
                <Button asChild={True} variant="outline" className="w-fit">
                    <Link to={"/roadmap/" + roadmapId + "/skill-map" if roadmapId != "" else "/skill-map"}>
                        <Brain className="size-4" />
                        View skill map
                    </Link>
                </Button>
            </CardContent>
        </Card>;
}

def:pub SkillSummaryList(title: str, skills: list[DashboardSkillSummary], emptyMessage: str) -> JsxElement {
    return
        <Card className="border-surface-border bg-surface">
            <CardHeader>
                <CardTitle className="text-lg font-semibold">{title}</CardTitle>
                <CardDescription>{emptyMessage if len(skills) == 0 else "Top persisted mastery signals."}</CardDescription>
            </CardHeader>
            <CardContent>
                {if len(skills) == 0 {
                    <p className="rounded-xl border border-surface-border-subtle bg-elevated p-4 text-sm text-copy-secondary">{emptyMessage}</p>
                } else {
                    <ul className="grid gap-2">
                        {for skill in skills {
                            <li key={skill.skill_id} className="flex flex-wrap items-center justify-between gap-2 rounded-xl border border-surface-border-subtle bg-elevated p-3 text-sm">
                                <span className="font-medium text-copy-primary">{skill.name if skill.name != "" else skill.skill_id}</span>
                                <span className="text-copy-secondary">{skill.score}% - {_title_case(skill.level)}</span>
                            </li>
                        }}
                    </ul>
                }}
            </CardContent>
        </Card>;
}

def:pub LessonSummaryCard(summary: DashboardLessonSummary) -> JsxElement {
    return
        <Card className="border-surface-border bg-surface">
            <CardHeader>
                <div className="flex items-start justify-between gap-3">
                    <div>
                        <CardTitle className="text-lg font-semibold">Lesson status</CardTitle>
                        <CardDescription className="mt-2">Generated content and persisted progress.</CardDescription>
                    </div>
                    <BookOpen className="size-5 text-brand" />
                </div>
            </CardHeader>
            <CardContent className="grid grid-cols-2 gap-2 text-sm">
                <MiniStat label="Generated" value={str(summary.generated_lessons)} />
                <MiniStat label="Pending" value={str(summary.pending_lessons)} />
                <MiniStat label="Completed" value={str(summary.completed_lessons)} />
                <MiniStat label="Available" value={str(summary.available_lessons)} />
            </CardContent>
        </Card>;
}

def:pub ChallengeSummaryCard(summary: DashboardChallengeSummary) -> JsxElement {
    return
        <Card className="border-surface-border bg-surface">
            <CardHeader>
                <div className="flex items-start justify-between gap-3">
                    <div>
                        <CardTitle className="text-lg font-semibold">Challenge status</CardTitle>
                        <CardDescription className="mt-2">Submissions and evaluations from persisted records.</CardDescription>
                    </div>
                    <Code2 className="size-5 text-brand" />
                </div>
            </CardHeader>
            <CardContent className="grid grid-cols-2 gap-2 text-sm">
                <MiniStat label="Generated" value={str(summary.generated_challenges)} />
                <MiniStat label="Submitted" value={str(summary.submitted_challenges)} />
                <MiniStat label="Evaluated" value={str(summary.evaluated_submissions)} />
                <MiniStat label="Passed" value={str(summary.passed_challenges)} />
                <MiniStat label="Failed" value={str(summary.failed_challenges)} />
                <MiniStat label="Drafts" value={str(summary.draft_submissions)} />
            </CardContent>
        </Card>;
}

def:pub RoadmapSnapshot(dashboard: DashboardView) -> JsxElement {
    progress = dashboard.roadmap_progress;
    current = dashboard.current_lesson;
    return
        <Card className="border-surface-border bg-surface">
            <CardHeader>
                <CardTitle className="text-lg font-semibold">Roadmap snapshot</CardTitle>
                <CardDescription>A compact read-only snapshot. Open the roadmap for the full sequence.</CardDescription>
            </CardHeader>
            <CardContent className="grid gap-3">
                <div className="grid gap-2 md:grid-cols-4">
                    <MiniStat label="Completed" value={str(progress.completed_lessons)} />
                    <MiniStat label="Available" value={str(progress.available_lessons)} />
                    <MiniStat label="Locked" value={str(progress.locked_lessons)} />
                    <MiniStat label="Total" value={str(progress.total_lessons)} />
                </div>
                {if current is not None {
                    lesson = current as DashboardCurrentLesson;
                    <div className="rounded-xl border border-surface-border-subtle bg-elevated p-4">
                        <p className="text-sm text-copy-muted">Current focus</p>
                        <p className="mt-1 font-medium text-copy-primary">{lesson.title}</p>
                        <p className="mt-1 text-sm text-copy-secondary">Week {lesson.week_number} - {_title_case(lesson.status)}</p>
                    </div>
                } else {
                    <p className="rounded-xl border border-surface-border-subtle bg-elevated p-4 text-sm text-copy-secondary">No current lesson is available yet.</p>
                }}
            </CardContent>
        </Card>;
}

def:pub RecentActivityList(activities: list[DashboardRecentActivity]) -> JsxElement {
    return
        <Card className="border-surface-border bg-surface">
            <CardHeader>
                <div className="flex items-start justify-between gap-3">
                    <div>
                        <CardTitle className="text-lg font-semibold">Recent activity</CardTitle>
                        <CardDescription>Persisted learner events returned by the dashboard.</CardDescription>
                    </div>
                    <Activity className="size-5 text-brand" />
                </div>
            </CardHeader>
            <CardContent>
                {if len(activities) == 0 {
                    <p className="rounded-xl border border-surface-border-subtle bg-elevated p-4 text-sm text-copy-secondary">Your activity history will appear here as you learn.</p>
                } else {
                    <ul className="grid gap-3" aria-label="Recent dashboard activity">
                        {for activity in activities {
                            <li key={activity.type + activity.timestamp + activity.related_entity_id} className="flex gap-3 rounded-xl border border-surface-border-subtle bg-elevated p-3">
                                <div className="mt-0.5 flex size-8 shrink-0 items-center justify-center rounded-xl border border-surface-border-subtle bg-surface">
                                    <Clock className="size-4 text-brand" />
                                </div>
                                <div className="min-w-0">
                                    <p className="font-medium text-copy-primary">{activity.title}</p>
                                    <p className="mt-1 text-xs text-copy-muted">{_title_case(activity.type)} - {format_datetime(activity.timestamp)}</p>
                                    {activity.description != "" and <p className="mt-2 text-sm text-copy-secondary">{activity.description}</p>}
                                </div>
                            </li>
                        }}
                    </ul>
                }}
            </CardContent>
        </Card>;
}

def:pub DashboardLoadingState() -> JsxElement {
    return
        <div className="grid gap-4" aria-label="Loading dashboard">
            <p className="sr-only">Loading your dashboard...</p>
            <div className="h-48 animate-pulse rounded-2xl border border-surface-border bg-surface" />
            <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
                {for index in [1, 2, 3, 4] {
                    <div key={str(index)} className="h-40 animate-pulse rounded-2xl border border-surface-border bg-surface" />
                }}
            </div>
            <div className="grid gap-4 lg:grid-cols-2">
                {for index in [1, 2] {
                    <div key={str(index)} className="h-64 animate-pulse rounded-2xl border border-surface-border bg-surface" />
                }}
            </div>
        </div>;
}

def:pub DashboardErrorState(
    title: str,
    message: str,
    actionLabel: str,
    actionTo: str,
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
                            <CardTitle className="text-lg font-semibold">{title}</CardTitle>
                            <CardDescription className="mt-2 leading-6">{message}</CardDescription>
                        </div>
                    </div>
                </CardHeader>
                <CardContent className="flex flex-wrap gap-3">
                    <Button asChild={True}>
                        <Link to={actionTo}>{actionLabel}</Link>
                    </Button>
                    {if onRetry is not None {
                        <Button variant="outline" onClick={lambda (_e: MouseEvent) { onRetry(); }}>
                            <RefreshCcw className="size-4" />
                            Retry
                        </Button>
                    }}
                </CardContent>
            </Card>
        </div>;
}

def:pub MiniStat(label: str, value: str) -> JsxElement {
    return
        <div className="rounded-xl border border-surface-border-subtle bg-elevated p-3">
            <p className="text-xs text-copy-muted">{label}</p>
            <p className="mt-1 text-lg font-semibold text-copy-primary">{value}</p>
        </div>;
}
