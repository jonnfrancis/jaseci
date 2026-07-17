"""Restricted lecturer state without management actions."""
import from "@jac/runtime" { Link }
import from "....components.ui.card" { Card, CardContent, CardDescription, CardHeader, CardTitle }

def:pub LecturerRestrictedPage() -> JsxElement {
    return <main className="flex min-h-screen items-center justify-center bg-base p-6 text-copy-primary"><Card className="w-full max-w-xl border-surface-border bg-surface"><CardHeader><CardTitle>Teaching tools are unavailable</CardTitle><CardDescription>Your lecturer profile is suspended or archived. Course-management actions are disabled.</CardDescription></CardHeader><CardContent role="alert"><Link to="/dashboard" className="text-brand">Continue in learner workspace</Link></CardContent></Card></main>;
}
