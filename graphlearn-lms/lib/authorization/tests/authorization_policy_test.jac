"""Feature 36 negative-first authorization policy tests."""

import os;
import from edges.domain_edges { OWNS_TRACK }
import from lib.authorization.metrics { ownership_scalar_fallback_total, reset_authorization_metrics }
import from lib.authorization.policy { AuthorizationPolicyService, authorization_audit_events, public_error_code, reset_authorization_audit }
import from lib.authorization.repositories { ownership_context }
import from nodes.authorization {
    AdministrativePermission, AuthorizationActor, AuthorizationDecisionType,
    AuthorizationReasonCode, AuthorizationResourceContext, AuthorizationScope,
    LecturerPermission, TrackAccessRole
}
import from nodes.identity { LecturerProfile, LecturerProfileStatus, LecturerVerificationStatus, UserRoleType }
import from nodes.learning_track { LearningTrack, LearningTrackStatus, LearningTrackType, LearningTrackVisibility, TrackOwnershipType, TrackVersionStatus }

def _actor(lecturer_id: str = "lec_owner", status: LecturerProfileStatus = LecturerProfileStatus.ACTIVE) -> AuthorizationActor {
    return AuthorizationActor(
        user_id="user_owner", resolved_at="now", active_roles=[UserRoleType.LECTURER],
        lecturer_id=lecturer_id, lecturer_status=status, is_authenticated=True,
        can_create_courses=True, can_publish_courses=True, can_review_grading=True
    );
}

def _resource(owner_id: str = "lec_owner", edge_exists: bool = True) -> AuthorizationResourceContext {
    return AuthorizationResourceContext(
        resource_type="LearningTrack", resource_id="trk_policy", track_id="trk_policy",
        owner_lecturer_id=owner_id, track_status=LearningTrackStatus.DRAFT,
        track_ownership_type=TrackOwnershipType.LECTURER,
        ownership_edge_exists=edge_exists
    );
}

test "default deny rejects unauthenticated and learner role claims" {
    policy = AuthorizationPolicyService();
    anonymous = AuthorizationActor(user_id="", resolved_at="now");
    denied = policy.authorize_lecturer_action(anonymous, LecturerPermission.CREATE_TRACK, None);
    assert denied.decision == AuthorizationDecisionType.DENY;
    assert denied.reason_code == AuthorizationReasonCode.AUTHENTICATION_REQUIRED;
    learner = AuthorizationActor(user_id="learner", resolved_at="now", active_roles=[UserRoleType.LEARNER], is_authenticated=True);
    claimed = policy.authorize_lecturer_action(learner, LecturerPermission.CREATE_TRACK, None);
    assert claimed.reason_code == AuthorizationReasonCode.ROLE_REQUIRED;
}

test "inactive lecturer profiles immediately lose management access" {
    policy = AuthorizationPolicyService(); resource = _resource();
    pending = policy.authorize_lecturer_action(_actor(status=LecturerProfileStatus.PENDING_REVIEW), LecturerPermission.EDIT_TRACK_METADATA, resource);
    suspended = policy.authorize_lecturer_action(_actor(status=LecturerProfileStatus.SUSPENDED), LecturerPermission.EDIT_TRACK_METADATA, resource);
    archived = policy.authorize_lecturer_action(_actor(status=LecturerProfileStatus.ARCHIVED), LecturerPermission.EDIT_TRACK_METADATA, resource);
    assert pending.reason_code == AuthorizationReasonCode.LECTURER_PROFILE_PENDING;
    assert suspended.reason_code == AuthorizationReasonCode.LECTURER_PROFILE_SUSPENDED;
    assert archived.reason_code == AuthorizationReasonCode.LECTURER_PROFILE_ARCHIVED;
}

test "active owner may edit draft but unrelated lecturer and conflicts are denied" {
    policy = AuthorizationPolicyService();
    allowed = policy.authorize_lecturer_action(_actor(), LecturerPermission.EDIT_TRACK_METADATA, _resource());
    unrelated = policy.authorize_lecturer_action(_actor("lec_other"), LecturerPermission.EDIT_TRACK_METADATA, _resource());
    conflict_resource = _resource(); conflict_resource.ownership_conflict = True;
    conflict = policy.authorize_lecturer_action(_actor(), LecturerPermission.EDIT_TRACK_METADATA, conflict_resource);
    assert allowed.decision == AuthorizationDecisionType.ALLOW and allowed.scope == AuthorizationScope.OWNED_TRACK;
    assert unrelated.reason_code == AuthorizationReasonCode.RESOURCE_OWNERSHIP_REQUIRED;
    assert conflict.reason_code == AuthorizationReasonCode.RESOURCE_OWNERSHIP_MISMATCH;
}

test "scalar ownership fallback is strict and observable" {
    os.environ["ALLOW_OWNER_SCALAR_FALLBACK"] = "false";
    reset_authorization_metrics();
    denied = AuthorizationPolicyService().authorize_lecturer_action(_actor(), LecturerPermission.VIEW_TRACK, _resource(edge_exists=False));
    assert denied.decision == AuthorizationDecisionType.DENY;
    assert ownership_scalar_fallback_total() == 0;
    os.environ["ALLOW_OWNER_SCALAR_FALLBACK"] = "true";
    allowed = AuthorizationPolicyService().authorize_lecturer_action(_actor(), LecturerPermission.VIEW_TRACK, _resource(edge_exists=False));
    assert allowed.decision == AuthorizationDecisionType.ALLOW;
    assert ownership_scalar_fallback_total() == 1;
    os.environ["ALLOW_OWNER_SCALAR_FALLBACK"] = "false";
}

