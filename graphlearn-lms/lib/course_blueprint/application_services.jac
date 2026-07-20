"""Authenticated lecturer boundary for blueprint generation control and status."""
import from lib.authorization.actor { resolve_authorization_actor }
import from lib.authorization.policy { AuthorizationPolicyService, public_error_code }
import from lib.authorization.repositories { version_resource_context }
import from lib.course_blueprint.generation_service { CourseBlueprintGenerationService }
import from lib.course_blueprint.repositories { BlueprintGenerationArtifactRepository }
import from lib.course_blueprint.planner { default_blueprint_generation_config }
import from lib.course_document.chunk_repository { DocumentChunkRepository }
import from lib.course_document.extraction_repository { DocumentExtractionRepository }
import from lib.course_document.repositories { CourseDocumentRepository }
import from lib.course_document.processing_workers { DocumentProcessingWorkerService }
import from lib.course_document.processing_job_repository { DocumentProcessingJobRepository }
import from lib.course_document.processing_service { DocumentProcessingOrchestrator }
import from lib.learning_track.repositories { repository_find_track, repository_find_version }
import from nodes.authorization { AuthorizationActor, AuthorizationDecisionType, LecturerPermission }
import from nodes.curriculum { BlueprintGenerationContext, BlueprintGenerationResult, BlueprintGenerationStatus, BlueprintGenerationStatusView, DocumentProcessingStage }

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
    active_job = DocumentProcessingJobRepository().find_active_by_stage(document, DocumentProcessingStage.BLUEPRINT_GENERATION);
    if active_job is None {
        runs = BlueprintGenerationArtifactRepository().list_runs(version);
        if len(runs) == 0 or runs[len(runs) - 1].status not in ["QUEUED", "ANALYZING_CHUNKS", "MERGING_CONCEPTS", "SYNTHESIZING_BLUEPRINT", "INFERRING_PREREQUISITES", "CRITIQUING", "VALIDATING"] { return False; }
        latest_run = runs[len(runs) - 1];
        _ = DocumentProcessingOrchestrator().start_stage(document, DocumentProcessingStage.BLUEPRINT_GENERATION, "dispatch-recovery|" + latest_run.generation_run_id);
    }
    # Execute inside the authenticated request context. A detached thread does not
    # retain the caller's graph root permissions and cannot safely mutate this job.
    worker_id = "blueprint-dispatch:" + actor.user_id;
    processed = DocumentProcessingWorkerService().run_stage(document, DocumentProcessingStage.BLUEPRINT_GENERATION, worker_id, request_id);
    if DocumentProcessingOrchestrator().artifact_satisfies(document, DocumentProcessingStage.BLUEPRINT_GENERATION) {
        _ = DocumentProcessingWorkerService().run_blueprint_validation(document, "blueprint-validation:" + actor.user_id);
    }
    return processed;
}
