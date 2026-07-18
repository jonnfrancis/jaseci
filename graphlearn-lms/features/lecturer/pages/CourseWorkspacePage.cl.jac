"""Owned lecturer course overview and setup workspace."""

import from "@jac/runtime" { Link, useParams }
import from "lucide-react" { AlertCircle, ArrowLeft, FileText, RefreshCw, Upload }
import from "....components.ui.button" { Button }
import from "....components.ui.card" { Card, CardContent, CardDescription, CardHeader, CardTitle }
import from "....components.ui.tabs" { Tabs, TabsContent, TabsList, TabsTrigger }
import from "..components.LecturerLoadingSkeleton" { LecturerLoadingSkeleton }
sv import from ....services.course_management {
    CourseDocument, LecturerCourseDetail, UploadCourseDocumentInput,
    load_course_source_document, load_lecturer_course, upload_lecturer_course_document
}

glob DOCUMENT_MAX_BYTES: int = 25 * 1024 * 1024;

async def encode_file(file: any) -> str {
    buffer = await file.arrayBuffer(); values = new(Uint8Array, buffer); binary = "";
    for index in range(values.length) { binary += chr(values[index]); }
    return btoa(binary) as str;
}

def:pub CourseWorkspacePage() -> JsxElement {
    has course: LecturerCourseDetail | None = None, source_document: CourseDocument | None = None;
    has selected_file: any = None, loading: bool = True, uploading: bool = False, replace_confirmed: bool = False;
    has error_message: str = "", upload_message: str = "";
    params = useParams(); raw_track_id = params["trackId"];
    track_id = str(raw_track_id) if raw_track_id else "";

    async def load_course() {
        loading = True; error_message = "";
        if track_id != "" {
            try {
                course = await load_lecturer_course(track_id); loaded = course as LecturerCourseDetail;
                if loaded.draft_version is not None { source_document = await load_course_source_document(track_id, loaded.draft_version.track_version_id); }
            }
            except Exception { error_message = "This course could not be opened. It may still be syncing or may no longer be available in your teaching workspace."; }
        } else {
            error_message = "The course link is incomplete.";
        }
        loading = False;
    }

    async can with entry { await load_course(); }

    def choose_file(event: ChangeEvent) {
        upload_message = ""; replace_confirmed = False; files = event.target.files as any; selected_file = files[0] if files and (files.length as int) > 0 else None;
        if selected_file is None { return; }
        name = str(selected_file.name).lower();
        if not (name.endswith(".pdf") or name.endswith(".docx")) { upload_message = "Only PDF and DOCX files are supported."; selected_file = None; }
        elif selected_file.size <= 0 { upload_message = "The selected file is empty."; selected_file = None; }
        elif selected_file.size > DOCUMENT_MAX_BYTES { upload_message = "The selected file exceeds the 25 MB limit."; selected_file = None; }
    }

    async def submit_document() {
        if selected_file is None or course is None or (source_document is not None and not replace_confirmed) { return; }
        detail = course as LecturerCourseDetail;
        if detail.draft_version is None { upload_message = "This course has no editable draft version."; return; }
        uploading = True; upload_message = "Uploading and validating document...";
        try {
            payload = await encode_file(selected_file);
            request = UploadCourseDocumentInput(track_id=track_id, track_version_id=detail.draft_version.track_version_id, original_filename=str(selected_file.name), mime_type=str(selected_file.type), file_size_bytes=int(selected_file.size), idempotency_key=str(selected_file.name) + "-" + str(selected_file.size) + "-" + str(selected_file.lastModified), content_base64=payload, replace_existing=replace_confirmed);
            result = await upload_lecturer_course_document(request);
            if result.ok { upload_message = "Source document uploaded successfully." if not result.duplicate else "This source document was already uploaded."; source_document = await load_course_source_document(track_id, detail.draft_version.track_version_id); selected_file = None; replace_confirmed = False; }
            else { upload_message = result.error.message if result.error is not None else "The source document could not be uploaded."; }
        } except Exception { upload_message = "The source document could not be uploaded. You can safely retry."; }
        uploading = False;
    }

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
                <TabsContent value="source" className="mt-6"><Card className="border-surface-border bg-surface"><CardHeader><CardTitle>Source material</CardTitle><CardDescription>Upload one PDF or DOCX (maximum 25 MB). Processing starts separately after upload.</CardDescription></CardHeader><CardContent className="space-y-5">
                    {source_document is not None and <div className="flex items-start gap-3 rounded-xl border border-surface-border bg-elevated p-4"><FileText className="mt-0.5 size-5 text-brand" /><div><p className="font-medium">{source_document.original_filename}</p><p className="text-sm text-copy-muted">{str(source_document.upload_status)} · {source_document.file_size_bytes} bytes · Processing {str(source_document.processing_status).lower().replace("_", " ")}</p></div></div>}
                    {source_document is None and <div className="rounded-xl border border-dashed border-surface-border p-6 text-center text-copy-muted">No notes uploaded</div>}
                    <div className="space-y-3"><label className="block text-sm font-medium" htmlFor="course-document">Choose PDF/DOCX</label><input id="course-document" type="file" accept=".pdf,.docx,application/pdf,application/vnd.openxmlformats-officedocument.wordprocessingml.document" disabled={uploading} onChange={choose_file} className="block w-full rounded-xl border border-surface-border bg-base p-3 text-sm" />
                    {selected_file is not None and <p className="text-sm text-copy-muted">Selected: {selected_file.name} ({selected_file.size} bytes)</p>}
                    {source_document is not None and selected_file is not None and <div className="rounded-xl border border-state-warning/40 bg-state-warning/10 p-4"><p className="font-medium">Replace current source document?</p><p className="mt-1 text-sm text-copy-muted">Replacing the document will invalidate any unapproved generated curriculum created from the current source.</p><label className="mt-3 flex items-center gap-2 text-sm"><input type="checkbox" checked={replace_confirmed} onChange={lambda (event: ChangeEvent) { replace_confirmed = event.target.checked; }} />I understand and want to replace it</label></div>}
                    {upload_message != "" and <p className="text-sm text-copy-muted" role="status">{upload_message}</p>}
                    <Button disabled={uploading or selected_file is None or (source_document is not None and not replace_confirmed)} onClick={lambda (_e: MouseEvent) { submit_document(); }}><Upload className="size-4" />{"Uploading..." if uploading else ("Replace document" if source_document is not None else "Upload document")}</Button></div>
                </CardContent></Card></TabsContent>
                <TabsContent value="curriculum" className="mt-6"><Card className="border-surface-border bg-surface"><CardHeader><CardTitle>Curriculum</CardTitle><CardDescription>Curriculum generation is locked until source material is ready.</CardDescription></CardHeader></Card></TabsContent>
                <TabsContent value="publishing" className="mt-6"><Card className="border-surface-border bg-surface"><CardHeader><CardTitle>Publishing</CardTitle><CardDescription>Resolve readiness blockers before requesting publication.</CardDescription></CardHeader></Card></TabsContent>
            </Tabs>
        </div>
    </main>;
}
