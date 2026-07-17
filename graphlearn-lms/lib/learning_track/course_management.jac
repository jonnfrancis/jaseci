"""Lecturer-owned course aggregate management and safe projections."""

import re;
import from edges.domain_edges { HAS_BLUEPRINT, HAS_SOURCE_DOCUMENT, HAS_TRACK_VERSION }
import from lib.learning_track.application_services {
    begin_operation, complete_operation, fail_operation, service_error, service_now
}
import from lib.learning_track.repositories {
    repository_active_version, repository_find_track, repository_find_track_by_slug,
    repository_list_owned, repository_versions
}
import from lib.learning_track.repository_types {
    ActorContext, IdempotencyContext, PageRequest, ServiceError, ServiceResult
}
import from lib.learning_track.service {
    create_initial_version_for_track, create_track, track_configuration
}
import from nodes.curriculum { CourseBlueprint, CourseDocument }
import from nodes.learning_track {
    CourseReadiness, CreateCourseTrackInput, CreateLearningTrackInput,
    LearningTrack, LearningTrackStatus, LearningTrackType, LearningTrackVisibility,
    LecturerCourseDetail, LecturerCourseList, LecturerCourseSummary,
    TrackConfiguration, TrackConfigurationView, TrackDifficultyLevel,
    TrackOwnershipType, TrackSourceKind, TrackVersion, TrackVersionStatus,
    TrackVersionSummary, UpdateCourseTrackInput, UpdateTrackConfigurationInput
}

glob COURSE_TITLE_MIN: int = 3;
glob COURSE_TITLE_MAX: int = 160;
glob COURSE_DESCRIPTION_MAX: int = 1000;
glob COURSE_TEXT_MAX: int = 120;
glob COURSE_DURATION_MAX: int = 260;
glob COURSE_QUESTIONS_MAX: int = 200;
glob COURSE_LESSON_MINUTES_MAX: int = 480;

def _clean(value: str | None) -> str | None {
    if value is None { return None; }
    cleaned = value.strip();
    return cleaned if cleaned != "" else None;
}

def _fingerprint(input: CreateCourseTrackInput) -> str {
    return "|".join([
        input.title.strip(), input.short_description.strip(), input.course_code or "",
        input.subject_area or "", input.academic_level or "",
        str(input.estimated_duration_weeks), str(input.default_difficulty),
        str(input.supports_diagnostic_assessment), str(input.supports_multiple_choice),
        str(input.supports_short_answer), str(input.supports_numeric_answer),
        str(input.supports_code_challenge), str(input.supports_essay),
        str(input.supports_project_activity), str(input.default_pass_score),
        str(input.mastery_threshold), str(input.max_assessment_questions),
        str(input.default_lesson_minutes)
    ]);
}

def _valid_title(value: str) -> bool {
    cleaned = value.strip();
    if len(cleaned) < COURSE_TITLE_MIN or len(cleaned) > COURSE_TITLE_MAX { return False; }
    if re.search(r"[A-Za-z0-9]", cleaned) is None { return False; }
    return all([ord(char) >= 32 and ord(char) != 127 for char in cleaned]);
}

def _valid_code(value: str | None) -> bool {
    if value is None { return True; }
    cleaned = value.strip();
    return len(cleaned) <= 40 and re.fullmatch(r"[A-Za-z0-9 ._/-]*", cleaned) is not None;
}

def _configuration_valid_values(pass_score: float, mastery: float, questions: int, minutes: int) -> bool {
    return pass_score >= 0.0 and pass_score <= 1.0 and mastery >= pass_score and mastery <= 1.0 and questions >= 1 and questions <= COURSE_QUESTIONS_MAX and minutes >= 5 and minutes <= COURSE_LESSON_MINUTES_MAX;
}

