"""Focused administrator lecturer-management service tests."""

import os;
import from uuid { uuid4 }
import from edges.domain_edges { HAS_LECTURER_PROFILE, HAS_ROLE_ASSIGNMENT }
import from lib.identity.admin_services { approve_lecturer_onboarding, grant_course_reviewer, revoke_course_reviewer, set_lecturer_capabilities }
import from lib.identity.services { authorize_current_lecturer_admin_management, identity_now }
import from lib.learning_track.course_management { create_course_service }
import from lib.learning_track.repositories { repository_find_track }
import from lib.learning_track.repository_types { ActorContext }
import from nodes.identity { LecturerProfile, LecturerProfileStatus, LecturerVerificationStatus, RoleAssignmentSource, RoleAssignmentStatus, UserRoleAssignment, UserRoleType }
import from nodes.learning_track { CreateCourseTrackInput, LecturerCourseDetail }

test "admin approval capabilities and independent reviewer grants remain distinct" {
    suffix = uuid4().hex; user_id = jid(root); now = identity_now();
    profile = LecturerProfile(lecturer_id="lecturer_" + suffix, user_id=user_id, display_name="Reviewer " + suffix[:6], created_at=now, updated_at=now, professional_title="Professor", institution_name="GraphLearn", department="Review", biography="Independent curriculum reviewer.", areas_of_expertise=["Curriculum"], profile_completed=True, status=LecturerProfileStatus.PENDING_REVIEW, verification_status=LecturerVerificationStatus.VERIFIED);
    assignment = UserRoleAssignment(role_assignment_id="role_" + suffix, user_id=user_id, role_type=UserRoleType.LECTURER, source=RoleAssignmentSource.REGISTRATION, created_at=now, updated_at=now, status=RoleAssignmentStatus.PENDING);
    root +>:HAS_LECTURER_PROFILE(created_at=now):+> profile; root +>:HAS_ROLE_ASSIGNMENT(created_at=now):+> assignment;

    previous_admin_roots = os.environ.get("APPLICATION_ADMIN_ROOT_IDS");
    os.environ["APPLICATION_ADMIN_ROOT_IDS"] = user_id;
    authorization = authorize_current_lecturer_admin_management();
    assert authorization.ok and authorization.granted_node_count == 2;

    approved = approve_lecturer_onboarding(user_id, user_id, True);
    assert approved.ok and profile.status == LecturerProfileStatus.ACTIVE and assignment.status == RoleAssignmentStatus.ACTIVE and profile.can_publish_courses;
    changed = set_lecturer_capabilities(user_id, user_id, False);
    assert changed.ok and not profile.can_publish_courses;

    owner_actor = ActorContext(user_id="owner_user_" + suffix, lecturer_id="owner_lecturer_" + suffix, request_id="course_" + suffix, roles=["LECTURER"]);
    created = create_course_service(owner_actor, CreateCourseTrackInput(title="Reviewer Grant " + suffix[:6], client_request_id="course_" + suffix));
    detail = created.value as LecturerCourseDetail;
    granted = grant_course_reviewer(user_id, detail.track.track_id, "admin_user");
    assert granted.ok and granted.access_role == "REVIEWER";
    revoked = revoke_course_reviewer(user_id, detail.track.track_id);
    assert revoked.ok;

    track = repository_find_track(detail.track.track_id); assert track is not None; track.owner_id = profile.lecturer_id;
    denied = grant_course_reviewer(user_id, detail.track.track_id, "admin_user");
    assert not denied.ok and denied.error_code == "REVIEWER_MUST_BE_INDEPENDENT";
    if previous_admin_roots is None { del os.environ["APPLICATION_ADMIN_ROOT_IDS"]; }
    else { os.environ["APPLICATION_ADMIN_ROOT_IDS"] = previous_admin_roots; }
}
