"""Authenticated learner dashboard page."""

import from "@jac/runtime" { useNavigate }
import from "....lib.auth.auth_client" { current_auth_session }
import from "....lib.journey.journey_state" { read_journey_state }
import from "...dashboard.components.DashboardComponents" {
    ChallengeSummaryCard,
    CurrentLessonCard,
    DashboardErrorState,
    DashboardHeader,
    DashboardLoadingState,
    DashboardStatePanel,
    LessonSummaryCard,
    MasterySummaryCard,
    RecentActivityList,
    RoadmapProgressCard,
    RoadmapSnapshot,
    SkillSummaryList
}
sv import from ....services.dashboard {
    DashboardLoadState,
    DashboardView,
    load_dashboard
}

def _dashboard_ready_for_full_view(state: str) -> bool {
    return state == "in_progress" or state == "ready" or state == "completed";
}

def:pub DashboardPage() -> JsxElement {
    nav = useNavigate();
    has load_state: DashboardLoadState | None = None;
    has learner_id_value: str = "";
    has loading: bool = True;
    has failed: bool = False;
    has error_message: str = "";

    async def fetch_dashboard() {
        loading = True;
        failed = False;
        error_message = "";
        load_state = None;

        session: dict[str, any] = {};
        learner_id_raw: any = None;
        learner_id: str = "";
        selected_language: str = "";
        roadmap_id: str = "";
        journey: any = None;

        try {
            session = current_auth_session() as dict[str, any];
            learner_id_raw = session["learner_id"];
            learner_id = str(learner_id_raw) if learner_id_raw else "";
            learner_id_value = learner_id;

            if learner_id == "" {
                failed = True;
                error_message = "Please log in again to load your dashboard.";
                loading = False;
                return;
            }

            journey = read_journey_state();
            selected_language = str(journey.selected_language) if journey.selected_language else "";
            roadmap_id = str(journey.roadmap_id) if journey.roadmap_id else "";

            load_state = await load_dashboard(learner_id, selected_language, roadmap_id);
        } except Exception as e {
            print("Dashboard load failed:", e);
            failed = True;
            error_message = "Unable to load your dashboard.";
        }

        loading = False;
    }

    def go_login() {
        nav("/login", {"replace": True});
    }

    async can with entry {
        await fetch_dashboard();
    }

    if loading {
        return
            <main className="min-h-screen bg-base text-copy-primary">
                <div className="mx-auto flex max-w-7xl flex-col gap-6 px-6 py-6">
                    <DashboardLoadingState />
                </div>
            </main>;
    }

    if failed {
        return
            <main className="min-h-screen bg-base p-6 text-copy-primary">
                <DashboardErrorState
                    title="Dashboard could not be loaded."
                    message={error_message if error_message != "" else "The dashboard request failed. Try again or log in again."}
                    actionLabel={"Log in again" if learner_id_value == "" else "Retry dashboard"}
                    actionTo={"/login" if learner_id_value == "" else "/dashboard"}
                    onRetry={lambda { fetch_dashboard(); }}
                />
            </main>;
    }

    if load_state is None {
        return
            <main className="min-h-screen bg-base p-6 text-copy-primary">
                <DashboardErrorState
                    title="Dashboard is unavailable."
                    message="No dashboard response was returned."
                    actionLabel="Return to landing"
                    actionTo="/"
                    onRetry={lambda { fetch_dashboard(); }}
                />
            </main>;
    }

    if (load_state as DashboardLoadState).status == "missing_learner" {
        return
            <main className="min-h-screen bg-base p-6 text-copy-primary">
                <DashboardErrorState
                    title="Log in again."
                    message={(load_state as DashboardLoadState).message}
                    actionLabel="Log in"
                    actionTo="/login"
                    onRetry={lambda { go_login(); }}
                />
            </main>;
    }

    if (load_state as DashboardLoadState).status != "ready" or (load_state as DashboardLoadState).dashboard is None {
        return
            <main className="min-h-screen bg-base p-6 text-copy-primary">
                <DashboardErrorState
                    title="Dashboard is not ready."
                    message={(load_state as DashboardLoadState).message if (load_state as DashboardLoadState).message != "" else "Dashboard data could not be displayed yet."}
                    actionLabel="Return to assessment"
                    actionTo="/assessment"
                    onRetry={lambda { fetch_dashboard(); }}
                />
            </main>;
    }

    dashboard = (load_state as DashboardLoadState).dashboard as DashboardView;
    roadmap_id = "";
    if dashboard.active_roadmap is not None {
        roadmap_id = (dashboard.active_roadmap as any).roadmap_id as str;
    }

    if not _dashboard_ready_for_full_view(dashboard.dashboard_state) {
        return
            <main className="min-h-screen bg-base text-copy-primary">
                <div className="mx-auto flex max-w-7xl flex-col gap-6 px-6 py-6">
                    <DashboardHeader dashboard={dashboard} />
                    <DashboardStatePanel dashboard={dashboard} />
                    {dashboard.active_roadmap is not None and
                        <section className="grid gap-4 lg:grid-cols-2" aria-label="Dashboard preview">
                            <RoadmapProgressCard dashboard={dashboard} />
                            <CurrentLessonCard dashboard={dashboard} />
                        </section>
                    }
                </div>
            </main>;
    }

    return
        <main className="min-h-screen bg-base text-copy-primary">
            <div className="mx-auto flex max-w-7xl flex-col gap-6 px-6 py-6">
                <DashboardHeader dashboard={dashboard} />
                {dashboard.dashboard_state == "completed" and <DashboardStatePanel dashboard={dashboard} />}
                <section className="grid gap-4 lg:grid-cols-2" aria-label="Primary dashboard cards">
                    <RoadmapProgressCard dashboard={dashboard} />
                    <CurrentLessonCard dashboard={dashboard} />
                </section>
                <section className="grid gap-4 md:grid-cols-2 xl:grid-cols-4" aria-label="Dashboard summary cards">
                    <MasterySummaryCard summary={dashboard.mastery_summary} roadmapId={roadmap_id} />
                    <LessonSummaryCard summary={dashboard.lesson_summary} />
                    <ChallengeSummaryCard summary={dashboard.challenge_summary} />
                    <RoadmapSnapshot dashboard={dashboard} />
                </section>
                <section className="grid gap-4 lg:grid-cols-3" aria-label="Skills and activity">
                    <SkillSummaryList
                        title="Strongest skills"
                        skills={dashboard.mastery_summary.strongest_skills}
                        emptyMessage="Mastery data will appear after your first evaluated challenge."
                    />
                    <SkillSummaryList
                        title="Weakest skills"
                        skills={dashboard.mastery_summary.weakest_skills}
                        emptyMessage="Weak skill signals will appear after evaluation evidence is available."
                    />
                    <RecentActivityList activities={dashboard.recent_activity} />
                </section>
            </div>
        </main>;
}
