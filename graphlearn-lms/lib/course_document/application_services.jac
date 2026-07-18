"""Authenticated authorization boundary for course-document operations."""

import from lib.authorization.actor { resolve_authorization_actor }
import from lib.authorization.policy { AuthorizationPolicyService, public_error_code }
import from lib.authorization.repositories { version_resource_context }
import from lib.course_document.repositories { CourseDocumentRepository }
import from lib.course_document.service { CourseDocumentUploadService }
import from lib.course_document.processing_service { DocumentProcessingOrchestrator }
import from lib.learning_track.repositories { repository_find_track, repository_find_version }
import from lib.learning_track.repository_types { ActorContext }
import from nodes.authorization { AuthorizationDecisionType, LecturerPermission }
import from nodes.curriculum { CourseDocument, CourseDocumentError, CourseDocumentUploadResult, CourseSourceDocumentView, CourseSourceWorkspaceView, DocumentProcessingState, DocumentProcessingStatusView, UploadCourseDocumentInput }

def _denied(code: str) -> CourseDocumentUploadResult { return CourseDocumentUploadResult(ok=False, error=CourseDocumentError(code=code, message="The requested course document operation is not permitted.")); }

def upload_authorized_course_document(input: UploadCourseDocumentInput, request_id: str = "") -> CourseDocumentUploadResult {
    actor = resolve_authorization_actor(); context = version_resource_context(input.track_id, input.track_version_id, actor.lecturer_id);
    if context is None { return _denied("TRACK_NOT_FOUND"); }
    decision = AuthorizationPolicyService().authorize_lecturer_action(actor, LecturerPermission.UPLOAD_COURSE_DOCUMENT, context);
    if decision.decision == AuthorizationDecisionType.DENY { return _denied(public_error_code(decision)); }
    return CourseDocumentUploadService().upload(ActorContext(user_id=actor.user_id, request_id=request_id, lecturer_id=actor.lecturer_id, learner_id=actor.learner_id, roles=[str(role) for role in actor.active_roles]), input);
}

def load_authorized_active_document(track_id: str, track_version_id: str) -> CourseDocument | None {
    actor = resolve_authorization_actor(); context = version_resource_context(track_id, track_version_id, actor.lecturer_id);
    if context is None { return None; }
    decision = AuthorizationPolicyService().authorize_lecturer_action(actor, LecturerPermission.VIEW_COURSE_DOCUMENT, context);
    if decision.decision == AuthorizationDecisionType.DENY { return None; }
    track = repository_find_track(track_id);
    if track is None { return None; }
    version = repository_find_version(track, track_version_id);
    return None if version is None else CourseDocumentRepository().find_active_for_version(version);
}

def _authorized_processing_document(track_id: str, track_version_id: str, document_id: str, permission: LecturerPermission) -> CourseDocument {
    actor = resolve_authorization_actor(); context = version_resource_context(track_id, track_version_id, actor.lecturer_id);
    if context is None { raise PermissionError("TRACK_NOT_FOUND"); }
    decision = AuthorizationPolicyService().authorize_lecturer_action(actor, permission, context);
    if decision.decision == AuthorizationDecisionType.DENY { raise PermissionError(public_error_code(decision)); }
    return DocumentProcessingOrchestrator().resolve_document(track_id, track_version_id, document_id);
}

def get_authorized_document_processing_status(track_id: str, track_version_id: str, document_id: str) -> DocumentProcessingStatusView { document = _authorized_processing_document(track_id, track_version_id, document_id, LecturerPermission.VIEW_COURSE_DOCUMENT); orchestrator = DocumentProcessingOrchestrator(); return DocumentProcessingStatusView(summary=orchestrator.projection.project(document).summary, stages=orchestrator.projection.project(document).stages, warnings=orchestrator.audit_document_processing_state(document)); }
def retry_authorized_document_processing(track_id: str, track_version_id: str, document_id: str) -> DocumentProcessingStatusView { document = _authorized_processing_document(track_id, track_version_id, document_id, LecturerPermission.PROCESS_COURSE_DOCUMENT); return DocumentProcessingOrchestrator().manual_retry(document); }
def cancel_authorized_document_processing(track_id: str, track_version_id: str, document_id: str, reason: str = "LECTURER_CANCELLED") -> DocumentProcessingStatusView { document = _authorized_processing_document(track_id, track_version_id, document_id, LecturerPermission.PROCESS_COURSE_DOCUMENT); orchestrator = DocumentProcessingOrchestrator(); _ = orchestrator.request_cancel(document, reason); return orchestrator.projection.project(document); }

def load_authorized_source_workspace(track_id: str, track_version_id: str) -> CourseSourceWorkspaceView {
    document = load_authorized_active_document(track_id, track_version_id);
    if document is None { return CourseSourceWorkspaceView(track_id=track_id, track_version_id=track_version_id, source_required=True, status_label="Missing", next_action_label="Upload", blocker_message="Upload a PDF or DOCX to begin source processing.", interpretation_eligible=False); }
    active = document as CourseDocument;
    processing = DocumentProcessingOrchestrator().projection.project(active);
    state = processing.summary.state;
    ready = active.is_active and state == DocumentProcessingState.READY_FOR_BLUEPRINT;
    attention = state in [DocumentProcessingState.VALIDATION_FAILED, DocumentProcessingState.OCR_REQUIRED, DocumentProcessingState.NO_EXTRACTABLE_TEXT, DocumentProcessingState.EXTRACTION_FAILED, DocumentProcessingState.CHUNKING_FAILED, DocumentProcessingState.BLOCKED, DocumentProcessingState.CANCELLED];
    status_label = "Ready" if ready else ("Needs attention" if attention else "Processing");
    next_action = "Interpret course" if ready else (("Retry" if processing.summary.retry_available else "Replace") if attention else "Wait");
    blocker = "" if ready else (processing.summary.user_message or processing.summary.progress_message or "Course interpretation unlocks after source processing completes.");
    safe_document = CourseSourceDocumentView(document_id=active.document_id, filename=active.original_filename, file_type="PDF" if active.file_extension.lower() == ".pdf" else "DOCX", file_size_bytes=active.file_size_bytes, uploaded_at=active.uploaded_at, is_active=active.is_active);
    return CourseSourceWorkspaceView(track_id=track_id, track_version_id=track_version_id, source_required=False, status_label=status_label, next_action_label=next_action, blocker_message=blocker, interpretation_eligible=ready, document=safe_document, processing=processing);
}
