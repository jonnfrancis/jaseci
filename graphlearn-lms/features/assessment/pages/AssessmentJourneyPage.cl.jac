"""Authenticated assessment-to-roadmap journey page."""

import from "lucide-react" {
    AlertCircle,
    ArrowLeft,
    CheckCircle2,
    Code2,
    LogOut,
    Map,
    Play,
    RefreshCcw,
    RotateCcw
}
import from "@jac/runtime" { useNavigate }
import from "....components.ui.button" { Button }
import from "....components.ui.card" {
    Card,
    CardContent,
    CardDescription,
    CardHeader,
    CardTitle
}
import from "..components.AssessmentComponents" {
    AssessmentHeader,
    AssessmentProgress,
    AssessmentQuestion,
    AssessmentQuestionList,
    AssessmentNavigation,
    AssessmentLoadingState
}
import from "....lib.auth.auth_client" {
    restore_auth_session,
    logout_user
}
import from "....lib.journey.journey_state" {
    clear_journey_state,
    save_journey_state
}
sv import from ....services.assessment_journey {
    generate_roadmap_for_journey,
    load_assessment_journey,
    retry_assessment_evaluation,
    start_assessment_journey,
    submit_and_evaluate_assessment,
    supported_language_tracks
}

obj JourneyQuestionResponse {
    has question_id: str;
    has question_type: str;
    has selected_option_id: str = "";
    has short_answer: str = "";
}

def _contains_id(ids: list[str], target_id: str) -> bool {
    for item in ids {
        if item == target_id {
            return True;
        }
    }
    return False;
}

def _has_answer(response: JourneyQuestionResponse) -> bool {
    if response.question_type == "multiple_choice" {
        return response.selected_option_id != "";
    }
    return response.short_answer.strip() != "";
}

def _find_response(responses: list[JourneyQuestionResponse], question_id: str) -> JourneyQuestionResponse | None {
    for response in responses {
        if response.question_id == question_id {
            return response;
        }
    }
    return None;
}

def _invalid_question_ids(assessment: any, responses: list[JourneyQuestionResponse]) -> list[str] {
    if assessment is None {
        return [];
    }
    missing: list[str] = [];
    questions = assessment.questions as list[any];
    for question in questions {
        question_id = question.id as str;
        required = question.required as bool;
        response = _find_response(responses, question_id);
        if required and (response is None or not _has_answer(response)) {
            missing = missing + [question_id];
        }
    }
    return missing;
}

def _answered_count(assessment: any, responses: list[JourneyQuestionResponse]) -> int {
    if assessment is None {
        return 0;
    }
    count = 0;
    questions = assessment.questions as list[any];
    for question in questions {
        response = _find_response(responses, question.id as str);
        if response is not None and _has_answer(response) {
            count += 1;
        }
    }
    return count;
}

def _completion_percentage(assessment: any, responses: list[JourneyQuestionResponse]) -> int {
    if assessment is None {
        return 0;
    }
    questions = assessment.questions as list[any];
    if len(questions) == 0 {
        return 0;
    }
    return int((_answered_count(assessment, responses) * 100) / len(questions));
}

def _to_payload_response(response: JourneyQuestionResponse) -> dict[str, str] {
    return {
        "question_id": response.question_id,
        "question_type": response.question_type,
        "selected_option_id": response.selected_option_id,
        "short_answer": response.short_answer
    };
}

