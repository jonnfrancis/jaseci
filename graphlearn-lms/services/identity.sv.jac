"""Authenticated identity API; the caller's persistent root is authoritative."""

import from edges.domain_edges { HAS_IDENTITY_PROFILE, HAS_LEARNER_PROFILE, HAS_ROLE_ASSIGNMENT }
import from lib.identity.repositories { IdentityRepository, LecturerRepository }
import from lib.identity.services {
    assign_role, identity_error, identity_now, profile_summary, request_lecturer_onboarding,
    resolve_authenticated_actor, transition_lecturer_profile, transition_role,
    submit_lecturer_onboarding, update_lecturer_profile
}
import from lib.authorization.policy { AuthorizationPolicyService, authorization_now }
import from nodes.authorization { AdministrativePermission, AuthorizationActor, AuthorizationDecisionType, LecturerPermission }
import from nodes.identity {
    AuthenticatedWorkspaceBootstrap, IdentityError, IdentityResult, LecturerOnboardingStep,
    LecturerProfile, LecturerProfileInput, LecturerProfileStatus,
    RoleAssignmentSource, RoleAssignmentStatus, UserIdentityProfile,
    UserRoleAssignment, UserRoleMigrationRecord, UserRoleType, WorkspaceAvailability, WorkspaceKind
}
import from nodes.learner { Learner }

obj LearnerIdentityView {
    has learner_id: str;
    has auth_user_id: str;
    has auth_root_id: str;
    has name: str;
    has email: str;
    has active_roles: list[UserRoleType] = [];
    has lecturer_id: str | None = None;
}

def _identity_view(learner: Learner) -> LearnerIdentityView {
    actor_result = resolve_authenticated_actor();
    return LearnerIdentityView(
        learner_id=learner.id, auth_user_id=learner.auth_user_id,
        auth_root_id=learner.auth_root_id, name=learner.name, email=learner.email,
        active_roles=actor_result.actor.active_roles if actor_result.ok and actor_result.actor is not None else [],
        lecturer_id=actor_result.actor.lecturer_id if actor_result.ok and actor_result.actor is not None else None
    );
}

def _ensure_identity_profile(user_id: str, name: str, email: str) {
    repository = IdentityRepository(); profile = repository.find_identity_profile_by_user_id(user_id);
    timestamp = identity_now();
    if profile is None {
        profile = UserIdentityProfile(
            identity_profile_id="idp_" + user_id.replace(":", "_"), user_id=user_id,
            display_name=name if name != "" else (email if email != "" else "Learner"),
            created_at=timestamp, updated_at=timestamp,
            email_snapshot=email if email != "" else None,
            username_snapshot=name if name != "" else None,
            last_seen_at=timestamp
        );
        root +>:HAS_IDENTITY_PROFILE(created_at=timestamp):+> profile;
    } else {
        if name != "" { profile.display_name = name; profile.username_snapshot = name; }
        if email != "" { profile.email_snapshot = email; }
        profile.last_seen_at = timestamp; profile.updated_at = timestamp;
    }
}

def _ensure_learner_role(user_id: str, source: RoleAssignmentSource) {
    repository = IdentityRepository();
    for assignment in repository.list_role_assignments(user_id) {
        if assignment.role_type == UserRoleType.LEARNER and assignment.status == RoleAssignmentStatus.ACTIVE { return; }
    }
    _ = assign_role(UserRoleType.LEARNER, source, active=True);
}

