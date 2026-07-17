"""Lecturer onboarding status and recovery states."""
import from "@jac/runtime" { Link, Navigate }
import from "....components.ui.card" { Card, CardContent, CardDescription, CardHeader, CardTitle }
import from "....lib.auth.workspace_client" { load_workspace_bootstrap }
import from "..components.LecturerLoadingSkeleton" { LecturerLoadingSkeleton }

def:pub LecturerStatusPage() -> JsxElement {
    has loading: bool = True; has step: str = ""; has failed: bool = False;
    async can with entry { try { bootstrap = await load_workspace_bootstrap(); step = str(bootstrap.lecturer_onboarding_step); } except Exception { failed = True; } loading = False; }
    if loading { return <LecturerLoadingSkeleton compact={True} />; }
    if step == "ACTIVE" { return <Navigate to="/lecturer/courses" replace={True} />; }
    if step == "PROFILE_REQUIRED" or step == "READY_TO_SUBMIT" { return <Navigate to="/lecturer/onboarding" replace={True} />; }
    if step == "SUSPENDED" or step == "ARCHIVED" { return <Navigate to="/lecturer/restricted" replace={True} />; }
    title = "Your lecturer profile is awaiting approval." if step == "PENDING_APPROVAL" else ("Your lecturer request needs attention." if step == "REJECTED" else "Lecturer status is unavailable.");
    description = "You can continue using the learner workspace while you wait." if step == "PENDING_APPROVAL" else ("Review your profile and submit an allowed correction." if step == "REJECTED" else "Retry after checking your connection. Your session has been preserved.");
    return <main className="flex min-h-screen items-center justify-center bg-base p-6 text-copy-primary"><Card className="w-full max-w-xl border-surface-border bg-surface"><CardHeader><CardTitle>{title}</CardTitle><CardDescription>{description}</CardDescription></CardHeader><CardContent role={"alert" if failed else "status"} className="flex flex-col gap-4"><Link to="/dashboard" className="text-brand">Open learner workspace</Link>{step == "REJECTED" and <Link to="/lecturer/onboarding" className="text-brand">Edit lecturer profile</Link>}</CardContent></Card></main>;
}