def:pub AssessmentJourneyPage() -> JsxElement {
    nav = useNavigate();
    has journey: any = None;
    has tracks: list[any] = [];
    has responses: list[JourneyQuestionResponse] = [];
    has learner_id_value: str = "";
    has learner_display: str = "";
    has current_index: int = 0;
    has loading: bool = True;
    has starting: bool = False;
    has submitting: bool = False;
    has generating_roadmap: bool = False;
    has retrying_evaluation: bool = False;
    has attempted_submit: bool = False;
    has error_message: str = "";

    async can with entry {
        await refresh_journey();
    }

    def persist_journey(next_journey: any) {
        if next_journey is None {
            return;
        }
        evaluation_id = "";
        if next_journey.evaluation is not None {
            evaluation_id = next_journey.evaluation.evaluation_id as str;
        }
        save_journey_state(
            next_journey.selected_language,
            next_journey.assessment_id,
            next_journey.attempt_id,
            evaluation_id,
            next_journey.roadmap_id
        );
    }

    def reset_local_assessment_state() {
        responses = [];
        current_index = 0;
        attempted_submit = False;
        error_message = "";
    }

    async def refresh_journey() {
        loading = True;
        error_message = "";

        session: dict[str, any] = {};
        learner_display_value: str = "";
        tracks_result: list[any] = [];
        learner_id_raw: any = None;
        learner_id_val: str = "";

        try {
            session = (await restore_auth_session()) as dict[str, any];

            learner_id_raw = session["learner_id"];

            if learner_id_raw {
                learner_id_val = str(learner_id_raw);
            } else {
                learner_id_val = "";
            }
            print("Learner ID:", learner_id_val);

            learner_id_value = learner_id_val;
            print("Learner ID Value:", learner_id_value);

            if str(session["email"] or "") != "" {
                learner_display_value = str(session["email"]);
            } else {
                learner_display_value = learner_id_val;
            }

            learner_display = learner_display_value;

            tracks_result = await supported_language_tracks();
            tracks = tracks_result;

            if learner_id_val != "" {
                print("Loading assessment journey for learner:", learner_id_val);
                journey = await load_assessment_journey(learner_id_val);
                persist_journey(journey);
            } else {
                journey = {"status": "landing"};
                error_message = "Your session is missing a learner id. Log in again.";
            }
        } except Exception as e {
            print("Assessment refresh failed:", e);
            journey = {"status": "landing"};
            error_message = "Unable to load assessment state: " + str(e);
        }

        loading = False;
    }

    async def start_language(language: str) {
        if learner_id_value == "" {
            error_message = "Log in again before starting an assessment.";
            return;
        }
        starting = True;
        error_message = "";
        reset_local_assessment_state();
        try {
            learner_name = learner_display if learner_display != "" else learner_id_value;
            journey = await start_assessment_journey(language, learner_id_value, learner_name);
            persist_journey(journey);
        } except Exception {
            error_message = "Unable to start assessment.";
        }
        starting = False;
    }

    def answer_multiple_choice(question_id: str, option_id: str) {
        next_responses: list[JourneyQuestionResponse] = [];
        replaced = False;
        for response in responses {
            if response.question_id == question_id {
                next_responses = next_responses + [
                    JourneyQuestionResponse(
                        question_id=question_id,
                        question_type="multiple_choice",
                        selected_option_id=option_id
                    )
                ];
                replaced = True;
            } else {
                next_responses = next_responses + [response];
            }
        }
        if not replaced {
            next_responses = next_responses + [
                JourneyQuestionResponse(
                    question_id=question_id,
                    question_type="multiple_choice",
                    selected_option_id=option_id
                )
            ];
        }
        responses = next_responses;
    }

    def answer_short(question_id: str, answer_text: str) {
        next_responses: list[JourneyQuestionResponse] = [];
        replaced = False;
        for response in responses {
            if response.question_id == question_id {
                next_responses = next_responses + [
                    JourneyQuestionResponse(
                        question_id=question_id,
                        question_type="short_answer",
                        short_answer=answer_text
                    )
                ];
                replaced = True;
            } else {
                next_responses = next_responses + [response];
            }
        }
        if not replaced {
            next_responses = next_responses + [
                JourneyQuestionResponse(
                    question_id=question_id,
                    question_type="short_answer",
                    short_answer=answer_text
                )
            ];
        }
        responses = next_responses;
    }

    def previous_question() {
        if current_index > 0 {
            current_index -= 1;
        }
    }

    def next_question() {
        assessment = journey.assessment if journey is not None else None;
        questions = assessment.questions as list[any] if assessment is not None else [];
        if assessment is not None and current_index < len(questions) - 1 {
            current_index += 1;
        }
    }

    def select_question(index: int) {
        current_index = index;
    }

    async def submit_assessment() {
        attempted_submit = True;
        error_message = "";
        if learner_id_value == "" {
            error_message = "Log in again before submitting your assessment.";
            return;
        }
        if journey is None or journey.assessment is None {
            error_message = "Unable to submit assessment.";
            return;
        }
        invalid = _invalid_question_ids(journey.assessment, responses);
        if len(invalid) > 0 {
            error_message = "Answer every required question before submitting.";
            return;
        }
        submitting = True;
        try {
            assessment_id: str = journey.assessment.id as str;
            journey = await submit_and_evaluate_assessment(
                learner_id_value,
                assessment_id,
                [_to_payload_response(response) for response in responses],
                "client-submitted"
            );
            persist_journey(journey);
        } except Exception as e {
            error_message = "Unable to submit assessment: " + str(e);
        }
        submitting = False;
    }

    async def retry_evaluation() {
        if learner_id_value == "" {
            error_message = "Log in again before retrying evaluation.";
            return;
        }
        if journey is None or journey.assessment_id == "" or journey.attempt_id == "" {
            error_message = "Evaluation cannot be retried yet.";
            return;
        }
        retrying_evaluation = True;
        error_message = "";
        try {
            assessment_id: str = journey.assessment_id as str;
            attempt_id: str = journey.attempt_id as str;
            journey = await retry_assessment_evaluation(
                learner_id_value,
                assessment_id,
                attempt_id,
                "client-evaluation-retry"
            );
            persist_journey(journey);
        } except Exception {
            error_message = "Evaluation could not be completed.";
        }
        retrying_evaluation = False;
    }

    async def generate_roadmap() {
        if generating_roadmap {
            return;
        }
        error_message = "";
        if learner_id_value == "" {
            error_message = "Log in again before generating your roadmap.";
            return;
        }
        if journey is None or journey.evaluation is None {
            error_message = "Complete assessment evaluation before generating a roadmap.";
            return;
        }
        generating_roadmap = True;
        try {
            next_journey: any = None;
            next_roadmap_id: str = "";
            assessment_id: str = journey.assessment_id as str;
            attempt_id: str = journey.attempt_id as str;
            evaluation_id: str = journey.evaluation.evaluation_id as str;
            selected_language: str = journey.selected_language as str;

            next_journey = await generate_roadmap_for_journey(
                learner_id_value,
                assessment_id,
                attempt_id,
                evaluation_id,
                selected_language
            );
            print("Generated journey returned to client:", next_journey);
            print("Generated journey roadmap id direct:", next_journey.roadmap_id);

            next_roadmap_id = next_journey.roadmap_id as str;
            
            if next_roadmap_id == "" {
                error_message = "Roadmap generation failed: no roadmap id returned.";
                generating_roadmap = False;
                return;
            }
            print("Roadmap generated:", next_roadmap_id);

            journey = next_journey;
            persist_journey(next_journey);

            roadmap_id = next_roadmap_id;
            nav("/roadmap/" + roadmap_id);
        } except Exception as e {
            print("Generate roadmap failed:", e);
            error_message = "Unable to generate roadmap: " + str(e);
        }
        generating_roadmap = False;
    }

    def logout() {
        logout_user();
        clear_journey_state();
        nav("/login", {"replace": True});
    }

    if loading {
        return
            <section className="min-h-screen bg-base p-6 text-copy-primary">
                <div className="mx-auto max-w-7xl">
                    <AssessmentLoadingState />
                </div>
            </section>;
    }

    assessment = journey.assessment if journey is not None else None;
    status = journey.status if journey is not None else "landing";

    if status == "assessment" and assessment is not None {
        questions = assessment.questions as list[any];
        question_count = len(questions);
        invalid_ids = _invalid_question_ids(assessment, responses) if attempted_submit else [];
        current_question = questions[current_index];
        current_question_id = current_question.id as str;
        current_response = _find_response(responses, current_question_id);
        return
            <section className="min-h-screen bg-base text-copy-primary">
                <div className="mx-auto flex min-h-screen max-w-7xl flex-col gap-6 px-6 py-6">
                    <div className="flex flex-wrap items-center justify-between gap-3">
                        <Button variant="outline" onClick={lambda (_e: MouseEvent) { journey = {"status": "landing"}; reset_local_assessment_state(); }}>
                            <ArrowLeft className="size-4" />
                            Tracks
                        </Button>
                        <Button variant="ghost" onClick={lambda (_e: MouseEvent) { refresh_journey(); }}>
                            <RefreshCcw className="size-4" />
                            Recover state
                        </Button>
                    </div>
                    <AssessmentHeader assessment={assessment} />
                    <AssessmentProgress
                        answered_count={_answered_count(assessment, responses)}
                        total_count={question_count}
                        completion_percentage={_completion_percentage(assessment, responses)}
                        current_index={current_index}
                    />
                    {(error_message != "" or journey.error_message != "") and
                        <ErrorPanel message={error_message if error_message != "" else journey.error_message} />
                    }
                    <div className="grid flex-1 gap-6 lg:grid-cols-[16rem_1fr]">
                        <AssessmentQuestionList
                            assessment={assessment}
                            responses={responses}
                            invalid_question_ids={invalid_ids}
                            current_index={current_index}
                            onSelectQuestion={select_question}
                        />
                        <main className="flex min-w-0 flex-col gap-4">
                            <AssessmentQuestion
                                question={current_question}
                                question_number={current_index + 1}
                                response={current_response}
                                invalid={_contains_id(invalid_ids, current_question_id)}
                                onMultipleChoice={answer_multiple_choice}
                                onShortAnswer={answer_short}
                            />
                            <AssessmentNavigation
                                current_index={current_index}
                                total_count={question_count}
                                submitting={submitting}
                                onPrevious={previous_question}
                                onNext={next_question}
                                onSubmit={lambda { submit_assessment(); }}
                            />
                        </main>
                    </div>
                </div>
            </section>;
    }

    if status == "results" and journey is not None and journey.evaluation is not None {
        return
            <ResultsScreen
                journey={journey}
                evaluation={journey.evaluation}
                tracks={tracks}
                starting={starting}
                generating_roadmap={generating_roadmap}
                error_message={error_message}
                onStartLanguage={start_language}
                onGenerateRoadmap={generate_roadmap}
                onLogout={logout}
            />;
    }

    if status == "evaluation_pending" and journey is not None {
        return
            <PendingEvaluationScreen
                message={journey.error_message if journey.error_message != "" else "Assessment submitted successfully. Evaluation pending."}
                retrying={retrying_evaluation}
                onRetry={retry_evaluation}
                onRefresh={refresh_journey}
            />;
    }

    return
        <AssessmentHome
            tracks={tracks}
            starting={starting}
            error_message={error_message}
            learner_display={learner_display}
            onStartLanguage={start_language}
            onRefresh={refresh_journey}
            onLogout={logout}
        />;
}

