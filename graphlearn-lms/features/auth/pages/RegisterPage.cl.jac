"""Register page."""

import from "lucide-react" { BookOpen, GraduationCap, UserPlus }
import from "@jac/runtime" { useNavigate }
import from "....components.ui.button" { Button }
import from .LoginPage { AuthError, AuthShell }
import from "....lib.auth.auth_client" { register_user }
import from "....lib.auth.workspace_client" { load_workspace_bootstrap }
sv import from ....services.identity { request_lecturer_role }

def:pub RegisterPage() -> JsxElement {
    nav = useNavigate();
    has username: str = "";
    has email: str = "";
    has password: str = "";
    has busy: bool = False;
    has error_message: str = "";
    has intent: str = "";

    async def submit_register() {
        busy = True;
        error_message = "";
        session: dict[str, any] = {};
        try {
            session = (await register_user(username, email, password)) as dict[str, any];

            if session["authenticated"] as bool {
                if intent == "LECTURER" {
                    onboarding = await request_lecturer_role(username);
                    if not onboarding.ok {
                        nav("/lecturer/onboarding", {"replace": True});
                        return;
                    }
                }
                bootstrap = await load_workspace_bootstrap();
                nav(bootstrap.recommended_route, {"replace": True});
            } else {
                error_message = "Registration failed. Check your details and try again.";
            }
        } except Exception {
            error_message = "Your account was created, but workspace setup could not finish. Log in to resume safely.";
        }
        busy = False;
    }

    return
        <AuthShell
            title="Create your account"
            description="Start with an assessment so GraphLearn can build your roadmap."
            footerText="Already have an account?"
            footerHref="/login"
            footerLabel="Login"
        >
            <fieldset className="grid gap-3">
                <legend className="text-sm font-medium text-copy-secondary">Choose your starting workspace</legend>
                <div className="grid gap-3 sm:grid-cols-2">
                    <button type="button" aria-pressed={intent == "STUDENT"} onClick={lambda (_e: MouseEvent) { intent = "STUDENT"; }} className={"rounded-2xl border p-4 text-left focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand " + ("border-brand bg-accent-dim" if intent == "STUDENT" else "border-surface-border bg-elevated")}>
                        <BookOpen className="mb-3 size-5 text-brand" /><span className="block font-semibold">Student</span><span className="mt-1 block text-sm text-copy-muted">Learn through an adaptive roadmap.</span>
                    </button>
                    <button type="button" aria-pressed={intent == "LECTURER"} onClick={lambda (_e: MouseEvent) { intent = "LECTURER"; }} className={"rounded-2xl border p-4 text-left focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand " + ("border-brand bg-accent-dim" if intent == "LECTURER" else "border-surface-border bg-elevated")}>
                        <GraduationCap className="mb-3 size-5 text-brand" /><span className="block font-semibold">Lecturer</span><span className="mt-1 block text-sm text-copy-muted">Create courses after profile review.</span>
                    </button>
                </div>
            </fieldset>
            <label className="grid gap-2 text-sm text-copy-secondary">
                Name
                <input className="rounded-xl border border-surface-border-subtle bg-elevated px-3 py-2 text-copy-primary" value={username} onChange={lambda (e: ChangeEvent) { username = e.target.value; }} />
            </label>
            <label className="grid gap-2 text-sm text-copy-secondary">
                Email
                <input className="rounded-xl border border-surface-border-subtle bg-elevated px-3 py-2 text-copy-primary" value={email} onChange={lambda (e: ChangeEvent) { email = e.target.value; }} />
            </label>
            <label className="grid gap-2 text-sm text-copy-secondary">
                Password
                <input type="password" className="rounded-xl border border-surface-border-subtle bg-elevated px-3 py-2 text-copy-primary" value={password} onChange={lambda (e: ChangeEvent) { password = e.target.value; }} />
            </label>
            {error_message != "" and <AuthError message={error_message} />}
            <Button onClick={lambda (_e: MouseEvent) { submit_register(); }} disabled={busy or intent == "" or email.strip() == "" or password.strip() == ""}>
                <UserPlus className="size-4" />
                { "Working..." if busy else "Register" }
            </Button>
        </AuthShell>;
}
