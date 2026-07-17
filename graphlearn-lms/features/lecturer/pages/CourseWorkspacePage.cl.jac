"""Owned lecturer course overview and setup workspace."""

import from "@jac/runtime" { Link, useParams }
import from "lucide-react" { AlertCircle, ArrowLeft, RefreshCw }
import from "....components.ui.button" { Button }
import from "....components.ui.card" { Card, CardContent, CardDescription, CardHeader, CardTitle }
import from "....components.ui.tabs" { Tabs, TabsContent, TabsList, TabsTrigger }
import from "..components.LecturerLoadingSkeleton" { LecturerLoadingSkeleton }
sv import from ....services.course_management { LecturerCourseDetail, load_lecturer_course }

def:pub CourseWorkspacePage() -> JsxElement {
    has course: LecturerCourseDetail | None = None, loading: bool = True, error_message: str = "";
    params = useParams(); raw_track_id = params["trackId"];
    track_id = str(raw_track_id) if raw_track_id else "";

    async def load_course() {
        loading = True; error_message = "";
        if track_id != "" {
            try { course = await load_lecturer_course(track_id); }
            except Exception { error_message = "This course could not be opened. It may still be syncing or may no longer be available in your teaching workspace."; }
        } else {
            error_message = "The course link is incomplete.";
        }
        loading = False;
    }

    async can with entry { await load_course(); }

    if loading { return <LecturerLoadingSkeleton />; }
    if course is None { return <main className="flex min-h-screen items-center justify-center bg-base p-6 text-copy-primary">
        <Card className="w-full max-w-xl border-surface-border bg-surface text-copy-primary">
            <CardHeader><div className="flex items-start gap-3"><div className="flex size-10 shrink-0 items-center justify-center rounded-xl bg-state-error/10 text-state-error"><AlertCircle className="size-5" /></div><div><CardTitle className="text-copy-primary">Course unavailable</CardTitle><CardDescription>{error_message if error_message != "" else "The course workspace could not be loaded."}</CardDescription></div></div></CardHeader>
            <CardContent className="flex flex-col gap-3 sm:flex-row"><Button onClick={lambda (_e: MouseEvent) { load_course(); }}><RefreshCw className="size-4" />Try again</Button><Link to="/lecturer/courses" className="inline-flex min-h-10 items-center justify-center gap-2 rounded-xl border border-surface-border pl-4 pr-4 text-sm font-medium text-copy-primary"><ArrowLeft className="size-4" />Back to courses</Link></CardContent>
        </Card>
    </main>; }
    current = course as LecturerCourseDetail;
    return <main className="min-h-screen bg-base pt-8 pb-8 pl-6 pr-6 text-copy-primary">
        <div className="mx-auto flex max-w-6xl flex-col gap-6">
            <div className="flex items-start justify-between gap-4">
                <div><Link to="/lecturer/courses" className="text-sm text-brand hover:underline">Courses</Link><h1 className="mt-2 text-3xl font-bold tracking-tight">{current.track.title}</h1><p className="text-copy-muted">{current.track.course_code or "No course code"}</p></div>
                <span className="rounded-xl border border-surface-border bg-elevated pl-3 pr-3 pt-1 pb-1 text-sm">{str(current.track.status)}</span>
            </div>
            {current.track.status == "DRAFT" and <div className="rounded-2xl border border-brand/30 bg-accent-dim p-4 text-sm text-brand">This course is a private draft. Learners cannot see or enroll in it.</div>}
            <Tabs defaultValue="overview">
                <TabsList><TabsTrigger value="overview">Overview</TabsTrigger><TabsTrigger value="setup">Course setup</TabsTrigger><TabsTrigger value="source">Source material</TabsTrigger><TabsTrigger value="curriculum">Curriculum</TabsTrigger><TabsTrigger value="publishing">Publishing</TabsTrigger></TabsList>
                <TabsContent value="overview" className="mt-6 grid gap-4 lg:grid-cols-3">
                    <Card className="border-surface-border bg-surface lg:col-span-2"><CardHeader><CardTitle>Course overview</CardTitle><CardDescription>{current.track.short_description or "Add a description before publishing."}</CardDescription></CardHeader><CardContent><dl className="grid gap-4 sm:grid-cols-2"><div><dt className="text-sm text-copy-muted">Subject</dt><dd>{current.track.subject_area or "Not set"}</dd></div><div><dt className="text-sm text-copy-muted">Academic level</dt><dd>{current.track.academic_level or "Not set"}</dd></div><div><dt className="text-sm text-copy-muted">Version</dt><dd>{current.track.current_version_number}</dd></div><div><dt className="text-sm text-copy-muted">Enrollment</dt><dd>{"Open" if current.track.is_enrollment_open else "Closed"}</dd></div></dl></CardContent></Card>
                    <Card className="border-surface-border bg-surface"><CardHeader><CardTitle>Readiness</CardTitle><CardDescription>{"Ready to publish" if current.readiness.publication_ready else "Setup still required"}</CardDescription></CardHeader><CardContent><ul className="flex flex-col gap-2 text-sm text-copy-muted">{for blocker in current.readiness.blockers { <li key={blocker}>• {blocker.replace("_", " ")}</li> }}</ul></CardContent></Card>
                </TabsContent>
                <TabsContent value="setup" className="mt-6"><Card className="border-surface-border bg-surface"><CardHeader><CardTitle>Learning and assessment defaults</CardTitle><CardDescription>Configuration revision {current.configuration.revision}</CardDescription></CardHeader><CardContent><div className="grid gap-4 sm:grid-cols-2"><p>Pass score: {current.configuration.default_pass_score}</p><p>Mastery threshold: {current.configuration.mastery_threshold}</p><p>Assessment questions: {current.configuration.max_assessment_questions}</p><p>Lesson duration: {current.configuration.default_lesson_minutes} minutes</p></div></CardContent></Card></TabsContent>
                <TabsContent value="source" className="mt-6"><Card className="border-surface-border bg-surface"><CardHeader><CardTitle>Source material</CardTitle><CardDescription>Document upload is delivered by the next course-content feature.</CardDescription></CardHeader></Card></TabsContent>
                <TabsContent value="curriculum" className="mt-6"><Card className="border-surface-border bg-surface"><CardHeader><CardTitle>Curriculum</CardTitle><CardDescription>Curriculum generation is locked until source material is ready.</CardDescription></CardHeader></Card></TabsContent>
                <TabsContent value="publishing" className="mt-6"><Card className="border-surface-border bg-surface"><CardHeader><CardTitle>Publishing</CardTitle><CardDescription>Resolve readiness blockers before requesting publication.</CardDescription></CardHeader></Card></TabsContent>
            </Tabs>
        </div>
    </main>;
}
