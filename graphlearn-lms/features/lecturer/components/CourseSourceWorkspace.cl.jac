"""Lecturer source upload, durable processing, recovery, and interpretation handoff."""

import from react { useEffect }
import from "@jac/runtime" { Link }
import from "lucide-react" {
    AlertTriangle,
    Check,
    FileText,
    RefreshCw,
    RotateCcw,
    Upload,
    X
}
import from "....components.ui.button" { Button }
import from "....components.ui.card" {
    Card,
    CardContent,
    CardDescription,
    CardHeader,
    CardTitle
}
import from "....components.ui.dialog" {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle
}
import from "....lib.utils" { format_datetime }
sv import from ....services.course_management {
    CourseSourceWorkspaceView,
    LecturerCourseDetail,
    UploadCourseDocumentInput,
    cancel_lecturer_course_document,
    load_course_source_workspace,
    retry_lecturer_course_document,
    upload_lecturer_course_document
}

glob DOCUMENT_MAX_BYTES: int = 25 * 1024 * 1024;

async def _encode_file(file: any) -> str {
    buffer = await file.arrayBuffer();
    values = new(Uint8Array, buffer);
    binary = "";
    for index in range(values.length) {
        binary += chr(values[index]);
    }
    return btoa(binary) as str;
}

def _format_bytes(size: int) -> str {
    if size >= 1024 * 1024 {
        return f"{float(size) / float(1024 * 1024):.1f} MB";
    }
    if size >= 1024 {
        return f"{float(size) / 1024.0:.1f} KB";
    }
    return str(size) + " bytes";
}

def _active_state(view: CourseSourceWorkspaceView | None) -> bool {
    if view is None or view.processing is None {
        return False;
    }
    state = str(view.processing.summary.state);
    return state in [
        "UPLOADED",
        "STORED",
        "VALIDATION_PENDING",
        "VALIDATING",
        "VALIDATED",
        "EXTRACTION_PENDING",
        "EXTRACTING",
        "EXTRACTED",
        "CHUNKING_PENDING",
        "CHUNKING"
    ];
}

def _stage_label(stage: str) -> str {
    if stage == "SECURITY_VALIDATION" {
        return "Safety checks";
    }
    if stage == "TEXT_EXTRACTION" {
        return "Reading content";
    }
    if stage == "CONTENT_CHUNKING" {
        return "Preparing course sections";
    }
    return "Secure upload";
}

