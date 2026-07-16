"""Shared learning-track catalogue domain models."""

enum LearningTrackType: str {
    PROGRAMMING_LANGUAGE = "PROGRAMMING_LANGUAGE",
    LECTURER_COURSE = "LECTURER_COURSE"
}

enum LearningTrackStatus: str {
    DRAFT = "DRAFT",
    PROCESSING = "PROCESSING",
    REVIEW_REQUIRED = "REVIEW_REQUIRED",
    PUBLISHED = "PUBLISHED",
    FAILED = "FAILED",
    ARCHIVED = "ARCHIVED"
}

enum LearningTrackVisibility: str {
    PUBLIC = "PUBLIC",
    INSTITUTION = "INSTITUTION",
    PRIVATE = "PRIVATE"
}

enum TrackOwnershipType: str {
    SYSTEM = "SYSTEM",
    LECTURER = "LECTURER",
    INSTITUTION = "INSTITUTION"
}

enum TrackVersionStatus: str {
    DRAFT = "DRAFT",
    REVIEW_REQUIRED = "REVIEW_REQUIRED",
    APPROVED = "APPROVED",
    PUBLISHED = "PUBLISHED",
    SUPERSEDED = "SUPERSEDED",
    FAILED = "FAILED",
    ARCHIVED = "ARCHIVED"
}

enum TrackDifficultyLevel: str {
    BEGINNER = "BEGINNER",
    INTERMEDIATE = "INTERMEDIATE",
    ADVANCED = "ADVANCED",
    MIXED = "MIXED"
}

enum TrackSourceKind: str {
    SEEDED = "SEEDED",
    LECTURER_DOCUMENT = "LECTURER_DOCUMENT",
    MANUAL = "MANUAL"
}

node LearningTrack {
    has track_id: str;
    has slug: str;
    has title: str;
    has track_type: LearningTrackType;
    has ownership_type: TrackOwnershipType;
    has created_at: str;
    has updated_at: str;
    has short_description: str = "";
    has status: LearningTrackStatus = LearningTrackStatus.DRAFT;
    has visibility: LearningTrackVisibility = LearningTrackVisibility.PRIVATE;
    has owner_id: str | None = None;
    has institution_id: str | None = None;
    has course_code: str | None = None;
    has subject_area: str | None = None;
    has academic_level: str | None = None;
    has default_difficulty: TrackDifficultyLevel = TrackDifficultyLevel.MIXED;
    has estimated_duration_weeks: int | None = None;
    has active_version_id: str | None = None;
    has current_version_number: int = 0;
    has is_enrollment_open: bool = False;
    has published_at: str | None = None;
    has archived_at: str | None = None;
    has revision: int = 1;
    has last_modified_by: str | None = None;
}

node TrackVersion {
    has track_version_id: str;
    has track_id: str;
    has version_number: int;
    has title_snapshot: str;
    has source_kind: TrackSourceKind;
    has created_by: str;
    has created_at: str;
    has updated_at: str;
    has status: TrackVersionStatus = TrackVersionStatus.DRAFT;
    has description_snapshot: str = "";
    has change_summary: str = "";
    has curriculum_schema_version: int = 1;
    has approved_by: str | None = None;
    has approved_at: str | None = None;
    has published_at: str | None = None;
    has superseded_at: str | None = None;
    has revision: int = 1;
    has last_modified_by: str | None = None;
}

node TrackConfiguration {
    has configuration_id: str;
    has track_id: str;
    has created_at: str;
    has updated_at: str;
    has supports_diagnostic_assessment: bool = True;
    has supports_multiple_choice: bool = True;
    has supports_short_answer: bool = True;
    has supports_numeric_answer: bool = False;
    has supports_code_challenge: bool = False;
    has supports_essay: bool = False;
    has supports_project_activity: bool = False;
    has default_pass_score: float = 0.70;
    has mastery_threshold: float = 0.80;
    has max_assessment_questions: int = 20;
    has default_lesson_minutes: int = 30;
    has revision: int = 1;
    has last_modified_by: str | None = None;
}

obj CreateCourseTrackInput {
    has title: str;
    has short_description: str = "";
    has course_code: str | None = None;
    has subject_area: str | None = None;
    has academic_level: str | None = None;
    has estimated_duration_weeks: int | None = None;
    has default_difficulty: TrackDifficultyLevel = TrackDifficultyLevel.MIXED;
    has visibility: LearningTrackVisibility = LearningTrackVisibility.PRIVATE;
    has supports_diagnostic_assessment: bool = True;
    has supports_multiple_choice: bool = True;
    has supports_short_answer: bool = True;
    has supports_numeric_answer: bool = False;
    has supports_code_challenge: bool = False;
    has supports_essay: bool = False;
    has supports_project_activity: bool = False;
    has default_pass_score: float = 0.70;
    has mastery_threshold: float = 0.80;
    has max_assessment_questions: int = 20;
    has default_lesson_minutes: int = 30;
    has client_request_id: str | None = None;
}

