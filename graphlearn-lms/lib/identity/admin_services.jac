"""Cross-root administrator operations for lecturer onboarding and capabilities."""

import os;
import from edges.domain_edges { HAS_LECTURER_PROFILE, HAS_ROLE_ASSIGNMENT, HAS_TRACK_ACCESS }
import from lib.identity.services { identity_now }
import from lib.learning_track.repositories { repository_find_track }
import from nodes.authorization { TrackAccessRole }
import from nodes.identity {
    AdminLecturerOperationResult, AdminLecturerView, LecturerProfile,
    LecturerProfileStatus, RoleAssignmentStatus, UserRoleAssignment, UserRoleType
}

def _target_root(user_id: str) -> any {
    try { return jobj(user_id); }
    except Exception { return None; }
}

def _target_profile(target: any, user_id: str) -> LecturerProfile | None {
    matches = [item for item in [target ->:HAS_LECTURER_PROFILE:->[?:LecturerProfile]] if item.user_id == user_id];
    return matches[0] if len(matches) == 1 else None;
}

def _lecturer_assignment(target: any, user_id: str) -> UserRoleAssignment | None {
    matches = [item for item in [target ->:HAS_ROLE_ASSIGNMENT:->[?:UserRoleAssignment]] if item.user_id == user_id and item.role_type == UserRoleType.LECTURER and item.status != RoleAssignmentStatus.REVOKED];
    return matches[0] if len(matches) == 1 else None;
}

def _view(profile: LecturerProfile, assignment: UserRoleAssignment) -> AdminLecturerView {
    return AdminLecturerView(user_id=profile.user_id, lecturer_id=profile.lecturer_id, display_name=profile.display_name, profile_status=profile.status, role_status=assignment.status, profile_completed=profile.profile_completed, can_create_courses=profile.can_create_courses, can_publish_courses=profile.can_publish_courses, can_review_grading=profile.can_review_grading);
}

def _error(operation: str, code: str, message: str) -> AdminLecturerOperationResult {
    return AdminLecturerOperationResult(ok=False, operation=operation, error_code=code, message=message);
}

def _administrator_can_write(profile: LecturerProfile, actor_user_id: str) -> bool {
    return actor_user_id.replace("-", "") in profile.admin_management_root_ids;
}

def list_pending_lecturers(limit: int = 50) -> list[AdminLecturerView] {
    bounded = min(100, max(1, limit)); results: list[AdminLecturerView] = [];
    for target in allroots() {
        if len(results) >= bounded { break; }
        user_id = jid(target); resolved = _target_root(user_id); profile = _target_profile(resolved, user_id) if resolved is not None else None; assignment = _lecturer_assignment(resolved, user_id) if resolved is not None else None;
        if profile is not None and assignment is not None and (profile.status == LecturerProfileStatus.PENDING_REVIEW or assignment.status == RoleAssignmentStatus.PENDING) { results.append(_view(profile, assignment)); }
    }
    return results;
}

def approve_lecturer_onboarding(target_user_id: str, actor_user_id: str, can_publish_courses: bool = False) -> AdminLecturerOperationResult {
    operation = "APPROVE_LECTURER_ONBOARDING"; target = _target_root(target_user_id);
    if target is None { return _error(operation, "LECTURER_IDENTITY_NOT_FOUND", "The target identity was not found."); }
    profile = _target_profile(target, target_user_id); assignment = _lecturer_assignment(target, target_user_id);
    if profile is None or assignment is None { return _error(operation, "LECTURER_ONBOARDING_NOT_FOUND", "A pending lecturer profile and role assignment are required."); }
    if not profile.profile_completed { return _error(operation, "LECTURER_PROFILE_INCOMPLETE", "The lecturer must complete onboarding before approval."); }
    if not _administrator_can_write(profile, actor_user_id) { return _error(operation, "APPLICATION_ADMIN_WRITE_ACCESS_REQUIRED", "The lecturer must authorize application administrator management first."); }
    timestamp = identity_now();
    if not assignment.activate_by_administrator(actor_user_id, timestamp) { return _error(operation, "ROLE_ACTIVATION_FAILED", "The lecturer role could not be activated."); }
    if not profile.activate_by_administrator(can_publish_courses, timestamp) { return _error(operation, "LECTURER_ACTIVATION_FAILED", "The lecturer profile could not be activated."); }
    if profile.status != LecturerProfileStatus.ACTIVE or assignment.status != RoleAssignmentStatus.ACTIVE { return _error(operation, "LECTURER_ACTIVATION_FAILED", "The lecturer did not reach an active state."); }
    return AdminLecturerOperationResult(ok=True, operation=operation, lecturer=_view(profile, assignment), message="Lecturer onboarding approved.");
}

