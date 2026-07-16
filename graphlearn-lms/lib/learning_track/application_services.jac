"""Track-aware domain and application services over focused repositories."""

import from datetime { datetime, timezone }
import from uuid { uuid4 }
import from edges.domain_edges { FOR_TRACK, FOR_TRACK_VERSION, HAS_ENROLLMENT }
import from lib.learning_track.repositories {
    repository_active_version, repository_find_active_enrollment, repository_find_track,
    repository_find_version, repository_mastery, repository_prerequisite_cycle,
    repository_roadmap_items, repository_skills, repository_version_belongs_to,
    repository_versions
}
import from lib.learning_track.repository_types {
    ActorContext, ApplicationOperation, IdempotencyContext, ResolvedTrackContext,
    ServiceError, ServiceResult, TrackProgressSummary
}
import from lib.learning_track.service {
    activate_published_version, can_discover, can_enroll, create_initial_version, create_next_draft_version,
    create_track, resolve_legacy_programming_track, track_configuration,
    transition_track_status, transition_version_status
}
import from nodes.enrollment { Enrollment }
import from nodes.learner { Learner }
import from nodes.learning_track {
    CreateLearningTrackInput, LearningTrack, LearningTrackStatus, TrackOwnershipType,
    TrackVersion, TrackVersionStatus
}

def service_now -> str {
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z");
}

def service_error(code: str, message: str) -> ServiceResult {
    return ServiceResult(ok=False, error=ServiceError(code=code, message=message));
}

def find_operation(context: IdempotencyContext) -> ApplicationOperation | None {
    for operation in [root.shared -->][?:ApplicationOperation] {
        if operation.key == context.key and operation.operation == context.operation {
            return operation;
        }
    }
    return None;
}

def begin_operation(context: IdempotencyContext) -> ApplicationOperation {
    existing = find_operation(context);
    if existing is not None { return existing; }
    timestamp = service_now();
    return (root.shared ++> ApplicationOperation(
        key=context.key,
        operation=context.operation,
        actor_id=context.actor_id,
        request_id=context.request_id,
        status="STARTED",
        created_at=timestamp,
        updated_at=timestamp
    ))[0];
}

def complete_operation(operation: ApplicationOperation, entity_id: str) {
    operation.status = "COMPLETED";
    operation.entity_id = entity_id;
    operation.error_code = None;
    operation.updated_at = service_now();
}

def fail_operation(operation: ApplicationOperation, error_code: str) {
    operation.status = "INCOMPLETE";
    operation.error_code = error_code;
    operation.updated_at = service_now();
}

# TrackContextService. Legacy language fallback is intentionally isolated here.
def resolve_track_context_service(
    track_id: str | None,
    track_version_id: str | None,
    language: str | None
) -> ServiceResult {
    resolution = resolve_legacy_programming_track(track_id, track_version_id, language);
    if not resolution.resolved or resolution.track_id is None or resolution.track_version_id is None {
        return service_error(resolution.error_code or "TRACK_NOT_FOUND", resolution.message);
    }
    track = repository_find_track(resolution.track_id);
    if track is None { return service_error("TRACK_NOT_FOUND", "Learning track was not found."); }
    version = repository_find_version(track, resolution.track_version_id);
    if version is None or not repository_version_belongs_to(track, version) {
        return service_error("TRACK_VERSION_MISMATCH", "Track version does not belong to the track.");
    }
    return ServiceResult(ok=True, value=ResolvedTrackContext(
        track_id=track.track_id,
        track_version_id=version.track_version_id,
        title=track.title,
        legacy_language=resolution.canonical_language,
        resolution_source=resolution.resolution_type
    ));
}

# LearningTrackDomainService
def actor_can_manage(actor: ActorContext, track: LearningTrack) -> bool {
    if track.ownership_type == TrackOwnershipType.SYSTEM { return "system" in actor.roles; }
    if track.owner_id is not None and track.owner_id == actor.user_id { return True; }
    return track.institution_id is not None and track.institution_id in actor.institution_ids and "institution_admin" in actor.roles;
}

def validate_track_management(actor: ActorContext, track: LearningTrack) -> ServiceResult {
    if not actor_can_manage(actor, track) {
        return service_error("UNAUTHORIZED_TRACK_OPERATION", "This actor cannot manage the learning track.");
    }
    return ServiceResult(ok=True, value=track);
}

def validate_version_mutable(version: TrackVersion) -> ServiceResult {
    if version.status in [TrackVersionStatus.PUBLISHED, TrackVersionStatus.SUPERSEDED] {
        return service_error("TRACK_VERSION_IMMUTABLE", "Published curriculum versions are immutable.");
    }
    return ServiceResult(ok=True, value=version);
}

