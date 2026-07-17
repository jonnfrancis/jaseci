"""Role-aware workspace bootstrap and non-authoritative preference helpers."""

sv import from ...services.identity {
    AuthenticatedWorkspaceBootstrap, WorkspaceKind,
    load_authenticated_workspace_bootstrap
}

glob WORKSPACE_PREFERENCE_KEY: str = "graphlearn.workspace.preference";

def:pub read_workspace_preference() -> WorkspaceKind | None {
    value = localStorage.getItem(WORKSPACE_PREFERENCE_KEY); # jac:ignore[W2001,E1030,W6002]
    if value == "LEARNER" { return "LEARNER" as WorkspaceKind; }
    if value == "LECTURER" { return "LECTURER" as WorkspaceKind; }
    return None;
}

def:pub save_workspace_preference(workspace: WorkspaceKind) {
    localStorage.setItem(WORKSPACE_PREFERENCE_KEY, str(workspace)); # jac:ignore[W2001,E1030,W6002]
}

def:pub clear_workspace_preference() {
    localStorage.removeItem(WORKSPACE_PREFERENCE_KEY); # jac:ignore[W2001,E1030,W6002]
}

async def:pub load_workspace_bootstrap() -> AuthenticatedWorkspaceBootstrap {
    return await load_authenticated_workspace_bootstrap(read_workspace_preference());
}

async def:pub select_workspace(workspace: WorkspaceKind) -> AuthenticatedWorkspaceBootstrap {
    bootstrap = await load_authenticated_workspace_bootstrap(workspace);
    if bootstrap.recommended_workspace == workspace { save_workspace_preference(workspace); }
    return bootstrap;
}
