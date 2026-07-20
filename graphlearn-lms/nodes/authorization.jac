"""Typed authorization policy contracts for lecturer and administrator actions."""

import from nodes.identity { LecturerProfileStatus, UserRoleType }
import from nodes.learning_track { LearningTrackStatus, TrackOwnershipType, TrackVersionStatus }

enum AuthorizationDecisionType: str { ALLOW = "ALLOW", DENY = "DENY" }

enum AuthorizationScope: str {
    SELF = "SELF", OWNED_TRACK = "OWNED_TRACK", ASSIGNED_TRACK = "ASSIGNED_TRACK",
    ENROLLED_TRACK = "ENROLLED_TRACK", INSTITUTION = "INSTITUTION", SYSTEM = "SYSTEM"
}

enum LecturerPermission: str {
    VIEW_OWN_PROFILE = "VIEW_OWN_PROFILE", EDIT_OWN_PROFILE = "EDIT_OWN_PROFILE",
    LIST_OWN_TRACKS = "LIST_OWN_TRACKS", CREATE_TRACK = "CREATE_TRACK",
    VIEW_TRACK = "VIEW_TRACK", EDIT_TRACK_METADATA = "EDIT_TRACK_METADATA",
    ARCHIVE_TRACK = "ARCHIVE_TRACK", RESTORE_TRACK = "RESTORE_TRACK",
    CREATE_TRACK_VERSION = "CREATE_TRACK_VERSION", VIEW_TRACK_VERSION = "VIEW_TRACK_VERSION",
    EDIT_DRAFT_VERSION = "EDIT_DRAFT_VERSION", SUBMIT_VERSION_FOR_REVIEW = "SUBMIT_VERSION_FOR_REVIEW",
    APPROVE_VERSION = "APPROVE_VERSION", PUBLISH_VERSION = "PUBLISH_VERSION",
    SUPERSEDE_VERSION = "SUPERSEDE_VERSION", UPLOAD_COURSE_DOCUMENT = "UPLOAD_COURSE_DOCUMENT",
    VIEW_COURSE_DOCUMENT = "VIEW_COURSE_DOCUMENT", DELETE_DRAFT_DOCUMENT = "DELETE_DRAFT_DOCUMENT",
    PROCESS_COURSE_DOCUMENT = "PROCESS_COURSE_DOCUMENT", VIEW_BLUEPRINT = "VIEW_BLUEPRINT",
    EDIT_BLUEPRINT = "EDIT_BLUEPRINT", APPROVE_BLUEPRINT = "APPROVE_BLUEPRINT",
    REGENERATE_BLUEPRINT_SECTION = "REGENERATE_BLUEPRINT_SECTION",
    VIEW_COURSE_ENROLLMENTS = "VIEW_COURSE_ENROLLMENTS",
    VIEW_COURSE_LEARNER_SUMMARY = "VIEW_COURSE_LEARNER_SUMMARY",
    VIEW_COURSE_SUBMISSION = "VIEW_COURSE_SUBMISSION",
    REVIEW_LOW_CONFIDENCE_GRADE = "REVIEW_LOW_CONFIDENCE_GRADE",
    MANAGE_TRACK_COLLABORATORS = "MANAGE_TRACK_COLLABORATORS",
    VIEW_TRACK_AUDIT_LOG = "VIEW_TRACK_AUDIT_LOG"
}

enum AdministrativePermission: str {
    VIEW_ANY_LECTURER_PROFILE = "VIEW_ANY_LECTURER_PROFILE",
    APPROVE_LECTURER_PROFILE = "APPROVE_LECTURER_PROFILE",
    MANAGE_LECTURER_CAPABILITIES = "MANAGE_LECTURER_CAPABILITIES",
    SUSPEND_LECTURER_PROFILE = "SUSPEND_LECTURER_PROFILE",
    REINSTATE_LECTURER_PROFILE = "REINSTATE_LECTURER_PROFILE",
    VIEW_ANY_TRACK = "VIEW_ANY_TRACK", ARCHIVE_ANY_TRACK = "ARCHIVE_ANY_TRACK",
    RESTORE_ANY_TRACK = "RESTORE_ANY_TRACK", PUBLISH_ANY_TRACK = "PUBLISH_ANY_TRACK",
    ASSIGN_ROLE = "ASSIGN_ROLE", REVOKE_ROLE = "REVOKE_ROLE",
    VIEW_SECURITY_AUDIT_LOG = "VIEW_SECURITY_AUDIT_LOG",
    REPAIR_RESOURCE_OWNERSHIP = "REPAIR_RESOURCE_OWNERSHIP"
}

