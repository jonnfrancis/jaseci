"""Trusted authorization actor resolution from the authenticated identity graph."""

import from lib.authorization.policy { authorization_now }
import from lib.identity.repositories { LecturerRepository }
import from lib.identity.services { resolve_authenticated_actor }
import from nodes.authorization { AdministrativePermission, AuthorizationActor }
import from nodes.identity { UserRoleType }

def _admin_permissions -> list[AdministrativePermission] {
    return [
        AdministrativePermission.VIEW_ANY_LECTURER_PROFILE,
        AdministrativePermission.APPROVE_LECTURER_PROFILE,
        AdministrativePermission.SUSPEND_LECTURER_PROFILE,
        AdministrativePermission.REINSTATE_LECTURER_PROFILE,
        AdministrativePermission.VIEW_ANY_TRACK, AdministrativePermission.ARCHIVE_ANY_TRACK,
        AdministrativePermission.RESTORE_ANY_TRACK, AdministrativePermission.PUBLISH_ANY_TRACK,
        AdministrativePermission.ASSIGN_ROLE, AdministrativePermission.REVOKE_ROLE,
        AdministrativePermission.VIEW_SECURITY_AUDIT_LOG,
        AdministrativePermission.REPAIR_RESOURCE_OWNERSHIP
    ];
}

def resolve_authorization_actor -> AuthorizationActor {
    identity = resolve_authenticated_actor();
    if not identity.ok or identity.actor is None { return AuthorizationActor(user_id="", resolved_at=authorization_now()); }
    trusted = identity.actor;
    actor = AuthorizationActor(
        user_id=trusted.user_id, active_roles=trusted.active_roles.copy(),
        learner_id=trusted.learner_id, lecturer_id=trusted.lecturer_id,
        is_authenticated=trusted.is_authenticated, resolved_at=authorization_now(),
        admin_permissions=_admin_permissions() if UserRoleType.ADMIN in trusted.active_roles else []
    );
    if UserRoleType.LECTURER in trusted.active_roles {
        profile = LecturerRepository().find_by_user_id(trusted.user_id);
        if profile is not None and profile.user_id == trusted.user_id and profile.lecturer_id == trusted.lecturer_id {
            actor.lecturer_status = profile.status; actor.can_create_courses = profile.can_create_courses;
            actor.can_publish_courses = profile.can_publish_courses; actor.can_review_grading = profile.can_review_grading;
        }
    }
    return actor;
}
