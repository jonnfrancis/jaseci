"""Guarded placeholder for the next AI-owned course interpretation feature."""

import from "@jac/runtime" { Link, Navigate, useParams }
import from "....components.ui.card" { Card, CardDescription, CardHeader, CardTitle }
import from "..components.LecturerLoadingSkeleton" { LecturerLoadingSkeleton }
sv import from ....services.course_management { CourseSourceWorkspaceView, LecturerCourseDetail, load_course_source_workspace, load_lecturer_course }

def:pub CourseInterpretationPage() -> JsxElement {
    has loading: bool = True, allowed: bool = False;
    params = useParams(); raw_track_id = params["trackId"];
    track_id = str(raw_track_id) if raw_track_id else "";
    async can with entry {
        if track_id != "" {
            try {
                course = await load_lecturer_course(track_id);
                if course.draft_version is not None {
                    source = await load_course_source_workspace(track_id, course.draft_version.track_version_id);
                    allowed = source.interpretation_eligible;
                }
            } except Exception { allowed = False; }
        }
        loading = False;
    }
    if loading { return <LecturerLoadingSkeleton/>; }
    if not allowed { return <Navigate to={"/lecturer/courses/" + track_id} replace={True}/>; }
    return <main className="min-h-screen bg-base px-6 py-8 text-copy-primary"><div className="mx-auto max-w-3xl"><Link to={"/lecturer/courses/" + track_id} className="text-sm text-brand hover:underline">← Back to course</Link><Card className="mt-5 border-ai-accent/40 bg-surface"><CardHeader><CardTitle>Ready for AI course interpretation</CardTitle><CardDescription>The verified source handoff is ready. Blueprint generation belongs to the next feature and has not started.</CardDescription></CardHeader></Card></div></main>;
}
