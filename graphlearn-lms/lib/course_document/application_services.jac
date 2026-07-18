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
import from nodes.curriculum { CourseDocument, CourseDocumentError, CourseDocumentUploadResult, DocumentProcessingStatusView, UploadCourseDocumentInput }

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
