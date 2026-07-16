"""Private thin walker for the lecturer course dashboard."""

import from lib.authorization.application_services { get_authorized_lecturer_dashboard }
import from lib.learning_track.repository_types { ServiceResult }
import from nodes.lecturer_dashboard { LecturerDashboardQuery, LecturerDashboardResponse }

walker get_lecturer_course_dashboard {
    has query: LecturerDashboardQuery = LecturerDashboardQuery();

    can project with Root entry {
        result: ServiceResult = get_authorized_lecturer_dashboard(self.query);
        if not result.ok or not isinstance(result.value, LecturerDashboardResponse) {
            raise ValueError(result.error.code if result.error is not None else "DASHBOARD_LOAD_FAILED");
        }
        report result.value as LecturerDashboardResponse;
    }
}
