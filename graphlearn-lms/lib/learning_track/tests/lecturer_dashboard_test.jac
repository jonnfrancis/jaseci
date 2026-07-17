"""Feature 38 lecturer dashboard projection tests."""

import from uuid { uuid4 }
import from edges.domain_edges { HAS_LECTURER_PROFILE, OWNS_TRACK }
import from lib.identity.services { identity_now }
import from lib.learning_track.course_management { archive_course_service, create_course_service }
import from lib.learning_track.lecturer_dashboard { get_lecturer_dashboard_service }
import from lib.learning_track.repositories { repository_find_track }
import from lib.learning_track.repository_types { ActorContext }
import from nodes.learning_track { CreateCourseTrackInput, LecturerCourseDetail }
import from nodes.identity { LecturerProfile, LecturerProfileStatus, LecturerVerificationStatus }
import from nodes.lecturer_dashboard {
    CourseDashboardAction, CourseReadinessState, LecturerDashboardQuery, LecturerDashboardResponse
}

def _dashboard_actor(suffix: str) -> ActorContext {
    return ActorContext(user_id="dashboard_user_" + suffix, lecturer_id="dashboard_lecturer_" + suffix, request_id="dashboard_request_" + suffix, roles=["LECTURER"]);
}

def _attach_dashboard_owner(actor: ActorContext, detail: LecturerCourseDetail) {
    profiles = [item for item in [root ->:HAS_LECTURER_PROFILE:->[?:LecturerProfile]] if item.lecturer_id == actor.lecturer_id];
    profile: LecturerProfile;
    if len(profiles) > 0 { profile = profiles[0]; }
    else {
        profile = LecturerProfile(
            lecturer_id=actor.lecturer_id or "", user_id=jid(root), display_name="Dashboard Lecturer",
            created_at=identity_now(), updated_at=identity_now(), status=LecturerProfileStatus.ACTIVE,
            verification_status=LecturerVerificationStatus.NOT_REQUIRED, profile_completed=True,
            can_create_courses=True
        );
        root +>:HAS_LECTURER_PROFILE(created_at=identity_now()):+> profile;
    }
    track = repository_find_track(detail.track.track_id);
    if track is not None { profile +>:OWNS_TRACK(granted_at=identity_now()):+> track; }
}

test "dashboard projects owned draft readiness and action" {
    suffix = str(uuid4()).replace("-", ""); actor = _dashboard_actor(suffix);
    created = create_course_service(actor, CreateCourseTrackInput(title="Database Systems " + suffix, short_description="Relational database foundations.", subject_area="Computer Science", client_request_id="dashboard_" + suffix));
    assert created.ok;
    _attach_dashboard_owner(actor, created.value as LecturerCourseDetail);
    result = get_lecturer_dashboard_service(actor, "Dr Ada", False, LecturerDashboardQuery());
    assert result.ok and isinstance(result.value, LecturerDashboardResponse);
    dashboard = result.value as LecturerDashboardResponse;
    assert dashboard.summary.total_courses == 1 and dashboard.summary.draft_courses == 1;
    assert len(dashboard.courses) == 1;
    assert dashboard.courses[0].readiness_state == CourseReadinessState.READY_FOR_DOCUMENT;
    assert dashboard.courses[0].next_action == CourseDashboardAction.UPLOAD_DOCUMENT;
    assert dashboard.courses[0].enrollment_count is None;
    assert not dashboard.summary.enrollment_metrics_available;
}

test "dashboard search filters before pagination" {
    suffix = str(uuid4()).replace("-", ""); actor = _dashboard_actor(suffix);
    algorithms = create_course_service(actor, CreateCourseTrackInput(title="Algorithms " + suffix, short_description="Algorithm design.", course_code="CSC-301", client_request_id="alg_" + suffix));
    chemistry = create_course_service(actor, CreateCourseTrackInput(title="Organic Chemistry " + suffix, short_description="Chemical structures.", course_code="CHEM-201", client_request_id="chem_" + suffix));
    _attach_dashboard_owner(actor, algorithms.value as LecturerCourseDetail);
    _attach_dashboard_owner(actor, chemistry.value as LecturerCourseDetail);
    result = get_lecturer_dashboard_service(actor, "Lecturer", False, LecturerDashboardQuery(search="csc-301", page_size=1));
    dashboard = result.value as LecturerDashboardResponse;
    assert dashboard.total_items == 1 and len(dashboard.courses) == 1;
    assert dashboard.courses[0].course_code == "CSC-301";
}

test "archived courses are excluded unless requested" {
    suffix = str(uuid4()).replace("-", ""); actor = _dashboard_actor(suffix);
    created = create_course_service(actor, CreateCourseTrackInput(title="Archived Course " + suffix, short_description="A complete description.", client_request_id="archive_" + suffix));
    detail = created.value as LecturerCourseDetail;
    _attach_dashboard_owner(actor, detail);
    archived = archive_course_service(actor, detail.track.track_id, detail.track.revision);
    assert archived.ok;
    hidden = (get_lecturer_dashboard_service(actor, "Lecturer", False, LecturerDashboardQuery()).value as LecturerDashboardResponse);
    shown = (get_lecturer_dashboard_service(actor, "Lecturer", False, LecturerDashboardQuery(include_archived=True)).value as LecturerDashboardResponse);
    assert hidden.total_items == 0 and hidden.summary.total_courses == 0;
    assert shown.total_items == 1 and shown.courses[0].readiness_state == CourseReadinessState.ARCHIVED;
}
