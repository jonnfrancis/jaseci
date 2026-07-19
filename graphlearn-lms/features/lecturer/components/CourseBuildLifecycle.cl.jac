"""Shared accessible lifecycle summary driven only by CourseBuildWorkflowView."""
sv import from ....services.course_management { CourseBuildWorkflowView }

def:pub CourseBuildLifecycle(workflow: CourseBuildWorkflowView, compact: bool = False) -> JsxElement {
    stage = str(workflow.current_stage);
    steps: list[dict[str, object]] = [
        {"label": "Source", "stages": ["SOURCE_REQUIRED", "SOURCE_PROCESSING", "SOURCE_FAILED"]},
        {"label": "Generate", "stages": ["READY_FOR_GENERATION", "GENERATING_BLUEPRINT", "GENERATION_FAILED", "VALIDATING_BLUEPRINT"]},
        {"label": "Review", "stages": ["READY_FOR_REVIEW", "REVIEW_IN_PROGRESS", "CHANGES_REQUIRED", "APPROVED"]},
        {"label": "Publish", "stages": ["PUBLICATION_BLOCKED", "READY_TO_PUBLISH", "PUBLISHING"]},
        {"label": "Learner ready", "stages": ["PUBLISHED"]},
    ];
    return <section aria-label="Course build lifecycle" className="rounded-xl border border-border bg-surface p-4">
        <div className="flex items-center justify-between gap-4"><div><p className="text-xs font-semibold uppercase tracking-wider text-copy-muted">Current stage</p><h2 className="text-lg font-semibold">{workflow.stage_label}</h2></div><span className="rounded-full bg-accent-dim px-3 py-1 text-sm text-brand">{str(workflow.progress_percent) + "%"}</span></div>
        <ol className={"mt-4 grid gap-2 " + ("grid-cols-1" if compact else "grid-cols-2 md:grid-cols-5")}>
            {for idx in range(len(steps)) { <li key={str(steps[idx]["label"])} className={"rounded-lg border p-3 text-sm " + ("border-brand bg-accent-dim text-brand" if stage in (steps[idx]["stages"] as list[str]) else "border-border text-copy-muted")}><span className="mr-2 font-mono">{str(idx + 1)}</span>{str(steps[idx]["label"])}</li> }}
        </ol>
    </section>;
}

def:pub WorkflowBlockers(workflow: CourseBuildWorkflowView) -> JsxElement {
    return <div className="space-y-2" role="alert">{for blocker in workflow.blockers { <p key={blocker.code} className="rounded-lg border border-danger/40 bg-danger/10 p-3 text-sm text-danger"><span className="font-semibold">Blocked: </span>{blocker.message}</p> }}{for warning in workflow.warnings { <p key={warning} className="rounded-lg border border-warning/40 bg-warning/10 p-3 text-sm text-warning"><span className="font-semibold">Warning: </span>{warning}</p> }}</div>;
}
