"""Authenticated administrator control plane for lecturer operations."""

import os;
import from lib.authorization.actor { resolve_authorization_actor }
import from lib.authorization.policy { AuthorizationPolicyService }
import from lib.identity.admin_services { approve_lecturer_onboarding, grant_course_reviewer, list_pending_lecturers, revoke_course_reviewer, set_lecturer_capabilities }
import from lib.identity.services { assign_role }
import from nodes.authorization { AdministrativePermission, AuthorizationDecisionType }
import from nodes.identity { AdminLecturerOperationResult, AdminLecturerView, RoleAssignmentSource, UserRoleType }

def _require_admin(permission: AdministrativePermission) -> str {
    actor = resolve_authorization_actor(); decision = AuthorizationPolicyService().authorize_admin_action(actor, permission, None);
    if decision.decision == AuthorizationDecisionType.DENY { raise PermissionError("ADMIN_ROLE_REQUIRED"); }
    return actor.user_id;
}

def:priv bootstrap_application_admin_for_development(confirmation_user_id: str) -> AdminLecturerOperationResult {
    environment = os.getenv("APP_ENV", "development").strip().lower(); enabled = os.getenv("DEVELOPMENT_ADMIN_BOOTSTRAP_ENABLED", "false").strip().lower() in ["1", "true", "yes", "on"]; configured_user_id = os.getenv("DEVELOPMENT_ADMIN_USER_ID", "").strip(); current_user_id = jid(root);
    if environment in ["production", "prod"] or not enabled { return AdminLecturerOperationResult(ok=False, operation="BOOTSTRAP_APPLICATION_ADMIN", error_code="ADMIN_BOOTSTRAP_DISABLED", message="Development administrator bootstrap is disabled."); }
    if confirmation_user_id != current_user_id or configured_user_id == "" or configured_user_id != current_user_id { return AdminLecturerOperationResult(ok=False, operation="BOOTSTRAP_APPLICATION_ADMIN", error_code="ADMIN_BOOTSTRAP_IDENTITY_MISMATCH", message="The authenticated identity does not match DEVELOPMENT_ADMIN_USER_ID."); }
    result = assign_role(UserRoleType.ADMIN, RoleAssignmentSource.SYSTEM, granted_by=current_user_id, active=True);
    if not result.ok and (result.error is None or result.error.code != "ROLE_ALREADY_ACTIVE") { return AdminLecturerOperationResult(ok=False, operation="BOOTSTRAP_APPLICATION_ADMIN", error_code=result.error.code if result.error is not None else "ADMIN_BOOTSTRAP_FAILED", message=result.error.message if result.error is not None else "Application administrator bootstrap failed."); }
    return AdminLecturerOperationResult(ok=True, operation="BOOTSTRAP_APPLICATION_ADMIN", message="Application administrator role is active. Disable DEVELOPMENT_ADMIN_BOOTSTRAP_ENABLED now.");
}

def:priv list_pending_lecturer_onboarding(limit: int = 50) -> list[AdminLecturerView] { _ = _require_admin(AdministrativePermission.VIEW_ANY_LECTURER_PROFILE); return list_pending_lecturers(limit); }
def:priv admin_approve_lecturer_onboarding(target_user_id: str, can_publish_courses: bool = False) -> AdminLecturerOperationResult { actor_id = _require_admin(AdministrativePermission.APPROVE_LECTURER_PROFILE); return approve_lecturer_onboarding(target_user_id, actor_id, can_publish_courses); }
def:priv admin_set_lecturer_capabilities(target_user_id: str, can_publish_courses: bool) -> AdminLecturerOperationResult { actor_id = _require_admin(AdministrativePermission.MANAGE_LECTURER_CAPABILITIES); return set_lecturer_capabilities(target_user_id, actor_id, can_publish_courses); }
def:priv admin_grant_course_reviewer(target_user_id: str, track_id: str, expires_at: str | None = None) -> AdminLecturerOperationResult { actor_id = _require_admin(AdministrativePermission.ASSIGN_ROLE); return grant_course_reviewer(target_user_id, track_id, actor_id, expires_at); }
def:priv admin_revoke_course_reviewer(target_user_id: str, track_id: str) -> AdminLecturerOperationResult { _ = _require_admin(AdministrativePermission.REVOKE_ROLE); return revoke_course_reviewer(target_user_id, track_id); }
