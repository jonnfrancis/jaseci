"""Identity, role-management, lecturer-profile, and onboarding services."""

import os;
import from datetime { datetime, timezone }
import from uuid { uuid4 }
import from edges.domain_edges { HAS_LEARNER_PROFILE }
import from lib.identity.repositories { IdentityRepository, LecturerRepository }
import from lib.observability.events { ObservabilityEvent }
import from lib.observability.logger { emit_event }
import from nodes.identity {
    AuthenticatedActor, IdentityError, IdentityResult, LecturerProfile,
    LecturerProfileInput, LecturerProfileStatus, LecturerProfileSummary,
    LecturerVerificationStatus, RoleAssignmentResult, RoleAssignmentSource,
    RoleAssignmentStatus, UserRoleAssignment, UserRoleType
}
import from nodes.learner { Learner }

def identity_now -> str { return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"); }
def identity_id(prefix: str) -> str { return prefix + "_" + str(uuid4()).replace("-", ""); }
def identity_error(code: str, message: str, details: dict[str, str] | None = None) -> IdentityResult {
    return IdentityResult(ok=False, error=IdentityError(code=code, message=message, details=details if details is not None else {}));
}

def _emit(event: str, status: str, user_id: str, attributes: dict[str, object] | None = None) {
    emit_event(ObservabilityEvent(
        timestamp=identity_now(), level="info", event=event, status=status,
        message=event, request_id="", correlation_id="",
        entity_ids={"user_id": user_id}, attributes=attributes if attributes is not None else {}
    ));
}

def profile_summary(profile: LecturerProfile) -> LecturerProfileSummary {
    return LecturerProfileSummary(
        lecturer_id=profile.lecturer_id, display_name=profile.display_name,
        professional_title=profile.professional_title,
        institution_name=profile.institution_name, department=profile.department,
        areas_of_expertise=profile.areas_of_expertise.copy(), status=profile.status,
        biography=profile.biography, staff_number=profile.staff_number,
        verification_status=profile.verification_status,
        profile_completed=profile.profile_completed
    );
}

def assignment_result(assignment: UserRoleAssignment) -> RoleAssignmentResult {
    return RoleAssignmentResult(
        role_assignment_id=assignment.role_assignment_id, user_id=assignment.user_id,
        role_type=assignment.role_type, status=assignment.status, source=assignment.source
    );
}

def has_active_role(actor: AuthenticatedActor, role: UserRoleType) -> bool { return role in actor.active_roles; }

def resolve_authenticated_actor() -> IdentityResult {
    user_id = jid(root);
    if user_id.strip() == "" { return identity_error("AUTHENTICATION_REQUIRED", "Authentication is required."); }
    repository = IdentityRepository();
    assignments = repository.list_role_assignments(user_id);
    active_roles: list[UserRoleType] = [];
    for assignment in assignments {
        if assignment.user_id != user_id { _emit("identity.graph_invalid", "failed", user_id); return identity_error("IDENTITY_GRAPH_INVALID", "Identity graph is inconsistent."); }
        if assignment.status == RoleAssignmentStatus.ACTIVE {
            if assignment.role_type in active_roles { _emit("identity.graph_invalid", "failed", user_id); return identity_error("IDENTITY_GRAPH_INVALID", "Duplicate active role assignments were found."); }
            active_roles.append(assignment.role_type);
        }
    }
    learner = repository.find_learner_profile(user_id);
    lecturer = repository.find_lecturer_profile(user_id);
    if len([root ->:HAS_LEARNER_PROFILE:->[?:Learner]]) > 1 { return identity_error("IDENTITY_GRAPH_INVALID", "Multiple learner profiles are connected to this identity."); }
    if len([root ->:HAS_LEARNER_PROFILE:->[?:Learner]]) == 1 and learner is None { return identity_error("IDENTITY_GRAPH_INVALID", "Learner ownership does not match the authenticated identity."); }
    if lecturer is not None {
        if lecturer.status == LecturerProfileStatus.ACTIVE and UserRoleType.LECTURER not in active_roles { return identity_error("IDENTITY_GRAPH_INVALID", "An active lecturer profile requires an active lecturer role."); }
        if lecturer.status in [LecturerProfileStatus.SUSPENDED, LecturerProfileStatus.ARCHIVED] and (lecturer.can_create_courses or lecturer.can_publish_courses or lecturer.can_review_grading) { return identity_error("IDENTITY_GRAPH_INVALID", "Inactive lecturer profiles cannot retain capabilities."); }
    }
    resolved_lecturer_id: str | None = None;
    if lecturer is not None { resolved_lecturer_id = (lecturer as LecturerProfile).lecturer_id; }
    actor = AuthenticatedActor(
        user_id=user_id, active_roles=active_roles,
        learner_id=learner.id if learner is not None else None,
        lecturer_id=resolved_lecturer_id,
        is_authenticated=True
    );
    _emit("identity.actor_resolved", "success", user_id);
    return IdentityResult(ok=True, actor=actor);
}

def require_active_role(actor: AuthenticatedActor, role: UserRoleType) -> IdentityResult {
    if not has_active_role(actor, role) { return identity_error("ROLE_NOT_ACTIVE", "The required role is not active."); }
    return IdentityResult(ok=True, actor=actor);
}

def require_lecturer_actor(actor: AuthenticatedActor) -> IdentityResult {
    if not has_active_role(actor, UserRoleType.LECTURER) { return identity_error("LECTURER_ROLE_REQUIRED", "An active lecturer role is required."); }
    profile = LecturerRepository().find_by_user_id(actor.user_id);
    if profile is None { return identity_error("LECTURER_PROFILE_NOT_FOUND", "Lecturer profile was not found."); }
    if profile.status == LecturerProfileStatus.SUSPENDED { return identity_error("LECTURER_PROFILE_SUSPENDED", "This lecturer profile is currently suspended.", {"lecturer_id": profile.lecturer_id}); }
    if profile.status == LecturerProfileStatus.ARCHIVED { return identity_error("LECTURER_PROFILE_ARCHIVED", "This lecturer profile is archived."); }
    if profile.status != LecturerProfileStatus.ACTIVE { return identity_error("LECTURER_PROFILE_NOT_ACTIVE", "This lecturer profile is not active."); }
    return IdentityResult(ok=True, actor=actor, profile=profile_summary(profile));
}

def require_admin_actor(actor: AuthenticatedActor) -> IdentityResult {
    if not has_active_role(actor, UserRoleType.ADMIN) { return identity_error("ADMIN_ROLE_REQUIRED", "An active administrator role is required."); }
    return IdentityResult(ok=True, actor=actor);
}

def assign_role(role_type: UserRoleType, source: RoleAssignmentSource, granted_by: str | None = None, active: bool = False) -> IdentityResult {
    user_id = jid(root);
    repository = IdentityRepository();
    for existing in repository.list_role_assignments(user_id) {
        if existing.role_type == role_type and existing.status != RoleAssignmentStatus.REVOKED {
            if existing.status == RoleAssignmentStatus.ACTIVE { return identity_error("ROLE_ALREADY_ACTIVE", "The role is already active."); }
            return identity_error("ROLE_ASSIGNMENT_CONFLICT", "A non-terminal role assignment already exists.");
        }
    }
    timestamp = identity_now();
    assignment = UserRoleAssignment(
        role_assignment_id=identity_id("role"), user_id=user_id, role_type=role_type,
        source=source, created_at=timestamp, updated_at=timestamp,
        status=RoleAssignmentStatus.ACTIVE if active else RoleAssignmentStatus.PENDING,
        granted_by=granted_by, activated_at=timestamp if active else None
    );
    repository.save_role_assignment(assignment);
    _emit("role.assigned", "success", user_id, {"role_type": str(role_type), "assignment_id": assignment.role_assignment_id});
    return IdentityResult(ok=True, assignment=assignment_result(assignment));
}

def transition_role(assignment: UserRoleAssignment, target: RoleAssignmentStatus, actor_user_id: str) -> IdentityResult {
    current = assignment.status;
    valid = (current == RoleAssignmentStatus.PENDING and target in [RoleAssignmentStatus.ACTIVE, RoleAssignmentStatus.SUSPENDED, RoleAssignmentStatus.REVOKED]) or (current == RoleAssignmentStatus.ACTIVE and target in [RoleAssignmentStatus.SUSPENDED, RoleAssignmentStatus.REVOKED]) or (current == RoleAssignmentStatus.SUSPENDED and target in [RoleAssignmentStatus.ACTIVE, RoleAssignmentStatus.REVOKED]);
    if not valid { return identity_error("INVALID_ROLE_STATUS_TRANSITION", "The role status transition is not allowed."); }
    timestamp = identity_now();
    assignment.status = target; assignment.updated_at = timestamp;
    if target == RoleAssignmentStatus.ACTIVE { assignment.activated_at = timestamp; }
    elif target == RoleAssignmentStatus.SUSPENDED { assignment.suspended_at = timestamp; }
    elif target == RoleAssignmentStatus.REVOKED { assignment.revoked_at = timestamp; }
    event = "role.activated" if target == RoleAssignmentStatus.ACTIVE else ("role.suspended" if target == RoleAssignmentStatus.SUSPENDED else "role.revoked");
    _emit(event, "success", assignment.user_id, {"actor_user_id": actor_user_id, "old_status": str(current), "new_status": str(target)});
    return IdentityResult(ok=True, assignment=assignment_result(assignment));
}

def calculate_lecturer_profile_completion(profile: LecturerProfile) -> bool {
    return profile.display_name.strip() != "" and profile.institution_name is not None and profile.institution_name.strip() != "" and len(profile.areas_of_expertise) > 0;
}

def create_draft_lecturer_profile(display_name: str = "") -> IdentityResult {
    user_id = jid(root); repository = LecturerRepository();
    existing = repository.find_by_user_id(user_id);
    if existing is not None { return IdentityResult(ok=True, profile=profile_summary(existing), replayed=True); }
    timestamp = identity_now();
    profile = LecturerProfile(
        lecturer_id=identity_id("lec"), user_id=user_id,
        display_name=display_name.strip(), created_at=timestamp, updated_at=timestamp,
        verification_status=LecturerVerificationStatus.NOT_REQUIRED
    );
    profile.profile_completed = calculate_lecturer_profile_completion(profile);
    repository.save(profile);
    _emit("lecturer_profile.created", "success", user_id, {"lecturer_id": profile.lecturer_id});
    return IdentityResult(ok=True, profile=profile_summary(profile));
}

def update_lecturer_profile(input: LecturerProfileInput) -> IdentityResult {
    profile = LecturerRepository().find_by_user_id(jid(root));
    if profile is None { return identity_error("LECTURER_PROFILE_NOT_FOUND", "Lecturer profile was not found."); }
    if profile.status == LecturerProfileStatus.ARCHIVED { return identity_error("LECTURER_PROFILE_ARCHIVED", "This lecturer profile is archived."); }
    normalized: list[str] = [];
    for value in input.areas_of_expertise {
        clean = value.strip();
        if clean != "" and clean not in normalized and len(normalized) < 20 { normalized.append(clean); }
    }
    profile.display_name = input.display_name.strip()[:120];
    profile.professional_title = input.professional_title.strip()[:120] if input.professional_title is not None else None;
    profile.institution_name = input.institution_name.strip()[:160] if input.institution_name is not None else None;
    profile.department = input.department.strip()[:160] if input.department is not None else None;
    profile.biography = input.biography.strip()[:4000];
    profile.areas_of_expertise = normalized;
    profile.staff_number = input.staff_number.strip()[:120] if input.staff_number is not None else None;
    profile.profile_completed = calculate_lecturer_profile_completion(profile);
    profile.updated_at = identity_now();
    _emit("lecturer_profile.updated", "success", profile.user_id, {"lecturer_id": profile.lecturer_id});
    return IdentityResult(ok=True, profile=profile_summary(profile));
}

def transition_lecturer_profile(profile: LecturerProfile, target: LecturerProfileStatus, actor_user_id: str) -> IdentityResult {
    current = profile.status;
    valid = (current == LecturerProfileStatus.DRAFT and target in [LecturerProfileStatus.PENDING_REVIEW, LecturerProfileStatus.ACTIVE, LecturerProfileStatus.REJECTED, LecturerProfileStatus.ARCHIVED]) or (current == LecturerProfileStatus.PENDING_REVIEW and target in [LecturerProfileStatus.ACTIVE, LecturerProfileStatus.REJECTED, LecturerProfileStatus.DRAFT, LecturerProfileStatus.ARCHIVED]) or (current == LecturerProfileStatus.ACTIVE and target in [LecturerProfileStatus.SUSPENDED, LecturerProfileStatus.ARCHIVED]) or (current == LecturerProfileStatus.SUSPENDED and target in [LecturerProfileStatus.ACTIVE, LecturerProfileStatus.ARCHIVED]) or (current == LecturerProfileStatus.REJECTED and target in [LecturerProfileStatus.DRAFT, LecturerProfileStatus.ARCHIVED]);
    if not valid { return identity_error("INVALID_LECTURER_STATUS_TRANSITION", "The lecturer profile status transition is not allowed."); }
    if target == LecturerProfileStatus.ACTIVE and not profile.profile_completed { return identity_error("LECTURER_PROFILE_INCOMPLETE", "Complete the lecturer profile before activation."); }
    timestamp = identity_now(); profile.status = target; profile.updated_at = timestamp;
    if target == LecturerProfileStatus.ACTIVE {
        profile.activated_at = timestamp; profile.suspended_at = None;
        profile.can_create_courses = True;
        profile.can_publish_courses = os.getenv("LECTURER_CAN_PUBLISH", "false").strip().lower() in ["1", "true", "yes", "on"];
        profile.can_review_grading = True;
    } else {
        profile.can_create_courses = False; profile.can_publish_courses = False; profile.can_review_grading = False;
        if target == LecturerProfileStatus.SUSPENDED { profile.suspended_at = timestamp; }
        if target == LecturerProfileStatus.ARCHIVED { profile.archived_at = timestamp; }
    }
    event = "lecturer_profile.activated" if target == LecturerProfileStatus.ACTIVE else "lecturer_profile." + str(target).lower();
    _emit(event, "success", profile.user_id, {"actor_user_id": actor_user_id, "old_status": str(current), "new_status": str(target)});
    return IdentityResult(ok=True, profile=profile_summary(profile));
}

def request_lecturer_onboarding(display_name: str = "") -> IdentityResult {
    mode = os.getenv("LECTURER_ONBOARDING_MODE", "ADMIN_APPROVAL").strip().upper();
    if mode == "INVITATION_ONLY" { return identity_error("ROLE_ASSIGNMENT_FORBIDDEN", "Lecturer onboarding requires an invitation."); }
    profile_result = create_draft_lecturer_profile(display_name);
    if not profile_result.ok { return profile_result; }
    repository = IdentityRepository(); user_id = jid(root);
    assignment: UserRoleAssignment | None = None;
    for item in repository.list_role_assignments(user_id) {
        if item.role_type == UserRoleType.LECTURER and item.status != RoleAssignmentStatus.REVOKED { assignment = item; break; }
    }
    if assignment is None {
        assigned = assign_role(UserRoleType.LECTURER, RoleAssignmentSource.REGISTRATION, active=False);
        if not assigned.ok { return assigned; }
    }
    profile = repository.find_lecturer_profile(user_id);
    if profile is None { return identity_error("LECTURER_PROFILE_NOT_FOUND", "Lecturer profile was not found."); }
    _emit("role.requested", "success", user_id);
    return IdentityResult(ok=True, profile=profile_summary(profile), replayed=profile_result.replayed);
}

def submit_lecturer_onboarding() -> IdentityResult {
    mode = os.getenv("LECTURER_ONBOARDING_MODE", "ADMIN_APPROVAL").strip().upper();
    if mode == "INVITATION_ONLY" { return identity_error("LECTURER_ONBOARDING_NOT_AVAILABLE", "Lecturer onboarding requires an invitation."); }
    user_id = jid(root); repository = IdentityRepository();
    profile = repository.find_lecturer_profile(user_id);
    if profile is None { return identity_error("LECTURER_PROFILE_NOT_FOUND", "Lecturer profile was not found."); }
    if profile.status in [LecturerProfileStatus.PENDING_REVIEW, LecturerProfileStatus.ACTIVE] {
        return IdentityResult(ok=True, profile=profile_summary(profile), replayed=True);
    }
    if profile.status == LecturerProfileStatus.REJECTED {
        reopened = transition_lecturer_profile(profile, LecturerProfileStatus.DRAFT, user_id);
        if not reopened.ok { return reopened; }
    }
    if profile.status != LecturerProfileStatus.DRAFT { return identity_error("LECTURER_ONBOARDING_NOT_AVAILABLE", "This lecturer profile cannot be submitted."); }
    if not profile.profile_completed { return identity_error("LECTURER_PROFILE_INCOMPLETE", "Display name, institution, and at least one expertise area are required."); }
    assignment: UserRoleAssignment | None = None;
    for item in repository.list_role_assignments(user_id) {
        if item.role_type == UserRoleType.LECTURER and item.status != RoleAssignmentStatus.REVOKED { assignment = item; break; }
    }
    if assignment is None { return identity_error("ROLE_ASSIGNMENT_NOT_FOUND", "Lecturer onboarding was not started."); }
    if mode == "DEVELOPMENT_AUTO_ACTIVATE" {
        if assignment.status == RoleAssignmentStatus.PENDING {
            role_result = transition_role(assignment, RoleAssignmentStatus.ACTIVE, user_id);
            if not role_result.ok { return role_result; }
        }
        result = transition_lecturer_profile(profile, LecturerProfileStatus.ACTIVE, user_id);
        if result.ok { _emit("lecturer_onboarding.activated", "success", user_id, {"lecturer_id": profile.lecturer_id}); }
        return result;
    }
    result = transition_lecturer_profile(profile, LecturerProfileStatus.PENDING_REVIEW, user_id);
    if result.ok { _emit("lecturer_onboarding.pending", "success", user_id, {"lecturer_id": profile.lecturer_id}); }
    return result;
}

def resolve_course_owner_identity(actor: AuthenticatedActor) -> IdentityResult {
    validated = require_lecturer_actor(actor);
    if not validated.ok { return validated; }
    profile = LecturerRepository().find_by_user_id(actor.user_id);
    if profile is None or not profile.can_create_courses { return identity_error("COURSE_OWNER_IDENTITY_INVALID", "The lecturer cannot own a new course."); }
    return validated;
}
