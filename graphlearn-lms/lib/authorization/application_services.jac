"""Authorization-enforcing lecturer course application-service adapters."""

import from edges.domain_edges { OWNS_TRACK }
import from lib.authorization.actor { resolve_authorization_actor }
import from lib.authorization.policy { AuthorizationPolicyService, public_error_code }
import from lib.authorization.repositories { track_resource_context, version_resource_context }
import from lib.identity.repositories { LecturerRepository }
import from lib.identity.services { identity_now }
import from lib.learning_track.application_services { create_next_draft_service, create_track_service, publish_track_version_service, service_error }
import from lib.learning_track.course_management {
    archive_course_service, create_course_service, duplicate_course_service,
    get_course_service, list_courses_service, restore_course_service,
    update_configuration_service, update_course_service
}
import from lib.learning_track.repositories { repository_find_track }
import from lib.learning_track.repository_types { ActorContext, IdempotencyContext, ServiceResult }
import from nodes.authorization { AuthorizationActor, AuthorizationDecision, AuthorizationDecisionType, LecturerPermission }
import from nodes.learning_track {
    CreateCourseTrackInput, CreateLearningTrackInput, LearningTrack, LecturerCourseDetail,
    LearningTrackStatus, LearningTrackType, TrackOwnershipType,
    UpdateCourseTrackInput, UpdateTrackConfigurationInput
}

def _track_actor_context(actor: AuthorizationActor, request_id: str) -> ActorContext {
    return ActorContext(
        user_id=actor.user_id, request_id=request_id, learner_id=actor.learner_id,
        lecturer_id=actor.lecturer_id, roles=[str(role) for role in actor.active_roles]
    );
}

def _authorization_error(decision: AuthorizationDecision) -> ServiceResult {
    return service_error(public_error_code(decision), "The requested course operation is not permitted.");
}

def create_authorized_lecturer_track(input: CreateLearningTrackInput, idempotency_key: str, request_id: str = "") -> ServiceResult {
    actor = resolve_authorization_actor(); policy = AuthorizationPolicyService();
    decision = policy.authorize_lecturer_action(actor, LecturerPermission.CREATE_TRACK, None);
    if decision.decision == AuthorizationDecisionType.DENY { return _authorization_error(decision); }
    input.track_type = LearningTrackType.LECTURER_COURSE;
    input.ownership_type = TrackOwnershipType.LECTURER; input.owner_id = None;
    result = create_track_service(
        _track_actor_context(actor, request_id), input,
        IdempotencyContext(key=idempotency_key, operation="create-track", actor_id=actor.user_id, request_id=request_id)
    );
    if not result.ok or not isinstance(result.value, LearningTrack) { return result; }
    track = result.value as LearningTrack;
    profile = LecturerRepository().find_by_user_id(actor.user_id);
    if profile is None or actor.lecturer_id is None or track.owner_id != actor.lecturer_id { return service_error("COURSE_OWNER_IDENTITY_INVALID", "Course ownership could not be proven."); }
    if track not in [profile ->:OWNS_TRACK:->[?:LearningTrack]] { profile +>:OWNS_TRACK(granted_at=identity_now()):+> track; }
    final_context = track_resource_context(track.track_id, actor.lecturer_id);
    if final_context is None { return service_error("COURSE_OWNER_IDENTITY_INVALID", "Course ownership context is incomplete."); }
    final_decision = policy.authorize_lecturer_action(actor, LecturerPermission.EDIT_TRACK_METADATA, final_context);
    if final_decision.decision == AuthorizationDecisionType.DENY { return _authorization_error(final_decision); }
    return result;
}

def create_authorized_next_draft(track_id: str, change_summary: str = "", request_id: str = "") -> ServiceResult {
    actor = resolve_authorization_actor(); context = track_resource_context(track_id, actor.lecturer_id);
    if context is None { return service_error("TRACK_NOT_FOUND", "Learning track was not found."); }
    decision = AuthorizationPolicyService().authorize_lecturer_action(actor, LecturerPermission.CREATE_TRACK_VERSION, context);
    if decision.decision == AuthorizationDecisionType.DENY { return _authorization_error(decision); }
    result = create_next_draft_service(_track_actor_context(actor, request_id), track_id, change_summary);
    # Re-resolve state at the persistence boundary; callers must never rely on a stale decision.
    final_context = track_resource_context(track_id, actor.lecturer_id);
    if final_context is None { return service_error("TRACK_NOT_FOUND", "Learning track was not found."); }
    final_decision = AuthorizationPolicyService().authorize_lecturer_action(actor, LecturerPermission.VIEW_TRACK_VERSION, final_context);
    return result if final_decision.decision == AuthorizationDecisionType.ALLOW else _authorization_error(final_decision);
}

