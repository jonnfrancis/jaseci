"""Publication readiness, immutable sealing, history, and successor drafts."""
import from "@jac/runtime" { Link, useNavigate, useParams }
import from "....components.ui.button" { Button }
import from "....components.ui.card" { Card, CardContent, CardDescription, CardHeader, CardTitle }
import from "....components.ui.dialog" { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle }
import from "....components.ui.textarea" { Textarea }
import from "..components.CourseBuildLifecycle" { CourseBuildLifecycle }
import from "..components.LecturerLoadingSkeleton" { LecturerLoadingSkeleton }
sv import from ....services.course_management { CourseBuildWorkflowView, CreateDraftVersionRequest, LearnerIntegrationHandoffView, PublicationHistoryItem, PublicationReadinessResult, PublishCourseVersionRequest, create_course_draft_version, get_course_build_workflow, get_course_publication_readiness, get_learner_integration_handoff, list_course_publication_history, load_lecturer_course, publish_approved_course_version }

def _safe_error(code: str | None) -> str { if code == "COURSE_PUBLICATION_APPROVAL_STALE" { return "The course changed after approval. Approve the latest revision again."; } if code == "COURSE_PUBLICATION_SOURCE_STALE" { return "The approved source no longer matches this version."; } if code == "COURSE_PUBLICATION_VERSION_CONFLICT" { return "Publication readiness changed. Refresh before publishing."; } if code == "COURSE_VERSION_IMMUTABLE" { return "Published curriculum cannot be edited. Create a new version."; } return "This operation could not be completed safely. Refresh and try again."; }

