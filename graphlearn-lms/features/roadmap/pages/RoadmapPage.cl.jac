"""Read-only roadmap visualization page."""

import from "@jac/runtime" { useNavigate, useParams }
import from "...roadmap.components.RoadmapComponents" {
    RoadmapHeader,
    RoadmapLoadingState,
    RoadmapStateCard,
    RoadmapSummaryCards,
    RoadmapTimeline
}
sv import from "....services.roadmap" {
    RoadmapView,
    load_roadmap
}

def:pub RoadmapPage() -> JsxElement {
    has load_state: any = None;
    has loading: bool = True;
    has failed: bool = False;

    params = useParams();
    nav = useNavigate();
    raw_roadmap_id = params["roadmapId"];
    roadmap_id = str(raw_roadmap_id) if raw_roadmap_id else "";

    async def fetch_roadmap {
        loading = True;
        failed = False;
        try {
            load_state = await load_roadmap(roadmap_id);
        } except Exception {
            failed = True;
            load_state = None;
        }
        loading = False;
    }

    def go_home {
        nav("/");
    }

    async can with [roadmap_id] entry {
        await fetch_roadmap();
    }

    if loading {
        return
            <main className="min-h-screen bg-base text-copy-primary">
                <div className="mx-auto flex max-w-7xl flex-col gap-6 px-6 py-6">
                    <RoadmapLoadingState />
                </div>
            </main>;
    }

    if failed {
        return
            <main className="min-h-screen bg-base p-6 text-copy-primary">
                <RoadmapStateCard
                    title="Roadmap could not be loaded."
                    message="The roadmap request failed. Try again or return to the assessment launchpad."
                    action_label="Back to launchpad"
                    onAction={go_home}
                    retry_label="Retry"
                    onRetry={lambda { fetch_roadmap(); }}
                />
            </main>;
    }

    if load_state is None or load_state.status == "empty" or load_state.status == "not_found" {
        return
            <main className="min-h-screen bg-base p-6 text-copy-primary">
                <RoadmapStateCard
                    title="No roadmap found yet."
                    message="Complete an assessment to generate your personalized learning plan."
                    action_label="Back to launchpad"
                    onAction={go_home}
                />
            </main>;
    }

    if load_state.status == "malformed" or load_state.roadmap is None {
        return
            <main className="min-h-screen bg-base p-6 text-copy-primary">
                <RoadmapStateCard
                    title="Roadmap is not ready."
                    message={load_state.message if load_state.message != "" else "Roadmap generation is still preparing the outline."}
                    action_label="Back to launchpad"
                    onAction={go_home}
                    retry_label="Retry"
                    onRetry={lambda { fetch_roadmap(); }}
                />
            </main>;
    }

    roadmap = load_state.roadmap as RoadmapView;
    return
        <main className="min-h-screen bg-base text-copy-primary">
            <div className="mx-auto flex max-w-7xl flex-col gap-6 px-6 py-6">
                <RoadmapHeader roadmap={roadmap} />
                <RoadmapSummaryCards roadmap={roadmap} />
                <RoadmapTimeline roadmap={roadmap} />
            </div>
        </main>;
}