def _creation_error(input: CreateCourseTrackInput) -> ServiceResult | None {
    if not _valid_title(input.title) { return service_error("COURSE_TITLE_INVALID", "Course title must be 3 to 160 useful characters."); }
    if len(input.short_description.strip()) > COURSE_DESCRIPTION_MAX { return service_error("COURSE_TITLE_INVALID", "Course description is too long."); }
    if not _valid_code(input.course_code) { return service_error("COURSE_CODE_INVALID", "Course code contains unsupported characters or is too long."); }
    if input.subject_area is not None and len(input.subject_area.strip()) > COURSE_TEXT_MAX { return service_error("COURSE_TITLE_INVALID", "Subject area is too long."); }
    if input.academic_level is not None and len(input.academic_level.strip()) > COURSE_TEXT_MAX { return service_error("COURSE_TITLE_INVALID", "Academic level is too long."); }
    if input.estimated_duration_weeks is not None and (input.estimated_duration_weeks <= 0 or input.estimated_duration_weeks > COURSE_DURATION_MAX) { return service_error("COURSE_DURATION_INVALID", "Course duration is outside the supported range."); }
    if input.visibility != LearningTrackVisibility.PRIVATE { return service_error("COURSE_CONFIGURATION_INVALID", "New lecturer courses must be private drafts."); }
    if not _configuration_valid_values(input.default_pass_score, input.mastery_threshold, input.max_assessment_questions, input.default_lesson_minutes) { return service_error("COURSE_CONFIGURATION_INVALID", "Course scoring or duration defaults are invalid."); }
    return None;
}

def _version_summary(version: TrackVersion) -> TrackVersionSummary {
    return TrackVersionSummary(
        track_version_id=version.track_version_id, version_number=version.version_number,
        status=version.status, change_summary=version.change_summary,
        source_kind=version.source_kind, created_at=version.created_at,
        updated_at=version.updated_at, revision=version.revision
    );
}

def _configuration_view(configuration: TrackConfiguration) -> TrackConfigurationView {
    return TrackConfigurationView(
        supports_diagnostic_assessment=configuration.supports_diagnostic_assessment,
        supports_multiple_choice=configuration.supports_multiple_choice,
        supports_short_answer=configuration.supports_short_answer,
        supports_numeric_answer=configuration.supports_numeric_answer,
        supports_code_challenge=configuration.supports_code_challenge,
        supports_essay=configuration.supports_essay,
        supports_project_activity=configuration.supports_project_activity,
        default_pass_score=configuration.default_pass_score,
        mastery_threshold=configuration.mastery_threshold,
        max_assessment_questions=configuration.max_assessment_questions,
        default_lesson_minutes=configuration.default_lesson_minutes,
        revision=configuration.revision
    );
}

def compute_course_readiness(track: LearningTrack) -> CourseReadiness {
    configuration = track_configuration(track);
    versions = repository_versions(track);
    draft: TrackVersion | None = None;
    for version in versions {
        if version.status in [TrackVersionStatus.DRAFT, TrackVersionStatus.REVIEW_REQUIRED, TrackVersionStatus.APPROVED] { draft = version; }
    }
    metadata_complete = _valid_title(track.title) and track.short_description.strip() != "";
    configuration_valid = configuration is not None and _configuration_valid_values(configuration.default_pass_score, configuration.mastery_threshold, configuration.max_assessment_questions, configuration.default_lesson_minutes);
    supports_activity = configuration is not None and (configuration.supports_diagnostic_assessment or configuration.supports_multiple_choice or configuration.supports_short_answer or configuration.supports_numeric_answer or configuration.supports_code_challenge or configuration.supports_essay or configuration.supports_project_activity);
    initial_version_valid = False;
    has_document = False;
    has_blueprint = False;
    if draft is not None {
        current_draft = draft as TrackVersion;
        initial_version_valid = len(versions) >= 1 and current_draft.track_id == track.track_id;
        has_document = len([current_draft ->:HAS_SOURCE_DOCUMENT:->[?:CourseDocument]]) > 0;
        has_blueprint = len([current_draft ->:HAS_BLUEPRINT:->[?:CourseBlueprint]]) > 0;
    }
    blockers: list[str] = [];
    if not metadata_complete { blockers.append("SHORT_DESCRIPTION_REQUIRED"); }
    if not has_document { blockers.append("NO_SOURCE_DOCUMENT"); }
    if not has_blueprint { blockers.append("NO_CURRICULUM_BLUEPRINT"); }
    if not supports_activity { blockers.append("NO_SUPPORTED_ACTIVITY_TYPE"); }
    if not initial_version_valid { blockers.append("INVALID_ACTIVE_DRAFT"); }
    ready = metadata_complete and configuration_valid and initial_version_valid and has_document and has_blueprint and supports_activity;
    return CourseReadiness(
        metadata_complete=metadata_complete, configuration_valid=configuration_valid,
        initial_version_valid=initial_version_valid, has_source_document=has_document,
        document_processing_complete=False, blueprint_available=has_blueprint,
        blueprint_review_complete=False, publication_ready=ready,
        blockers=blockers, warnings=[]
    );
}