def:pub CoursePublicationPage() -> JsxElement {
    has loading: bool = True, publishing: bool = False, publish_open: bool = False, draft_open: bool = False, creating: bool = False;
    has track_version_id: str = "", release_note: str = "", message: str = "", idempotency_key: str = "";
    has readiness: PublicationReadinessResult | None = None, workflow: CourseBuildWorkflowView | None = None, handoff: LearnerIntegrationHandoffView | None = None;
    has history: list[PublicationHistoryItem] = [];
    params = useParams(); raw_track_id = params["trackId"]; track_id = str(raw_track_id) if raw_track_id else ""; navigate = useNavigate();
    async def load() {
        try {
            course = await load_lecturer_course(track_id); version = course.draft_version if course.draft_version is not None else course.active_version;
            if version is not None { track_version_id = version.track_version_id; workflow = await get_course_build_workflow(track_id, track_version_id); try { readiness = await get_course_publication_readiness(track_id, track_version_id); } except Exception {} }
            history = await list_course_publication_history(track_id); handoff = await get_learner_integration_handoff(track_id);
        } except Exception { message = "Publication state could not be loaded."; }
        loading = False;
    }
    async can with entry { await load(); }
    def handle_note(e: ChangeEvent) { release_note = e.target.value; }
    async def publish() {
        if publishing or readiness is None or not (readiness as PublicationReadinessResult).ready { return; }
        publishing = True; publish_open = False; current = readiness as PublicationReadinessResult;
        if idempotency_key == "" { idempotency_key = "publish-" + track_version_id + "-" + str(current.blueprint_revision or 0); }
        try { result = await publish_approved_course_version(PublishCourseVersionRequest(track_id=track_id, track_version_id=track_version_id, expected_revision=current.blueprint_revision or 0, idempotency_key=idempotency_key, publish_note=release_note if release_note.strip() != "" else None)); if result.error_code is not None { message = _safe_error(result.error_code); } await load(); }
        except Exception { message = "Publication outcome is unknown. Readiness and history were reloaded before another attempt."; await load(); }
        publishing = False;
    }
    async def create_draft() {
        if creating { return; } creating = True; draft_open = False;
        try { result = await create_course_draft_version(CreateDraftVersionRequest(track_id=track_id, idempotency_key="new-version-" + track_id + "-" + track_version_id, base_version_id=track_version_id, clone_curriculum=True)); if result.error_code is not None { message = _safe_error(result.error_code); } else { navigate("/lecturer/courses/" + track_id); } }
        except Exception { message = "A new draft version could not be created."; }
        creating = False;
    }
    if loading { return <LecturerLoadingSkeleton/>; }
    return <main className="min-h-screen bg-base px-5 py-8 text-copy-primary"><div className="mx-auto max-w-5xl space-y-5">
        <Link to={"/lecturer/courses/" + track_id} className="text-sm text-brand">Back to course workspace</Link>
        {if workflow is not None { <CourseBuildLifecycle workflow={workflow as CourseBuildWorkflowView}/> }}
        <header><p className="text-xs font-semibold uppercase tracking-wider text-copy-muted">Publication readiness</p><h1 className="text-3xl font-semibold" tabIndex={-1}>Publish course version</h1><p className="text-copy-secondary">Publishing seals this curriculum. Enrollment remains separate.</p></header>
        {if handoff is not None and (handoff as LearnerIntegrationHandoffView).ready { current_handoff = handoff as LearnerIntegrationHandoffView; <Card className="border-success/40"><CardHeader><CardTitle>Published version {str(current_handoff.version_number or 0)}</CardTitle><CardDescription>{"Publication " + (current_handoff.publication_id or "Unavailable") + " / " + current_handoff.visibility}</CardDescription></CardHeader><CardContent className="space-y-4"><p className="rounded-md bg-success/10 p-3 text-success">{"Learner integration ready" if current_handoff.enrollment_open else "Published, learner access closed"}</p><p>This active version is immutable. Existing learners remain pinned.</p><Button onClick={lambda (_e: MouseEvent) { draft_open = True; }}>Create new version</Button></CardContent></Card> }
        elif readiness is not None { current = readiness as PublicationReadinessResult; <><div className="grid gap-4 sm:grid-cols-4"><Card><CardHeader><CardDescription>Version</CardDescription><CardTitle>{str(current.version_number or current.expected_version_number or 0)}</CardTitle></CardHeader></Card><Card><CardHeader><CardDescription>Modules</CardDescription><CardTitle>{str(current.module_count)}</CardTitle></CardHeader></Card><Card><CardHeader><CardDescription>Skills</CardDescription><CardTitle>{str(current.skill_count)}</CardTitle></CardHeader></Card><Card><CardHeader><CardDescription>Outcomes</CardDescription><CardTitle>{str(current.outcome_count)}</CardTitle></CardHeader></Card></div><Card><CardHeader><CardTitle>{"Ready to publish" if current.ready else "Publication blocked"}</CardTitle><CardDescription>{current.validation_status + " / " + current.approval_status}</CardDescription></CardHeader><CardContent className="space-y-3">{for code in current.blocking_codes { <p key={code} role="alert" className="rounded-md border border-danger/40 bg-danger/10 p-3 text-danger">{_safe_error(code)}</p> }}<label htmlFor="release-note">Release note</label><Textarea id="release-note" value={release_note} onChange={handle_note}/><Button onClick={lambda (_e: MouseEvent) { publish_open = True; }} disabled={not current.ready or publishing}>Review publication confirmation</Button></CardContent></Card></> }}
        <Card><CardHeader><CardTitle>Publication history</CardTitle><CardDescription>Immutable releases and activation events.</CardDescription></CardHeader><CardContent className="space-y-3">{for item in history { <div key={item.publication_id} className="rounded-lg border border-border p-3"><p className="font-medium">{"Version " + str(item.version_number) + " / " + item.status}</p><p className="text-sm text-copy-muted">{item.published_at + " / " + (item.release_notes or "No release note")}</p></div> }}{if len(history) == 0 { <p className="text-copy-muted">No published versions yet.</p> }}</CardContent></Card>
        {if message != "" { <p role="alert" className="rounded-lg border border-danger/40 bg-danger/10 p-4 text-danger">{message}</p> }}
        <Dialog open={publish_open} onOpenChange={lambda (open: bool) { publish_open = open; }}><DialogContent><DialogHeader><DialogTitle>Publish and seal this version?</DialogTitle><DialogDescription>Publishing seals this version. Future curriculum changes require a new draft. Existing learners remain pinned. Publishing does not automatically open enrollment.</DialogDescription></DialogHeader><DialogFooter><Button variant="outline" onClick={lambda (_e: MouseEvent) { publish_open = False; }}>Cancel</Button><Button onClick={lambda (_e: MouseEvent) { publish(); }} disabled={publishing}>Publish version</Button></DialogFooter></DialogContent></Dialog>
        <Dialog open={draft_open} onOpenChange={lambda (open: bool) { draft_open = open; }}><DialogContent><DialogHeader><DialogTitle>Create a new draft version?</DialogTitle><DialogDescription>The published version remains immutable and existing learners stay on their version. The new version must be validated, reviewed, approved, and published.</DialogDescription></DialogHeader><DialogFooter><Button variant="outline" onClick={lambda (_e: MouseEvent) { draft_open = False; }}>Cancel</Button><Button onClick={lambda (_e: MouseEvent) { create_draft(); }} disabled={creating}>Create new version</Button></DialogFooter></DialogContent></Dialog>
    </div></main>;
}