def:pub CourseSourceWorkspace(
    track_id: str, course: LecturerCourseDetail
) -> JsxElement {
    has view: CourseSourceWorkspaceView | None = None;
    has selected_file: any = None;
    has loading: bool = True,
        uploading: bool = False,
        mutating: bool = False,
        dragging: bool = False;
    has feedback: str = "",
        status_error: str = "";
    has replace_open: bool = False,
        cancel_open: bool = False;
    version_id = course.draft_version.track_version_id
        if course.draft_version is not None
        else "";
    polling_document_id: str = "";
    polling_state: str = "";
    if view is not None {
        current_view = view as CourseSourceWorkspaceView;
        if current_view.document is not None {
            polling_document_id = current_view.document.document_id;
        }
        if current_view.processing is not None {
            polling_state = str(current_view.processing.summary.state);
        }
    }

    async def refresh(silent: bool = False) {
        if version_id == "" {
            loading = False;
            return;
        }
        if not silent {
            mutating = True;
        }
        try {
            view = await load_course_source_workspace(track_id, version_id);
            status_error = "";
        } except Exception {
            status_error = "Processing status is temporarily unavailable. The last known status is still shown.";
        }
        loading = False;
        mutating = False;
    }

    async can with entry {
        await refresh();
    }
    useEffect(
        lambda {
            timer = setInterval(
                lambda { if _active_state(view) { refresh(True); }}, 4000
            );
            return lambda { clearInterval(timer); };
        },
        [
            track_id,
            version_id,
            polling_document_id,
            polling_state
        ]
    );

    def select_file(file: any) {
        feedback = "";
        selected_file = file;
        if selected_file is None {
            return;
        }
        name = str(selected_file.name).lower();
        if not (name.endswith(".pdf") or name.endswith(".docx")) {
            feedback = "Choose a PDF or DOCX file.";
            selected_file = None;
        } elif selected_file.size <= 0 {
            feedback = "The selected file is empty. Choose another document.";
            selected_file = None;
        } elif selected_file.size > DOCUMENT_MAX_BYTES {
            feedback = "The selected file exceeds the 25 MB limit.";
            selected_file = None;
        }
    }

    def choose_file(event: ChangeEvent) {
        files = event.target.files as any;
        select_file(files[0] if files and (files.length as int) > 0 else None);
    }

    def drag_over(event: Event) {
        event.preventDefault();
        dragging = True;
    }

    def drag_leave(event: Event) {
        event.preventDefault();
        dragging = False;
    }

    def drop_file(event: Event) {
        event.preventDefault();
        dragging = False;
        raw_event = event as any;
        files = raw_event.dataTransfer.files;
        select_file(files[0] if files and (files.length as int) > 0 else None);
    }

    async def upload(replace_existing: bool) {
        if selected_file is None or version_id == "" or uploading {
            return;
        }
        uploading = True;
        feedback = "Uploading source document…";
        try {
            payload = await _encode_file(selected_file);
            input = {
                "track_id": track_id,
                "track_version_id": version_id,
                "original_filename": str(selected_file.name),
                "mime_type": str(selected_file.type),
                "file_size_bytes": int(selected_file.size),
                "idempotency_key": str(selected_file.name) + "-" + str(selected_file.size) + "-" + str(selected_file.lastModified),
                "content_base64": payload,
                "replace_existing": replace_existing
            } as UploadCourseDocumentInput;
            result = await upload_lecturer_course_document(input);
            if result.ok {
                feedback = "Source document stored. Durable processing has started."
                    if not result.duplicate
                    else "This source document was already stored; its current processing status is shown.";
                selected_file = None;
                replace_open = False;
                await refresh(True);
            } else {
                feedback = result.error.message
                    if result.error
                    else "The source document could not be uploaded. Check the file and try again.";
            }
        } except Exception {
            feedback = "The source document could not be uploaded. Your existing source has not been changed.";
        }
        uploading = False;
    }

    async def retry_processing() {
        if view is None or view.document is None {
            return;
        }
        mutating = True;
        feedback = "Retry requested…";
        try {
            view = await retry_lecturer_course_document(
                track_id, version_id, view.document.document_id
            );
            feedback = "Processing retry requested.";
        } except Exception {
            feedback = "Processing could not be retried right now.";
        }
        mutating = False;
    }

    async def cancel_processing() {
        if view is None or view.document is None {
            return;
        }
        mutating = True;
        feedback = "Cancellation requested…";
        cancel_open = False;
        try {
            view = await cancel_lecturer_course_document(
                track_id, version_id, view.document.document_id
            );
        } except Exception {
            feedback = "Cancellation could not be requested right now.";
        }
        mutating = False;
    }

    if loading and view is None {
        return
            <section
                aria-label="Loading source material"
                className="grid animate-pulse gap-4 lg:grid-cols-2"
            >
                <div className="h-44 rounded-2xl bg-surface"/>
                <div className="h-44 rounded-2xl bg-surface"/>
                <div className="h-56 rounded-2xl bg-surface lg:col-span-2"/>
            </section>;
    }
    current = view;
    return
        <section className="space-y-5" aria-busy={mutating or uploading}>
            {status_error != ""
            and <div
                role="status"
                className="rounded-xl border border-state-warning/40 bg-state-warning/10 p-3 text-sm"
            >
                {status_error}
            </div>}
            <Card className="border-surface-border bg-surface">
                <CardHeader>
                    <CardTitle>Source material</CardTitle>
                    <CardDescription>
                        Upload one text-based PDF or DOCX, up to 25 MB. GraphLearn validates, reads, and organizes it securely.
                    </CardDescription>
                </CardHeader>
                <CardContent className="space-y-5">
                    {if current is None or current.source_required {
                        <div
                            className="rounded-xl border border-dashed border-surface-border p-6 text-center"
                        >
                            <FileText className="mx-auto size-7 text-brand"/>
                            <p className="mt-2 font-medium">No source material yet</p>
                            <p className="mt-1 text-sm text-copy-muted">
                                Choose course notes to begin. Scanned or password-protected PDFs cannot be read yet.
                            </p>
                        </div>
                    } else {
                        if current.document is not None {
                            <div
                                className="flex flex-col justify-between gap-4 rounded-xl border border-surface-border bg-elevated p-4 sm:flex-row sm:items-start"
                            >
                                <div className="min-w-0">
                                    <p className="break-words font-medium">
                                        {current.document.filename}
                                    </p>
                                    <p className="mt-1 text-sm text-copy-muted">
                                        {current.document.file_type} · {_format_bytes(
                                            current.document.file_size_bytes
                                        )} · Uploaded {format_datetime(current.document.uploaded_at)}
                                    </p>
                                    <p className="mt-2 text-sm font-medium">
                                        {current.status_label}
                                    </p>
                                </div>
                                <div className="flex flex-wrap gap-2">
                                    <Button
                                        variant="outline"
                                        onClick={lambda (_e: MouseEvent) { refresh(); }}
                                        aria-label="Refresh processing status"
                                    >
                                        <RefreshCw className="size-4"/>
                                        Refresh status
                                    </Button>
                                    {current.processing is not None
                                    and current.processing.summary.cancel_available
                                    and <Button
                                        variant="outline"
                                        onClick={lambda (_e: MouseEvent) { cancel_open = True; }}
                                    >
                                        <X className="size-4"/>
                                        Cancel processing
                                    </Button>}
                                </div>
                            </div>
                        }
                    } }
                    <div>
                        <label
                            htmlFor="course-source-file"
                            onDragOver={drag_over}
                            onDragLeave={drag_leave}
                            onDrop={drop_file}
                            className={"relative flex min-h-40 cursor-pointer flex-col items-center justify-center rounded-2xl border border-dashed p-6 text-center transition-colors " + ("border-brand bg-accent-dim" if dragging else "border-surface-border bg-base hover:border-brand/60")}
                        >
                            <Upload className="size-7 text-brand"/>
                            <span className="mt-3 font-medium text-copy-primary">Drop a PDF or DOCX here</span>
                            <span className="mt-1 text-sm text-copy-muted">or choose a file · maximum 25 MB</span>
                            <input
                                id="course-source-file"
                                type="file"
                                accept=".pdf,.docx,application/pdf,application/vnd.openxmlformats-officedocument.wordprocessingml.document"
                                disabled={uploading}
                                onChange={choose_file}
                                className="absolute inset-0 cursor-pointer opacity-0"
                            />
                        </label>
                        {selected_file is not None
                        and <p className="mt-2 break-words text-sm text-copy-muted">
                            Selected: {selected_file.name} ({_format_bytes(
                                int(selected_file.size)
                            )})
                        </p>}
                        <Button
                            className="mt-3 w-full sm:w-auto"
                            disabled={selected_file is None or uploading}
                            onClick={lambda (_e: MouseEvent) { if current is not None
                            and not current.source_required {
                                replace_open = True;
                            } else {
                                upload(False);
                            } }}
                        >
                            <Upload className="size-4"/>
                            {"Uploading…"
                                if uploading
                                else (
                                    "Replace source"
                                        if current is not None
                                        and not current.source_required
                                        else "Upload source"
                                )}
                        </Button>
                    </div>
                    {feedback != ""
                    and <p role="status" className="text-sm text-copy-muted">
                        {feedback}
                    </p>}
                </CardContent>
            </Card>
            {if current is not None and current.processing is not None {
                <div className="grid gap-5 lg:grid-cols-[1.5fr_1fr]">
                    <Card className="border-surface-border bg-surface">
                        <CardHeader>
                            <CardTitle>Source processing</CardTitle>
                            <CardDescription role="status">
                                {current.processing.summary.progress_message
                                or current.status_label}
                            </CardDescription>
                        </CardHeader>
                        <CardContent>
                            <div className="mb-2 flex justify-between text-sm">
                                <span>{current.status_label}</span>
                                <span>
                                    {current.processing.summary.overall_progress_percent}%
                                </span>
                            </div>
                            <div
                                role="progressbar"
                                aria-label="Source processing progress"
                                aria-valuemin={0}
                                aria-valuemax={100}
                                aria-valuenow={current.processing.summary.overall_progress_percent}
                                className="h-2 overflow-hidden rounded-full bg-surface-border"
                            >
                                <div
                                    className="h-full bg-brand motion-reduce:transition-none"
                                    style={{
                                        "width": str(
                                            current.processing.summary.overall_progress_percent
                                        ) + "%"
                                    }}
                                />
                            </div>
                            <ol className="mt-5 space-y-3">
                                {for stage in current.processing.stages {
                                    <li
                                        key={str(stage.stage)}
                                        className="flex items-start gap-3 rounded-xl border border-surface-border p-3"
                                    >
                                        <Check className="mt-0.5 size-4 text-brand"/>
                                        <div>
                                            <p className="font-medium">
                                                {_stage_label(str(stage.stage))}
                                            </p>
                                            <p className="text-sm text-copy-muted">
                                                {str(stage.status).replace(
                                                    "_", " "
                                                ).title()} · Attempt {stage.attempt_count}
                                            </p>
                                        </div>
                                    </li>
                                }}
                            </ol>
                        </CardContent>
                    </Card>
                    <Card className="border-surface-border bg-surface">
                        <CardHeader>
                            <CardTitle>
                                {"Ready for AI course interpretation"
                                    if current.interpretation_eligible
                                    else (
                                        "Source needs attention"
                                            if current.status_label == "Needs attention"
                                            else "What happens next"
                                    )}
                            </CardTitle>
                            <CardDescription>
                                {"Your source passed validation, was read, and was organized into traceable course sections."
                                    if current.interpretation_eligible
                                    else current.blocker_message}
                            </CardDescription>
                        </CardHeader>
                        <CardContent className="space-y-3">
                            {current.processing.summary.error_code is not None
                            and <div
                                role="alert"
                                className="flex gap-2 rounded-xl border border-state-error/40 bg-state-error/10 p-3 text-sm"
                            >
                                <AlertTriangle className="size-4 shrink-0"/>
                                {current.processing.summary.user_message or "We could not continue processing this source document."}
                            </div>}
                            {current.processing.summary.retry_available
                            and <Button
                                onClick={lambda (_e: MouseEvent) { retry_processing(); }}
                                disabled={mutating}
                            >
                                <RotateCcw className="size-4"/>
                                Retry processing
                            </Button>}
                            {current.interpretation_eligible
                            and <Link
                                to={"/lecturer/courses/" + track_id + "/interpretation"}
                                className="inline-flex min-h-10 w-full items-center justify-center rounded-xl bg-ai-accent px-4 font-semibold text-base"
                            >
                                Continue to course interpretation →
                            </Link>}
                            {not current.interpretation_eligible
                            and <button
                                type="button"
                                disabled={True}
                                aria-describedby="interpretation-blocker"
                                className="min-h-10 w-full rounded-xl bg-surface-border px-4 text-sm text-copy-muted"
                            >
                                Continue to course interpretation
                            </button>}
                            <p
                                id="interpretation-blocker"
                                className="text-sm text-copy-muted"
                            >
                                {current.blocker_message}
                            </p>
                        </CardContent>
                    </Card>
                </div>
            }}
            <Dialog
                open={replace_open}
                onOpenChange={lambda (open: bool) { replace_open = open; }}
            >
                <DialogContent>
                    <DialogHeader>
                        <DialogTitle>Replace source document?</DialogTitle>
                        <DialogDescription>
                            The current document will stop processing and become historical. Published course evidence is not automatically replaced.
                        </DialogDescription>
                    </DialogHeader>
                    <DialogFooter>
                        <Button
                            variant="outline"
                            onClick={lambda (_e: MouseEvent) { replace_open = False; }}
                        >
                            Keep current source
                        </Button>
                        <Button onClick={lambda (_e: MouseEvent) { upload(True); }}>
                            Replace and process
                        </Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>
            <Dialog
                open={cancel_open}
                onOpenChange={lambda (open: bool) { cancel_open = open; }}
            >
                <DialogContent>
                    <DialogHeader>
                        <DialogTitle>Cancel document processing?</DialogTitle>
                        <DialogDescription>
                            Completed source artifacts will remain in history, but this document will not continue to the next processing stage.
                        </DialogDescription>
                    </DialogHeader>
                    <DialogFooter>
                        <Button
                            variant="outline"
                            onClick={lambda (_e: MouseEvent) { cancel_open = False; }}
                        >
                            Keep processing
                        </Button>
                        <Button
                            onClick={lambda (_e: MouseEvent) { cancel_processing(); }}
                        >
                            Cancel processing
                        </Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>
        </section>;
}