def course_summary(track: LearningTrack) -> LecturerCourseSummary {
    readiness = compute_course_readiness(track);
    stage = "READY_TO_PUBLISH" if readiness.publication_ready else ("ARCHIVED" if track.status == LearningTrackStatus.ARCHIVED else "COURSE_SETUP");
    return LecturerCourseSummary(
        track_id=track.track_id, slug=track.slug, title=track.title,
        short_description=track.short_description, course_code=track.course_code,
        subject_area=track.subject_area, academic_level=track.academic_level,
        status=track.status, visibility=track.visibility,
        current_version_number=track.current_version_number,
        active_version_id=track.active_version_id,
        is_enrollment_open=track.is_enrollment_open, readiness_stage=stage,
        created_at=track.created_at, updated_at=track.updated_at, revision=track.revision
    );
}

def course_detail(track: LearningTrack) -> LecturerCourseDetail | None {
    if track.owner_id is None { return None; }
    configuration = track_configuration(track);
    if configuration is None { return None; }
    draft: TrackVersion | None = None;
    for version in repository_versions(track) {
        if version.status in [TrackVersionStatus.DRAFT, TrackVersionStatus.REVIEW_REQUIRED, TrackVersionStatus.APPROVED] { draft = version; }
    }
    active = repository_active_version(track);
    actions: list[str] = ["ARCHIVE_COURSE"];
    if track.status == LearningTrackStatus.ARCHIVED { actions = ["RESTORE_DRAFT"]; }
    elif track.status != LearningTrackStatus.PUBLISHED { actions = ["EDIT_METADATA", "EDIT_CONFIGURATION", "UPLOAD_DOCUMENT", "ARCHIVE_COURSE"]; }
    return LecturerCourseDetail(
        track=course_summary(track), owner_id=track.owner_id,
        institution_id=track.institution_id,
        estimated_duration_weeks=track.estimated_duration_weeks,
        default_difficulty=track.default_difficulty,
        draft_version=_version_summary(draft as TrackVersion) if draft is not None else None,
        active_version=_version_summary(active as TrackVersion) if active is not None else None,
        configuration=_configuration_view(configuration), readiness=compute_course_readiness(track),
        available_actions=actions
    );
}

def create_course_service(actor: ActorContext, input: CreateCourseTrackInput) -> ServiceResult {
    validation = _creation_error(input);
    if validation is not None { return validation; }
    if actor.lecturer_id is None { return service_error("LECTURER_PROFILE_REQUIRED", "An active lecturer profile is required."); }
    request_key = input.client_request_id.strip() if input.client_request_id is not None else "";
    if request_key == "" { request_key = "course_" + actor.request_id; }
    if len(request_key) > 120 { return service_error("COURSE_CONFIGURATION_INVALID", "Client request ID is too long."); }
    context = IdempotencyContext(key=request_key, operation="create-course-track", actor_id=actor.user_id, request_id=actor.request_id);
    operation = begin_operation(context);
    fingerprint = _fingerprint(input);
    if operation.payload_fingerprint != "" and operation.payload_fingerprint != fingerprint { return service_error("IDEMPOTENCY_KEY_PAYLOAD_CONFLICT", "The request ID was already used with different course data."); }
    operation.payload_fingerprint = fingerprint;
    if operation.status == "COMPLETED" and operation.entity_id is not None {
        existing = repository_find_track(operation.entity_id);
        if existing is not None { return ServiceResult(ok=True, value=course_detail(existing), replayed=True); }
    }
    base = CreateLearningTrackInput(
        title=input.title, short_description=input.short_description,
        track_type=LearningTrackType.LECTURER_COURSE,
        ownership_type=TrackOwnershipType.LECTURER,
        visibility=LearningTrackVisibility.PRIVATE, course_code=input.course_code,
        subject_area=input.subject_area, academic_level=input.academic_level,
        default_difficulty=input.default_difficulty,
        estimated_duration_weeks=input.estimated_duration_weeks
    );
    created = create_track(base, actor.lecturer_id);
    if not created.ok or created.track is None { fail_operation(operation, "COURSE_AGGREGATE_CREATION_FAILED"); return service_error("COURSE_AGGREGATE_CREATION_FAILED", "Course aggregate could not be created."); }
    track = created.track;
    version_result = create_initial_version_for_track(track, actor.lecturer_id);
    configuration = track_configuration(track);
    if not version_result.ok or version_result.version is None or configuration is None {
        track.status = LearningTrackStatus.FAILED; fail_operation(operation, "COURSE_AGGREGATE_INVALID");
        return service_error("COURSE_AGGREGATE_INVALID", "Course aggregate is incomplete and can be repaired by retrying.");
    }
    configuration.supports_diagnostic_assessment = input.supports_diagnostic_assessment;
    configuration.supports_multiple_choice = input.supports_multiple_choice;
    configuration.supports_short_answer = input.supports_short_answer;
    configuration.supports_numeric_answer = input.supports_numeric_answer;
    configuration.supports_code_challenge = input.supports_code_challenge;
    configuration.supports_essay = input.supports_essay;
    configuration.supports_project_activity = input.supports_project_activity;
    configuration.default_pass_score = input.default_pass_score;
    configuration.mastery_threshold = input.mastery_threshold;
    configuration.max_assessment_questions = input.max_assessment_questions;
    configuration.default_lesson_minutes = input.default_lesson_minutes;
    configuration.last_modified_by = actor.user_id;
    track.last_modified_by = actor.user_id;
    complete_operation(operation, track.track_id);
    return ServiceResult(ok=True, value=course_detail(track));
}

