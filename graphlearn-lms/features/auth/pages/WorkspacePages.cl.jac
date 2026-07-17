"""Workspace selection and post-login bootstrap recovery."""
import from "@jac/runtime" { useNavigate }
import from "lucide-react" { BookOpen, GraduationCap, LogOut, RefreshCw }
import from "....components.ui.button" { Button }
import from "....components.ui.card" { Card, CardContent, CardDescription, CardHeader, CardTitle }
import from "....lib.auth.auth_client" { logout_user }
import from "....lib.auth.workspace_client" { load_workspace_bootstrap, select_workspace }
sv import from ....services.identity { WorkspaceKind }

def:pub WorkspaceChooserPage() -> JsxElement {
    nav = useNavigate(); has busy: bool = False; has error_message: str = "";
    async def choose(workspace: WorkspaceKind) { busy = True; error_message = ""; try { bootstrap = await select_workspace(workspace); nav(bootstrap.recommended_route, {"replace": True}); } except Exception { error_message = "That workspace is not currently available."; } busy = False; }
    return <main className="flex min-h-screen items-center justify-center bg-base p-6 text-copy-primary"><Card className="w-full max-w-2xl border-surface-border bg-surface text-copy-primary"><CardHeader><CardTitle className="text-2xl text-copy-primary">Choose a workspace</CardTitle><CardDescription>Your selection is a preference and is rechecked against your current roles.</CardDescription></CardHeader><CardContent className="grid gap-4 sm:grid-cols-2"><Button variant="outline" className="h-auto justify-start p-6 text-copy-primary" disabled={busy} onClick={lambda (_e: MouseEvent) { choose("LEARNER" as WorkspaceKind); }}><BookOpen className="size-5" /><span>Learning workspace</span></Button><Button variant="outline" className="h-auto justify-start p-6 text-copy-primary" disabled={busy} onClick={lambda (_e: MouseEvent) { choose("LECTURER" as WorkspaceKind); }}><GraduationCap className="size-5" /><span>Teaching workspace</span></Button>{error_message != "" and <div role="alert" className="sm:col-span-2 rounded-xl border border-state-error p-3 text-state-error">{error_message}</div>}</CardContent></Card></main>;
}

def:pub IdentityRecoveryPage() -> JsxElement {
    nav = useNavigate(); has busy: bool = False; has error_message: str = "Workspace setup could not be loaded. Your authenticated session is still available.";
    async def retry() { busy = True; try { bootstrap = await load_workspace_bootstrap(); nav(bootstrap.recommended_route, {"replace": True}); } except Exception { error_message = "Workspace setup is still unavailable. Try again or log out."; } busy = False; }
    def logout() { logout_user(); nav("/login", {"replace": True}); }
    return <main className="flex min-h-screen items-center justify-center bg-base p-6 text-copy-primary"><Card className="w-full max-w-xl border-surface-border bg-surface"><CardHeader><CardTitle>Workspace recovery</CardTitle><CardDescription>{error_message}</CardDescription></CardHeader><CardContent role="alert" className="flex gap-3"><Button disabled={busy} onClick={lambda (_e: MouseEvent) { retry(); }}><RefreshCw className="size-4" />Retry</Button><Button variant="outline" onClick={lambda (_e: MouseEvent) { logout(); }}><LogOut className="size-4" />Log out</Button></CardContent></Card></main>;
}
