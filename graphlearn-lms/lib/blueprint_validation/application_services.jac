"""Feature 44 BLUEPRINT_VALIDATION job-stage integration."""
import from lib.blueprint_validation.service { BlueprintValidationService }
import from lib.course_blueprint.repositories { CourseBlueprintRepository }
import from lib.course_document.processing_service { DocumentProcessingOrchestrator }
import from lib.curriculum_graph.repositories { CurriculumGraphRepository }
import from lib.curriculum_graph.service { TopicSkillGraphGenerationService }
import from lib.learning_track.repositories { repository_find_track, repository_find_version }
import from nodes.curriculum { BlueprintValidationContext, BlueprintValidationResult, BlueprintValidationStatus, CourseBlueprint, CourseDocument, DocumentProcessingJob, GraphGenerationContext }
import from nodes.learning_track { LearningTrack, TrackVersion }

def execute_blueprint_validation_job(document: CourseDocument, job: DocumentProcessingJob, worker_id: str) -> BlueprintValidationResult {
    track = repository_find_track(document.track_id); version = repository_find_version(track as LearningTrack, document.track_version_id) if track is not None else None;
    if version is None { return BlueprintValidationResult(validation_report_id="", status=BlueprintValidationStatus.INVALID, error_code="BLUEPRINT_NOT_READY_FOR_VALIDATION"); }
    blueprint = CourseBlueprintRepository().find_active_for_version(version as TrackVersion); if blueprint is None or blueprint.document_id != document.document_id { return BlueprintValidationResult(validation_report_id="", status=BlueprintValidationStatus.INVALID, error_code="BLUEPRINT_NOT_READY_FOR_VALIDATION"); }
    runs = CurriculumGraphRepository().list_runs(version as TrackVersion); graph_id: str | None = None; for run in runs { if run.is_active and run.blueprint_id == blueprint.blueprint_id { graph_id = run.graph_generation_id; } }
    if graph_id is None { generated = TopicSkillGraphGenerationService().generate_graph(blueprint.blueprint_id, GraphGenerationContext(track_id=document.track_id, track_version_id=document.track_version_id, blueprint_id=blueprint.blueprint_id, request_id=job.job_id, actor_id=worker_id)); graph_id = generated.graph_generation_id; }
    if graph_id is None { _ = DocumentProcessingOrchestrator().fail_job(document, job, worker_id, "BLUEPRINT_GRAPH_INCONSISTENT", "Draft curriculum graph generation failed validation prerequisites.", False); return BlueprintValidationResult(validation_report_id="", status=BlueprintValidationStatus.INVALID, error_code="BLUEPRINT_GRAPH_INCONSISTENT"); }
    result = BlueprintValidationService().validate_blueprint(blueprint.blueprint_id, BlueprintValidationContext(track_id=document.track_id, track_version_id=document.track_version_id, blueprint_id=blueprint.blueprint_id, graph_generation_id=graph_id, request_id=job.job_id, actor_id=worker_id));
    if result.eligible_for_review { _ = DocumentProcessingOrchestrator().complete_job(document, job, worker_id, result.validation_report_id); } else { _ = DocumentProcessingOrchestrator().fail_job(document, job, worker_id, result.error_code or "BLUEPRINT_VALIDATION_FAILED", "Generated course structure did not pass the grounding quality gate.", False); }
    return result;
}
