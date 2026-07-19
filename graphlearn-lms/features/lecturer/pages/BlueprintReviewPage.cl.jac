"""Lecturer workspace for inspecting and approving a validated blueprint."""
import from "@jac/runtime" { Link, Navigate, useParams }
import from "....components.ui.button" { Button }
import from "....components.ui.card" { Card, CardContent, CardDescription, CardHeader, CardTitle }
import from "..components.LecturerLoadingSkeleton" { LecturerLoadingSkeleton }
sv import from ....services.course_management { BlueprintApprovalRequest, LecturerBlueprintReviewView, LecturerCourseDetail, approve_course_blueprint, get_lecturer_blueprint_review, load_lecturer_course }

def:pub BlueprintReviewPage() -> JsxElement {
    has loading: bool = True, approving: bool = False;
    has error_message: str = "";
    has track_version_id: str = "";
    has review: LecturerBlueprintReviewView | None = None;
    params = useParams(); raw_track_id = params["trackId"];
    track_id = str(raw_track_id) if raw_track_id else "";

    async can with entry {
        if track_id != "" {
            try {
                course = await load_lecturer_course(track_id);
                if course.draft_version is not None {
                    track_version_id = course.draft_version.track_version_id;
                    review = await get_lecturer_blueprint_review(track_id, course.draft_version.track_version_id);
                } else { error_message = "This course has no editable draft version."; }
            } except Exception { error_message = "The blueprint is not ready for lecturer review."; }
        }
        loading = False;
    }

    async def handle_approve {
        if review is None or track_version_id == "" { return; }
        approving = True; error_message = "";
        try {
            _ = await approve_course_blueprint(track_id, track_version_id, BlueprintApprovalRequest(blueprint_id=review.blueprint_id, expected_revision=review.blueprint_revision));
            review = await get_lecturer_blueprint_review(track_id, track_version_id);
        } except Exception { error_message = "Approval was blocked. Refresh the review and resolve validation issues."; }
        approving = False;
    }

    if loading { return <LecturerLoadingSkeleton/>; }
    if review is None and error_message == "" { return <Navigate to={"/lecturer/courses/" + track_id} replace={True}/>; }
    return <main className="min-h-screen bg-base px-5 py-8 text-copy-primary">
        <div className="mx-auto max-w-7xl space-y-5">
            <Link to={"/lecturer/courses/" + track_id} className="text-sm text-brand hover:underline">Back to course</Link>
            {if review is not None {
                <header className="flex flex-col gap-4 rounded-xl border border-border bg-surface p-6 md:flex-row md:items-center md:justify-between">
                    <div><p className="text-xs font-semibold uppercase tracking-wider text-copy-muted">Blueprint review · Revision {str(review.blueprint_revision)}</p><h1 className="mt-1 text-3xl font-semibold">{review.course_title}</h1><p className="mt-2 max-w-3xl text-copy-secondary">{review.course_summary}</p></div>
                    <Button onClick={handle_approve} disabled={not review.approval_available or approving}>{"Approving..." if approving else "Approve blueprint"}</Button>
                </header>
                <Card><CardHeader><CardTitle>Validation summary</CardTitle><CardDescription>{review.validation_summary.status + " · " + str(review.validation_summary.warning_count) + " warnings · " + str(review.validation_summary.blocking_issue_count) + " blocking"}</CardDescription></CardHeader><CardContent><div className="grid gap-3 sm:grid-cols-4"><p>Source {str(round(review.validation_summary.source_coverage_ratio * 100.0))}%</p><p>Concepts {str(round(review.validation_summary.concept_coverage_ratio * 100.0))}%</p><p>Modules {str(round(review.validation_summary.module_coverage_ratio * 100.0))}%</p><p>Grounding {str(round(review.validation_summary.grounding_ratio * 100.0))}%</p></div></CardContent></Card>
                <div className="grid gap-5 lg:grid-cols-[18rem_1fr]">
                    <aside className="space-y-3"><h2 className="text-lg font-semibold">Modules</h2>{for module in review.modules { <Card key={module.module_id}><CardHeader><CardTitle className="text-base">{str(module.order_index + 1) + ". " + module.title}</CardTitle><CardDescription>{str(len(module.concept_keys)) + " concepts · " + str(len(module.outcome_keys)) + " outcomes · " + module.confidence}</CardDescription></CardHeader></Card> }}</aside>
                    <section className="space-y-5">
                        {for module in review.modules { <Card key={module.module_id}><CardHeader><CardTitle>{module.title}</CardTitle><CardDescription>{module.description}</CardDescription></CardHeader><CardContent className="space-y-4"><div><h3 className="font-medium">Concepts</h3>{for concept in review.concepts { if concept.local_concept_key in module.concept_keys { <div key={concept.concept_id} className="mt-2 rounded-lg border border-border p-3"><p className="font-medium">{concept.canonical_name}</p><p className="text-sm text-copy-secondary">{concept.description}</p></div> } }}</div><div><h3 className="font-medium">Learning outcomes</h3>{for outcome in review.outcomes { if outcome.local_outcome_key in module.outcome_keys { <p key={outcome.outcome_id} className="mt-2 text-sm">{outcome.statement}</p> } }}</div></CardContent></Card> }}
                        <Card><CardHeader><CardTitle>Prerequisites</CardTitle></CardHeader><CardContent>{for item in review.prerequisites { <div key={item.prerequisite_id} className="mb-2 rounded-lg border border-border p-3"><p className="font-medium">{item.prerequisite_concept_key + " → " + item.dependent_concept_key}</p><p className="text-sm text-copy-secondary">{item.strength + " · " + item.rationale}</p></div> }}</CardContent></Card>
                    </section>
                </div>
            }}
            {if error_message != "" { <p className="rounded-lg border border-danger/40 bg-danger/10 p-4 text-sm text-danger">{error_message}</p> }}
        </div>
    </main>;
}
