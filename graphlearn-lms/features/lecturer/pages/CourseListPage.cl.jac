"""Bounded lecturer-owned course list."""

import from "@jac/runtime" { Link }
import from "...components.ui.card" { Card, CardContent, CardDescription, CardHeader, CardTitle }
import from "...components.ui.input" { Input }
sv import from ...services.course_management { LecturerCourseList, LecturerCourseSummary, load_lecturer_courses }

def:pub CourseListPage() -> JsxElement {
    has result: LecturerCourseList | None = None, search: str = "", loading: bool = True, error_message: str = "";

    async def load {
        loading = True; error_message = "";
        try { result = await load_lecturer_courses(search if search.strip() != "" else None, None, 20, None, "updated_desc"); }
        except Exception { error_message = "Courses could not be loaded."; }
        loading = False;
    }
    async can with entry { await load(); }

    items: list[LecturerCourseSummary] = [];
    if result is not None { items = (result as LecturerCourseList).items; }
    return <main className="min-h-screen bg-base pt-8 pb-8 pl-6 pr-6 text-copy-primary">
        <div className="mx-auto flex max-w-6xl flex-col gap-6">
            <div className="flex items-center justify-between gap-4"><div><p className="text-sm text-copy-muted">Lecturer workspace</p><h1 className="text-3xl font-bold tracking-tight">Courses</h1></div><Link to="/lecturer/courses/new" className="rounded-xl bg-brand pl-4 pr-4 pt-2 pb-2 font-medium text-base">Create course</Link></div>
            <Input value={search} placeholder="Search title, code, or subject" onChange={lambda (e: ChangeEvent) { search = e.target.value; }} onKeyDown={lambda (e: KeyboardEvent) { if e.key == "Enter" { load(); } }} />
            {error_message != "" and <p className="text-state-error">{error_message}</p>}
            {if loading { <p className="text-copy-muted">Loading courses…</p> }
            elif len(items) == 0 { <Card className="border-surface-border bg-surface"><CardHeader><CardTitle>No courses yet</CardTitle><CardDescription>Create your first private draft course.</CardDescription></CardHeader></Card> }
            else { <div className="grid gap-4 md:grid-cols-2">{for item in items { <Link key={item.track_id} to={"/lecturer/courses/" + item.track_id}><Card className="h-full border-surface-border bg-surface transition hover:border-brand"><CardHeader><CardTitle>{item.title}</CardTitle><CardDescription>{item.course_code or item.subject_area or "Private lecturer course"}</CardDescription></CardHeader><CardContent><div className="flex items-center justify-between text-sm text-copy-muted"><span>{str(item.status)}</span><span>Revision {item.revision}</span></div></CardContent></Card></Link> }}</div> }}
        </div>
    </main>;
}