obj UpdateCourseTrackInput {
    has track_id: str;
    has expected_revision: int;
    has title: str | None = None;
    has short_description: str | None = None;
    has course_code: str | None = None;
    has subject_area: str | None = None;
    has academic_level: str | None = None;
    has estimated_duration_weeks: int | None = None;
    has default_difficulty: TrackDifficultyLevel | None = None;
    has visibility: LearningTrackVisibility | None = None;
    has clear_fields: list[str] = [];
    has client_request_id: str | None = None;
}

obj UpdateTrackConfigurationInput {
    has track_id: str;
    has expected_revision: int;
    has supports_diagnostic_assessment: bool | None = None;
    has supports_multiple_choice: bool | None = None;
    has supports_short_answer: bool | None = None;
    has supports_numeric_answer: bool | None = None;
    has supports_code_challenge: bool | None = None;
    has supports_essay: bool | None = None;
    has supports_project_activity: bool | None = None;
    has default_pass_score: float | None = None;
    has mastery_threshold: float | None = None;
    has max_assessment_questions: int | None = None;
    has default_lesson_minutes: int | None = None;
}

obj CourseReadiness {
    has metadata_complete: bool;
    has configuration_valid: bool;
    has initial_version_valid: bool;
    has has_source_document: bool;
    has document_processing_complete: bool;
    has blueprint_available: bool;
    has blueprint_review_complete: bool;
    has publication_ready: bool;
    has blockers: list[str];
    has warnings: list[str];
}

obj TrackConfigurationView {
    has supports_diagnostic_assessment: bool;
    has supports_multiple_choice: bool;
    has supports_short_answer: bool;
    has supports_numeric_answer: bool;
    has supports_code_challenge: bool;
    has supports_essay: bool;
    has supports_project_activity: bool;
    has default_pass_score: float;
    has mastery_threshold: float;
    has max_assessment_questions: int;
    has default_lesson_minutes: int;
    has revision: int;
}

obj TrackVersionSummary {
    has track_version_id: str;
    has version_number: int;
    has status: TrackVersionStatus;
    has change_summary: str;
    has source_kind: TrackSourceKind;
    has created_at: str;
    has updated_at: str;
    has revision: int;
}

obj LecturerCourseSummary {
    has track_id: str;
    has slug: str;
    has title: str;
    has short_description: str;
    has course_code: str | None;
    has subject_area: str | None;
    has academic_level: str | None;
    has status: LearningTrackStatus;
    has visibility: LearningTrackVisibility;
    has current_version_number: int;
    has active_version_id: str | None;
    has is_enrollment_open: bool;
    has readiness_stage: str;
    has created_at: str;
    has updated_at: str;
    has revision: int;
}

obj LecturerCourseDetail {
    has track: LecturerCourseSummary;
    has owner_id: str;
    has institution_id: str | None;
    has estimated_duration_weeks: int | None;
    has default_difficulty: TrackDifficultyLevel;
    has draft_version: TrackVersionSummary | None;
    has active_version: TrackVersionSummary | None;
    has configuration: TrackConfigurationView;
    has readiness: CourseReadiness;
    has available_actions: list[str];
}

obj LecturerCourseList {
    has items: list[LecturerCourseSummary];
    has next_cursor: str | None = None;
    has total_estimate: int = 0;
}

node LearningCatalogue {
    has created_at: str;
    has updated_at: str;
    has catalogue_id: str = "global";
    has name: str = "GraphLearn Catalogue";
}

obj CreateLearningTrackInput {
    has title: str;
    has track_type: LearningTrackType;
    has ownership_type: TrackOwnershipType;
    has short_description: str = "";
    has visibility: LearningTrackVisibility = LearningTrackVisibility.PRIVATE;
    has owner_id: str | None = None;
    has institution_id: str | None = None;
    has course_code: str | None = None;
    has subject_area: str | None = None;
    has academic_level: str | None = None;
    has default_difficulty: TrackDifficultyLevel = TrackDifficultyLevel.MIXED;
    has estimated_duration_weeks: int | None = None;
}

obj LearningTrackSummary {
    has track_id: str;
    has slug: str;
    has title: str;
    has short_description: str;
    has track_type: LearningTrackType;
    has status: LearningTrackStatus;
    has visibility: LearningTrackVisibility;
    has course_code: str | None;
    has subject_area: str | None;
    has active_version_id: str | None;
    has is_enrollment_open: bool;
}

obj LearningTrackDetail {
    has track: LearningTrackSummary;
    has ownership_type: TrackOwnershipType;
    has owner_id: str | None;
    has institution_id: str | None;
    has academic_level: str | None;
    has default_difficulty: TrackDifficultyLevel;
    has estimated_duration_weeks: int | None;
    has current_version_number: int;
    has created_at: str;
    has updated_at: str;
    has published_at: str | None;
}

obj LearningTrackError {
    has code: str;
    has message: str;
    has details: dict[str, str] = {};
}

obj LearningTrackResult {
    has ok: bool;
    has track: LearningTrack | None = None;
    has version: TrackVersion | None = None;
    has error: LearningTrackError | None = None;
}

obj LearningTrackMigrationReport {
    has tracks_created: int = 0;
    has tracks_existing: int = 0;
    has versions_created: int = 0;
    has records_mapped: int = 0;
    has records_skipped: int = 0;
    has records_failed: int = 0;
}
