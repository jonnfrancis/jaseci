"""Coding challenge workspace page."""

import from "@jac/runtime" { useNavigate, useParams }
import from "..components.ChallengeWorkspaceComponents" {
    ChallengeCriteriaPanel,
    ChallengeEditor,
    ChallengeErrorState,
    ChallengeHeader,
    ChallengeHintsPanel,
    ChallengeInstructionsPanel,
    ChallengeLoadingState,
    ChallengeSubmitPanel
}
import from "....lib.auth.auth_storage" { read_auth_session }
sv import from ....services.challenge {
    ChallengeSubmitState,
    ChallengeWorkspaceState,
    GeneratedChallengeView,
    open_challenge,
    submit_challenge_solution
}

def _draft_key(challenge_id: str) -> str {
    return "graphlearn.challenge.draft." + challenge_id;
}

def _usable_code(value: str) -> str {
    cleaned = value.strip();
    if cleaned == "" or cleaned == "undefined" or cleaned == "null" {
        return "";
    }
    return value;
}

def:pub ChallengeWorkspacePage() -> JsxElement {
    has workspace_state: ChallengeWorkspaceState | None = None;
    has loading: bool = True;
    has failed: bool = False;
    has editor_code: str = "";
    has validation_message: str = "";
    has saving: bool = False;
    has save_error: str = "";
    has save_success: str = "";
    has submission_id: str = "";
    has evaluation_score: int = -1;
    has evaluation_passed: bool = False;
    has evaluation_summary: str = "";
    has evaluation_next_step: str = "";
    has revealed_hint_count: int = 0;

    params = useParams();
    nav = useNavigate();
    raw_roadmap_id = params["roadmapId"];
    raw_lesson_id = params["roadmapLessonId"];
    raw_challenge_id = params["challengeId"];
    roadmap_id = str(raw_roadmap_id) if raw_roadmap_id else "";
    roadmap_lesson_id = str(raw_lesson_id) if raw_lesson_id else "";
    challenge_id = str(raw_challenge_id) if raw_challenge_id else "";
    auth = read_auth_session();
    raw_learner_id = auth["learner_id"];
    learner_id = str(raw_learner_id) if raw_learner_id else "";

    def go_login {
        nav("/login");
    }

    def go_lesson {
        if roadmap_id != "" and roadmap_lesson_id != "" {
            nav("/roadmap/" + roadmap_id + "/lesson/" + roadmap_lesson_id);
        } elif roadmap_id != "" {
            nav("/roadmap/" + roadmap_id);
        } else {
            nav("/assessment");
        }
    }

    def go_roadmap {
        if roadmap_id != "" {
            nav("/roadmap/" + roadmap_id);
        } else {
            nav("/assessment");
        }
    }

    def read_local_draft(challenge_id_value: str) -> str {
        stored = localStorage.getItem(_draft_key(challenge_id_value)); # jac:ignore[W2001,E1030,W6002]
        return str(stored) if stored else "";
    }

    def save_local_draft(challenge_id_value: str, code_value: str) {
        localStorage.setItem(_draft_key(challenge_id_value), code_value); # jac:ignore[W2001,E1030,W6002]
    }

    def clear_local_draft(challenge_id_value: str) {
        localStorage.removeItem(_draft_key(challenge_id_value)); # jac:ignore[W2001,E1030,W6002]
    }

    async def load_workspace {
        loading = True;
        failed = False;
        workspace_state = None;
        validation_message = "";
        save_error = "";
        save_success = "";
        submission_id = "";
        evaluation_score = -1;
        evaluation_passed = False;
        evaluation_summary = "";
        evaluation_next_step = "";
        revealed_hint_count = 0;
        try {
            fetched_state: ChallengeWorkspaceState = await open_challenge(learner_id, roadmap_id, roadmap_lesson_id, challenge_id);
            workspace_state = fetched_state;
            if fetched_state.status == "ready" and fetched_state.challenge is not None {
                challenge: GeneratedChallengeView = fetched_state.challenge;
                starter_code = _usable_code(str(challenge.starter_code));
                raw_local_draft = read_local_draft(str(challenge.id));
                local_draft = _usable_code(raw_local_draft);
                draft_code = "";
                if fetched_state.draft is not None {
                    draft: any = fetched_state.draft;
                    draft_code = _usable_code(str(draft.code));
                }
                if raw_local_draft != "" and local_draft == "" {
                    clear_local_draft(str(challenge.id));
                }
                if local_draft != "" {
                    editor_code = local_draft;
                } elif draft_code != "" {
                    editor_code = draft_code;
                } else {
                    editor_code = starter_code;
                }
                if fetched_state.latest_submission is not None {
                    latest: any = fetched_state.latest_submission;
                    submission_id = str(latest.id);
                    save_success = "Latest submission loaded.";
                }
                if fetched_state.latest_evaluation is not None {
                    latest_evaluation: any = fetched_state.latest_evaluation;
                    evaluation_score = int(latest_evaluation.score);
                    evaluation_passed = bool(latest_evaluation.passed);
                    evaluation_summary = str(latest_evaluation.feedback_summary);
                    evaluation_next_step = str(latest_evaluation.suggested_next_step);
                    save_success = "Latest evaluation loaded.";
                }
            }
        } except Exception {
            failed = True;
            workspace_state = None;
        }
        loading = False;
    }

    def update_code(value: str) {
        editor_code = value;
        validation_message = "";
        save_error = "";
        evaluation_score = -1;
        evaluation_passed = False;
        evaluation_summary = "";
        evaluation_next_step = "";
        if challenge_id != "" {
            save_local_draft(challenge_id, value);
        }
    }

    def reveal_hint {
        if workspace_state is not None and workspace_state.challenge is not None {
            challenge: GeneratedChallengeView = workspace_state.challenge;
            if revealed_hint_count < len(challenge.hints) {
                revealed_hint_count = revealed_hint_count + 1;
            }
        }
    }

    async def submit_solution {
        if editor_code.strip() == "" {
            validation_message = "Add code before submitting your solution.";
            return;
        }
        saving = True;
        save_error = "";
        save_success = "";
        evaluation_score = -1;
        evaluation_passed = False;
        evaluation_summary = "";
        evaluation_next_step = "";
        try {
            submit_state: ChallengeSubmitState = await submit_challenge_solution(
                learner_id,
                roadmap_id,
                roadmap_lesson_id,
                challenge_id,
                editor_code
            );
            if submit_state.status != "failed" and submit_state.submission is not None {
                submission: any = submit_state.submission;
                submission_id = str(submission.id);
                save_success = submit_state.message if submit_state.message != "" else "Submission submitted and evaluated.";
                if submit_state.evaluation is not None {
                    evaluation: any = submit_state.evaluation;
                    evaluation_score = int(evaluation.score);
                    evaluation_passed = bool(evaluation.passed);
                    evaluation_summary = str(evaluation.feedback_summary);
                    evaluation_next_step = str(evaluation.suggested_next_step);
                }
                clear_local_draft(challenge_id);
            } else {
                save_error = submit_state.message if submit_state.message != "" else "Submission could not be evaluated.";
            }
        } except Exception {
            save_error = "Submission could not be evaluated. Try again.";
        }
        saving = False;
    }

    async can with (learner_id, roadmap_id, roadmap_lesson_id, challenge_id) entry {
        if learner_id != "" and roadmap_id != "" and roadmap_lesson_id != "" and challenge_id != "" {
            await load_workspace();
        } else {
            loading = False;
        }
    }

    if learner_id == "" {
        return
            <main className="min-h-screen bg-base p-6 text-copy-primary">
                <ChallengeErrorState
                    title="Log in again to open this challenge."
                    message="The challenge workspace needs your learner id so it can load and save the right solution."
                    actionLabel="Log in"
                    onAction={go_login}
                />
            </main>;
    }

    if roadmap_id == "" or roadmap_lesson_id == "" or challenge_id == "" {
        return
            <main className="min-h-screen bg-base p-6 text-copy-primary">
                <ChallengeErrorState
                    title="Challenge route is incomplete."
                    message="The roadmap id, lesson id, or challenge id is missing from the URL."
                    actionLabel="Return to roadmap"
                    onAction={go_roadmap}
                />
            </main>;
    }

    if loading {
        return
            <main className="min-h-screen bg-base p-6 text-copy-primary">
                <ChallengeLoadingState message="Loading your challenge..." />
            </main>;
    }

    if failed {
        return
            <main className="min-h-screen bg-base p-6 text-copy-primary">
                <ChallengeErrorState
                    title="Challenge could not be loaded."
                    message="The challenge request failed. Try again or return to the lesson."
                    actionLabel="Return to lesson"
                    onAction={go_lesson}
                    retryLabel="Retry"
                    onRetry={lambda { load_workspace(); }}
                />
            </main>;
    }

    if workspace_state is None {
        return
            <main className="min-h-screen bg-base p-6 text-copy-primary">
                <ChallengeErrorState
                    title="Challenge is unavailable."
                    message="No challenge response was returned."
                    actionLabel="Return to lesson"
                    onAction={go_lesson}
                    retryLabel="Retry"
                    onRetry={lambda { load_workspace(); }}
                />
            </main>;
    }

    if workspace_state.status != "ready" or workspace_state.challenge is None {
        action_label = "Log in" if workspace_state.status == "missing_learner" else "Return to lesson";
        action = go_login if workspace_state.status == "missing_learner" else go_lesson;
        return
            <main className="min-h-screen bg-base p-6 text-copy-primary">
                <ChallengeErrorState
                    title="Challenge is not ready."
                    message={workspace_state.message if workspace_state.message != "" else "Challenge could not be loaded."}
                    actionLabel={action_label}
                    onAction={action}
                    retryLabel="Retry"
                    onRetry={lambda { load_workspace(); }}
                />
            </main>;
    }

    challenge: GeneratedChallengeView = workspace_state.challenge;
    lesson_title: str = workspace_state.lesson_title;

    return
        <main className="min-h-screen bg-base text-copy-primary">
            <div className="mx-auto flex max-w-[1600px] flex-col gap-5 px-4 py-5 md:px-6">
                <ChallengeHeader challenge={challenge} lessonTitle={lesson_title} onBack={go_lesson} />
                <div className="grid gap-5 xl:grid-cols-[320px_minmax(0,1fr)_320px] xl:items-start">
                    <ChallengeInstructionsPanel challenge={challenge} />
                    <ChallengeEditor
                        code={editor_code}
                        language={challenge.language}
                        validationMessage={validation_message}
                        onCodeChange={update_code}
                    />
                    <div className="flex flex-col gap-5">
                        <ChallengeHintsPanel
                            challenge={challenge}
                            revealedCount={revealed_hint_count}
                            onReveal={reveal_hint}
                        />
                        <ChallengeSubmitPanel
                            submissionId={submission_id}
                            saving={saving}
                            successMessage={save_success}
                            errorMessage={save_error}
                            evaluationScore={evaluation_score}
                            evaluationPassed={evaluation_passed}
                            evaluationSummary={evaluation_summary}
                            evaluationNextStep={evaluation_next_step}
                            onSubmit={submit_solution}
                            onBack={go_roadmap}
                        />
                        <ChallengeCriteriaPanel challenge={challenge} />
                    </div>
                </div>
            </div>
        </main>;
}
