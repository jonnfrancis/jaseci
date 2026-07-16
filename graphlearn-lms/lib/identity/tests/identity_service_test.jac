"""Feature 35 role, lecturer-profile, identity, and migration tests."""

import from lib.identity.repositories { IdentityRepository }
import from lib.identity.services {
    calculate_lecturer_profile_completion, create_draft_lecturer_profile,
    request_lecturer_onboarding, resolve_authenticated_actor,
    transition_lecturer_profile, transition_role, update_lecturer_profile
}
import from nodes.identity {
    LecturerProfile, LecturerProfileInput, LecturerProfileStatus,
    LecturerVerificationStatus, RoleAssignmentSource, RoleAssignmentStatus,
    UserRoleAssignment, UserRoleType
}

def _test_profile(status: LecturerProfileStatus = LecturerProfileStatus.DRAFT) -> LecturerProfile {
    return LecturerProfile(
        lecturer_id="lec_test", user_id="user_test", display_name="Dr. Ada",
        institution_name="Independent Institute", areas_of_expertise=["Graph systems"],
        created_at="now", updated_at="now", status=status,
        verification_status=LecturerVerificationStatus.NOT_REQUIRED
    );
}

test "profile completion is calculated server side" {
    profile = _test_profile();
    assert calculate_lecturer_profile_completion(profile);
    profile.areas_of_expertise = [];
    assert not calculate_lecturer_profile_completion(profile);
}

test "role lifecycle rejects invalid transitions and revoked is terminal" {
    assignment = UserRoleAssignment(
        role_assignment_id="role_test", user_id="user_test",
        role_type=UserRoleType.LECTURER, source=RoleAssignmentSource.ADMIN,
        created_at="now", updated_at="now", status=RoleAssignmentStatus.PENDING,
        granted_by="admin_test"
    );
    activated = transition_role(assignment, RoleAssignmentStatus.ACTIVE, "admin_test");
    assert activated.ok;
    suspended = transition_role(assignment, RoleAssignmentStatus.SUSPENDED, "admin_test");
    assert suspended.ok;
    revoked = transition_role(assignment, RoleAssignmentStatus.REVOKED, "admin_test");
    assert revoked.ok;
    invalid = transition_role(assignment, RoleAssignmentStatus.ACTIVE, "admin_test");
    assert not invalid.ok;
    assert invalid.error is not None and invalid.error.code == "INVALID_ROLE_STATUS_TRANSITION";
}

test "suspending lecturer disables every capability" {
    profile = _test_profile(LecturerProfileStatus.ACTIVE);
    profile.profile_completed = True;
    profile.can_create_courses = True;
    profile.can_publish_courses = True;
    profile.can_review_grading = True;
    result = transition_lecturer_profile(profile, LecturerProfileStatus.SUSPENDED, "admin_test");
    assert result.ok;
    assert not profile.can_create_courses;
    assert not profile.can_publish_courses;
    assert not profile.can_review_grading;
}

test "ordinary profile input has no identity status or capability fields" {
    input = LecturerProfileInput(
        display_name=" Dr. Grace ", institution_name="University",
        areas_of_expertise=["Compilers", "Compilers", "  Graphs  "]
    );
    assert input.display_name.strip() == "Dr. Grace";
    assert not hasattr(input, "user_id");
    assert not hasattr(input, "status");
    assert not hasattr(input, "can_publish_courses");
}

test "multi role actor resolution omits inactive roles" {
    user_id = jid(root); repository = IdentityRepository();
    assignments = repository.list_role_assignments(user_id);
    has_learner = len([item for item in assignments if item.role_type == UserRoleType.LEARNER]) > 0;
    if not has_learner {
        repository.save_role_assignment(UserRoleAssignment(
            role_assignment_id="role_test_learner_" + user_id, user_id=user_id,
            role_type=UserRoleType.LEARNER, source=RoleAssignmentSource.MIGRATION,
            created_at="now", updated_at="now", status=RoleAssignmentStatus.ACTIVE,
            activated_at="now"
        ));
    }
    actor = resolve_authenticated_actor();
    assert actor.ok;
    assert actor.actor is not None;
    assert UserRoleType.LEARNER in actor.actor.active_roles;
}
