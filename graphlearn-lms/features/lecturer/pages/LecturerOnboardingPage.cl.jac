"""Resumable lecturer profile onboarding."""

import from "@jac/runtime" { Link, useNavigate }
import from "lucide-react" { GraduationCap, Save }
import from "....components.ui.button" { Button }
import from "....components.ui.card" { Card, CardContent, CardDescription, CardHeader, CardTitle }
import from "..components.LecturerLoadingSkeleton" { LecturerLoadingSkeleton }
sv import from ....services.identity {
    IdentityResult, LecturerProfileInput, get_my_lecturer_profile,
    request_lecturer_role, submit_my_lecturer_onboarding, update_my_lecturer_profile
}

def:pub LecturerOnboardingPage() -> JsxElement {
    nav = useNavigate();
    has display_name: str = ""; has professional_title: str = "";
    has institution_name: str = ""; has department: str = "";
    has expertise: str = ""; has biography: str = ""; has staff_number: str = "";
    has status: str = "DRAFT"; has loading: bool = True; has busy: bool = False;
    has message: str = ""; has error_message: str = "";

    async def load_profile() {
        loading = True; error_message = "";
        try {
            result: IdentityResult = await get_my_lecturer_profile();
            if not result.ok {
                result = await request_lecturer_role();
            }
            if result.ok and result.profile {
                profile = result.profile;
                display_name = profile.display_name; professional_title = profile.professional_title or "";
                institution_name = profile.institution_name or ""; department = profile.department or "";
                expertise = ", ".join(profile.areas_of_expertise or []); biography = profile.biography or "";
                staff_number = profile.staff_number or ""; current_status = str(profile.status or "DRAFT"); status = current_status;
                if current_status == "PENDING_REVIEW" or current_status == "REJECTED" { nav("/lecturer/onboarding/status", {"replace": True}); }
                elif current_status == "ACTIVE" { nav("/lecturer/courses", {"replace": True}); }
                elif current_status == "SUSPENDED" or current_status == "ARCHIVED" { nav("/lecturer/restricted", {"replace": True}); }
            } else { error_message = "Lecturer onboarding could not be started. Try again."; }
        } except Exception { error_message = "Lecturer onboarding could not be loaded. Your account remains signed in."; }
        loading = False;
    }

    async can with entry { await load_profile(); }

    async def save_profile(submit: bool) {
        error_message = ""; message = "";
        expertise_values = [value.strip() for value in expertise.split(",") if value.strip() != ""];
        if display_name.strip() == "" { error_message = "Display name is required."; return; }
        if submit and institution_name.strip() == "" { error_message = "Institution name is required before submission."; return; }
        if submit and len(expertise_values) == 0 { error_message = "Add at least one area of expertise before submission."; return; }
        busy = True;
        try {
            input = {
                "display_name": display_name, "professional_title": professional_title,
                "institution_name": institution_name, "department": department, "biography": biography,
                "areas_of_expertise": expertise_values, "staff_number": staff_number
            } as LecturerProfileInput;
            result = await update_my_lecturer_profile(input);
            if not result.ok { error_message = result.error.message if result.error is not None else "Profile could not be saved."; }
            elif submit {
                submitted = await submit_my_lecturer_onboarding();
                if not submitted.ok { error_message = submitted.error.message if submitted.error else "Profile could not be submitted."; }
                elif submitted.profile and str(submitted.profile.status) == "ACTIVE" { nav("/lecturer/courses", {"replace": True}); }
                else { nav("/lecturer/onboarding/status", {"replace": True}); }
            } else { message = "Draft saved. You can safely return later."; }
        } except Exception { error_message = "Profile changes could not be saved. Try again without creating another account."; }
        busy = False;
    }

    if loading { return <LecturerLoadingSkeleton />; }
    return <main className="min-h-screen bg-base p-6 text-copy-primary">
        <div className="mx-auto grid max-w-5xl gap-6 lg:grid-cols-[minmax(0,2fr)_minmax(16rem,1fr)]">
            <Card className="border-surface-border bg-surface">
                <CardHeader><div className="flex items-center gap-3"><GraduationCap className="size-6 text-brand" /><div><CardTitle>Lecturer profile</CardTitle><CardDescription>Save a draft or submit a complete profile for access review.</CardDescription></div></div></CardHeader>
                <CardContent><form className="grid gap-4" onSubmit={lambda (e: FormEvent) { e.preventDefault(); save_profile(True); }}>
                    <label className="grid gap-2 text-sm">Display name <input aria-required="true" maxLength={120} value={display_name} onChange={lambda (e: ChangeEvent) { display_name = e.target.value; }} className="rounded-xl border border-surface-border-subtle bg-elevated p-3" /></label>
                    <label className="grid gap-2 text-sm">Professional title <input maxLength={120} value={professional_title} onChange={lambda (e: ChangeEvent) { professional_title = e.target.value; }} className="rounded-xl border border-surface-border-subtle bg-elevated p-3" /></label>
                    <label className="grid gap-2 text-sm">Institution name <input aria-required="true" maxLength={160} value={institution_name} onChange={lambda (e: ChangeEvent) { institution_name = e.target.value; }} className="rounded-xl border border-surface-border-subtle bg-elevated p-3" /></label>
                    <label className="grid gap-2 text-sm">Department <input maxLength={160} value={department} onChange={lambda (e: ChangeEvent) { department = e.target.value; }} className="rounded-xl border border-surface-border-subtle bg-elevated p-3" /></label>
                    <label className="grid gap-2 text-sm">Areas of expertise <span className="text-copy-muted">Comma-separated; at least one is required.</span><input aria-required="true" value={expertise} onChange={lambda (e: ChangeEvent) { expertise = e.target.value; }} className="rounded-xl border border-surface-border-subtle bg-elevated p-3" /></label>
                    <label className="grid gap-2 text-sm">Biography <textarea maxLength={4000} value={biography} onChange={lambda (e: ChangeEvent) { biography = e.target.value; }} className="min-h-32 rounded-xl border border-surface-border-subtle bg-elevated p-3" /></label>
                    <label className="grid gap-2 text-sm">Staff number <input maxLength={120} value={staff_number} onChange={lambda (e: ChangeEvent) { staff_number = e.target.value; }} className="rounded-xl border border-surface-border-subtle bg-elevated p-3" /></label>
                    {error_message != "" and <div role="alert" className="rounded-xl border border-state-error p-3 text-state-error">{error_message}</div>}
                    {message != "" and <div role="status" className="rounded-xl border border-state-success p-3 text-state-success">{message}</div>}
                    <div className="flex flex-col gap-3 sm:flex-row"><Button type="button" variant="outline" disabled={busy} onClick={lambda (_e: MouseEvent) { save_profile(False); }}><Save className="size-4" />Save draft</Button><Button type="submit" disabled={busy}>Submit profile</Button></div>
                </form></CardContent>
            </Card>
            <Card className="h-fit border-surface-border bg-surface"><CardHeader><CardTitle>What happens next</CardTitle><CardDescription>Current status: {status}</CardDescription></CardHeader><CardContent className="grid gap-3 text-sm text-copy-muted"><p>Production access requires administrator approval. Development auto-activation is controlled only by the server.</p><Link to="/dashboard" className="text-brand">Continue in learner workspace</Link></CardContent></Card>
        </div>
    </main>;
}
