"""Central default-deny authorization policy and trusted actor resolver."""

import os;
import from datetime { datetime, timezone }
import from uuid { uuid4 }
import from lib.authorization.metrics { record_authorization, record_owner_scalar_fallback }
import from lib.observability.events { ObservabilityEvent }
import from lib.observability.logger { emit_event }
import from nodes.authorization {
    AdministrativePermission, AuthorizationActor, AuthorizationAuditEvent,
    AuthorizationDecision, AuthorizationDecisionType, AuthorizationReasonCode,
    AuthorizationResourceContext, AuthorizationScope, LecturerPermission, TrackAccessRole
}
import from nodes.identity { LecturerProfileStatus, UserRoleType }
import from nodes.learning_track { LearningTrackStatus, TrackOwnershipType, TrackVersionStatus }

glob AUTHORIZATION_AUDIT_EVENTS: list[AuthorizationAuditEvent] = [];

def authorization_now -> str { return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"); }

def is_authenticated(actor: AuthorizationActor) -> bool { return actor.is_authenticated and actor.user_id.strip() != ""; }
def has_active_role(actor: AuthorizationActor, role: UserRoleType) -> bool { return role in actor.active_roles; }
def has_active_lecturer_profile(actor: AuthorizationActor) -> bool {
    return has_active_role(actor, UserRoleType.LECTURER) and actor.lecturer_id is not None and actor.lecturer_status == LecturerProfileStatus.ACTIVE;
}
def has_admin_permission(actor: AuthorizationActor, permission: AdministrativePermission) -> bool {
    return has_active_role(actor, UserRoleType.ADMIN) and permission in actor.admin_permissions;
}

def _audit(actor: AuthorizationActor, decision: AuthorizationDecision, resource: AuthorizationResourceContext | None) {
    global AUTHORIZATION_AUDIT_EVENTS;
    if decision.decision == AuthorizationDecisionType.DENY and os.getenv("AUTHORIZATION_AUDIT_DENIES", "true").strip().lower() not in ["1", "true", "yes", "on"] { return; }
    item = AuthorizationAuditEvent(
        audit_id="authz_" + str(uuid4()).replace("-", ""), actor_user_id=actor.user_id or None,
        actor_lecturer_id=actor.lecturer_id, permission=decision.permission,
        decision=decision.decision, reason_code=decision.reason_code,
        resource_type=resource.resource_type if resource is not None else None,
        resource_id=resource.resource_id if resource is not None else None,
        track_id=resource.track_id if resource is not None else None,
        track_version_id=resource.track_version_id if resource is not None else None,
        occurred_at=authorization_now()
    );
    AUTHORIZATION_AUDIT_EVENTS.append(item);
    emit_event(ObservabilityEvent(
        timestamp=item.occurred_at, level="info" if decision.decision == AuthorizationDecisionType.ALLOW else "warn",
        event="authorization.decision", status=str(decision.decision), message="Authorization policy evaluated.",
        request_id="", correlation_id="", error_code="" if decision.decision == AuthorizationDecisionType.ALLOW else str(decision.reason_code),
        entity_ids={"actor_user_id": actor.user_id, "resource_id": item.resource_id or "", "track_id": item.track_id or ""},
        attributes={"permission": decision.permission, "reason_code": str(decision.reason_code)}
    ));
}

def _decision(actor: AuthorizationActor, permission: str, allowed: bool, reason: AuthorizationReasonCode, message: str, scope: AuthorizationScope | None = None, resource: AuthorizationResourceContext | None = None) -> AuthorizationDecision {
    decision = AuthorizationDecision(
        decision=AuthorizationDecisionType.ALLOW if allowed else AuthorizationDecisionType.DENY,
        permission=permission, scope=scope, reason_code=AuthorizationReasonCode.ALLOWED if allowed else reason,
        message=message, actor_id=actor.user_id or None,
        resource_type=resource.resource_type if resource is not None else None,
        resource_id=resource.resource_id if resource is not None else None,
        evaluated_at=authorization_now()
    );
    record_authorization(allowed); _audit(actor, decision, resource); return decision;
}

def _deny(actor: AuthorizationActor, permission: str, reason: AuthorizationReasonCode, message: str, resource: AuthorizationResourceContext | None = None) -> AuthorizationDecision {
    return _decision(actor, permission, False, reason, message, resource=resource);
}

def _allow(actor: AuthorizationActor, permission: str, scope: AuthorizationScope, resource: AuthorizationResourceContext | None = None) -> AuthorizationDecision {
    return _decision(actor, permission, True, AuthorizationReasonCode.ALLOWED, "Permission granted.", scope, resource);
}

def _profile_denial(actor: AuthorizationActor, permission: str, resource: AuthorizationResourceContext | None = None) -> AuthorizationDecision | None {
    if not is_authenticated(actor) { return _deny(actor, permission, AuthorizationReasonCode.AUTHENTICATION_REQUIRED, "Authentication is required.", resource); }
    if not has_active_role(actor, UserRoleType.LECTURER) { return _deny(actor, permission, AuthorizationReasonCode.ROLE_REQUIRED, "An active lecturer role is required.", resource); }
    if actor.lecturer_id is None or actor.lecturer_status is None { return _deny(actor, permission, AuthorizationReasonCode.LECTURER_PROFILE_REQUIRED, "A lecturer profile is required.", resource); }
    if actor.lecturer_status == LecturerProfileStatus.SUSPENDED { return _deny(actor, permission, AuthorizationReasonCode.LECTURER_PROFILE_SUSPENDED, "The lecturer profile is suspended.", resource); }
    if actor.lecturer_status == LecturerProfileStatus.ARCHIVED { return _deny(actor, permission, AuthorizationReasonCode.LECTURER_PROFILE_ARCHIVED, "The lecturer profile is archived.", resource); }
    if actor.lecturer_status != LecturerProfileStatus.ACTIVE { return _deny(actor, permission, AuthorizationReasonCode.LECTURER_PROFILE_PENDING, "The lecturer profile is not active.", resource); }
    return None;
}

def owns_track(actor: AuthorizationActor, resource: AuthorizationResourceContext) -> bool {
    if resource.ownership_conflict or actor.lecturer_id is None or resource.owner_lecturer_id != actor.lecturer_id { return False; }
    if resource.ownership_edge_exists { return True; }
    if os.getenv("ALLOW_OWNER_SCALAR_FALLBACK", "false").strip().lower() in ["1", "true", "yes", "on"] {
        record_owner_scalar_fallback(); return True;
    }
    return False;
}

def has_track_assignment(resource: AuthorizationResourceContext, roles: list[TrackAccessRole]) -> bool {
    return resource.access_role is not None and resource.access_role in roles;
}

def _resource_access(actor: AuthorizationActor, permission: str, resource: AuthorizationResourceContext, owner: bool) -> AuthorizationDecision | None {
    if resource.ownership_conflict { return _deny(actor, permission, AuthorizationReasonCode.RESOURCE_OWNERSHIP_MISMATCH, "Resource ownership is inconsistent.", resource); }
    if resource.owner_lecturer_id is None { return _deny(actor, permission, AuthorizationReasonCode.RESOURCE_OWNERSHIP_REQUIRED, "Lecturer ownership is required.", resource); }
    if owner { return None; }
    if has_track_assignment(resource, [TrackAccessRole.EDITOR, TrackAccessRole.REVIEWER, TrackAccessRole.VIEWER]) { return None; }
    return _deny(actor, permission, AuthorizationReasonCode.RESOURCE_OWNERSHIP_REQUIRED, "The resource is outside the actor's authorized scope.", resource);
}

def _is_version_permission(permission: LecturerPermission) -> bool {
    return permission in [LecturerPermission.CREATE_TRACK_VERSION, LecturerPermission.VIEW_TRACK_VERSION, LecturerPermission.EDIT_DRAFT_VERSION, LecturerPermission.SUBMIT_VERSION_FOR_REVIEW, LecturerPermission.APPROVE_VERSION, LecturerPermission.PUBLISH_VERSION, LecturerPermission.SUPERSEDE_VERSION, LecturerPermission.UPLOAD_COURSE_DOCUMENT, LecturerPermission.VIEW_COURSE_DOCUMENT, LecturerPermission.DELETE_DRAFT_DOCUMENT, LecturerPermission.PROCESS_COURSE_DOCUMENT, LecturerPermission.VIEW_BLUEPRINT, LecturerPermission.EDIT_BLUEPRINT, LecturerPermission.APPROVE_BLUEPRINT, LecturerPermission.REGENERATE_BLUEPRINT_SECTION];
}

obj AuthorizationPolicyService {
    def authorize_lecturer_action(actor: AuthorizationActor, permission: LecturerPermission, resource: AuthorizationResourceContext | None) -> AuthorizationDecision {
        permission_name = str(permission);
        if permission in [LecturerPermission.VIEW_OWN_PROFILE, LecturerPermission.EDIT_OWN_PROFILE] {
            if not is_authenticated(actor) { return _deny(actor, permission_name, AuthorizationReasonCode.AUTHENTICATION_REQUIRED, "Authentication is required.", resource); }
            if actor.lecturer_id is None or actor.lecturer_status is None { return _deny(actor, permission_name, AuthorizationReasonCode.LECTURER_PROFILE_REQUIRED, "A lecturer profile is required.", resource); }
            if permission == LecturerPermission.VIEW_OWN_PROFILE { return _allow(actor, permission_name, AuthorizationScope.SELF, resource); }
            if actor.lecturer_status in [LecturerProfileStatus.SUSPENDED, LecturerProfileStatus.ARCHIVED] { return _deny(actor, permission_name, AuthorizationReasonCode.ROLE_INACTIVE, "This lecturer profile cannot be edited.", resource); }
            return _allow(actor, permission_name, AuthorizationScope.SELF, resource);
        }
        profile_denial = _profile_denial(actor, permission_name, resource);
        if profile_denial is not None { return profile_denial; }
        if permission == LecturerPermission.CREATE_TRACK {
            return _allow(actor, permission_name, AuthorizationScope.SELF) if actor.can_create_courses else _deny(actor, permission_name, AuthorizationReasonCode.ROLE_INACTIVE, "Course creation capability is disabled.");
        }
        if permission == LecturerPermission.LIST_OWN_TRACKS { return _allow(actor, permission_name, AuthorizationScope.OWNED_TRACK); }
        if resource is None { return _deny(actor, permission_name, AuthorizationReasonCode.POLICY_CONTEXT_INVALID, "A trusted resource context is required."); }
        if resource.track_id is None { return _deny(actor, permission_name, AuthorizationReasonCode.POLICY_CONTEXT_INVALID, "Track context is missing.", resource); }
        if resource.track_ownership_type == TrackOwnershipType.SYSTEM { return _deny(actor, permission_name, AuthorizationReasonCode.RESOURCE_OWNERSHIP_REQUIRED, "System tracks are outside lecturer-owner scope.", resource); }
        owner = owns_track(actor, resource);
        access_denial = _resource_access(actor, permission_name, resource, owner);
        if access_denial is not None { return access_denial; }
        access_role = TrackAccessRole.OWNER if owner else resource.access_role;
        scope = AuthorizationScope.OWNED_TRACK if owner else AuthorizationScope.ASSIGNED_TRACK;
        if resource.track_status == LearningTrackStatus.ARCHIVED {
            if permission in [LecturerPermission.VIEW_TRACK, LecturerPermission.VIEW_TRACK_VERSION, LecturerPermission.VIEW_TRACK_AUDIT_LOG] { return _allow(actor, permission_name, scope, resource); }
            if permission == LecturerPermission.RESTORE_TRACK and owner { return _allow(actor, permission_name, scope, resource); }
            return _deny(actor, permission_name, AuthorizationReasonCode.TRACK_ARCHIVED, "Archived tracks cannot be changed.", resource);
        }
        if _is_version_permission(permission) and not resource.version_belongs_to_track { return _deny(actor, permission_name, AuthorizationReasonCode.VERSION_TRACK_MISMATCH, "The version does not belong to the track.", resource); }
        if resource.version_status in [TrackVersionStatus.PUBLISHED, TrackVersionStatus.SUPERSEDED] and permission in [LecturerPermission.EDIT_DRAFT_VERSION, LecturerPermission.UPLOAD_COURSE_DOCUMENT, LecturerPermission.DELETE_DRAFT_DOCUMENT, LecturerPermission.PROCESS_COURSE_DOCUMENT, LecturerPermission.EDIT_BLUEPRINT, LecturerPermission.APPROVE_BLUEPRINT, LecturerPermission.REGENERATE_BLUEPRINT_SECTION] {
            return _deny(actor, permission_name, AuthorizationReasonCode.VERSION_IMMUTABLE, "Published and superseded versions are immutable.", resource);
        }
        if permission in [LecturerPermission.VIEW_TRACK, LecturerPermission.VIEW_TRACK_VERSION, LecturerPermission.VIEW_COURSE_DOCUMENT, LecturerPermission.VIEW_BLUEPRINT, LecturerPermission.VIEW_TRACK_AUDIT_LOG] { return _allow(actor, permission_name, scope, resource); }
        if permission == LecturerPermission.EDIT_TRACK_METADATA {
            if access_role not in [TrackAccessRole.OWNER, TrackAccessRole.EDITOR] { return _deny(actor, permission_name, AuthorizationReasonCode.RESOURCE_OWNERSHIP_REQUIRED, "Metadata editing requires owner or editor access.", resource); }
            return _allow(actor, permission_name, scope, resource) if resource.track_status in [LearningTrackStatus.DRAFT, LearningTrackStatus.PROCESSING, LearningTrackStatus.REVIEW_REQUIRED, LearningTrackStatus.FAILED] else _deny(actor, permission_name, AuthorizationReasonCode.TRACK_NOT_EDITABLE, "The track is not editable.", resource);
        }
        if permission == LecturerPermission.ARCHIVE_TRACK { return _allow(actor, permission_name, scope, resource) if owner else _deny(actor, permission_name, AuthorizationReasonCode.RESOURCE_OWNERSHIP_REQUIRED, "Only the owner may archive the track.", resource); }
        if permission == LecturerPermission.RESTORE_TRACK { return _allow(actor, permission_name, scope, resource) if owner else _deny(actor, permission_name, AuthorizationReasonCode.RESOURCE_OWNERSHIP_REQUIRED, "Only the owner may restore the track.", resource); }
        if permission in [LecturerPermission.CREATE_TRACK_VERSION, LecturerPermission.EDIT_DRAFT_VERSION, LecturerPermission.SUBMIT_VERSION_FOR_REVIEW, LecturerPermission.UPLOAD_COURSE_DOCUMENT, LecturerPermission.DELETE_DRAFT_DOCUMENT, LecturerPermission.PROCESS_COURSE_DOCUMENT, LecturerPermission.EDIT_BLUEPRINT, LecturerPermission.REGENERATE_BLUEPRINT_SECTION] {
            if access_role not in [TrackAccessRole.OWNER, TrackAccessRole.EDITOR] { return _deny(actor, permission_name, AuthorizationReasonCode.RESOURCE_OWNERSHIP_REQUIRED, "Draft editing requires owner or editor access.", resource); }
            if resource.version_status is not None and resource.version_status not in [TrackVersionStatus.DRAFT, TrackVersionStatus.REVIEW_REQUIRED] { return _deny(actor, permission_name, AuthorizationReasonCode.VERSION_NOT_EDITABLE, "The version is not editable.", resource); }
            return _allow(actor, permission_name, scope, resource);
        }
        if permission in [LecturerPermission.APPROVE_VERSION, LecturerPermission.APPROVE_BLUEPRINT] {
            if access_role == TrackAccessRole.REVIEWER { return _allow(actor, permission_name, scope, resource); }
            if owner and os.getenv("ALLOW_LECTURER_SELF_APPROVAL", "false").strip().lower() in ["1", "true", "yes", "on"] { return _allow(actor, permission_name, scope, resource); }
            return _deny(actor, permission_name, AuthorizationReasonCode.PERMISSION_NOT_SUPPORTED, "Self approval is disabled; reviewer or administrator approval is required.", resource);
        }
        if permission == LecturerPermission.PUBLISH_VERSION {
            if not owner or not actor.can_publish_courses or os.getenv("ALLOW_LECTURER_SELF_PUBLISH", "true").strip().lower() not in ["1", "true", "yes", "on"] { return _deny(actor, permission_name, AuthorizationReasonCode.PERMISSION_NOT_SUPPORTED, "Explicit owner publication permission is required.", resource); }
            return _allow(actor, permission_name, scope, resource);
        }
        if permission == LecturerPermission.SUPERSEDE_VERSION { return _allow(actor, permission_name, scope, resource) if owner else _deny(actor, permission_name, AuthorizationReasonCode.RESOURCE_OWNERSHIP_REQUIRED, "Only the owner may supersede a version.", resource); }
        if permission in [LecturerPermission.VIEW_COURSE_ENROLLMENTS, LecturerPermission.VIEW_COURSE_LEARNER_SUMMARY] {
            if not resource.enrollment_belongs_to_track { return _deny(actor, permission_name, AuthorizationReasonCode.ENROLLMENT_REQUIRED, "Enrollment is outside the authorized track.", resource); }
            return _allow(actor, permission_name, AuthorizationScope.ENROLLED_TRACK, resource);
        }
        if permission in [LecturerPermission.VIEW_COURSE_SUBMISSION, LecturerPermission.REVIEW_LOW_CONFIDENCE_GRADE] {
            if not resource.enrollment_belongs_to_track or not resource.submission_belongs_to_track { return _deny(actor, permission_name, AuthorizationReasonCode.LEARNER_DATA_SCOPE_DENIED, "Submission is outside the authorized course scope.", resource); }
            if not actor.can_review_grading { return _deny(actor, permission_name, AuthorizationReasonCode.ROLE_INACTIVE, "Grading-review capability is disabled.", resource); }
            if permission == LecturerPermission.REVIEW_LOW_CONFIDENCE_GRADE and not resource.flagged_for_review { return _deny(actor, permission_name, AuthorizationReasonCode.LEARNER_DATA_SCOPE_DENIED, "Submission is not in the review queue.", resource); }
            return _allow(actor, permission_name, AuthorizationScope.ENROLLED_TRACK, resource);
        }
        if permission == LecturerPermission.MANAGE_TRACK_COLLABORATORS { return _allow(actor, permission_name, scope, resource) if owner else _deny(actor, permission_name, AuthorizationReasonCode.RESOURCE_OWNERSHIP_REQUIRED, "Only the owner may manage collaborators.", resource); }
        return _deny(actor, permission_name, AuthorizationReasonCode.PERMISSION_NOT_SUPPORTED, "The permission is not supported by the current policy.", resource);
    }

    def authorize_admin_action(actor: AuthorizationActor, permission: AdministrativePermission, resource: AuthorizationResourceContext | None) -> AuthorizationDecision {
        permission_name = str(permission);
        if not is_authenticated(actor) { return _deny(actor, permission_name, AuthorizationReasonCode.AUTHENTICATION_REQUIRED, "Authentication is required.", resource); }
        if not has_admin_permission(actor, permission) { return _deny(actor, permission_name, AuthorizationReasonCode.ADMIN_PERMISSION_REQUIRED, "The explicit administrative permission is required.", resource); }
        if resource is not None and resource.ownership_conflict and permission != AdministrativePermission.REPAIR_RESOURCE_OWNERSHIP { return _deny(actor, permission_name, AuthorizationReasonCode.RESOURCE_OWNERSHIP_MISMATCH, "Resource ownership requires repair.", resource); }
        if resource is not None and resource.version_status in [TrackVersionStatus.PUBLISHED, TrackVersionStatus.SUPERSEDED] and permission not in [AdministrativePermission.VIEW_ANY_TRACK, AdministrativePermission.PUBLISH_ANY_TRACK, AdministrativePermission.VIEW_SECURITY_AUDIT_LOG] { return _deny(actor, permission_name, AuthorizationReasonCode.VERSION_IMMUTABLE, "Published curriculum remains immutable for administrators.", resource); }
        return _allow(actor, permission_name, AuthorizationScope.SYSTEM, resource);
    }

    def require_allowed(decision: AuthorizationDecision) {
        if decision.decision == AuthorizationDecisionType.DENY { raise PermissionError(public_error_code(decision)); }
    }
}

def public_error_code(decision: AuthorizationDecision) -> str {
    if decision.reason_code == AuthorizationReasonCode.AUTHENTICATION_REQUIRED { return "AUTHENTICATION_REQUIRED"; }
    if decision.reason_code in [AuthorizationReasonCode.LECTURER_PROFILE_PENDING, AuthorizationReasonCode.LECTURER_PROFILE_SUSPENDED, AuthorizationReasonCode.LECTURER_PROFILE_ARCHIVED, AuthorizationReasonCode.LECTURER_PROFILE_REQUIRED, AuthorizationReasonCode.ROLE_REQUIRED, AuthorizationReasonCode.ROLE_INACTIVE] { return "LECTURER_NOT_ACTIVE"; }
    if decision.reason_code in [AuthorizationReasonCode.RESOURCE_NOT_FOUND, AuthorizationReasonCode.RESOURCE_OWNERSHIP_REQUIRED, AuthorizationReasonCode.RESOURCE_OWNERSHIP_MISMATCH] and os.getenv("PRIVATE_RESOURCE_HIDE_EXISTENCE", "true").strip().lower() in ["1", "true", "yes", "on"] { return "TRACK_NOT_FOUND"; }
    if decision.reason_code in [AuthorizationReasonCode.TRACK_NOT_EDITABLE, AuthorizationReasonCode.TRACK_ARCHIVED] { return "TRACK_NOT_EDITABLE"; }
    if decision.reason_code in [AuthorizationReasonCode.VERSION_NOT_EDITABLE, AuthorizationReasonCode.VERSION_IMMUTABLE] { return "VERSION_NOT_EDITABLE"; }
    if decision.reason_code in [AuthorizationReasonCode.VERSION_TRACK_MISMATCH, AuthorizationReasonCode.RESOURCE_SCOPE_MISMATCH, AuthorizationReasonCode.LEARNER_DATA_SCOPE_DENIED, AuthorizationReasonCode.SUBMISSION_TRACK_MISMATCH] { return "RESOURCE_SCOPE_MISMATCH"; }
    return "FORBIDDEN";
}

def authorization_audit_events -> list[AuthorizationAuditEvent] { return AUTHORIZATION_AUDIT_EVENTS.copy(); }
def reset_authorization_audit { global AUTHORIZATION_AUDIT_EVENTS; AUTHORIZATION_AUDIT_EVENTS = []; }

# No authorization decision cache is used. Identity/profile/role and resource
# state are resolved for every policy evaluation, so revocation is immediate.
def invalidate_authorization_cache(_actor_user_id: str) {}
