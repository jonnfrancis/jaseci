"""Read-only skill map visualization page."""

import from "@jac/runtime" { useNavigate, useParams }
import from "....lib.auth.auth_client" { current_auth_session }
import from "....lib.journey.journey_state" { read_journey_language }
import from "...skill_map.components.SkillMapComponents" {
    SelectedSkillPanel,
    SkillGraphView,
    SkillMapFilters,
    SkillMapHeader,
    SkillMapLoadingState,
    SkillMapStateCard,
    SkillMapSummaryCards
}
sv import from ....services.roadmap { RoadmapLoadState, load_roadmap }
sv import from ....services.skill_map {
    SkillMapLoadState,
    SkillMapSkill,
    SkillMapView,
    load_skill_map
}

def _first_skill_id(skill_map: SkillMapView | None) -> str {
    if skill_map is None {
        return "";
    }
    if len((skill_map as SkillMapView).skills) == 0 {
        return "";
    }
    return (skill_map as SkillMapView).skills[0].skill_id;
}

def _find_skill(skills: list[SkillMapSkill], skill_id: str) -> SkillMapSkill | None {
    for skill in skills {
        if skill.skill_id == skill_id {
            return skill;
        }
    }
    return None;
}

def:pub SkillMapPage() -> JsxElement {
    params = useParams();
    nav = useNavigate();
    raw_roadmap_id = params["roadmapId"];
    roadmap_id = str(raw_roadmap_id) if raw_roadmap_id else "";

    has load_state: SkillMapLoadState | None = None;
    has roadmap_title: str = "";
    has learner_id_value: str = "";
    has loading: bool = True;
    has failed: bool = False;
    has filter: str = "all";
    has selected_skill_id: str = "";

    async def fetch_skill_map {
        loading = True;
        failed = False;
        load_state = None;
        roadmap_title = "";

        session: dict[str, any] = {};
        learner_id_raw: any = None;
        selected_language: str = "";

        try {
            session = current_auth_session() as dict[str, any];
            learner_id_raw = session["learner_id"];
            learner_id_value = str(learner_id_raw) if learner_id_raw else "";

            if learner_id_value == "" {
                load_state = SkillMapLoadState(
                    status="missing_learner",
                    message="Log in again to load your skill map."
                );
                loading = False;
                return;
            }

            selected_language = read_journey_language() as str;

            load_state = await load_skill_map(learner_id_value, selected_language, roadmap_id);

            if load_state.skill_map is not None {
                selected_skill_id = _first_skill_id(load_state.skill_map);
            }

            if roadmap_id != "" {
                roadmap_state: RoadmapLoadState = await load_roadmap(roadmap_id);
                if roadmap_state.roadmap is not None {
                    roadmap_title = roadmap_state.roadmap.title;
                }
            }
        } except Exception as e {
            print("Skill map load failed:", e);
            failed = True;
            load_state = None;
        }

        loading = False;
    }

    def choose_filter(next_filter: str) {
        filter = next_filter;
    }

    def choose_skill(skill_id: str) {
        selected_skill_id = skill_id;
    }

    def go_login {
        nav("/login", {"replace": True});
    }

    async can with [roadmap_id] entry {
        await fetch_skill_map();
    }

    if loading {
        return
            <main className="min-h-screen bg-base text-copy-primary">
                <div className="mx-auto flex max-w-7xl flex-col gap-6 px-6 py-6">
                    <p className="sr-only">Loading your skill map...</p>
                    <SkillMapLoadingState />
                </div>
            </main>;
    }

    if failed {
        return
            <main className="min-h-screen bg-base p-6 text-copy-primary">
                <SkillMapStateCard
                    title="Skill map could not be loaded."
                    message="The skill map request failed. Try again or return to your learning path."
                    action_label={"Back to roadmap" if roadmap_id != "" else "Back to assessment"}
                    action_to={"/roadmap/" + roadmap_id if roadmap_id != "" else "/assessment"}
                    retry_label="Retry"
                    onRetry={lambda { fetch_skill_map(); }}
                />
            </main>;
    }

    if load_state is None {
        return
            <main className="min-h-screen bg-base p-6 text-copy-primary">
                <SkillMapStateCard
                    title="Skill map is unavailable."
                    message="No skill map response was returned."
                    action_label="Back to assessment"
                    action_to="/assessment"
                    retry_label="Retry"
                    onRetry={lambda { fetch_skill_map(); }}
                />
            </main>;
    }

    if load_state.status == "missing_learner" {
        return
            <main className="min-h-screen bg-base p-6 text-copy-primary">
                <SkillMapStateCard
                    title="Log in again."
                    message={load_state.message}
                    action_label="Log in"
                    action_to="/login"
                    retry_label="Retry"
                    onRetry={lambda { go_login(); }}
                />
            </main>;
    }

    if load_state.status != "ready" or load_state.skill_map is None {
        return
            <main className="min-h-screen bg-base p-6 text-copy-primary">
                <SkillMapStateCard
                    title="Skill map is not ready."
                    message={load_state.message if load_state.message != "" else "Complete an assessment and coding challenge to start building your mastery graph."}
                    action_label={"Back to roadmap" if roadmap_id != "" else "Back to assessment"}
                    action_to={"/roadmap/" + roadmap_id if roadmap_id != "" else "/assessment"}
                    retry_label="Retry"
                    onRetry={lambda { fetch_skill_map(); }}
                />
            </main>;
    }

    skill_map = load_state.skill_map as SkillMapView;

    if len(skill_map.skills) == 0 {
        return
            <main className="min-h-screen bg-base text-copy-primary">
                <div className="mx-auto flex max-w-7xl flex-col gap-6 px-6 py-6">
                    <SkillMapHeader skillMap={skill_map} roadmapTitle={roadmap_title} />
                    <SkillMapStateCard
                        title="No skill map yet."
                        message="Complete an assessment and coding challenge to start building your mastery graph."
                        action_label={"Back to roadmap" if skill_map.roadmap_id != "" else "Back to assessment"}
                        action_to={"/roadmap/" + skill_map.roadmap_id if skill_map.roadmap_id != "" else "/assessment"}
                        retry_label="Retry"
                        onRetry={lambda { fetch_skill_map(); }}
                    />
                </div>
            </main>;
    }

    selected_skill = _find_skill(skill_map.skills, selected_skill_id);

    return
        <main className="min-h-screen bg-base text-copy-primary">
            <div className="mx-auto flex max-w-7xl flex-col gap-6 px-6 py-6">
                <SkillMapHeader skillMap={skill_map} roadmapTitle={roadmap_title} />
                <SkillMapSummaryCards summary={skill_map.summary} />
                <div className="flex flex-col gap-3 rounded-2xl border border-surface-border bg-surface p-4">
                    <p className="text-sm font-medium text-copy-secondary">Filter by mastery level</p>
                    <SkillMapFilters activeFilter={filter} onFilter={choose_filter} />
                </div>
                <div className="grid gap-6 xl:grid-cols-[1fr_24rem]">
                    <SkillGraphView
                        skillMap={skill_map}
                        activeFilter={filter}
                        selectedSkillId={selected_skill_id}
                        onSelectSkill={choose_skill}
                    />
                    <SelectedSkillPanel skill={selected_skill} skills={skill_map.skills} edges={skill_map.edges} />
                </div>
            </div>
        </main>;
}
