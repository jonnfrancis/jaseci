"""Register page."""

import from "lucide-react" { UserPlus }
import from "@jac/runtime" { useNavigate }
import from "....components.ui.button" { Button }
import from .LoginPage { AuthError, AuthShell }
import from "....lib.auth.auth_client" { register_user }

def:pub RegisterPage() -> JsxElement {
    nav = useNavigate();
    has username: str = "";
    has email: str = "";
    has password: str = "";
    has busy: bool = False;
    has error_message: str = "";

    async def submit_register() {
        busy = True;
        error_message = "";
        session: dict = {};
        try {
            session = await register_user(username, email, password);

            if session["authenticated"] as bool {
                nav("/assessment", {"replace": True});
            } else {
                error_message = "Registration failed. Check your details and try again.";
            }
        } except Exception as e {
            error_message = "Registration failed: " + str(e);
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
            <Button onClick={lambda (_e: MouseEvent) { submit_register(); }} disabled={busy or email.strip() == "" or password.strip() == ""}>
                <UserPlus className="size-4" />
                { "Working..." if busy else "Register and continue" }
            </Button>
        </AuthShell>;
}