test "published version is immutable even for owner and administrator" {
    resource = _resource(); resource.resource_type = "TrackVersion"; resource.resource_id = "trv_published";
    resource.track_version_id = "trv_published"; resource.version_status = TrackVersionStatus.PUBLISHED;
    owner = AuthorizationPolicyService().authorize_lecturer_action(_actor(), LecturerPermission.EDIT_DRAFT_VERSION, resource);
    admin = AuthorizationActor(
        user_id="admin", resolved_at="now", active_roles=[UserRoleType.ADMIN], is_authenticated=True,
        admin_permissions=[AdministrativePermission.ARCHIVE_ANY_TRACK]
    );
    admin_denied = AuthorizationPolicyService().authorize_admin_action(admin, AdministrativePermission.ARCHIVE_ANY_TRACK, resource);
    assert owner.reason_code == AuthorizationReasonCode.VERSION_IMMUTABLE;
    assert admin_denied.reason_code == AuthorizationReasonCode.VERSION_IMMUTABLE;
}

test "editor reviewer and system track scopes follow the matrix" {
    editor_resource = _resource("lec_owner", False); editor_resource.access_role = TrackAccessRole.EDITOR;
    editor = AuthorizationPolicyService().authorize_lecturer_action(_actor("lec_editor"), LecturerPermission.EDIT_TRACK_METADATA, editor_resource);
    reviewer_resource = _resource("lec_owner", False); reviewer_resource.access_role = TrackAccessRole.REVIEWER;
    reviewer = AuthorizationPolicyService().authorize_lecturer_action(_actor("lec_reviewer"), LecturerPermission.EDIT_TRACK_METADATA, reviewer_resource);
    system_resource = _resource(); system_resource.track_ownership_type = TrackOwnershipType.SYSTEM;
    system_denied = AuthorizationPolicyService().authorize_lecturer_action(_actor(), LecturerPermission.EDIT_TRACK_METADATA, system_resource);
    assert editor.decision == AuthorizationDecisionType.ALLOW;
    assert reviewer.decision == AuthorizationDecisionType.DENY;
    assert system_denied.decision == AuthorizationDecisionType.DENY;
}

test "learner and submission data require complete same track scope" {
    resource = _resource(); resource.resource_type = "Submission"; resource.resource_id = "sub_1";
    resource.enrollment_id = "enr_1"; resource.submission_id = "sub_1";
    resource.enrollment_belongs_to_track = True; resource.submission_belongs_to_track = False;
    guessed = AuthorizationPolicyService().authorize_lecturer_action(_actor(), LecturerPermission.VIEW_COURSE_SUBMISSION, resource);
    resource.submission_belongs_to_track = True; resource.flagged_for_review = False;
    not_flagged = AuthorizationPolicyService().authorize_lecturer_action(_actor(), LecturerPermission.REVIEW_LOW_CONFIDENCE_GRADE, resource);
    resource.flagged_for_review = True;
    review = AuthorizationPolicyService().authorize_lecturer_action(_actor(), LecturerPermission.REVIEW_LOW_CONFIDENCE_GRADE, resource);
    assert guessed.reason_code == AuthorizationReasonCode.LEARNER_DATA_SCOPE_DENIED;
    assert not_flagged.decision == AuthorizationDecisionType.DENY;
    assert review.decision == AuthorizationDecisionType.ALLOW;
}

test "administrators require explicit permission and denials are safely audited" {
    reset_authorization_audit(); resource = _resource();
    admin = AuthorizationActor(user_id="admin", resolved_at="now", active_roles=[UserRoleType.ADMIN], is_authenticated=True);
    denied = AuthorizationPolicyService().authorize_admin_action(admin, AdministrativePermission.ARCHIVE_ANY_TRACK, resource);
    assert denied.reason_code == AuthorizationReasonCode.ADMIN_PERMISSION_REQUIRED;
    assert len(authorization_audit_events()) == 1;
    assert public_error_code(AuthorizationPolicyService().authorize_lecturer_action(_actor("lec_other"), LecturerPermission.VIEW_TRACK, resource)) == "TRACK_NOT_FOUND";
}

test "repository proves graph ownership and detects scalar edge conflict" {
    profile = LecturerProfile(
        lecturer_id="lec_graph", user_id="user_graph", display_name="Graph Lecturer",
        created_at="now", updated_at="now", status=LecturerProfileStatus.ACTIVE,
        verification_status=LecturerVerificationStatus.NOT_REQUIRED
    );
    track = LearningTrack(
        track_id="trk_graph", slug="graph", title="Graph", track_type=LearningTrackType.LECTURER_COURSE,
        ownership_type=TrackOwnershipType.LECTURER, owner_id="lec_graph",
        created_at="now", updated_at="now", status=LearningTrackStatus.DRAFT,
        visibility=LearningTrackVisibility.PRIVATE
    );
    profile +>:OWNS_TRACK(granted_at="now"):+> track;
    context = ownership_context(profile, track);
    assert context.ownership_edge_exists and not context.ownership_conflict;
    track.owner_id = "lec_conflict";
    conflict = ownership_context(profile, track);
    assert conflict.ownership_conflict;
}
