"""Login page."""

import from "lucide-react" { AlertCircle, BookOpen, LogIn }
import from "@jac/runtime" { Link, useNavigate }
import from "....components.ui.button" { Button }
import from "....components.ui.card" {
    Card,
    CardContent,
    CardDescription,
    CardHeader,
    CardTitle
}
import from "....lib.auth.auth_client" { login_user }
import from "....lib.auth.workspace_client" { load_workspace_bootstrap }

def:pub LoginPage() -> JsxElement {
    nav = useNavigate();
    has email: str = "";
    has password: str = "";
    has busy: bool = False;
    has error_message: str = "";

    async def submit_login() {
        busy = True;
        error_message = "";
        try {
            session = await login_user(email, password);
            if session["authenticated"] as bool {
                try {
                    bootstrap = await load_workspace_bootstrap();
                    nav(bootstrap.recommended_route, {"replace": True});
                } except Exception {
                    nav("/identity/recovery", {"replace": True});
                }
            } else {
                error_message = "Authentication failed. Check your credentials and try again.";
            }
        } except Exception {
            error_message = "Authentication failed. Check your credentials and try again.";
        }
        busy = False;
    }

    return
        <AuthShell
            title="Log in to continue"
            description="Access your assessment state and personalized roadmap."
            footerText="Need an account?"
            footerHref="/register"
            footerLabel="Register"
        >
            <label className="grid gap-2 text-sm text-copy-secondary">
                Email
                <input className="rounded-xl border border-surface-border-subtle bg-elevated px-3 py-2 text-copy-primary" value={email} onChange={lambda (e: ChangeEvent) { email = e.target.value; }} />
            </label>
            <label className="grid gap-2 text-sm text-copy-secondary">
                Password
                <input type="password" className="rounded-xl border border-surface-border-subtle bg-elevated px-3 py-2 text-copy-primary" value={password} onChange={lambda (e: ChangeEvent) { password = e.target.value; }} />
            </label>
            {error_message != "" and <AuthError message={error_message} />}
            <Button onClick={lambda (_e: MouseEvent) { submit_login(); }} disabled={busy or email.strip() == "" or password.strip() == ""}>
                <LogIn className="size-4" />
                { "Working..." if busy else "Login" }
            </Button>
        </AuthShell>;
}

def:pub AuthShell(
    title: str,
    description: str,
    footerText: str,
    footerHref: str,
    footerLabel: str,
    children: any = None
) -> JsxElement {
    return
        <main className="min-h-screen bg-base px-6 py-6 text-copy-primary">
            <div className="mx-auto flex min-h-[calc(100vh-3rem)] max-w-md flex-col justify-center gap-6">
                <Link to="/" className="flex w-fit items-center gap-3 text-copy-primary">
                    <div className="flex size-9 items-center justify-center rounded-xl border border-surface-border-subtle bg-elevated">
                        <BookOpen className="size-5 text-brand" />
                    </div>
                    <span className="font-semibold">GraphLearn LMS</span>
                </Link>
                <Card className="border-surface-border bg-surface">
                    <CardHeader>
                        <CardTitle>{title}</CardTitle>
                        <CardDescription>{description}</CardDescription>
                    </CardHeader>
                    <CardContent className="grid gap-3">
                        {children}
                    </CardContent>
                </Card>
                <p className="text-sm text-copy-muted">
                    {footerText}{" "}
                    <Link to={footerHref} className="text-brand">{footerLabel}</Link>
                </p>
            </div>
        </main>;
}

def:pub AuthError(message: str) -> JsxElement {
    return
        <div role="alert" className="flex items-center gap-2 rounded-2xl border border-state-error bg-surface p-3 text-sm text-state-error">
            <AlertCircle className="size-4" />
            {message}
        </div>;
}