"""Resolve/bind one learner without accepting a caller-provided user id."""
def:priv resolve_current_learner(
    legacy_learner_id: str = "",
    name: str = "",
    email: str = ""
) -> LearnerIdentityView {
    user_id = jid(root); learners = [root -->][?:Learner];
    learner: Learner | None = None;
    learner_created = False;
    for candidate in learners {
        if candidate.auth_root_id == user_id {
            if learner is not None { raise Exception("IDENTITY_GRAPH_INVALID"); }
            learner = candidate;
        }
    }
    if learner is None {
        candidates: list[Learner] = [];
        for candidate in learners {
            if (legacy_learner_id != "" and candidate.id == legacy_learner_id) or (email != "" and candidate.id.lower() == email.lower()) { candidates.append(candidate); }
        }
        if len(candidates) > 1 { raise Exception("IDENTITY_GRAPH_INVALID"); }
        if len(candidates) == 1 { learner = candidates[0]; }
    }
    if learner is None and len(learners) > 0 { raise Exception("IDENTITY_GRAPH_INVALID"); }
    if learner is None {
        learner_created = True;
        learner = (root ++> Learner(
            id=user_id, name=name if name != "" else (email if email != "" else "Learner"),
            createdAt=identity_now(), updatedAt=identity_now(),
            auth_user_id=user_id, auth_root_id=user_id, email=email
        ))[0];
    }
    if learner.auth_root_id not in ["", user_id] { raise Exception("IDENTITY_GRAPH_INVALID"); }
    learner.auth_root_id = user_id; learner.auth_user_id = user_id;
    if email != "" { learner.email = email; }
    if name != "" { learner.name = name; }
    if learner not in [root ->:HAS_LEARNER_PROFILE:->[?:Learner]] {
        root +>:HAS_LEARNER_PROFILE(created_at=identity_now()):+> learner;
    }
    _ensure_identity_profile(user_id, name, email);
    _ensure_learner_role(user_id, RoleAssignmentSource.REGISTRATION if learner_created else RoleAssignmentSource.MIGRATION);
    return _identity_view(learner);
}

def:priv get_current_identity -> IdentityResult { return resolve_authenticated_actor(); }

def:priv get_my_lecturer_profile -> IdentityResult {
    actor = resolve_authenticated_actor();
    if not actor.ok or actor.actor is None { return actor; }
    profile = LecturerRepository().find_by_user_id(actor.actor.user_id);
    if profile is None { return IdentityResult(ok=False, error=IdentityError(code="LECTURER_PROFILE_NOT_FOUND", message="Lecturer profile was not found.")); }
    authorization_actor = AuthorizationActor(
        user_id=actor.actor.user_id, resolved_at=authorization_now(),
        active_roles=actor.actor.active_roles.copy(), lecturer_id=profile.lecturer_id,
        lecturer_status=profile.status, is_authenticated=True
    );
    decision = AuthorizationPolicyService().authorize_lecturer_action(
        authorization_actor, LecturerPermission.VIEW_OWN_PROFILE, None
    );
    if decision.decision == AuthorizationDecisionType.DENY { return identity_error("ROLE_ASSIGNMENT_FORBIDDEN", "The lecturer profile is not available."); }
    return IdentityResult(ok=True, profile=profile_summary(profile));
}

def:priv update_my_lecturer_profile(input: LecturerProfileInput) -> IdentityResult {
    identity = resolve_authenticated_actor();
    if not identity.ok or identity.actor is None { return identity; }
    profile = LecturerRepository().find_by_user_id(identity.actor.user_id);
    if profile is None { return identity_error("LECTURER_PROFILE_NOT_FOUND", "Lecturer profile was not found."); }
    authorization_actor = AuthorizationActor(
        user_id=identity.actor.user_id, resolved_at=authorization_now(),
        active_roles=identity.actor.active_roles.copy(), lecturer_id=profile.lecturer_id,
        lecturer_status=profile.status, is_authenticated=True
    );
    decision = AuthorizationPolicyService().authorize_lecturer_action(
        authorization_actor, LecturerPermission.EDIT_OWN_PROFILE, None
    );
    if decision.decision == AuthorizationDecisionType.DENY { return identity_error("ROLE_ASSIGNMENT_FORBIDDEN", "The lecturer profile cannot be edited."); }
    return update_lecturer_profile(input);
}
def:priv request_lecturer_role(display_name: str = "") -> IdentityResult { return request_lecturer_onboarding(display_name); }
def:priv submit_my_lecturer_onboarding -> IdentityResult { return submit_lecturer_onboarding(); }