# LearningTrackApplicationService. Caller supplies trusted ActorContext; owner_id input is ignored.
def create_track_service(
    actor: ActorContext,
    input: CreateLearningTrackInput,
    idempotency: IdempotencyContext
) -> ServiceResult {
    if idempotency.operation != "create-track" or idempotency.actor_id != actor.user_id {
        return service_error("IDEMPOTENCY_CONFLICT", "Idempotency context does not match this operation.");
    }
    operation = begin_operation(idempotency);
    if operation.status == "COMPLETED" and operation.entity_id is not None {
        replay_track = repository_find_track(operation.entity_id);
        if replay_track is not None { return ServiceResult(ok=True, value=replay_track, replayed=True); }
        fail_operation(operation, "APPLICATION_OPERATION_INCOMPLETE");
    }
    input.owner_id = None;
    trusted_system = "system" in actor.roles;
    created = create_track(input, actor.user_id, trusted_system=trusted_system);
    if not created.ok or created.track is None {
        code = created.error.code if created.error is not None else "APPLICATION_OPERATION_INCOMPLETE";
        fail_operation(operation, code);
        return service_error(code, created.error.message if created.error is not None else "Track creation failed.");
    }
    track = created.track;
    version_result = create_initial_version(track.track_id, actor.user_id);
    if not version_result.ok or version_result.version is None {
        fail_operation(operation, "APPLICATION_OPERATION_INCOMPLETE");
        track.status = LearningTrackStatus.FAILED;
        track.is_enrollment_open = False;
        return service_error("APPLICATION_OPERATION_INCOMPLETE", "Track exists but initial version creation is incomplete and retryable.");
    }
    complete_operation(operation, track.track_id);
    return ServiceResult(ok=True, value=track);
}

# TrackVersionService
def create_next_draft_service(actor: ActorContext, track_id: str, change_summary: str = "") -> ServiceResult {
    track = repository_find_track(track_id);
    if track is None { return service_error("TRACK_NOT_FOUND", "Learning track was not found."); }
    permission = validate_track_management(actor, track);
    if not permission.ok { return permission; }
    for version in repository_versions(track) {
        if version.status in [TrackVersionStatus.DRAFT, TrackVersionStatus.REVIEW_REQUIRED, TrackVersionStatus.APPROVED] {
            return service_error("TRACK_ALREADY_HAS_DRAFT", "Track already has an active draft workflow.");
        }
    }
    result = create_next_draft_version(track_id, actor.user_id, change_summary);
    if not result.ok or result.version is None {
        return service_error(result.error.code if result.error is not None else "APPLICATION_OPERATION_INCOMPLETE", "Draft version could not be created.");
    }
    return ServiceResult(ok=True, value=result.version);
}

# TrackPublicationService with preflight validation and an explicit incomplete marker.
def publish_track_version_service(
    actor: ActorContext,
    track_id: str,
    track_version_id: str,
    open_enrollment: bool,
    idempotency: IdempotencyContext
) -> ServiceResult {
    if idempotency.operation != "publish-version" { return service_error("IDEMPOTENCY_CONFLICT", "Invalid publication idempotency operation."); }
    operation = begin_operation(idempotency);
    track = repository_find_track(track_id);
    if track is None { fail_operation(operation, "TRACK_NOT_FOUND"); return service_error("TRACK_NOT_FOUND", "Learning track was not found."); }
    if not actor_can_manage(actor, track) { fail_operation(operation, "UNAUTHORIZED_TRACK_OPERATION"); return service_error("UNAUTHORIZED_TRACK_OPERATION", "This actor cannot publish the track."); }
    version = repository_find_version(track, track_version_id);
    if version is None or not repository_version_belongs_to(track, version) { fail_operation(operation, "TRACK_VERSION_MISMATCH"); return service_error("TRACK_VERSION_MISMATCH", "Version does not belong to the track."); }
    if operation.status == "COMPLETED" and track.active_version_id == track_version_id and version.status == TrackVersionStatus.PUBLISHED {
        return ServiceResult(ok=True, value=version, replayed=True);
    }
    if version.status != TrackVersionStatus.APPROVED { fail_operation(operation, "TRACK_VERSION_MISMATCH"); return service_error("TRACK_VERSION_MISMATCH", "Only an approved version can be published."); }
    if track.title.strip() == "" or track_configuration(track) is None { fail_operation(operation, "CURRICULUM_GRAPH_INVALID"); return service_error("CURRICULUM_GRAPH_INVALID", "Required track metadata or configuration is missing."); }
    cycle = repository_prerequisite_cycle(track, track_version_id);
    if len(cycle) > 0 { fail_operation(operation, "PREREQUISITE_CYCLE_DETECTED"); return service_error("PREREQUISITE_CYCLE_DETECTED", "Curriculum prerequisite graph contains a cycle."); }
    old_active_id = track.active_version_id;
    activated = activate_published_version(track_id, track_version_id, actor.user_id);
    if not activated.ok {
        track.active_version_id = old_active_id;
        track.is_enrollment_open = False;
        fail_operation(operation, "APPLICATION_OPERATION_INCOMPLETE");
        return service_error("APPLICATION_OPERATION_INCOMPLETE", "Publication did not complete and discovery is blocked.");
    }
    if track.status != LearningTrackStatus.PUBLISHED {
        transitioned = transition_track_status(track_id, LearningTrackStatus.PUBLISHED, actor.user_id);
        if not transitioned.ok {
            track.is_enrollment_open = False;
            fail_operation(operation, "APPLICATION_OPERATION_INCOMPLETE");
            return service_error("APPLICATION_OPERATION_INCOMPLETE", "Version activated but track publication is incomplete and discovery is blocked.");
        }
    }
    track.is_enrollment_open = open_enrollment;
    complete_operation(operation, track_version_id);
    return ServiceResult(ok=True, value=version);
}

