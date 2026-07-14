"""AI Tutor recommendation panel for dashboard guidance."""

import from "@jac/runtime" { Link }
import from "lucide-react" {
    AlertCircle,
    ArrowRight,
    BookOpen,
    Brain,
    CheckCircle2,
    Code2,
    Map,
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
sv import from ....services.tutor {
    TutorRecommendationLoadState,
    TutorRecommendationView,
    load_tutor_recommendation
}

def _title_case(value: str) -> str {
    clean = value.replace("_", " ").strip();
    if clean == "" {
        return "Unknown";
    }
    return clean.title();
}

def _priority_label(priority: str) -> str {
    if priority == "high" {
        return "High priority";
    }
    if priority == "medium" {
        return "Medium priority";
    }
    return "Low priority";
}

def _priority_class(priority: str) -> str {
    if priority == "high" {
        return "border-state-warning text-state-warning";
    }
    if priority == "medium" {
        return "border-brand text-brand";
    }
    return "border-surface-border-subtle text-copy-secondary";
}

def _roadmap_route(roadmap_id: str) -> str {
    return "/roadmap/" + roadmap_id if roadmap_id != "" else "/dashboard";
}

def _skill_map_route(roadmap_id: str) -> str {
    return "/roadmap/" + roadmap_id + "/skill-map" if roadmap_id != "" else "/skill-map";
}

def _lesson_route(recommendation: TutorRecommendationView) -> str {
    if recommendation.roadmap_id != "" and recommendation.related_roadmap_lesson_id != "" {
        return "/roadmap/" + recommendation.roadmap_id + "/lesson/" + recommendation.related_roadmap_lesson_id;
    }
    return _roadmap_route(recommendation.roadmap_id);
}

def _challenge_route(recommendation: TutorRecommendationView) -> str {
    if recommendation.roadmap_id != "" and recommendation.related_roadmap_lesson_id != "" and recommendation.related_challenge_id != "" {
        return "/roadmap/" + recommendation.roadmap_id + "/lesson/" + recommendation.related_roadmap_lesson_id + "/challenge/" + recommendation.related_challenge_id;
    }
    if recommendation.related_roadmap_lesson_id != "" {
        return _lesson_route(recommendation);
    }
    return _roadmap_route(recommendation.roadmap_id);
}

def _cta_route(recommendation: TutorRecommendationView) -> str {
    rec_type = recommendation.recommendation_type;
    if rec_type == "start_assessment" or rec_type == "generate_roadmap" {
        return "/assessment";
    }
    if rec_type == "start_roadmap" or rec_type == "completed" {
        return _roadmap_route(recommendation.roadmap_id);
    }
    if rec_type == "continue_lesson" or rec_type == "generate_lesson" or rec_type == "review_lesson" {
        return _lesson_route(recommendation);
    }
    if rec_type == "start_challenge" or rec_type == "retry_challenge" {
        return _challenge_route(recommendation);
    }
    if rec_type == "practice_weak_skill" or rec_type == "view_skill_map" {
        return _skill_map_route(recommendation.roadmap_id);
    }
    return _roadmap_route(recommendation.roadmap_id);
}

def _cta_label(recommendation: TutorRecommendationView) -> str {
    rec_type = recommendation.recommendation_type;
    if rec_type == "start_assessment" {
        return "Start assessment";
    }
    if rec_type == "generate_roadmap" {
        return "Generate roadmap";
    }
    if rec_type == "start_roadmap" {
        return "View roadmap";
    }
    if rec_type == "continue_lesson" {
        return "Continue lesson";
    }
    if rec_type == "generate_lesson" {
        return "Open lesson";
    }
    if rec_type == "start_challenge" {
        return "Start challenge";
    }
    if rec_type == "retry_challenge" {
        return "Retry challenge";
    }
    if rec_type == "review_lesson" {
        return "Review lesson";
    }
    if rec_type == "practice_weak_skill" or rec_type == "view_skill_map" {
        return "View skill map";
    }
    if rec_type == "completed" {
        return "View roadmap";
    }
    return recommendation.suggested_cta_label if recommendation.suggested_cta_label != "" else "View roadmap";
}

def _type_icon(recommendation_type: str) -> JsxElement {
    if recommendation_type == "start_assessment" {
        return <Brain className="size-4" />;
    }
    if recommendation_type == "start_challenge" or recommendation_type == "retry_challenge" {
        return <Code2 className="size-4" />;
    }
    if recommendation_type == "practice_weak_skill" or recommendation_type == "view_skill_map" {
        return <Map className="size-4" />;
    }
    if recommendation_type == "completed" {
        return <CheckCircle2 className="size-4" />;
    }
    return <BookOpen className="size-4" />;
}

def:pub TutorPriorityBadge(priority: str) -> JsxElement {
    return
        <span className={"inline-flex w-fit items-center gap-1 rounded-xl border bg-elevated px-2.5 py-1 text-xs font-medium " + _priority_class(priority)}>
            {_priority_label(priority)}
        </span>;
}

def:pub TutorLoadingState() -> JsxElement {
    return
        <Card className="border-surface-border bg-subtle" aria-live="polite">
            <CardHeader>
                <div className="flex items-start gap-3">
                    <div className="flex size-10 shrink-0 items-center justify-center rounded-xl border border-surface-border-subtle bg-elevated">
                        <Sparkles className="size-5 text-ai-text" />
                    </div>
                    <div className="min-w-0 flex-1">
                        <CardTitle className="text-lg font-semibold">AI Tutor</CardTitle>
                        <CardDescription className="mt-2">AI Tutor is reviewing your progress...</CardDescription>
                    </div>
                </div>
            </CardHeader>
            <CardContent className="grid gap-3">
                <div className="h-4 w-2/3 animate-pulse rounded-xl bg-elevated" />
                <div className="h-4 w-full animate-pulse rounded-xl bg-elevated" />
                <div className="h-4 w-4/5 animate-pulse rounded-xl bg-elevated" />
            </CardContent>
        </Card>;
}

def:pub TutorErrorState(
    message: str,
    fallbackTo: str,
    onRefresh: Callable[[], None]
) -> JsxElement {
    return
        <Card className="border-surface-border bg-subtle" aria-live="polite">
            <CardHeader>
                <div className="flex items-start gap-3">
                    <div className="flex size-10 shrink-0 items-center justify-center rounded-xl border border-surface-border-subtle bg-elevated">
                        <AlertCircle className="size-5 text-state-warning" />
                    </div>
                    <div>
                        <CardTitle className="text-lg font-semibold">AI Tutor is unavailable right now.</CardTitle>
                        <CardDescription className="mt-2 leading-6">
                            {message if message != "" else "You can still continue from your roadmap."}
                        </CardDescription>
                    </div>
                </div>
            </CardHeader>
            <CardContent className="flex flex-wrap gap-3">
                <Button asChild={True}>
                    <Link to={fallbackTo}>
                        View roadmap
                        <ArrowRight className="size-4" />
                    </Link>
                </Button>
                <Button variant="outline" onClick={lambda (_e: MouseEvent) { onRefresh(); }}>
                    <RefreshCcw className="size-4" />
                    Refresh suggestion
                </Button>
            </CardContent>
        </Card>;
}

def:pub TutorEmptyState(fallbackTo: str, onRefresh: Callable[[], None]) -> JsxElement {
    return
        <Card className="border-surface-border bg-subtle" aria-live="polite">
            <CardHeader>
                <div className="flex items-start gap-3">
                    <div className="flex size-10 shrink-0 items-center justify-center rounded-xl border border-surface-border-subtle bg-elevated">
                        <Sparkles className="size-5 text-ai-text" />
                    </div>
                    <div>
                        <CardTitle className="text-lg font-semibold">No tutor recommendation yet.</CardTitle>
                        <CardDescription className="mt-2 leading-6">
                            Continue learning and your tutor will suggest the next best step.
                        </CardDescription>
                    </div>
                </div>
            </CardHeader>
            <CardContent className="flex flex-wrap gap-3">
                <Button asChild={True}>
                    <Link to={fallbackTo}>View roadmap</Link>
                </Button>
                <Button variant="outline" onClick={lambda (_e: MouseEvent) { onRefresh(); }}>
                    <RefreshCcw className="size-4" />
                    Refresh suggestion
                </Button>
            </CardContent>
        </Card>;
}

def:pub TutorRecommendationCard(
    recommendation: TutorRecommendationView,
    onRefresh: Callable[[], None]
) -> JsxElement {
    route = _cta_route(recommendation);
    label = _cta_label(recommendation);
    related_count = len(recommendation.related_skill_ids);
    return
        <Card className="border-surface-border bg-subtle">
            <CardHeader>
                <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
                    <div className="flex min-w-0 items-start gap-3">
                        <div className="flex size-10 shrink-0 items-center justify-center rounded-xl border border-surface-border-subtle bg-elevated text-ai-text">
                            <Sparkles className="size-5" />
                        </div>
                        <div className="min-w-0">
                            <div className="flex flex-wrap items-center gap-2">
                                <p className="text-sm font-medium text-ai-text">AI Tutor</p>
                                <TutorPriorityBadge priority={recommendation.priority} />
                            </div>
                            <CardTitle className="mt-3 text-xl font-semibold leading-tight text-copy-primary">
                                {recommendation.title}
                            </CardTitle>
                            <CardDescription className="mt-3 leading-6">
                                {recommendation.explanation}
                            </CardDescription>
                        </div>
                    </div>
                    <Button variant="outline" size="sm" onClick={lambda (_e: MouseEvent) { onRefresh(); }} aria-label="Refresh AI Tutor recommendation">
                        <RefreshCcw className="size-4" />
                        Refresh
                    </Button>
                </div>
            </CardHeader>
            <CardContent className="grid gap-4">
                <div className="rounded-xl border border-surface-border-subtle bg-elevated p-4">
                    <p className="text-xs font-medium uppercase tracking-wide text-copy-muted">Recommended action</p>
                    <p className="mt-2 text-sm leading-6 text-copy-primary">{recommendation.recommended_action}</p>
                </div>
                <div className="flex flex-wrap gap-2">
                    <span className="inline-flex items-center gap-1 rounded-xl border border-surface-border-subtle bg-elevated px-2.5 py-1 text-xs text-copy-secondary">
                        {_type_icon(recommendation.recommendation_type)}
                        {_title_case(recommendation.recommendation_type)}
                    </span>
                    {recommendation.related_roadmap_lesson_id != "" and
                        <span className="inline-flex items-center gap-1 rounded-xl border border-surface-border-subtle bg-elevated px-2.5 py-1 text-xs text-copy-secondary">
                            <BookOpen className="size-4" />
                            Lesson linked
                        </span>
                    }
                    {recommendation.related_challenge_id != "" and
                        <span className="inline-flex items-center gap-1 rounded-xl border border-surface-border-subtle bg-elevated px-2.5 py-1 text-xs text-copy-secondary">
                            <Code2 className="size-4" />
                            Challenge linked
                        </span>
                    }
                    {related_count > 0 and
                        <span className="inline-flex items-center gap-1 rounded-xl border border-surface-border-subtle bg-elevated px-2.5 py-1 text-xs text-copy-secondary">
                            <Brain className="size-4" />
                            {related_count} related skill{"" if related_count == 1 else "s"}
                        </span>
                    }
                </div>
                <div className="flex flex-wrap gap-3">
                    <Button asChild={True}>
                        <Link to={route}>
                            {label}
                            <ArrowRight className="size-4" />
                        </Link>
                    </Button>
                </div>
            </CardContent>
        </Card>;
}

def:pub AiTutorPanel(
    learnerId: str,
    roadmapId: str = "",
    language: str = ""
) -> JsxElement {
    has load_state: TutorRecommendationLoadState | None = None;
    has loading: bool = True;
    has failed: bool = False;
    has error_message: str = "";

    fallback_route = _roadmap_route(roadmapId);

    async def fetch_recommendation {
        loading = True;
        failed = False;
        error_message = "";
        load_state = None;

        if learnerId == "" {
            failed = True;
            error_message = "Log in again to load your AI Tutor recommendation.";
            loading = False;
            return;
        }

        try {
            fetched: TutorRecommendationLoadState = await load_tutor_recommendation(learnerId, roadmapId, language);
            load_state = fetched;
            if fetched.status != "ready" and fetched.status != "empty" {
                failed = True;
                error_message = fetched.message;
            }
        } except Exception {
            failed = True;
            error_message = "You can still continue from your roadmap.";
        }

        loading = False;
    }

    async can with (learnerId, roadmapId, language) entry {
        await fetch_recommendation();
    }

    if loading {
        return <TutorLoadingState />;
    }

    if failed {
        return <TutorErrorState message={error_message} fallbackTo={fallback_route} onRefresh={fetch_recommendation} />;
    }

    if load_state is None or (load_state as TutorRecommendationLoadState).recommendation is None {
        return <TutorEmptyState fallbackTo={fallback_route} onRefresh={fetch_recommendation} />;
    }

    recommendation = (load_state as TutorRecommendationLoadState).recommendation as TutorRecommendationView;
    return <TutorRecommendationCard recommendation={recommendation} onRefresh={fetch_recommendation} />;
}