def:priv load_authenticated_workspace_bootstrap(preferred_workspace: WorkspaceKind | None = None) -> AuthenticatedWorkspaceBootstrap {
    identity = resolve_authenticated_actor();
    if not identity.ok or identity.actor is None { raise Exception(identity.error.code if identity.error is not None else "IDENTITY_BOOTSTRAP_FAILED"); }
    actor = identity.actor; repository = IdentityRepository();
    identity_profile = repository.find_identity_profile_by_user_id(actor.user_id);
    lecturer = repository.find_lecturer_profile(actor.user_id);
    learner_available = UserRoleType.LEARNER in actor.active_roles and actor.learner_id is not None;
    lecturer_available = UserRoleType.LECTURER in actor.active_roles and lecturer is not None and lecturer.status == LecturerProfileStatus.ACTIVE;
    step = LecturerOnboardingStep.NOT_STARTED;
    lecturer_status: LecturerProfileStatus | None = None;
    if lecturer is not None {
        lecturer_status = lecturer.status;
        if lecturer.status == LecturerProfileStatus.DRAFT { step = LecturerOnboardingStep.READY_TO_SUBMIT if lecturer.profile_completed else LecturerOnboardingStep.PROFILE_REQUIRED; }
        elif lecturer.status == LecturerProfileStatus.PENDING_REVIEW { step = LecturerOnboardingStep.PENDING_APPROVAL; }
        elif lecturer.status == LecturerProfileStatus.ACTIVE { step = LecturerOnboardingStep.ACTIVE; }
        elif lecturer.status == LecturerProfileStatus.REJECTED { step = LecturerOnboardingStep.REJECTED; }
        elif lecturer.status == LecturerProfileStatus.SUSPENDED { step = LecturerOnboardingStep.SUSPENDED; }
        elif lecturer.status == LecturerProfileStatus.ARCHIVED { step = LecturerOnboardingStep.ARCHIVED; }
    }
    learner_route = "/dashboard" if learner_available else None;
    lecturer_route: str | None = None;
    if lecturer_available { lecturer_route = "/lecturer/courses"; }
    elif step in [LecturerOnboardingStep.PROFILE_REQUIRED, LecturerOnboardingStep.READY_TO_SUBMIT, LecturerOnboardingStep.NOT_STARTED] { lecturer_route = "/lecturer/onboarding"; }
    elif step in [LecturerOnboardingStep.PENDING_APPROVAL, LecturerOnboardingStep.REJECTED] { lecturer_route = "/lecturer/onboarding/status"; }
    elif step in [LecturerOnboardingStep.SUSPENDED, LecturerOnboardingStep.ARCHIVED] { lecturer_route = "/lecturer/restricted"; }
    recommended_workspace: WorkspaceKind | None = None; recommended_route = "/identity/recovery";
    if learner_available and lecturer_available {
        if preferred_workspace == WorkspaceKind.LEARNER { recommended_workspace = WorkspaceKind.LEARNER; recommended_route = "/dashboard"; }
        elif preferred_workspace == WorkspaceKind.LECTURER { recommended_workspace = WorkspaceKind.LECTURER; recommended_route = "/lecturer/courses"; }
        else { recommended_route = "/choose-workspace"; }
    } elif lecturer is not None { recommended_workspace = WorkspaceKind.LECTURER; recommended_route = lecturer_route or "/identity/recovery"; }
    elif learner_available { recommended_workspace = WorkspaceKind.LEARNER; recommended_route = "/dashboard"; }
    return AuthenticatedWorkspaceBootstrap(
        user_id=actor.user_id,
        display_name=identity_profile.display_name if identity_profile is not None else "GraphLearn user",
        active_roles=actor.active_roles.copy(), learner_id=actor.learner_id, lecturer_id=actor.lecturer_id,
        lecturer_status=lecturer_status, lecturer_onboarding_step=step,
        available_workspaces=[
            WorkspaceAvailability(workspace=WorkspaceKind.LEARNER, available=learner_available, recommended_route=learner_route, reason_code=None if learner_available else "LEARNER_ROLE_INACTIVE"),
            WorkspaceAvailability(workspace=WorkspaceKind.LECTURER, available=lecturer_available, recommended_route=lecturer_route, reason_code=None if lecturer_available else "LECTURER_ONBOARDING_REQUIRED")
        ],
        recommended_workspace=recommended_workspace, recommended_route=recommended_route,
        can_request_lecturer_role=lecturer is None, generated_at=identity_now()
    );
}

