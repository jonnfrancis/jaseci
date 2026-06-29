"""Generated lesson reading page."""

import from "@jac/runtime" { useNavigate, useParams }
import from "..components.LessonComponents" {
    LessonCodeExample,
    LessonErrorState,
    LessonHeader,
    LessonLoadingState,
    LessonMetadataPanel,
    LessonMiniExercise,
    LessonNavigationActions,
    LessonSectionCard,
    LessonSectionNav,
    LessonTakeaways
}
import from "....lib.auth.auth_storage" { read_auth_session }
sv import from ....services.lesson {
    LessonOpenState,
    open_lesson
}

def _completion_key(lesson_id: str) -> str {
    return "graphlearn.lesson.read." + lesson_id;
}

def _exercise_key(lesson_id: str) -> str {
    return "graphlearn.lesson.exercises." + lesson_id;
}

def _split_ids(value: str) -> list[str] {
    if value == "" {
        return [];
    }
    return value.split(",");
}

def _join_ids(values: list[str]) -> str {
    return ",".join(values);
}

def:pub LessonPage() -> JsxElement {
    has open_state: LessonOpenState | None = None;
    has loading: bool = True;
    has failed: bool = False;
    has active_section_id: str = "";
    has copied_example_id: str = "";
    has checked_exercise_ids: list[str] = [];
    has read_complete: bool = False;

    params = useParams();
    nav = useNavigate();
    raw_roadmap_id = params["roadmapId"];
    raw_lesson_id = params["roadmapLessonId"];
    roadmap_id = str(raw_roadmap_id) if raw_roadmap_id else "";
    roadmap_lesson_id = str(raw_lesson_id) if raw_lesson_id else "";
    auth = read_auth_session();
    raw_learner_id = auth["learner_id"];
    learner_id = str(raw_learner_id) if raw_learner_id else "";

    def go_roadmap {
        if roadmap_id != "" {
            nav("/roadmap/" + roadmap_id);
        } else {
            nav("/assessment");
        }
    }

    def go_login {
        nav("/login");
    }

    def go_lesson(next_roadmap_lesson_id: str) {
        nav("/roadmap/" + roadmap_id + "/lesson/" + next_roadmap_lesson_id);
    }

    def load_local_state(lesson_id: str) {
        read_complete = localStorage.getItem(_completion_key(lesson_id)) == "true"; # jac:ignore[W2001,E1030,W6002]
        stored = localStorage.getItem(_exercise_key(lesson_id)); # jac:ignore[W2001,E1030,W6002]
        checked_exercise_ids = _split_ids(str(stored) if stored else "");
    }

    async def load_lesson {
        loading = True;
        failed = False;
        open_state = None;
        copied_example_id = "";
        active_section_id = "";
        try {
            open_state = await open_lesson(learner_id, roadmap_id, roadmap_lesson_id);
            if open_state is not None and open_state.lesson is not None {
                lesson: any = open_state.lesson;
                sections: list[any] = lesson.sections as list[any];
                if len(sections) > 0 {
                    first_section: any = sections[0];
                    active_section_id = str(first_section.id);
                }
                load_local_state(str(lesson.id));
            }
        } except Exception {
            failed = True;
            open_state = None;
        }
        loading = False;
    }

    def select_section(section_id: str) {
        active_section_id = section_id;
        element = document.getElementById(section_id); # jac:ignore[W2001,E1030,W6002]
        if element {
            element.scrollIntoView({"behavior": "smooth", "block": "start"}); # jac:ignore[E1030,W6002]
        }
    }

    def copy_code(example_id: str, code: str) {
        copied_example_id = example_id;
        navigator.clipboard.writeText(code); # jac:ignore[W2001,E1030,W6002]
    }

    def toggle_exercise(exercise_id: str) {
        if exercise_id in checked_exercise_ids {
            checked_exercise_ids = [item for item in checked_exercise_ids if item != exercise_id];
        } else {
            checked_exercise_ids = checked_exercise_ids + [exercise_id];
        }
        if open_state is not None and open_state.lesson is not None {
            lesson: any = open_state.lesson;
            localStorage.setItem(_exercise_key(str(lesson.id)), _join_ids(checked_exercise_ids)); # jac:ignore[W2001,E1030,W6002]
        }
    }

    def mark_complete {
        read_complete = True;
        if open_state is not None and open_state.lesson is not None {
            lesson: any = open_state.lesson;
            localStorage.setItem(_completion_key(str(lesson.id)), "true"); # jac:ignore[W2001,E1030,W6002]
        }
    }

    async can with (learner_id, roadmap_id, roadmap_lesson_id) entry {
        if learner_id != "" and roadmap_id != "" and roadmap_lesson_id != "" {
            await load_lesson();
        } else {
            loading = False;
        }
    }

    if learner_id == "" {
        return
            <main className="min-h-screen bg-base p-6 text-copy-primary">
                <LessonErrorState
                    title="Log in again to open this lesson."
                    message="The lesson viewer needs your learner id so it can load the correct generated content."
                    actionLabel="Log in"
                    onAction={go_login}
                />
            </main>;
    }

    if roadmap_id == "" or roadmap_lesson_id == "" {
        return
            <main className="min-h-screen bg-base p-6 text-copy-primary">
                <LessonErrorState
                    title="Lesson route is incomplete."
                    message="The roadmap id or lesson id is missing from the URL."
                    actionLabel="Return to roadmap"
                    onAction={go_roadmap}
                />
            </main>;
    }

    if loading {
        return
            <main className="min-h-screen bg-base p-6 text-copy-primary">
                <LessonLoadingState message="Generating your lesson, building examples, preparing mini exercises, and saving lesson content..." />
            </main>;
    }

    if failed {
        return
            <main className="min-h-screen bg-base p-6 text-copy-primary">
                <LessonErrorState
                    title="Lesson could not be loaded."
                    message="The lesson request failed. Try again or return to your roadmap."
                    actionLabel="Back to roadmap"
                    onAction={go_roadmap}
                    retryLabel="Retry generation"
                    onRetry={lambda { load_lesson(); }}
                />
            </main>;
    }

    if open_state is None {
        return
            <main className="min-h-screen bg-base p-6 text-copy-primary">
                <LessonErrorState
                    title="Lesson is unavailable."
                    message="No lesson response was returned."
                    actionLabel="Back to roadmap"
                    onAction={go_roadmap}
                    retryLabel="Retry"
                    onRetry={lambda { load_lesson(); }}
                />
            </main>;
    }

    if open_state.status != "ready" or open_state.lesson is None {
        action_label = "Log in" if open_state.status == "missing_learner" else "Back to roadmap";
        action = go_login if open_state.status == "missing_learner" else go_roadmap;
        return
            <main className="min-h-screen bg-base p-6 text-copy-primary">
                <LessonErrorState
                    title="Lesson is not ready."
                    message={open_state.message if open_state.message != "" else "Lesson generation could not complete."}
                    actionLabel={action_label}
                    onAction={action}
                    retryLabel="Retry generation"
                    onRetry={lambda { load_lesson(); }}
                />
            </main>;
    }

    lesson: any = open_state.lesson;
    previous_lesson: any = None;
    next_lesson: any = None;
    if open_state.previous_lesson is not None {
        previous_lesson = open_state.previous_lesson;
    }
    if open_state.next_lesson is not None {
        next_lesson = open_state.next_lesson;
    }

    return
        <main className="min-h-screen bg-base text-copy-primary">
            <div className="mx-auto flex max-w-7xl flex-col gap-6 px-6 py-6">
                <LessonHeader lesson={lesson} onBack={go_roadmap} readComplete={read_complete} />
                <div className="grid gap-6 lg:grid-cols-[240px_minmax(0,1fr)_280px] lg:items-start">
                    <div className="lg:sticky lg:top-6">
                        <LessonSectionNav
                            sections={lesson.sections}
                            activeSectionId={active_section_id}
                            onSelect={select_section}
                        />
                    </div>
                    <article className="flex min-w-0 flex-col gap-6">
                        {for section in lesson.sections {
                            <LessonSectionCard key={section.id} section={section} />
                        }}
                        <section className="flex flex-col gap-4" aria-label="Code examples">
                            <div className="flex items-center gap-2">
                                <h2 className="text-xl font-semibold text-copy-primary">Examples</h2>
                            </div>
                            {for example in lesson.examples {
                                <LessonCodeExample
                                    key={example.id}
                                    example={example}
                                    language={lesson.language}
                                    copiedId={copied_example_id}
                                    onCopy={copy_code}
                                />
                            }}
                        </section>
                        <section className="flex flex-col gap-4" aria-label="Mini exercises">
                            <h2 className="text-xl font-semibold text-copy-primary">Mini exercises</h2>
                            {for exercise in lesson.mini_exercises {
                                <LessonMiniExercise
                                    key={exercise.id}
                                    exercise={exercise}
                                    checked={exercise.id in checked_exercise_ids}
                                    onToggle={toggle_exercise}
                                />
                            }}
                        </section>
                        <div className="lg:hidden">
                            <LessonTakeaways takeaways={lesson.key_takeaways} />
                        </div>
                        <LessonNavigationActions
                            previousLesson={previous_lesson}
                            nextLesson={next_lesson}
                            onNavigate={go_lesson}
                            onBack={go_roadmap}
                        />
                    </article>
                    <div className="hidden flex-col gap-4 lg:sticky lg:top-6 lg:flex">
                        <LessonMetadataPanel lesson={lesson} readComplete={read_complete} onComplete={mark_complete} />
                        <LessonTakeaways takeaways={lesson.key_takeaways} />
                    </div>
                    <div className="lg:hidden">
                        <LessonMetadataPanel lesson={lesson} readComplete={read_complete} onComplete={mark_complete} />
                    </div>
                </div>
            </div>
        </main>;
}
