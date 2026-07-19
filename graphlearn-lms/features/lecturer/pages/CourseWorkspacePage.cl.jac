"""Owned lecturer course overview and setup workspace."""

import from "@jac/runtime" { Link, useParams }
import from "lucide-react" { AlertCircle, ArrowLeft, RefreshCw }
import from "....components.ui.button" { Button }
import from "....components.ui.card" {
    Card,
    CardContent,
    CardDescription,
    CardHeader,
    CardTitle
}
import from "....components.ui.tabs" { Tabs, TabsContent, TabsList, TabsTrigger }
import from "..components.LecturerLoadingSkeleton" { LecturerLoadingSkeleton }
import from "..components.CourseSourceWorkspace" { CourseSourceWorkspace }
import from "..components.CourseBuildLifecycle" { CourseBuildLifecycle, WorkflowBlockers }
sv import from ....services.course_management {
    CourseBuildWorkflowView,
    LecturerCourseDetail,
    get_course_build_workflow,
    load_lecturer_course
}

def:pub CourseWorkspacePage() -> JsxElement {
    has course: LecturerCourseDetail | None = None;
    has workflow: CourseBuildWorkflowView | None = None;
    has loading: bool = True;
    has error_message: str = "";
    params = useParams();
    raw_track_id = params["trackId"];
    track_id = str(raw_track_id) if raw_track_id else "";

    async def load_course() {
        loading = True;
        error_message = "";
        if track_id != "" {
            try {
                course = await load_lecturer_course(track_id);
                loaded = course as LecturerCourseDetail;
                version = loaded.draft_version if loaded.draft_version is not None else loaded.active_version;
                if version is not None { workflow = await get_course_build_workflow(track_id, version.track_version_id); }
            } except Exception {
                error_message = "This course could not be opened. It may still be syncing or may no longer be available in your teaching workspace.";
            }
        } else {
            error_message = "The course link is incomplete.";
        }
        loading = False;
    }

    async can with entry {
        await load_course();
    }

    if loading {
        return <LecturerLoadingSkeleton/>;
    }
    if course is None {
        return
            <main
                className="flex min-h-screen items-center justify-center bg-base p-6 text-copy-primary"
            >
                <Card
                    className="w-full max-w-xl border-surface-border bg-surface text-copy-primary"
                >
                    <CardHeader>
                        <div className="flex items-start gap-3">
                            <div
                                className="flex size-10 shrink-0 items-center justify-center rounded-xl bg-state-error/10 text-state-error"
                            >
                                <AlertCircle className="size-5"/>
                            </div>
                            <div>
                                <CardTitle className="text-copy-primary">
                                    Course unavailable
                                </CardTitle>
                                <CardDescription>
                                    {error_message
                                        if error_message != ""
                                        else "The course workspace could not be loaded."}
                                </CardDescription>
                            </div>
                        </div>
                    </CardHeader>
                    <CardContent className="flex flex-col gap-3 sm:flex-row">
                        <Button onClick={lambda (_e: MouseEvent) { load_course(); }}>
                            <RefreshCw className="size-4"/>
                            Try again
                        </Button>
                        <Link
                            to="/lecturer/courses"
                            className="inline-flex min-h-10 items-center justify-center gap-2 rounded-xl border border-surface-border pl-4 pr-4 text-sm font-medium text-copy-primary"
                        >
                            <ArrowLeft className="size-4"/>
                            Back to courses
                        </Link>
                    </CardContent>
                </Card>
            </main>;
    }
    current = course as LecturerCourseDetail;
    return
        <main className="min-h-screen bg-base pt-8 pb-8 pl-6 pr-6 text-copy-primary">
            <div className="mx-auto flex max-w-6xl flex-col gap-6">
                <div className="flex items-start justify-between gap-4">
                    <div>
                        <Link
                            to="/lecturer/courses"
                            className="text-sm text-brand hover:underline"
                        >
                            Courses
                        </Link>
                        <h1 className="mt-2 text-3xl font-bold tracking-tight">
                            {current.track.title}
                        </h1>
                        <p className="text-copy-muted">
                            {current.track.course_code or "No course code"}
                        </p>
                    </div>
                    <span
                        className="rounded-xl border border-surface-border bg-elevated pl-3 pr-3 pt-1 pb-1 text-sm"
                    >
                        {str(current.track.status)}
                    </span>
                </div>
                {if workflow is not None { <><CourseBuildLifecycle workflow={workflow as CourseBuildWorkflowView}/><WorkflowBlockers workflow={workflow as CourseBuildWorkflowView}/></> }}
                {current.track.status == "DRAFT"
                and <div
                    className="rounded-2xl border border-brand/30 bg-accent-dim p-4 text-sm text-brand"
                >
                    This course is a private draft. Learners cannot see or enroll in it.
                </div>}
                <Tabs defaultValue="overview" className="flex w-full flex-col gap-0">
                    <div className="overflow-x-auto border-b border-surface-border">
                        <TabsList variant="line" aria-label="Course workspace sections" className="flex h-auto min-w-max items-end justify-start gap-8 rounded-none p-0">
                            <TabsTrigger value="overview" className="h-12 flex-none rounded-none border-none px-1 text-copy-muted outline-none after:inset-x-0 after:bottom-0 after:h-0.5 after:bg-brand after:content-[''] data-[state=active]:text-brand data-[state=active]:after:opacity-100">Overview</TabsTrigger>
                            <TabsTrigger value="setup" className="h-12 flex-none rounded-none border-none px-1 text-copy-muted outline-none after:inset-x-0 after:bottom-0 after:h-0.5 after:bg-brand after:content-[''] data-[state=active]:text-brand data-[state=active]:after:opacity-100">Course setup</TabsTrigger>
                            <TabsTrigger value="source" className="h-12 flex-none rounded-none border-none px-1 text-copy-muted outline-none after:inset-x-0 after:bottom-0 after:h-0.5 after:bg-brand after:content-[''] data-[state=active]:text-brand data-[state=active]:after:opacity-100">Source material</TabsTrigger>
                            <TabsTrigger value="curriculum" className="h-12 flex-none rounded-none border-none px-1 text-copy-muted outline-none after:inset-x-0 after:bottom-0 after:h-0.5 after:bg-brand after:content-[''] data-[state=active]:text-brand data-[state=active]:after:opacity-100">Curriculum</TabsTrigger>
                            <TabsTrigger value="publishing" className="h-12 flex-none rounded-none border-none px-1 text-copy-muted outline-none after:inset-x-0 after:bottom-0 after:h-0.5 after:bg-brand after:content-[''] data-[state=active]:text-brand data-[state=active]:after:opacity-100">Publishing</TabsTrigger>
                        </TabsList>
                    </div>
                    <TabsContent
                        value="overview"
                        className="mt-0 grid gap-4 pt-6 lg:grid-cols-3"
                    >
                        <Card
                            className="border-surface-border bg-surface text-copy-primary lg:col-span-2"
                        >
                            <CardHeader>
                                <CardTitle>Course overview</CardTitle>
                                <CardDescription>
                                    {current.track.short_description
                                    or "Add a description before publishing."}
                                </CardDescription>
                            </CardHeader>
                            <CardContent>
                                <dl className="grid gap-4 sm:grid-cols-2">
                                    <div>
                                        <dt className="text-sm text-copy-muted">
                                            Subject
                                        </dt>
                                        <dd>
                                            {current.track.subject_area or "Not set"}
                                        </dd>
                                    </div>
                                    <div>
                                        <dt className="text-sm text-copy-muted">
                                            Academic level
                                        </dt>
                                        <dd>
                                            {current.track.academic_level or "Not set"}
                                        </dd>
                                    </div>
                                    <div>
                                        <dt className="text-sm text-copy-muted">
                                            Version
                                        </dt>
                                        <dd>{current.track.current_version_number}</dd>
                                    </div>
                                    <div>
                                        <dt className="text-sm text-copy-muted">
                                            Enrollment
                                        </dt>
                                        <dd>
                                            {"Open"
                                                if current.track.is_enrollment_open
                                                else "Closed"}
                                        </dd>
                                    </div>
                                </dl>
                            </CardContent>
                        </Card>
                        <Card className="border-surface-border bg-surface text-copy-primary">
                            <CardHeader>
                                <CardTitle>Readiness</CardTitle>
                                <CardDescription>
                                    {"Ready to publish"
                                        if current.readiness.publication_ready
                                        else "Setup still required"}
                                </CardDescription>
                            </CardHeader>
                            <CardContent>
                                <ul
                                    className="flex flex-col gap-2 text-sm text-copy-muted"
                                >
                                    {for blocker in current.readiness.blockers {
                                        <li key={blocker}>
                                            • {blocker.replace("_", " ")}
                                        </li>
                                    }}
                                </ul>
                            </CardContent>
                        </Card>
                    </TabsContent>
                    <TabsContent value="setup" className="mt-0 pt-6">
                        <Card className="border-surface-border bg-surface text-copy-primary">
                            <CardHeader>
                                <CardTitle>Learning and assessment defaults</CardTitle>
                                <CardDescription>
                                    Configuration revision {current.configuration.revision}
                                </CardDescription>
                            </CardHeader>
                            <CardContent>
                                <div className="grid gap-4 sm:grid-cols-2">
                                    <p>
                                        Pass score: {current.configuration.default_pass_score}
                                    </p>
                                    <p>
                                        Mastery threshold: {current.configuration.mastery_threshold}
                                    </p>
                                    <p>
                                        Assessment questions: {current.configuration.max_assessment_questions}
                                    </p>
                                    <p>
                                        Lesson duration: {current.configuration.default_lesson_minutes} minutes
                                    </p>
                                </div>
                            </CardContent>
                        </Card>
                    </TabsContent>
                    <TabsContent value="source" className="mt-0 pt-6">
                        <CourseSourceWorkspace track_id={track_id} course={current}/>
                    </TabsContent>
                    <TabsContent value="curriculum" className="mt-0 pt-6">
                        {if workflow is not None { current_flow = workflow as CourseBuildWorkflowView; <Card className="border-surface-border bg-surface text-copy-primary"><CardHeader><CardTitle>Curriculum · {current_flow.stage_label}</CardTitle><CardDescription>{str(current_flow.blueprint.progress_percent) + "% · " + str(current_flow.blueprint.warning_count) + " warnings"}</CardDescription></CardHeader><CardContent className="space-y-4"><p className="text-sm text-copy-secondary">{current_flow.source.blocker_message if not current_flow.source.interpretation_eligible and current_flow.blueprint.blueprint_id is None else "Continue the authoritative blueprint workflow from its current durable state."}</p>{if str(current_flow.current_stage) in ["READY_FOR_GENERATION", "GENERATING_BLUEPRINT", "GENERATION_FAILED", "VALIDATING_BLUEPRINT"] { <Link to={"/lecturer/courses/" + track_id + "/interpretation"} className="inline-flex rounded-md bg-brand px-4 py-2 text-sm font-semibold text-base">{"View generation" if str(current_flow.current_stage) != "READY_FOR_GENERATION" else "Generate blueprint"}</Link> } elif str(current_flow.current_stage) in ["READY_FOR_REVIEW", "REVIEW_IN_PROGRESS", "CHANGES_REQUIRED"] { <Link to={"/lecturer/courses/" + track_id + "/blueprint"} className="inline-flex rounded-md bg-brand px-4 py-2 text-sm font-semibold text-base">Review blueprint</Link> } elif str(current_flow.current_stage) in ["APPROVED", "PUBLICATION_BLOCKED", "READY_TO_PUBLISH"] { <Link to={"/lecturer/courses/" + track_id + "/publication"} className="inline-flex rounded-md bg-brand px-4 py-2 text-sm font-semibold text-base">Continue to publication</Link> } elif str(current_flow.current_stage) == "PUBLISHED" { <p className="rounded-md border border-success/40 bg-success/10 p-3 text-success">Published immutable version {str(current_flow.version_number)}</p> }}</CardContent></Card> }}
                    </TabsContent>
                    <TabsContent value="publishing" className="mt-0 pt-6">
                        {if workflow is not None { current_flow = workflow as CourseBuildWorkflowView; <Card className="border-surface-border bg-surface text-copy-primary"><CardHeader><CardTitle>Publishing</CardTitle><CardDescription>{"Active version " + (current_flow.active_version_id or "None") + " · Visibility " + str(current.track.visibility) + " · Enrollment " + ("open" if current.track.is_enrollment_open else "closed")}</CardDescription></CardHeader><CardContent className="space-y-4">{if current_flow.review is not None { <p>{"Approval: " + (current_flow.review.status if current_flow.review is not None else "Not approved") + " · Revision " + str(current_flow.review.revision if current_flow.review is not None else 0)}</p> }}<WorkflowBlockers workflow={current_flow}/><Link to={"/lecturer/courses/" + track_id + "/publication"} className="inline-flex rounded-md bg-brand px-4 py-2 text-sm font-semibold text-base">{"View published version" if str(current_flow.current_stage) == "PUBLISHED" else "View publication readiness"}</Link></CardContent></Card> }}
                    </TabsContent>
                </Tabs>
            </div>
        </main>;
}
