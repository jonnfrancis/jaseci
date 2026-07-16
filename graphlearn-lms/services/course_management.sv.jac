"""Typed private RPC surface for lecturer course pages."""

import from lib.authorization.application_services {
    archive_authorized_course, create_authorized_course,
    get_authorized_course, list_authorized_courses,
    get_authorized_lecturer_dashboard,
    restore_authorized_course, update_authorized_configuration,
    update_authorized_course
}
import from lib.learning_track.repository_types { ServiceResult }
import from nodes.learning_track {
    CreateCourseTrackInput, LearningTrackStatus, LecturerCourseDetail,
    LecturerCourseList, UpdateCourseTrackInput, UpdateTrackConfigurationInput
}
import from nodes.lecturer_dashboard {
    CourseDashboardAction, CourseReadinessState, LecturerCourseDashboardItem,
    LecturerCourseSort, LecturerDashboardQuery, LecturerDashboardResponse, SortDirection
}

def _detail(result: ServiceResult) -> LecturerCourseDetail {
    if not result.ok or not isinstance(result.value, LecturerCourseDetail) {
        raise ValueError(result.error.code if result.error is not None else "COURSE_AGGREGATE_INVALID");
    }
    return result.value as LecturerCourseDetail;
}

def:priv create_lecturer_course(input: CreateCourseTrackInput) -> LecturerCourseDetail {
    return _detail(create_authorized_course(input, input.client_request_id or ""));
}

def:priv load_lecturer_course(track_id: str) -> LecturerCourseDetail {
    return _detail(get_authorized_course(track_id));
}

def:priv load_lecturer_courses(search: str | None = None, status: LearningTrackStatus | None = None, page_size: int = 20, cursor: str | None = None, sort: str = "updated_desc") -> LecturerCourseList {
    result = list_authorized_courses(status, search, None, page_size, cursor, sort);
    if not result.ok or not isinstance(result.value, LecturerCourseList) { raise ValueError(result.error.code if result.error is not None else "COURSE_LIST_FILTER_INVALID"); }
    return result.value as LecturerCourseList;
}

def:priv get_lecturer_course_dashboard(query: LecturerDashboardQuery) -> LecturerDashboardResponse {
    result = get_authorized_lecturer_dashboard(query);
    if not result.ok or not isinstance(result.value, LecturerDashboardResponse) { raise ValueError(result.error.code if result.error is not None else "DASHBOARD_LOAD_FAILED"); }
    return result.value as LecturerDashboardResponse;
}

def:priv save_lecturer_course(input: UpdateCourseTrackInput) -> LecturerCourseDetail {
    return _detail(update_authorized_course(input, input.client_request_id or ""));
}

def:priv save_lecturer_configuration(input: UpdateTrackConfigurationInput) -> LecturerCourseDetail {
    return _detail(update_authorized_configuration(input));
}

def:priv archive_lecturer_course(track_id: str, expected_revision: int, reason: str | None = None) -> LecturerCourseDetail {
    return _detail(archive_authorized_course(track_id, expected_revision, reason));
}

def:priv restore_lecturer_course(track_id: str, expected_revision: int) -> LecturerCourseDetail {
    return _detail(restore_authorized_course(track_id, expected_revision));
}
