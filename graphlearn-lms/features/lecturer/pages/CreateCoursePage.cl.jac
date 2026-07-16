"""Lecturer course creation shell."""

import from "@jac/runtime" { Link, useNavigate }
import from "...components.ui.button" { Button }
import from "...components.ui.card" { Card, CardContent, CardDescription, CardHeader, CardTitle }
import from "...components.ui.input" { Input }
import from "...components.ui.textarea" { Textarea }
sv import from ...services.course_management { CreateCourseTrackInput, LecturerCourseDetail, create_lecturer_course }

def:pub CreateCoursePage() -> JsxElement {
    has title: str = "", short_description: str = "", course_code: str = "",
        subject_area: str = "", academic_level: str = "", duration: str = "",
        saving: bool = False, error_message: str = "";
    navigate = useNavigate();

    async def submit(event: FormEvent) {
        event.preventDefault();
        if saving { return; }
        saving = True; error_message = "";
        try {
            weeks: int | None = int(duration) if duration.strip() != "" else None;
            request_id = "course-" + str(new(Date).getTime()); # jac:ignore[W2001,W6002]
            created = await create_lecturer_course(CreateCourseTrackInput(
                title=title, short_description=short_description,
                course_code=course_code if course_code.strip() != "" else None,
                subject_area=subject_area if subject_area.strip() != "" else None,
                academic_level=academic_level if academic_level.strip() != "" else None,
                estimated_duration_weeks=weeks, client_request_id=request_id
            ));
            navigate("/lecturer/courses/" + created.track.track_id);
        } except Exception as error {
            error_message = "Course could not be created. Check the highlighted values and try again.";
        } finally { saving = False; }
    }

    return <main className="min-h-screen bg-base pt-8 pb-8 pl-6 pr-6 text-copy-primary">
        <div className="mx-auto flex max-w-5xl flex-col gap-6">
            <div className="flex items-center justify-between gap-4">
                <div><p className="text-sm text-copy-muted">Lecturer workspace</p><h1 className="text-3xl font-bold tracking-tight">Create course</h1></div>
                <Link to="/lecturer/courses" className="text-sm text-brand hover:underline">Back to courses</Link>
            </div>
            <Card className="border-surface-border bg-surface">
                <CardHeader><CardTitle>Course setup</CardTitle><CardDescription>Create a private draft. Learners cannot see or enroll in it.</CardDescription></CardHeader>
                <CardContent>
                    <form className="flex flex-col gap-6" onSubmit={submit}>
                        <div className="grid gap-4 md:grid-cols-2">
                            <label className="flex flex-col gap-2 text-sm">Title<Input value={title} required={True} maxLength={160} onChange={lambda (e: ChangeEvent) { title = e.target.value; }} /></label>
                            <label className="flex flex-col gap-2 text-sm">Course code<Input value={course_code} maxLength={40} placeholder="CSC 220" onChange={lambda (e: ChangeEvent) { course_code = e.target.value; }} /></label>
                            <label className="flex flex-col gap-2 text-sm">Subject area<Input value={subject_area} onChange={lambda (e: ChangeEvent) { subject_area = e.target.value; }} /></label>
                            <label className="flex flex-col gap-2 text-sm">Academic level<Input value={academic_level} onChange={lambda (e: ChangeEvent) { academic_level = e.target.value; }} /></label>
                            <label className="flex flex-col gap-2 text-sm">Duration in weeks<Input type="number" min="1" max="260" value={duration} onChange={lambda (e: ChangeEvent) { duration = e.target.value; }} /></label>
                        </div>
                        <label className="flex flex-col gap-2 text-sm">Short description<Textarea value={short_description} maxLength={1000} onChange={lambda (e: ChangeEvent) { short_description = e.target.value; }} /></label>
                        {error_message != "" and <p className="text-sm text-state-error" role="alert">{error_message}</p>}
                        <div className="flex justify-end"><Button type="submit" disabled={saving}>{"Creating…" if saving else "Create private draft"}</Button></div>
                    </form>
                </CardContent>
            </Card>
        </div>
    </main>;
}