def get_course_service(actor: ActorContext, track_id: str) -> ServiceResult {
    track = repository_find_track(track_id.strip());
    if track is None or actor.lecturer_id is None or track.owner_id != actor.lecturer_id or track.ownership_type != TrackOwnershipType.LECTURER { return service_error("COURSE_NOT_FOUND", "Course was not found."); }
    detail = course_detail(track);
    return ServiceResult(ok=True, value=detail) if detail is not None else service_error("COURSE_AGGREGATE_INVALID", "Course aggregate is incomplete.");
}

def list_courses_service(actor: ActorContext, status: LearningTrackStatus | None = None, search: str | None = None, subject_area: str | None = None, page_size: int = 20, cursor: str | None = None, sort: str = "updated_desc") -> ServiceResult {
    if actor.lecturer_id is None { return service_error("LECTURER_PROFILE_REQUIRED", "An active lecturer profile is required."); }
    if sort not in ["updated_desc", "created_desc", "title_asc", "title_desc"] or page_size < 1 or page_size > 100 { return service_error("COURSE_LIST_FILTER_INVALID", "Course list filter is invalid."); }
    query = search.strip().lower() if search is not None else "";
    if len(query) > 120 { return service_error("COURSE_LIST_FILTER_INVALID", "Course search is too long."); }
    raw = repository_list_owned(actor.lecturer_id, PageRequest(limit=100, cursor=None));
    tracks: list[LearningTrack] = [];
    for item in raw.items {
        if isinstance(item, LearningTrack) and item.track_type == LearningTrackType.LECTURER_COURSE and (status is None or item.status == status) and (subject_area is None or (item.subject_area or "").lower() == subject_area.strip().lower()) and (query == "" or query in item.title.lower() or query in (item.course_code or "").lower() or query in (item.subject_area or "").lower()) { tracks.append(item); }
    }
    if sort == "updated_desc" { tracks.sort(key=lambda t: LearningTrack : t.updated_at, reverse=True); }
    elif sort == "created_desc" { tracks.sort(key=lambda t: LearningTrack : t.created_at, reverse=True); }
    elif sort == "title_desc" { tracks.sort(key=lambda t: LearningTrack : t.title.lower(), reverse=True); }
    else { tracks.sort(key=lambda t: LearningTrack : t.title.lower()); }
    offset = 0;
    if cursor is not None { try { offset = int(cursor); } except ValueError { return service_error("COURSE_LIST_FILTER_INVALID", "Course cursor is invalid."); } }
    end = min(offset + page_size, len(tracks));
    return ServiceResult(ok=True, value=LecturerCourseList(items=[course_summary(t) for t in tracks[offset:end]], next_cursor=str(end) if end < len(tracks) else None, total_estimate=len(tracks)));
}

