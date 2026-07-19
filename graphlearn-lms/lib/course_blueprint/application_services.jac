"""Authenticated lecturer boundary for blueprint generation control and status."""
import from lib.authorization.actor { resolve_authorization_actor }
import from lib.authorization.policy { AuthorizationPolicyService, public_error_code }
import from lib.authorization.repositories { version_resource_context }
import from lib.course_blueprint.generation_service { CourseBlueprintGenerationService }
import from lib.course_blueprint.planner { default_blueprint_generation_config }
import from lib.course_document.chunk_repository { DocumentChunkRepository }
import from lib.course_document.extraction_repository { DocumentExtractionRepository }
import from lib.course_document.repositories { CourseDocumentRepository }
import from lib.course_document.processing_workers { DocumentProcessingWorkerService }
import from lib.learning_track.repositories { repository_find_track, repository_find_version }
import from nodes.authorization { AuthorizationActor, AuthorizationDecisionType, LecturerPermission }
import from nodes.curriculum { BlueprintGenerationContext, BlueprintGenerationResult, BlueprintGenerationStatus, BlueprintGenerationStatusView }

def _authorize(track_id: str, track_version_id: str, permission: LecturerPermission) -> AuthorizationActor {
    actor = resolve_authorization_actor(); resource = version_resource_context(track_id, track_version_id, actor.lecturer_id); if resource is None { raise PermissionError("TRACK_NOT_FOUND"); } decision = AuthorizationPolicyService().authorize_lecturer_action(actor, permission, resource); if decision.decision == AuthorizationDecisionType.DENY { raise PermissionError(public_error_code(decision)); } return actor;
}

def generate_authorized_course_blueprint(track_id: str, track_version_id: str, request_id: str = "", force_regenerate: bool = False) -> BlueprintGenerationResult {
    actor = _authorize(track_id, track_version_id, LecturerPermission.PROCESS_COURSE_DOCUMENT); track = repository_find_track(track_id); if track is None { return BlueprintGenerationResult(status=BlueprintGenerationStatus.FAILED, concept_count=0, module_count=0, outcome_count=0, prerequisite_count=0, source_coverage_ratio=0.0, warnings=[], error_code="BLUEPRINT_SOURCE_NOT_READY"); } version = repository_find_version(track, track_version_id); if version is None { return BlueprintGenerationResult(status=BlueprintGenerationStatus.FAILED, concept_count=0, module_count=0, outcome_count=0, prerequisite_count=0, source_coverage_ratio=0.0, warnings=[], error_code="BLUEPRINT_SOURCE_NOT_READY"); } document = CourseDocumentRepository().find_active_for_version(version); if document is None { return BlueprintGenerationResult(status=BlueprintGenerationStatus.FAILED, concept_count=0, module_count=0, outcome_count=0, prerequisite_count=0, source_coverage_ratio=0.0, warnings=[], error_code="BLUEPRINT_SOURCE_NOT_READY"); } extraction = DocumentExtractionRepository().find_active_for_document(document); chunk_set = None if extraction is None else DocumentChunkRepository().find_active_chunk_set(extraction); if chunk_set is None { return BlueprintGenerationResult(status=BlueprintGenerationStatus.FAILED, concept_count=0, module_count=0, outcome_count=0, prerequisite_count=0, source_coverage_ratio=0.0, warnings=[], error_code="BLUEPRINT_CHUNK_SET_INVALID"); } return CourseBlueprintGenerationService().prepare_generation(BlueprintGenerationContext(track_id=track_id, track_version_id=track_version_id, document_id=document.document_id, chunk_set_id=chunk_set.chunk_set_id, request_id=request_id, actor_id=actor.user_id, config=default_blueprint_generation_config(), force_regenerate=force_regenerate));
}

def get_authorized_blueprint_generation_status(track_id: str, track_version_id: str) -> BlueprintGenerationStatusView { _ = _authorize(track_id, track_version_id, LecturerPermission.VIEW_COURSE_DOCUMENT); return CourseBlueprintGenerationService().get_generation_status(track_id, track_version_id); }
def retry_authorized_blueprint_generation(track_id: str, track_version_id: str, request_id: str = "") -> BlueprintGenerationResult { return generate_authorized_course_blueprint(track_id, track_version_id, request_id, False); }
def dispatch_authorized_blueprint_generation(track_id: str, track_version_id: str, request_id: str = "") -> bool {
    actor = _authorize(track_id, track_version_id, LecturerPermission.PROCESS_COURSE_DOCUMENT); track = repository_find_track(track_id);
    if track is None { return False; } version = repository_find_version(track, track_version_id);
    if version is None { return False; } document = CourseDocumentRepository().find_active_for_version(version);
    if document is None { return False; }
    return DocumentProcessingWorkerService().run_next(document, "blueprint-dispatch:" + actor.user_id, request_id);
}
