"""Thin private transport walkers for lecturer course management."""

import from lib.authorization.application_services {
    archive_authorized_course, create_authorized_course,
    duplicate_authorized_course, get_authorized_course,
    list_authorized_courses, restore_authorized_course,
    update_authorized_configuration, update_authorized_course
}
import from lib.learning_track.repository_types { ServiceResult }
import from nodes.learning_track {
    CreateCourseTrackInput, LearningTrackStatus, UpdateCourseTrackInput,
    UpdateTrackConfigurationInput
}

walker:priv create_course_track {
    has input: CreateCourseTrackInput;
    can execute with Root entry { report create_authorized_course(self.input, self.input.client_request_id or ""); }
}

walker:priv get_lecturer_course {
    has track_id: str;
    can execute with Root entry { report get_authorized_course(self.track_id); }
}

walker:priv list_lecturer_courses {
    has status: LearningTrackStatus | None = None;
    has search: str | None = None;
    has subject_area: str | None = None;
    has page_size: int = 20;
    has cursor: str | None = None;
    has sort: str = "updated_desc";
    can execute with Root entry { report list_authorized_courses(self.status, self.search, self.subject_area, self.page_size, self.cursor, self.sort); }
}

walker:priv update_course_track {
    has input: UpdateCourseTrackInput;
    can execute with Root entry { report update_authorized_course(self.input, self.input.client_request_id or ""); }
}

walker:priv update_course_track_configuration {
    has input: UpdateTrackConfigurationInput;
    can execute with Root entry { report update_authorized_configuration(self.input); }
}

walker:priv archive_course_track {
    has track_id: str;
    has expected_revision: int;
    has reason: str | None = None;
    can execute with Root entry { report archive_authorized_course(self.track_id, self.expected_revision, self.reason); }
}

walker:priv restore_course_track {
    has track_id: str;
    has expected_revision: int;
    can execute with Root entry { report restore_authorized_course(self.track_id, self.expected_revision); }
}

walker:priv duplicate_course_track {
    has track_id: str;
    has client_request_id: str;
    can execute with Root entry { report duplicate_authorized_course(self.track_id, self.client_request_id); }
}