def:pub ErrorPanel(message: str) -> JsxElement {
    return
        <div role="alert" className="flex items-center gap-2 rounded-2xl border border-state-error bg-surface p-4 text-sm text-state-error">
            <AlertCircle className="size-4" />
            {message}
        </div>;
}

def:pub AssessmentHome(
    tracks: list[any],
    starting: bool,
    error_message: str,
    learner_display: str,
    onStartLanguage: Callable[[str], None],
    onRefresh: Callable[[], None],
    onLogout: Callable[[], None]
) -> JsxElement {
    return
        <main className="min-h-screen bg-base text-copy-primary">
            <div className="mx-auto flex max-w-7xl flex-col gap-8 px-6 py-6">
                <header className="flex flex-wrap items-center justify-between gap-3 border-b border-surface-border pb-4">
                    <div>
                        <p className="text-sm text-brand">Assessment</p>
                        <h1 className="text-2xl font-semibold">Choose your starting track</h1>
                    </div>
                    <div className="flex flex-wrap items-center gap-2">
                        {learner_display != "" and
                            <span className="rounded-xl border border-surface-border-subtle bg-elevated px-3 py-2 text-sm text-copy-secondary">
                                {learner_display}
                            </span>
                        }
                        <Button variant="ghost" onClick={lambda (_e: MouseEvent) { onRefresh(); }}>
                            <RefreshCcw className="size-4" />
                            Recover state
                        </Button>
                        <Button variant="ghost" onClick={lambda (_e: MouseEvent) { onLogout(); }}>
                            <LogOut className="size-4" />
                            Logout
                        </Button>
                    </div>
                </header>
                {error_message != "" and <ErrorPanel message={error_message} />}
                <section className="grid gap-4 md:grid-cols-2" aria-label="Supported learning tracks">
                    {for track in tracks {
                        <LanguageTrackCard
                            key={track.id}
                            track={track}
                            starting={starting}
                            onStartLanguage={onStartLanguage}
                        />
                    }}
                </section>
            </div>
        </main>;
}

