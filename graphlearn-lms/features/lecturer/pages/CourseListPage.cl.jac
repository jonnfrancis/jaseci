"""Responsive, action-oriented lecturer course dashboard."""

import from react { useEffect }
import from "@jac/runtime" { Link, useNavigate }
import from "....components.ui.card" {
    Card,
    CardContent,
    CardDescription,
    CardHeader,
    CardTitle
}
import from "....components.ui.input" { Input }
import from "....lib.auth.workspace_client" { select_workspace }
import from "....lib.utils" { format_datetime }
sv import from ....services.identity { WorkspaceKind }
sv import from ....services.course_management {
    CourseReadinessState,
    LearningTrackStatus,
    LecturerCourseDashboardItem,
    LecturerCourseSort,
    LecturerDashboardQuery,
    LecturerDashboardResponse,
    SortDirection,
    get_lecturer_course_dashboard
}

def _label(value: str) -> str {
    return value.replace("_", " ").title();
}

def:pub CourseListPage() -> JsxElement {
    nav = useNavigate();
    has dashboard: LecturerDashboardResponse | None = None;
    has search: str = "",
        status_filter: str = "",
        readiness_filter: str = "",
        subject_filter: str = "";
    has include_archived: bool = False,
        sort_value: str = "UPDATED_DESC";
    has page: int = 1,
        loading: bool = True,
        refreshing: bool = False,
        error_message: str = "";

    async def load(target_page: int = 1) {
        if dashboard is None {
            loading = True;
        } else {
            refreshing = True;
        }
        error_message = "";
        statuses: list[LearningTrackStatus] = [];
        readiness: list[CourseReadinessState] = [];
        subjects: list[str] = [];
        if status_filter != "" {
            statuses = [status_filter as LearningTrackStatus];
        }
        if readiness_filter != "" {
            readiness = [readiness_filter as CourseReadinessState];
        }
        if subject_filter != "" {
            subjects = [subject_filter];
        }
        sort_by = ("TITLE" as LecturerCourseSort)
            if sort_value in ["TITLE_ASC", "TITLE_DESC"]
            else ("UPDATED_AT" as LecturerCourseSort);
        direction = ("ASC" as SortDirection)
            if sort_value in ["TITLE_ASC", "UPDATED_ASC"]
            else ("DESC" as SortDirection);
        try {
            query = {
                "search": search if search.strip() != "" else None,
                "statuses": statuses,
                "readiness_states": readiness,
                "visibilities": [],
                "subject_areas": subjects,
                "include_archived": include_archived,
                "sort_by": sort_by,
                "sort_direction": direction,
                "page": target_page,
                "page_size": 20
            } as LecturerDashboardQuery;
            dashboard = await get_lecturer_course_dashboard(query);
            page = target_page;
        } except Exception as e {
            error_message = "Courses could not be loaded. " + str(e);
        }
        loading = False;
        refreshing = False;
    }

    async can with entry {
        await load();
    }
    useEffect(
        lambda {
            timer = setTimeout(lambda { load(1); }, 350);
            return lambda { clearTimeout(timer); };
        },
        [
            search,
            status_filter,
            readiness_filter,
            subject_filter,
            include_archived,
            sort_value
        ]
    );

    courses: list[LecturerCourseDashboardItem] = [];
    if dashboard is not None {
        courses = (dashboard as LecturerDashboardResponse).courses;
    }
    def clear_filters(e: MouseEvent) {
        search = "";
        status_filter = "";
        readiness_filter = "";
        subject_filter = "";
        include_archived = False;
    }
    async def open_learning_workspace() {
        try {
            bootstrap = await select_workspace(WorkspaceKind.LEARNER);
            nav(bootstrap.recommended_route);
        } except Exception {
            error_message = "The learning workspace is not available for this account.";
        }
    }
    return
        <main className="min-h-screen bg-base px-4 py-8 text-copy-primary sm:px-6">
            <div
                className="mx-auto flex max-w-7xl flex-col gap-7"
                aria-busy={loading or refreshing}
            >
                <header
                    className="flex flex-col justify-between gap-4 sm:flex-row sm:items-end"
                >
                    <div>
                        <p className="text-sm font-medium text-brand">
                            Lecturer workspace
                        </p>
                        <h1 className="text-3xl font-bold tracking-tight">
                            Course dashboard
                        </h1>
                        <p className="mt-1 text-copy-muted">
                            Manage course setup, review, and publication from one workspace.
                        </p>
                    </div>
                    <div className="flex flex-wrap gap-3">
                        <button
                            type="button"
                            aria-label="Switch to learning workspace"
                            onClick={lambda (_e: MouseEvent) { open_learning_workspace(); }}
                            className="min-h-11 rounded-xl border border-surface-border px-4 py-2 text-sm"
                        >
                            Learning workspace
                        </button>
                        <Link
                            to="/lecturer/onboarding/status"
                            className="inline-flex min-h-11 items-center rounded-xl border border-surface-border px-4 py-2 text-sm"
                        >
                            Profile & status
                        </Link>
                        <Link
                            to="/lecturer/courses/new"
                            className="inline-flex min-h-11 items-center justify-center rounded-xl bg-brand px-5 py-2 font-semibold text-base"
                        >
                            Create course
                        </Link>
                    </div>
                </header>
                {if loading and dashboard is None {
                    <section
                        aria-label="Loading dashboard"
                        className="grid animate-pulse grid-cols-2 gap-3 lg:grid-cols-5"
                    >
                        {for i in range(5) {
                            <div
                                key={str(i)}
                                className="h-24 rounded-2xl border border-surface-border bg-surface"
                            />
                        }}
                    </section>
                    <div className="grid animate-pulse gap-4 md:grid-cols-2">
                        <div className="h-56 rounded-2xl bg-surface"/>
                        <div className="h-56 rounded-2xl bg-surface"/>
                    </div>
                } else {
                    if dashboard is not None {
                        <section
                            aria-label="Course summary"
                            className="grid grid-cols-2 gap-3 lg:grid-cols-5"
                        >
                            <Card
                                className="border-surface-border bg-surface text-copy-primary"
                            >
                                <CardHeader>
                                    <CardDescription>Total courses</CardDescription>
                                    <CardTitle
                                        className="text-3xl font-semibold tabular-nums text-copy-primary"
                                    >
                                        {(
                                            dashboard as LecturerDashboardResponse
                                        ).summary.total_courses}
                                    </CardTitle>
                                </CardHeader>
                            </Card>
                            <Card
                                className="border-surface-border bg-surface text-copy-primary"
                            >
                                <CardHeader>
                                    <CardDescription>Drafts</CardDescription>
                                    <CardTitle
                                        className="text-3xl font-semibold tabular-nums text-copy-primary"
                                    >
                                        {(
                                            dashboard as LecturerDashboardResponse
                                        ).summary.draft_courses}
                                    </CardTitle>
                                </CardHeader>
                            </Card>
                            <Card
                                className="border-surface-border bg-surface text-copy-primary"
                            >
                                <CardHeader>
                                    <CardDescription>Needs review</CardDescription>
                                    <CardTitle
                                        className="text-3xl font-semibold tabular-nums text-copy-primary"
                                    >
                                        {(
                                            dashboard as LecturerDashboardResponse
                                        ).summary.review_required_courses}
                                    </CardTitle>
                                </CardHeader>
                            </Card>
                            <Card
                                className="border-surface-border bg-surface text-copy-primary"
                            >
                                <CardHeader>
                                    <CardDescription>Published</CardDescription>
                                    <CardTitle
                                        className="text-3xl font-semibold tabular-nums text-copy-primary"
                                    >
                                        {(
                                            dashboard as LecturerDashboardResponse
                                        ).summary.published_courses}
                                    </CardTitle>
                                </CardHeader>
                            </Card>
                            <Card
                                className="border-surface-border bg-surface text-copy-primary"
                            >
                                <CardHeader>
                                    <CardDescription>Needs attention</CardDescription>
                                    <CardTitle
                                        className="text-3xl font-semibold tabular-nums text-copy-primary"
                                    >
                                        {(
                                            dashboard as LecturerDashboardResponse
                                        ).summary.failed_courses}
                                    </CardTitle>
                                </CardHeader>
                            </Card>
                        </section>
                    }
                    <section
                        aria-label="Course filters"
                        className="rounded-2xl border border-surface-border bg-surface p-4"
                    >
                        <label
                            htmlFor="course-search"
                            className="mb-2 block text-sm font-medium"
                        >
                            Search courses
                        </label>
                        <div className="grid gap-3 lg:grid-cols-5">
                            <Input
                                id="course-search"
                                value={search}
                                placeholder="Title, code, subject, or slug"
                                onChange={lambda (e: ChangeEvent) { search = e.target.value; }}
                            />
                            <select
                                aria-label="Lifecycle status"
                                value={status_filter}
                                onChange={lambda (e: ChangeEvent) { status_filter = e.target.value; }}
                                className="min-h-10 rounded-lg border border-surface-border bg-base px-3"
                            >
                                <option value="">All statuses</option>
                                <option value="DRAFT">Draft</option>
                                <option value="PROCESSING">Processing</option>
                                <option value="REVIEW_REQUIRED">Review required</option>
                                <option value="PUBLISHED">Published</option>
                                <option value="FAILED">Failed</option>
                                <option value="ARCHIVED">Archived</option>
                            </select>
                            <select
                                aria-label="Readiness"
                                value={readiness_filter}
                                onChange={lambda (e: ChangeEvent) { readiness_filter = e.target.value; }}
                                className="min-h-10 rounded-lg border border-surface-border bg-base px-3"
                            >
                                <option value="">All readiness</option>
                                {if dashboard is not None {
                                    for state in (
                                        dashboard as LecturerDashboardResponse
                                    ).available_filters.readiness_states {
                                        <option key={str(state)} value={str(state)}>
                                            {_label(str(state))}
                                        </option>
                                    }
                                }}
                            </select>
                            <select
                                aria-label="Subject area"
                                value={subject_filter}
                                onChange={lambda (e: ChangeEvent) { subject_filter = e.target.value; }}
                                className="min-h-10 rounded-lg border border-surface-border bg-base px-3"
                            >
                                <option value="">All subjects</option>
                                {if dashboard is not None {
                                    for subject in (
                                        dashboard as LecturerDashboardResponse
                                    ).available_filters.subject_areas {
                                        <option key={subject} value={subject}>
                                            {subject}
                                        </option>
                                    }
                                }}
                            </select>
                            <select
                                aria-label="Sort courses"
                                value={sort_value}
                                onChange={lambda (e: ChangeEvent) { sort_value = e.target.value; }}
                                className="min-h-10 rounded-lg border border-surface-border bg-base px-3"
                            >
                                <option value="UPDATED_DESC">Recently updated</option>
                                <option value="UPDATED_ASC">Oldest updated</option>
                                <option value="TITLE_ASC">Title A-Z</option>
                                <option value="TITLE_DESC">Title Z-A</option>
                            </select>
                        </div>
                        <label
                            className="mt-3 inline-flex cursor-pointer items-center gap-2 text-sm"
                        >
                            <input
                                type="checkbox"
                                checked={include_archived}
                                onChange={lambda (e: ChangeEvent) { include_archived = e.target.checked; }}
                            />{" "}
                            Show archived courses
                        </label>
                    </section>
                    if error_message != "" {
                        <section
                            role="alert"
                            className="rounded-xl border border-state-error p-4 text-state-error"
                        >
                            <p>{error_message}</p>
                            <button
                                className="mt-2 underline"
                                onClick={lambda (e: MouseEvent) { load(page); }}
                            >
                                Try again
                            </button>
                        </section>
                    }
                    if not loading and len(courses) == 0 {
                        <Card
                            className="border-surface-border bg-surface text-copy-primary"
                        >
                            <CardHeader>
                                <CardTitle className="text-copy-primary">
                                    {"You have not created any courses yet."
                                        if dashboard is not None
                                        and (
                                            dashboard as LecturerDashboardResponse
                                        ).summary.total_courses == 0
                                        else "No courses match the current search and filters."}
                                </CardTitle>
                                <CardDescription>
                                    {"Create your first course to upload notes and build an adaptive learning track."
                                        if dashboard is not None
                                        and (
                                            dashboard as LecturerDashboardResponse
                                        ).summary.total_courses == 0
                                        else "Try clearing the current filters."}
                                </CardDescription>
                            </CardHeader>
                            <CardContent>
                                {if dashboard is not None
                                and (
                                    dashboard as LecturerDashboardResponse
                                ).summary.total_courses == 0 {
                                    <Link
                                        to="/lecturer/courses/new"
                                        className="font-semibold text-brand"
                                    >
                                        Create course
                                    </Link>
                                } else {
                                    <button
                                        onClick={clear_filters}
                                        className="font-semibold text-brand"
                                    >
                                        Clear filters
                                    </button>
                                } }
                            </CardContent>
                        </Card>
                    } else {
                        <section
                            aria-label="Managed courses"
                            className="grid gap-4 md:grid-cols-2 xl:grid-cols-3"
                        >
                            {for course in courses {
                                <Card
                                    key={course.track_id}
                                    className="flex h-full flex-col border-surface-border bg-surface"
                                >
                                    <CardHeader>
                                        <div
                                            className="flex items-start justify-between gap-3"
                                        >
                                            <div>
                                                <CardTitle>{course.title}</CardTitle>
                                                <CardDescription>
                                                    {course.course_code
                                                    or course.subject_area
                                                    or "Private lecturer course"}
                                                </CardDescription>
                                            </div>
                                            <span
                                                className="rounded-full border border-surface-border px-2 py-1 text-xs font-semibold"
                                            >
                                                {_label(str(course.status))}
                                            </span>
                                        </div>
                                    </CardHeader>
                                    <CardContent className="flex flex-1 flex-col gap-4">
                                        <div>
                                            <div
                                                className="mb-1 flex justify-between text-sm"
                                            >
                                                <span>
                                                    {_label(
                                                        str(course.readiness_state)
                                                    )}
                                                </span>
                                                <span>{course.readiness_percent}%</span>
                                            </div>
                                            <div
                                                role="progressbar"
                                                aria-label={course.title + " setup progress"}
                                                aria-valuemin={0}
                                                aria-valuemax={100}
                                                aria-valuenow={course.readiness_percent}
                                                className="h-2 overflow-hidden rounded-full bg-surface-border"
                                            >
                                                <div
                                                    className="h-full bg-brand"
                                                    style={{
                                                        "width": str(
                                                            course.readiness_percent
                                                        ) + "%"
                                                    }}
                                                />
                                            </div>
                                        </div>
                                        <div className="text-sm text-copy-muted">
                                            <p>
                                                {"Active: version " + str(
                                                    course.active_version_number
                                                )
                                                    if course.active_version_number is not None
                                                    else "Draft version " + str(
                                                        course.draft_version_number or 1
                                                    )}
                                            </p>
                                            <p>Updated {format_datetime(course.updated_at)}</p>
                                            {course.enrollment_count is not None
                                            and <p>
                                                {course.enrollment_count} enrollments
                                            </p>}
                                        </div>
                                        <Link
                                            aria-label={_label(
                                                str(course.next_action)
                                            ) + " for " + course.title}
                                            to={"/lecturer/courses/" + course.track_id}
                                            className="mt-auto inline-flex min-h-10 items-center justify-center rounded-lg bg-brand px-4 font-semibold text-base"
                                        >
                                            {_label(str(course.next_action))}
                                        </Link>
                                    </CardContent>
                                </Card>
                            }}
                        </section>
                    }
                    if dashboard is not None
                    and (dashboard as LecturerDashboardResponse).total_pages > 1 {
                        <nav
                            aria-label="Dashboard pagination"
                            className="flex items-center justify-center gap-3"
                        >
                            <button
                                disabled={page <= 1}
                                onClick={lambda (e: MouseEvent) { load(page - 1); }}
                                className="rounded-lg border border-surface-border px-4 py-2 disabled:opacity-50"
                            >
                                Previous
                            </button>
                            <span>
                                Page {page} of {(
                                    dashboard as LecturerDashboardResponse
                                ).total_pages}
                            </span>
                            <button
                                disabled={page >= (
                                    dashboard as LecturerDashboardResponse
                                ).total_pages}
                                onClick={lambda (e: MouseEvent) { load(page + 1); }}
                                className="rounded-lg border border-surface-border px-4 py-2 disabled:opacity-50"
                            >
                                Next
                            </button>
                        </nav>
                    }
                } }
            </div>
        </main>;
}