def set_lecturer_capabilities(target_user_id: str, actor_user_id: str, can_publish_courses: bool) -> AdminLecturerOperationResult {
    operation = "SET_LECTURER_CAPABILITIES"; target = _target_root(target_user_id);
    if target is None { return _error(operation, "LECTURER_IDENTITY_NOT_FOUND", "The target identity was not found."); }
    profile = _target_profile(target, target_user_id); assignment = _lecturer_assignment(target, target_user_id);
    if profile is None or assignment is None { return _error(operation, "LECTURER_PROFILE_NOT_FOUND", "The lecturer profile was not found."); }
    if profile.status != LecturerProfileStatus.ACTIVE or assignment.status != RoleAssignmentStatus.ACTIVE { return _error(operation, "LECTURER_NOT_ACTIVE", "Capabilities can be granted only to an active lecturer."); }
    if not _administrator_can_write(profile, actor_user_id) { return _error(operation, "APPLICATION_ADMIN_WRITE_ACCESS_REQUIRED", "The lecturer must authorize application administrator management first."); }
    if not profile.set_capabilities_by_administrator(can_publish_courses, identity_now()) { return _error(operation, "LECTURER_CAPABILITY_UPDATE_FAILED", "Lecturer capabilities could not be updated."); }
    return AdminLecturerOperationResult(ok=True, operation=operation, lecturer=_view(profile, assignment), message="Lecturer capabilities updated.");
}

def grant_course_reviewer(target_user_id: str, track_id: str, actor_user_id: str, expires_at: str | None = None) -> AdminLecturerOperationResult {
    operation = "GRANT_COURSE_REVIEWER"; target = _target_root(target_user_id); track = repository_find_track(track_id);
    if target is None { return _error(operation, "LECTURER_IDENTITY_NOT_FOUND", "The target identity was not found."); }
    if track is None { return _error(operation, "TRACK_NOT_FOUND", "The course was not found."); }
    profile = _target_profile(target, target_user_id); assignment = _lecturer_assignment(target, target_user_id);
    if profile is None or assignment is None or profile.status != LecturerProfileStatus.ACTIVE or assignment.status != RoleAssignmentStatus.ACTIVE { return _error(operation, "LECTURER_NOT_ACTIVE", "Reviewer access requires an active lecturer."); }
    if track.owner_id == profile.lecturer_id { return _error(operation, "REVIEWER_MUST_BE_INDEPENDENT", "The course owner cannot be assigned as its reviewer."); }
    now = identity_now();
    for access in [edge profile ->:HAS_TRACK_ACCESS:-> track] { if access.revoked_at is None { access.revoked_at = now; } }
    profile +>:HAS_TRACK_ACCESS(access_role=TrackAccessRole.REVIEWER, granted_by=actor_user_id, granted_at=now, expires_at=expires_at):+> track;
    return AdminLecturerOperationResult(ok=True, operation=operation, lecturer=_view(profile, assignment), track_id=track.track_id, access_role="REVIEWER", message="Course reviewer access granted.");
}

def revoke_course_reviewer(target_user_id: str, track_id: str) -> AdminLecturerOperationResult {
    operation = "REVOKE_COURSE_REVIEWER"; target = _target_root(target_user_id); track = repository_find_track(track_id);
    if target is None or track is None { return _error(operation, "RESOURCE_NOT_FOUND", "The lecturer or course was not found."); }
    profile = _target_profile(target, target_user_id); assignment = _lecturer_assignment(target, target_user_id);
    if profile is None or assignment is None { return _error(operation, "LECTURER_PROFILE_NOT_FOUND", "The lecturer profile was not found."); }
    revoked = False; now = identity_now();
    for access in [edge profile ->:HAS_TRACK_ACCESS:-> track] { if access.access_role == TrackAccessRole.REVIEWER and access.revoked_at is None { access.revoked_at = now; revoked = True; } }
    if not revoked { return _error(operation, "REVIEWER_ACCESS_NOT_FOUND", "No active reviewer grant was found."); }
    return AdminLecturerOperationResult(ok=True, operation=operation, lecturer=_view(profile, assignment), track_id=track.track_id, access_role="REVIEWER", message="Course reviewer access revoked.");
}