def update_course_service(actor: ActorContext, input: UpdateCourseTrackInput) -> ServiceResult {
    loaded = get_course_service(actor, input.track_id);
    if not loaded.ok { return loaded; }
    track = repository_find_track(input.track_id) as LearningTrack;
    if track.revision != input.expected_revision { return ServiceResult(ok=False, error=ServiceError(code="COURSE_REVISION_CONFLICT", message="The course was updated by another operation.", details={"current_revision": str(track.revision)})); }
    if track.status not in [LearningTrackStatus.DRAFT, LearningTrackStatus.PROCESSING, LearningTrackStatus.REVIEW_REQUIRED, LearningTrackStatus.FAILED] { return service_error("COURSE_EDIT_NOT_ALLOWED", "Course metadata cannot be edited in its current state."); }
    if input.visibility is not None and input.visibility != LearningTrackVisibility.PRIVATE { return service_error("COURSE_CONFIGURATION_INVALID", "Draft lecturer courses must remain private."); }
    if input.title is not None and not _valid_title(input.title) { return service_error("COURSE_TITLE_INVALID", "Course title is invalid."); }
    if input.short_description is not None and len(input.short_description.strip()) > COURSE_DESCRIPTION_MAX { return service_error("COURSE_TITLE_INVALID", "Course description is too long."); }
    if input.course_code is not None and not _valid_code(input.course_code) { return service_error("COURSE_CODE_INVALID", "Course code is invalid."); }
    if input.estimated_duration_weeks is not None and (input.estimated_duration_weeks <= 0 or input.estimated_duration_weeks > COURSE_DURATION_MAX) { return service_error("COURSE_DURATION_INVALID", "Course duration is invalid."); }
    if input.title is not None { track.title = input.title.strip(); }
    if input.short_description is not None { track.short_description = input.short_description.strip(); }
    if input.course_code is not None { track.course_code = _clean(input.course_code); }
    if input.subject_area is not None { track.subject_area = _clean(input.subject_area); }
    if input.academic_level is not None { track.academic_level = _clean(input.academic_level); }
    if input.estimated_duration_weeks is not None { track.estimated_duration_weeks = input.estimated_duration_weeks; }
    if input.default_difficulty is not None { track.default_difficulty = input.default_difficulty; }
    for field in input.clear_fields {
        if field == "course_code" { track.course_code = None; }
        elif field == "subject_area" { track.subject_area = None; }
        elif field == "academic_level" { track.academic_level = None; }
        elif field == "estimated_duration_weeks" { track.estimated_duration_weeks = None; }
        else { return service_error("COURSE_CONFIGURATION_INVALID", "A requested clear field is not editable."); }
    }
    track.revision += 1; track.last_modified_by = actor.user_id; track.updated_at = service_now();
    for version in repository_versions(track) {
        if version.status == TrackVersionStatus.DRAFT { version.title_snapshot = track.title; version.description_snapshot = track.short_description; version.revision += 1; version.last_modified_by = actor.user_id; version.updated_at = track.updated_at; }
    }
    return ServiceResult(ok=True, value=course_detail(track));
}

def update_configuration_service(actor: ActorContext, input: UpdateTrackConfigurationInput) -> ServiceResult {
    loaded = get_course_service(actor, input.track_id);
    if not loaded.ok { return loaded; }
    track = repository_find_track(input.track_id) as LearningTrack;
    if track.status == LearningTrackStatus.PUBLISHED { return service_error("COURSE_VERSION_IMMUTABLE", "Published course configuration is immutable."); }
    configuration = track_configuration(track);
    if configuration is None { return service_error("COURSE_AGGREGATE_INVALID", "Course configuration is missing."); }
    if configuration.revision != input.expected_revision { return ServiceResult(ok=False, error=ServiceError(code="COURSE_REVISION_CONFLICT", message="The course configuration was updated by another operation.", details={"current_revision": str(configuration.revision)})); }
    pass_score = input.default_pass_score if input.default_pass_score is not None else configuration.default_pass_score;
    mastery = input.mastery_threshold if input.mastery_threshold is not None else configuration.mastery_threshold;
    questions = input.max_assessment_questions if input.max_assessment_questions is not None else configuration.max_assessment_questions;
    minutes = input.default_lesson_minutes if input.default_lesson_minutes is not None else configuration.default_lesson_minutes;
    if not _configuration_valid_values(pass_score, mastery, questions, minutes) { return service_error("COURSE_CONFIGURATION_INVALID", "Course configuration is invalid."); }
    if input.supports_diagnostic_assessment is not None { configuration.supports_diagnostic_assessment = input.supports_diagnostic_assessment; }
    if input.supports_multiple_choice is not None { configuration.supports_multiple_choice = input.supports_multiple_choice; }
    if input.supports_short_answer is not None { configuration.supports_short_answer = input.supports_short_answer; }
    if input.supports_numeric_answer is not None { configuration.supports_numeric_answer = input.supports_numeric_answer; }
    if input.supports_code_challenge is not None { configuration.supports_code_challenge = input.supports_code_challenge; }
    if input.supports_essay is not None { configuration.supports_essay = input.supports_essay; }
    if input.supports_project_activity is not None { configuration.supports_project_activity = input.supports_project_activity; }
    configuration.default_pass_score = pass_score; configuration.mastery_threshold = mastery;
    configuration.max_assessment_questions = questions; configuration.default_lesson_minutes = minutes;
    configuration.revision += 1; configuration.last_modified_by = actor.user_id; configuration.updated_at = service_now();
    return ServiceResult(ok=True, value=course_detail(track));
}

