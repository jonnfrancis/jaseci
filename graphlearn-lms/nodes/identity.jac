"""Application identity, role, lecturer-profile, and migration contracts."""

enum UserRoleType: str {
    LEARNER = "LEARNER",
    LECTURER = "LECTURER",
    ADMIN = "ADMIN"
}

enum RoleAssignmentStatus: str {
    PENDING = "PENDING",
    ACTIVE = "ACTIVE",
    SUSPENDED = "SUSPENDED",
    REVOKED = "REVOKED"
}

enum LecturerProfileStatus: str {
    DRAFT = "DRAFT",
    PENDING_REVIEW = "PENDING_REVIEW",
    ACTIVE = "ACTIVE",
    SUSPENDED = "SUSPENDED",
    REJECTED = "REJECTED",
    ARCHIVED = "ARCHIVED"
}

enum LecturerVerificationStatus: str {
    NOT_REQUIRED = "NOT_REQUIRED",
    UNVERIFIED = "UNVERIFIED",
    PENDING = "PENDING",
    VERIFIED = "VERIFIED",
    FAILED = "FAILED"
}

enum RoleAssignmentSource: str {
    SYSTEM = "SYSTEM",
    REGISTRATION = "REGISTRATION",
    ADMIN = "ADMIN",
    INVITATION = "INVITATION",
    MIGRATION = "MIGRATION"
}

enum RegistrationWorkspaceIntent: str {
    STUDENT = "STUDENT",
    LECTURER = "LECTURER"
}

enum WorkspaceKind: str {
    LEARNER = "LEARNER",
    LECTURER = "LECTURER"
}

enum LecturerOnboardingStep: str {
    NOT_STARTED = "NOT_STARTED",
    PROFILE_REQUIRED = "PROFILE_REQUIRED",
    READY_TO_SUBMIT = "READY_TO_SUBMIT",
    PENDING_APPROVAL = "PENDING_APPROVAL",
    ACTIVE = "ACTIVE",
    REJECTED = "REJECTED",
    SUSPENDED = "SUSPENDED",
    ARCHIVED = "ARCHIVED"
}

node UserIdentityProfile {
    has identity_profile_id: str;
    has user_id: str;
    has display_name: str;
    has created_at: str;
    has updated_at: str;
    has email_snapshot: str | None = None;
    has username_snapshot: str | None = None;
    has is_active: bool = True;
    has last_seen_at: str | None = None;
}

node UserRoleAssignment {
    has role_assignment_id: str;
    has user_id: str;
    has role_type: UserRoleType;
    has source: RoleAssignmentSource;
    has created_at: str;
    has updated_at: str;
    has status: RoleAssignmentStatus = RoleAssignmentStatus.PENDING;
    has granted_by: str | None = None;
    has reason: str = "";
    has activated_at: str | None = None;
    has suspended_at: str | None = None;
    has revoked_at: str | None = None;
}

node LecturerProfile {
    has lecturer_id: str;
    has user_id: str;
    has display_name: str;
    has created_at: str;
    has updated_at: str;
    has professional_title: str | None = None;
    has institution_name: str | None = None;
    has institution_id: str | None = None;
    has department: str | None = None;
    has biography: str = "";
    has areas_of_expertise: list[str] = [];
    has staff_number: str | None = None;
    has status: LecturerProfileStatus = LecturerProfileStatus.DRAFT;
    has verification_status: LecturerVerificationStatus = LecturerVerificationStatus.UNVERIFIED;
    has profile_completed: bool = False;
    has can_create_courses: bool = False;
    has can_publish_courses: bool = False;
    has can_review_grading: bool = False;
    has activated_at: str | None = None;
    has suspended_at: str | None = None;
    has archived_at: str | None = None;
}

obj AuthenticatedActor {
    has user_id: str;
    has username: str | None = None;
    has email: str | None = None;
    has active_roles: list[UserRoleType] = [];
    has learner_id: str | None = None;
    has lecturer_id: str | None = None;
    has is_authenticated: bool = False;
}

obj LecturerProfileInput {
    has display_name: str;
    has professional_title: str | None = None;
    has institution_name: str | None = None;
    has department: str | None = None;
    has biography: str = "";
    has areas_of_expertise: list[str] = [];
    has staff_number: str | None = None;
}

obj LecturerProfileSummary {
    has lecturer_id: str;
    has display_name: str;
    has professional_title: str | None;
    has institution_name: str | None;
    has department: str | None;
    has areas_of_expertise: list[str];
    has status: LecturerProfileStatus;
    has verification_status: LecturerVerificationStatus;
    has profile_completed: bool;
    has biography: str = "";
    has staff_number: str | None = None;
}

obj WorkspaceAvailability {
    has workspace: WorkspaceKind;
    has available: bool;
    has recommended_route: str | None = None;
    has reason_code: str | None = None;
}

obj AuthenticatedWorkspaceBootstrap {
    has user_id: str;
    has display_name: str;
    has active_roles: list[UserRoleType];
    has learner_id: str | None;
    has lecturer_id: str | None;
    has lecturer_status: LecturerProfileStatus | None;
    has lecturer_onboarding_step: LecturerOnboardingStep;
    has available_workspaces: list[WorkspaceAvailability];
    has recommended_workspace: WorkspaceKind | None;
    has recommended_route: str;
    has can_request_lecturer_role: bool;
    has generated_at: str;
}

obj RoleAssignmentResult {
    has role_assignment_id: str;
    has user_id: str;
    has role_type: UserRoleType;
    has status: RoleAssignmentStatus;
    has source: RoleAssignmentSource;
}

obj IdentityError {
    has code: str;
    has message: str;
    has details: dict[str, str] = {};
}

obj IdentityResult {
    has ok: bool;
    has actor: AuthenticatedActor | None = None;
    has profile: LecturerProfileSummary | None = None;
    has assignment: RoleAssignmentResult | None = None;
    has error: IdentityError | None = None;
    has replayed: bool = False;
}

obj UserRoleMigrationRecord {
    has migration_id: str;
    has migration_version: int;
    has user_id: str;
    has status: str;
    has learner_id: str | None = None;
    has lecturer_id: str | None = None;
    has message: str = "";
    has migrated_at: str | None = None;
}
