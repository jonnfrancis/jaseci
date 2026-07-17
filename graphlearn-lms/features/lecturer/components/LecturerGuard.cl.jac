"""Role-aware lecturer route guard; server authorization remains authoritative."""
import from "@jac/runtime" { Navigate }
import from "....lib.auth.workspace_client" { load_workspace_bootstrap }
import from .LecturerLoadingSkeleton { LecturerLoadingSkeleton }

def:pub LecturerGuard(children: any = None) -> JsxElement {
    has loading: bool = True; has route: str = ""; has allowed: bool = False;
    async can with entry {
        try {
            bootstrap = await load_workspace_bootstrap();
            if str(bootstrap.lecturer_onboarding_step) == "ACTIVE" { allowed = True; }
            else { route = bootstrap.available_workspaces[1].recommended_route or "/lecturer/onboarding"; }
        } except Exception { route = "/identity/recovery"; }
        loading = False;
    }
    if loading { return <LecturerLoadingSkeleton compact={True} />; }
    if not allowed { return <Navigate to={route} replace={True} />; }
    return <>{children}</>;
}
