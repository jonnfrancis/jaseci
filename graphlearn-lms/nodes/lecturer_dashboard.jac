"""Typed read projections for the lecturer course dashboard."""

import from nodes.learning_track { LearningTrackStatus, LearningTrackType, LearningTrackVisibility }

enum CourseReadinessState: str {
    METADATA_INCOMPLETE = "METADATA_INCOMPLETE", READY_FOR_DOCUMENT = "READY_FOR_DOCUMENT",
    DOCUMENT_UPLOADED = "DOCUMENT_UPLOADED", PROCESSING = "PROCESSING",
    PROCESSING_FAILED = "PROCESSING_FAILED", REVIEW_REQUIRED = "REVIEW_REQUIRED",
    READY_TO_PUBLISH = "READY_TO_PUBLISH", PUBLISHED = "PUBLISHED",
    PUBLISHED_WITH_DRAFT_UPDATE = "PUBLISHED_WITH_DRAFT_UPDATE", ARCHIVED = "ARCHIVED"
}

enum CourseDashboardAction: str {
    COMPLETE_METADATA = "COMPLETE_METADATA", UPLOAD_DOCUMENT = "UPLOAD_DOCUMENT",
    START_PROCESSING = "START_PROCESSING", VIEW_PROCESSING = "VIEW_PROCESSING",
    RETRY_PROCESSING = "RETRY_PROCESSING", REVIEW_BLUEPRINT = "REVIEW_BLUEPRINT",
    COMPLETE_PUBLICATION_CHECKS = "COMPLETE_PUBLICATION_CHECKS", PUBLISH_COURSE = "PUBLISH_COURSE",
    VIEW_COURSE = "VIEW_COURSE", VIEW_LEARNERS = "VIEW_LEARNERS",
    CONTINUE_DRAFT_UPDATE = "CONTINUE_DRAFT_UPDATE", RESTORE_COURSE = "RESTORE_COURSE", NONE = "NONE"
}

enum CourseProcessingState: str {
    NOT_STARTED = "NOT_STARTED", QUEUED = "QUEUED", EXTRACTING = "EXTRACTING",
    CHUNKING = "CHUNKING", ANALYZING = "ANALYZING", GENERATING_BLUEPRINT = "GENERATING_BLUEPRINT",
    VALIDATING = "VALIDATING", COMPLETED = "COMPLETED", FAILED = "FAILED", CANCELLED = "CANCELLED"
}

enum LecturerCourseSort: str { UPDATED_AT = "UPDATED_AT", CREATED_AT = "CREATED_AT", TITLE = "TITLE", STATUS = "STATUS", PUBLISHED_AT = "PUBLISHED_AT" }
enum SortDirection: str { ASC = "ASC", DESC = "DESC" }

obj LecturerDashboardQuery {
    has search: str | None = None;
    has statuses: list[LearningTrackStatus] = [];
    has readiness_states: list[CourseReadinessState] = [];
    has visibilities: list[LearningTrackVisibility] = [];
    has subject_areas: list[str] = [];
    has include_archived: bool = False;
    has sort_by: LecturerCourseSort = LecturerCourseSort.UPDATED_AT;
    has sort_direction: SortDirection = SortDirection.DESC;
    has page: int = 1;
    has page_size: int = 20;
}

obj CourseDashboardPermissions {
    has can_view: bool = True, can_edit_metadata: bool = False, can_upload_document: bool = False;
    has can_start_processing: bool = False, can_retry_processing: bool = False;
    has can_review_blueprint: bool = False, can_publish: bool = False;
    has can_open_enrollment: bool = False, can_close_enrollment: bool = False;
    has can_view_learners: bool = False, can_archive: bool = False, can_restore: bool = False;
}

obj LecturerCourseDashboardItem {
    has track_id: str, title: str, slug: str, short_description: str, track_type: LearningTrackType;
    has status: LearningTrackStatus, visibility: LearningTrackVisibility;
    has created_at: str, updated_at: str;
    has actor_permissions: CourseDashboardPermissions;
    has readiness_state: CourseReadinessState, next_action: CourseDashboardAction;
    has readiness_percent: int, source_document_count: int;
    has active_version_id: str | None = None, draft_version_id: str | None = None;
    has course_code: str | None = None, subject_area: str | None = None, academic_level: str | None = None;
    has is_enrollment_open: bool = False;
    has active_version_number: int | None = None, draft_version_number: int | None = None;
    has processing_state: CourseProcessingState | None = None;
    has processing_progress_percent: int | None = None, processing_error_code: str | None = None;
    has enrollment_count: int | None = None, active_learner_count: int | None = None;
    has published_at: str | None = None, archived_at: str | None = None;
}

obj LecturerDashboardSummary {
    has lecturer_id: str, display_name: str, generated_at: str;
    has total_courses: int = 0, draft_courses: int = 0, processing_courses: int = 0;
    has review_required_courses: int = 0, published_courses: int = 0, archived_courses: int = 0, failed_courses: int = 0;
    has total_enrollments: int = 0, active_learners: int = 0;
    has enrollment_metrics_available: bool = False, learner_activity_metrics_available: bool = False;
}

obj LecturerDashboardFilterOptions {
    has statuses: list[LearningTrackStatus] = [];
    has readiness_states: list[CourseReadinessState] = [];
    has visibilities: list[LearningTrackVisibility] = [];
    has subject_areas: list[str] = [];
}

obj LecturerDashboardResponse {
    has summary: LecturerDashboardSummary;
    has courses: list[LecturerCourseDashboardItem];
    has available_filters: LecturerDashboardFilterOptions;
    has generated_at: str;
    has page: int = 1, page_size: int = 20, total_items: int = 0, total_pages: int = 0;
}