def archive_course_service(actor: ActorContext, track_id: str, expected_revision: int, reason: str | None = None) -> ServiceResult {
    loaded = get_course_service(actor, track_id);
    if not loaded.ok { return loaded; }
    track = repository_find_track(track_id) as LearningTrack;
    if track.revision != expected_revision { return ServiceResult(ok=False, error=ServiceError(code="COURSE_REVISION_CONFLICT", message="The course was updated by another operation.", details={"current_revision": str(track.revision)})); }
    if track.status == LearningTrackStatus.ARCHIVED { return service_error("COURSE_ALREADY_ARCHIVED", "Course is already archived."); }
    if reason is not None and len(reason.strip()) > 500 { return service_error("COURSE_CONFIGURATION_INVALID", "Archive reason is too long."); }
    track.status = LearningTrackStatus.ARCHIVED; track.archived_at = service_now(); track.updated_at = track.archived_at as str;
    track.is_enrollment_open = False; track.revision += 1; track.last_modified_by = actor.user_id;
    return ServiceResult(ok=True, value=course_detail(track));
}

def restore_course_service(actor: ActorContext, track_id: str, expected_revision: int) -> ServiceResult {
    loaded = get_course_service(actor, track_id);
    if not loaded.ok { return loaded; }
    track = repository_find_track(track_id) as LearningTrack;
    if track.revision != expected_revision { return ServiceResult(ok=False, error=ServiceError(code="COURSE_REVISION_CONFLICT", message="The course was updated by another operation.", details={"current_revision": str(track.revision)})); }
    if track.status != LearningTrackStatus.ARCHIVED { return service_error("COURSE_NOT_ARCHIVED", "Course is not archived."); }
    if track.published_at is not None or track.active_version_id is not None { return service_error("COURSE_RESTORE_NOT_ALLOWED", "Published course restoration requires an administrative workflow."); }
    track.status = LearningTrackStatus.DRAFT; track.archived_at = None; track.is_enrollment_open = False;
    track.revision += 1; track.last_modified_by = actor.user_id; track.updated_at = service_now();
    return ServiceResult(ok=True, value=course_detail(track));
}

def duplicate_course_service(actor: ActorContext, track_id: str, client_request_id: str) -> ServiceResult {
    loaded = get_course_service(actor, track_id);
    if not loaded.ok { return loaded; }
    source = repository_find_track(track_id) as LearningTrack;
    configuration = track_configuration(source);
    if configuration is None { return service_error("COURSE_DUPLICATION_FAILED", "Source course configuration is missing."); }
    return create_course_service(actor, CreateCourseTrackInput(
        title=source.title + " Copy", short_description=source.short_description,
        course_code=source.course_code, subject_area=source.subject_area,
        academic_level=source.academic_level,
        estimated_duration_weeks=source.estimated_duration_weeks,
        default_difficulty=source.default_difficulty,
        supports_diagnostic_assessment=configuration.supports_diagnostic_assessment,
        supports_multiple_choice=configuration.supports_multiple_choice,
        supports_short_answer=configuration.supports_short_answer,
        supports_numeric_answer=configuration.supports_numeric_answer,
        supports_code_challenge=configuration.supports_code_challenge,
        supports_essay=configuration.supports_essay,
        supports_project_activity=configuration.supports_project_activity,
        default_pass_score=configuration.default_pass_score,
        mastery_threshold=configuration.mastery_threshold,
        max_assessment_questions=configuration.max_assessment_questions,
        default_lesson_minutes=configuration.default_lesson_minutes,
        client_request_id=client_request_id
    ));
}