# EnrollmentService. The graph edges prove learner, track, and version context.
def enroll_service(
    actor: ActorContext,
    learner: Learner,
    track_id: str,
    idempotency: IdempotencyContext
) -> ServiceResult {
    if actor.learner_id is None or actor.learner_id != learner.id or idempotency.operation != "create-enrollment" {
        return service_error("UNAUTHORIZED_TRACK_OPERATION", "Learner context does not match the authenticated actor.");
    }
    operation = begin_operation(idempotency);
    existing = repository_find_active_enrollment(learner, track_id);
    if existing is not None {
        if operation.status == "COMPLETED" or operation.status == "STARTED" {
            complete_operation(operation, existing.enrollment_id);
            return ServiceResult(ok=True, value=existing, replayed=True);
        }
        return service_error("ENROLLMENT_ALREADY_EXISTS", "Learner already has an active enrollment for this track.");
    }
    track = repository_find_track(track_id);
    if track is None { fail_operation(operation, "TRACK_NOT_FOUND"); return service_error("TRACK_NOT_FOUND", "Learning track was not found."); }
    if not can_discover(track, actor.user_id) or not can_enroll(track, actor.user_id) { fail_operation(operation, "TRACK_NOT_ENROLLABLE"); return service_error("TRACK_NOT_ENROLLABLE", "Learning track is not open for enrollment."); }
    version = repository_active_version(track);
    if version is None or version.status != TrackVersionStatus.PUBLISHED { fail_operation(operation, "TRACK_VERSION_NOT_FOUND"); return service_error("TRACK_VERSION_NOT_FOUND", "Track has no published active version."); }
    timestamp = service_now();
    enrollment = Enrollment(
        enrollment_id=f"enr_{str(uuid4()).replace('-', '')}",
        learner_id=learner.id,
        track_id=track.track_id,
        track_version_id=version.track_version_id,
        enrolled_at=timestamp,
        started_at=timestamp
    );
    learner +>:HAS_ENROLLMENT(enrolled_at=timestamp):+> enrollment;
    enrollment +>:FOR_TRACK:+> track;
    enrollment +>:FOR_TRACK_VERSION:+> version;
    complete_operation(operation, enrollment.enrollment_id);
    return ServiceResult(ok=True, value=enrollment);
}

# LearnerProgressService. Every read is rooted at one validated enrollment.
def track_progress_service(enrollment: Enrollment) -> TrackProgressSummary {
    skills = repository_skills(repository_find_track(enrollment.track_id) as LearningTrack, enrollment.track_version_id) if repository_find_track(enrollment.track_id) is not None else [];
    mastery = repository_mastery(enrollment);
    items = repository_roadmap_items(enrollment);
    completed = len([item for item in items if item.status == "COMPLETED"]);
    percent = (float(completed) * 100.0 / float(len(items))) if len(items) > 0 else 0.0;
    current: str | None = None;
    for item in items {
        if item.status in ["AVAILABLE", "IN_PROGRESS"] { current = item.lesson_template_id; break; }
    }
    mastered = len([record for record in mastery if record.status == "MASTERED" or record.confidence >= 0.8]);
    return TrackProgressSummary(
        enrollment_id=enrollment.enrollment_id,
        track_id=enrollment.track_id,
        track_version_id=enrollment.track_version_id,
        completion_percent=percent,
        mastered_skill_count=mastered,
        total_skill_count=len(skills),
        current_lesson_id=current
    );
}