def:pub LanguageTrackCard(
    track: any,
    starting: bool,
    onStartLanguage: Callable[[str], None]
) -> JsxElement {
    return
        <Card className="border-surface-border bg-surface">
            <CardHeader>
                <div className="flex items-start justify-between gap-3">
                    <div>
                        <CardTitle className="text-xl">{track.name}</CardTitle>
                        <CardDescription className="mt-2 leading-6">{track.description}</CardDescription>
                    </div>
                    <div className="flex size-10 items-center justify-center rounded-xl border border-surface-border-subtle bg-elevated">
                        <Code2 className="size-5 text-brand" />
                    </div>
                </div>
            </CardHeader>
            <CardContent className="flex flex-col gap-4">
                <div className="flex flex-wrap gap-2">
                    {for topic in track.topics {
                        <span key={topic} className="rounded-xl border border-surface-border-subtle bg-elevated px-3 py-1 text-sm text-copy-secondary">
                            {topic}
                        </span>
                    }}
                </div>
                <Button onClick={lambda (_e: MouseEvent) { onStartLanguage(track.id as str); }} disabled={starting}>
                    <Play className="size-4" />
                    Start assessment
                </Button>
            </CardContent>
        </Card>;
}

def:pub PendingEvaluationScreen(
    message: str,
    retrying: bool,
    onRetry: Callable[[], None],
    onRefresh: Callable[[], None]
) -> JsxElement {
    return
        <main className="min-h-screen bg-base p-6 text-copy-primary">
            <div className="mx-auto flex min-h-[80vh] max-w-3xl items-center">
                <Card className="w-full border-state-warning bg-surface">
                    <CardHeader>
                        <CardTitle className="flex items-center gap-2">
                            <AlertCircle className="size-5 text-state-warning" />
                            Evaluation pending
                        </CardTitle>
                        <CardDescription>{message}</CardDescription>
                    </CardHeader>
                    <CardContent className="flex flex-wrap gap-3">
                        <Button onClick={lambda (_e: MouseEvent) { onRetry(); }} disabled={retrying}>
                            <RotateCcw className="size-4" />
                            { "Retrying..." if retrying else "Retry evaluation" }
                        </Button>
                        <Button variant="outline" onClick={lambda (_e: MouseEvent) { onRefresh(); }}>
                            <RefreshCcw className="size-4" />
                            Recover state
                        </Button>
                    </CardContent>
                </Card>
            </div>
        </main>;
}