def:priv migrate_current_learner_roles -> UserRoleMigrationRecord {
    user_id = jid(root); learners = [root -->][?:Learner];
    if len(learners) != 1 {
        return UserRoleMigrationRecord(migration_id="identity-v1-" + user_id, migration_version=1, user_id=user_id, status="CONFLICT" if len(learners) > 1 else "SKIPPED", message="Expected exactly one learner on the authenticated root.", migrated_at=identity_now());
    }
    learner = learners[0]; before = len(IdentityRepository().list_role_assignments(user_id));
    _ = resolve_current_learner(learner.id, learner.name, learner.email);
    after = len(IdentityRepository().list_role_assignments(user_id));
    return UserRoleMigrationRecord(
        migration_id="identity-v1-" + user_id, migration_version=1, user_id=user_id,
        learner_id=learner.id, status="MIGRATED" if after > before else "UNCHANGED",
        message="Learner identity and active role are canonical.", migrated_at=identity_now()
    );
}

# Administrative lifecycle endpoints are authenticated and require an active
# application ADMIN assignment on the caller's own root. Cross-user admin
# indexing is intentionally deferred to the authorization-policy feature.
def:priv activate_my_pending_lecturer_for_development -> IdentityResult {
    identity_for_admin = resolve_authenticated_actor();
    if not identity_for_admin.ok or identity_for_admin.actor is None { return identity_error("IDENTITY_NOT_FOUND", "Authenticated identity was not found."); }
    trusted_admin = identity_for_admin.actor;
    authorization_actor = AuthorizationActor(
        user_id=trusted_admin.user_id, resolved_at=authorization_now(),
        active_roles=trusted_admin.active_roles.copy(), is_authenticated=trusted_admin.is_authenticated,
        admin_permissions=[AdministrativePermission.APPROVE_LECTURER_PROFILE] if UserRoleType.ADMIN in trusted_admin.active_roles else []
    );
    admin_decision = AuthorizationPolicyService().authorize_admin_action(
        authorization_actor, AdministrativePermission.APPROVE_LECTURER_PROFILE, None
    );
    if admin_decision.decision == AuthorizationDecisionType.DENY {
        return identity_error("ADMIN_ROLE_REQUIRED", "An active administrator role is required.");
    }
    actor = resolve_authenticated_actor();
    if not actor.ok or actor.actor is None { return identity_error("IDENTITY_NOT_FOUND", "Authenticated identity was not found."); }
    assignment: UserRoleAssignment | None = None;
    for item in IdentityRepository().list_role_assignments(actor.actor.user_id) { if item.role_type == UserRoleType.LECTURER and item.status == RoleAssignmentStatus.PENDING { assignment = item; break; } }
    if assignment is None { return identity_error("ROLE_ASSIGNMENT_NOT_FOUND", "Pending lecturer role was not found."); }
    role_result = transition_role(assignment, RoleAssignmentStatus.ACTIVE, actor.actor.user_id);
    if not role_result.ok { return role_result; }
    profile = LecturerRepository().find_by_user_id(actor.actor.user_id);
    if profile is None { return identity_error("LECTURER_PROFILE_NOT_FOUND", "Lecturer profile was not found."); }
    return transition_lecturer_profile(profile, LecturerProfileStatus.ACTIVE, actor.actor.user_id);
}