def publish_authorized_track_version(track_id: str, track_version_id: str, open_enrollment: bool, idempotency_key: str, request_id: str = "") -> ServiceResult {
    actor = resolve_authorization_actor(); context = version_resource_context(track_id, track_version_id, actor.lecturer_id);
    if context is None { return service_error("TRACK_NOT_FOUND", "Learning track was not found."); }
    decision = AuthorizationPolicyService().authorize_lecturer_action(actor, LecturerPermission.PUBLISH_VERSION, context);
    if decision.decision == AuthorizationDecisionType.DENY { return _authorization_error(decision); }
    # Publication service performs its own immediate version/status preflight.
    return publish_track_version_service(
        _track_actor_context(actor, request_id), track_id, track_version_id, open_enrollment,
        IdempotencyContext(key=idempotency_key, operation="publish-version", actor_id=actor.user_id, request_id=request_id)
    );
}

def create_authorized_course(input: CreateCourseTrackInput, request_id: str = "") -> ServiceResult {
    actor = resolve_authorization_actor();
    decision = AuthorizationPolicyService().authorize_lecturer_action(actor, LecturerPermission.CREATE_TRACK, None);
    if decision.decision == AuthorizationDecisionType.DENY { return _authorization_error(decision); }
    result = create_course_service(_track_actor_context(actor, request_id), input);
    if not result.ok { return result; }
    # Creation attaches trusted ownership after the aggregate exists.
    profile = LecturerRepository().find_by_user_id(actor.user_id);
    if profile is None or actor.lecturer_id is None { return service_error("LECTURER_PROFILE_REQUIRED", "An active lecturer profile is required."); }
    if not isinstance(result.value, LecturerCourseDetail) { return service_error("COURSE_AGGREGATE_INVALID", "Course projection is incomplete."); }
    detail = result.value as LecturerCourseDetail;
    candidate = repository_find_track(detail.track.track_id);
    if candidate is None or candidate.owner_id != actor.lecturer_id { return service_error("COURSE_AGGREGATE_INVALID", "Course ownership is incomplete."); }
    if candidate not in [profile ->:OWNS_TRACK:->[?:LearningTrack]] { profile +>:OWNS_TRACK(granted_at=identity_now()):+> candidate; }
    return result;
}

def _authorize_course(track_id: str, permission: LecturerPermission) -> tuple[AuthorizationActor, ServiceResult | None] {
    actor = resolve_authorization_actor(); context = track_resource_context(track_id, actor.lecturer_id);
    if context is None { return (actor, service_error("COURSE_NOT_FOUND", "Course was not found.")); }
    decision = AuthorizationPolicyService().authorize_lecturer_action(actor, permission, context);
    return (actor, None if decision.decision == AuthorizationDecisionType.ALLOW else _authorization_error(decision));
}

def get_authorized_course(track_id: str, request_id: str = "") -> ServiceResult {
    (actor, denied) = _authorize_course(track_id, LecturerPermission.VIEW_TRACK);
    return denied if denied is not None else get_course_service(_track_actor_context(actor, request_id), track_id);
}

def list_authorized_courses(status: LearningTrackStatus | None = None, search: str | None = None, subject_area: str | None = None, page_size: int = 20, cursor: str | None = None, sort: str = "updated_desc", request_id: str = "") -> ServiceResult {
    actor = resolve_authorization_actor(); decision = AuthorizationPolicyService().authorize_lecturer_action(actor, LecturerPermission.LIST_OWN_TRACKS, None);
    if decision.decision == AuthorizationDecisionType.DENY { return _authorization_error(decision); }
    return list_courses_service(_track_actor_context(actor, request_id), status, search, subject_area, page_size, cursor, sort);
}

def update_authorized_course(input: UpdateCourseTrackInput, request_id: str = "") -> ServiceResult {
    (actor, denied) = _authorize_course(input.track_id, LecturerPermission.EDIT_TRACK_METADATA);
    return denied if denied is not None else update_course_service(_track_actor_context(actor, request_id), input);
}

def update_authorized_configuration(input: UpdateTrackConfigurationInput, request_id: str = "") -> ServiceResult {
    (actor, denied) = _authorize_course(input.track_id, LecturerPermission.EDIT_TRACK_METADATA);
    return denied if denied is not None else update_configuration_service(_track_actor_context(actor, request_id), input);
}

def archive_authorized_course(track_id: str, expected_revision: int, reason: str | None = None, request_id: str = "") -> ServiceResult {
    (actor, denied) = _authorize_course(track_id, LecturerPermission.ARCHIVE_TRACK);
    return denied if denied is not None else archive_course_service(_track_actor_context(actor, request_id), track_id, expected_revision, reason);
}

def restore_authorized_course(track_id: str, expected_revision: int, request_id: str = "") -> ServiceResult {
    (actor, denied) = _authorize_course(track_id, LecturerPermission.RESTORE_TRACK);
    return denied if denied is not None else restore_course_service(_track_actor_context(actor, request_id), track_id, expected_revision);
}

def duplicate_authorized_course(track_id: str, client_request_id: str, request_id: str = "") -> ServiceResult {
    (actor, denied) = _authorize_course(track_id, LecturerPermission.VIEW_TRACK);
    return denied if denied is not None else duplicate_course_service(_track_actor_context(actor, request_id), track_id, client_request_id);
}