enum AuthorizationReasonCode: str {
    ALLOWED = "ALLOWED", AUTHENTICATION_REQUIRED = "AUTHENTICATION_REQUIRED",
    ACTOR_NOT_FOUND = "ACTOR_NOT_FOUND", ROLE_REQUIRED = "ROLE_REQUIRED",
    ROLE_INACTIVE = "ROLE_INACTIVE", LECTURER_PROFILE_REQUIRED = "LECTURER_PROFILE_REQUIRED",
    LECTURER_PROFILE_PENDING = "LECTURER_PROFILE_PENDING",
    LECTURER_PROFILE_SUSPENDED = "LECTURER_PROFILE_SUSPENDED",
    LECTURER_PROFILE_ARCHIVED = "LECTURER_PROFILE_ARCHIVED",
    RESOURCE_NOT_FOUND = "RESOURCE_NOT_FOUND",
    RESOURCE_OWNERSHIP_REQUIRED = "RESOURCE_OWNERSHIP_REQUIRED",
    RESOURCE_OWNERSHIP_MISMATCH = "RESOURCE_OWNERSHIP_MISMATCH",
    RESOURCE_SCOPE_MISMATCH = "RESOURCE_SCOPE_MISMATCH",
    TRACK_NOT_EDITABLE = "TRACK_NOT_EDITABLE", TRACK_ARCHIVED = "TRACK_ARCHIVED",
    TRACK_PRIVATE = "TRACK_PRIVATE", VERSION_NOT_EDITABLE = "VERSION_NOT_EDITABLE",
    VERSION_IMMUTABLE = "VERSION_IMMUTABLE", VERSION_TRACK_MISMATCH = "VERSION_TRACK_MISMATCH",
    ENROLLMENT_REQUIRED = "ENROLLMENT_REQUIRED",
    LEARNER_DATA_SCOPE_DENIED = "LEARNER_DATA_SCOPE_DENIED",
    SUBMISSION_TRACK_MISMATCH = "SUBMISSION_TRACK_MISMATCH",
    ADMIN_PERMISSION_REQUIRED = "ADMIN_PERMISSION_REQUIRED",
    POLICY_CONTEXT_INVALID = "POLICY_CONTEXT_INVALID",
    PERMISSION_NOT_SUPPORTED = "PERMISSION_NOT_SUPPORTED"
}

enum TrackAccessRole: str { OWNER = "OWNER", EDITOR = "EDITOR", REVIEWER = "REVIEWER", VIEWER = "VIEWER" }

obj AuthorizationActor {
    has user_id: str;
    has resolved_at: str;
    has session_id: str | None = None;
    has active_roles: list[UserRoleType] = [];
    has admin_permissions: list[AdministrativePermission] = [];
    has learner_id: str | None = None;
    has lecturer_id: str | None = None;
    has lecturer_status: LecturerProfileStatus | None = None;
    has can_create_courses: bool = False;
    has can_publish_courses: bool = False;
    has can_review_grading: bool = False;
    has is_authenticated: bool = False;
}

obj AuthorizationResourceContext {
    has resource_type: str;
    has resource_id: str;
    has track_id: str | None = None;
    has track_version_id: str | None = None;
    has owner_lecturer_id: str | None = None;
    has owner_user_id: str | None = None;
    has track_status: LearningTrackStatus | None = None;
    has track_ownership_type: TrackOwnershipType | None = None;
    has version_status: TrackVersionStatus | None = None;
    has learner_id: str | None = None;
    has enrollment_id: str | None = None;
    has submission_id: str | None = None;
    has institution_id: str | None = None;
    has access_role: TrackAccessRole | None = None;
    has ownership_edge_exists: bool = False;
    has ownership_conflict: bool = False;
    has version_belongs_to_track: bool = True;
    has enrollment_belongs_to_track: bool = True;
    has submission_belongs_to_track: bool = True;
    has flagged_for_review: bool = False;
}

obj AuthorizationDecision {
    has decision: AuthorizationDecisionType;
    has permission: str;
    has reason_code: AuthorizationReasonCode;
    has message: str;
    has evaluated_at: str;
    has scope: AuthorizationScope | None = None;
    has actor_id: str | None = None;
    has resource_type: str | None = None;
    has resource_id: str | None = None;
}

obj AuthorizationAuditEvent {
    has audit_id: str;
    has permission: str;
    has decision: AuthorizationDecisionType;
    has reason_code: AuthorizationReasonCode;
    has occurred_at: str;
    has actor_user_id: str | None = None;
    has actor_lecturer_id: str | None = None;
    has resource_type: str | None = None;
    has resource_id: str | None = None;
    has track_id: str | None = None;
    has track_version_id: str | None = None;
    has request_id: str | None = None;
}

obj OwnershipMigrationReport {
    has scanned: int = 0;
    has backfilled: int = 0;
    has unchanged: int = 0;
    has conflicts: int = 0;
    has skipped: int = 0;
}