def:pub ResultsScreen(
    journey: any,
    evaluation: any,
    tracks: list[any],
    starting: bool,
    generating_roadmap: bool,
    error_message: str,
    onStartLanguage: Callable[[str], None],
    onGenerateRoadmap: Callable[[], None],
    onLogout: Callable[[], None]
) -> JsxElement {
    return
        <main className="min-h-screen bg-base text-copy-primary">
            <div className="mx-auto flex max-w-7xl flex-col gap-6 px-6 py-6">
                <header className="flex flex-wrap items-center justify-between gap-3 border-b border-surface-border pb-4">
                    <div>
                        <p className="text-sm text-brand">Assessment results</p>
                        <h1 className="text-2xl font-semibold">{journey.selected_language} readiness</h1>
                    </div>
                    <div className="flex flex-wrap gap-2">
                        <Button onClick={lambda (_e: MouseEvent) { onGenerateRoadmap(); }} disabled={generating_roadmap}>
                            <Map className="size-4" />
                            { "Creating your personalized course outline..." if generating_roadmap else "Generate My Roadmap" }
                        </Button>
                        {for track in tracks {
                            <Button key={track.id} variant="outline" onClick={lambda (_e: MouseEvent) { onStartLanguage(track.id as str); }} disabled={starting}>
                                <Play className="size-4" />
                                New {track.name}
                            </Button>
                        }}
                        <Button variant="ghost" onClick={lambda (_e: MouseEvent) { onLogout(); }}>
                            <LogOut className="size-4" />
                            Logout
                        </Button>
                    </div>
                </header>
                {error_message != "" and <ErrorPanel message={error_message} />}

                <section className="grid gap-4 lg:grid-cols-[0.8fr_1.2fr]">
                    <Card className="border-surface-border bg-surface">
                        <CardHeader>
                            <CardTitle>Overall score</CardTitle>
                            <CardDescription>Evaluation output only.</CardDescription>
                        </CardHeader>
                        <CardContent className="flex flex-col gap-4">
                            <div className="text-6xl font-semibold text-brand">{evaluation.score.percentage}%</div>
                            <div className="rounded-xl border border-surface-border-subtle bg-elevated p-4 text-lg">
                                {evaluation.score.earned_points} / {evaluation.score.possible_points} points
                            </div>
                        </CardContent>
                    </Card>

                    <Card className="border-surface-border bg-surface">
                        <CardHeader>
                            <CardTitle>Skill breakdown</CardTitle>
                            <CardDescription>Evidence signals generated from question outcomes.</CardDescription>
                        </CardHeader>
                        <CardContent className="grid gap-3">
                            {for signal in evaluation.skill_signals {
                                <div key={signal.skill_id} className="grid gap-2 rounded-xl border border-surface-border-subtle bg-elevated p-4">
                                    <div className="flex flex-wrap items-center justify-between gap-2">
                                        <span className="font-medium">{signal.skill_id}</span>
                                        <span className="text-brand">{signal.accuracy}%</span>
                                    </div>
                                    <div className="h-2 overflow-hidden rounded-xl bg-surface">
                                        <div className="h-full rounded-xl bg-brand" style={{"width": f"{signal.accuracy}%"}} />
                                    </div>
                                    <p className="text-sm text-copy-muted">
                                        {signal.correct_count} correct, {signal.incorrect_count} incorrect
                                    </p>
                                </div>
                            }}
                        </CardContent>
                    </Card>
                </section>

                <Card className="border-surface-border bg-surface">
                    <CardHeader>
                        <CardTitle>Assessment summary</CardTitle>
                        <CardDescription>Persisted attempt and evaluation metadata.</CardDescription>
                    </CardHeader>
                    <CardContent className="grid gap-3 md:grid-cols-3">
                        <SummaryMetric label="Questions answered" value={f"{evaluation.question_count}"} />
                        <SummaryMetric label="Submission timestamp" value={evaluation.submitted_at} />
                        <SummaryMetric label="Completion time" value={evaluation.completion_time} />
                    </CardContent>
                </Card>
            </div>
        </main>;
}

def:pub SummaryMetric(label: str, value: str) -> JsxElement {
    return
        <div className="rounded-xl border border-surface-border-subtle bg-elevated p-4">
            <p className="text-sm text-copy-muted">{label}</p>
            <p className="mt-2 break-words text-sm font-medium text-copy-primary">{value}</p>
        </div>;
}
