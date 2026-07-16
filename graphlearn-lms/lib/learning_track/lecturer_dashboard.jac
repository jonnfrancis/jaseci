"""Authorization-scoped, read-only lecturer dashboard projection."""

import from edges.domain_edges { HAS_BLUEPRINT, HAS_SOURCE_DOCUMENT }
import from lib.learning_track.course_management { compute_course_readiness }
import from lib.learning_track.repositories { repository_list_owned, repository_versions }
import from lib.learning_track.repository_types { ActorContext, PageRequest, ServiceResult }
import from lib.learning_track.application_services { service_error, service_now }
import from nodes.curriculum { CourseBlueprint, CourseDocument }
import from nodes.learning_track { LearningTrack, LearningTrackStatus, LearningTrackType, TrackVersion, TrackVersionStatus }
import from nodes.lecturer_dashboard {
    CourseDashboardAction, CourseDashboardPermissions, CourseProcessingState, CourseReadinessState,
    LecturerCourseDashboardItem, LecturerCourseSort, LecturerDashboardFilterOptions,
    LecturerDashboardQuery, LecturerDashboardResponse, LecturerDashboardSummary, SortDirection
}

def _readiness(track: LearningTrack, versions: list[TrackVersion]) -> tuple[CourseReadinessState, int, int, CourseProcessingState | None, str | None] {
    if track.status == LearningTrackStatus.ARCHIVED { return (CourseReadinessState.ARCHIVED, 100 if track.published_at is not None else 0, 0, None, None); }
    base = compute_course_readiness(track); draft: TrackVersion | None = None;
    for version in versions { if version.status in [TrackVersionStatus.DRAFT, TrackVersionStatus.REVIEW_REQUIRED, TrackVersionStatus.APPROVED] { draft = version; } }
    documents: list[CourseDocument] = [];
    blueprints: list[CourseBlueprint] = [];
    if draft is not None { documents = [draft ->:HAS_SOURCE_DOCUMENT:->[?:CourseDocument]]; blueprints = [draft ->:HAS_BLUEPRINT:->[?:CourseBlueprint]]; }
    processing: CourseProcessingState | None = None; error_code: str | None = None;
    for document in documents {
        state = document.processing_status.upper();
        if state == "FAILED" { processing = CourseProcessingState.FAILED; error_code = "DOCUMENT_PROCESSING_FAILED"; }
        elif state == "QUEUED" { processing = CourseProcessingState.QUEUED; }
        elif state == "EXTRACTING" { processing = CourseProcessingState.EXTRACTING; }
        elif state == "CHUNKING" { processing = CourseProcessingState.CHUNKING; }
        elif state in ["ANALYZING", "PROCESSING"] { processing = CourseProcessingState.ANALYZING; }
        elif state == "GENERATING_BLUEPRINT" { processing = CourseProcessingState.GENERATING_BLUEPRINT; }
        elif state == "VALIDATING" { processing = CourseProcessingState.VALIDATING; }
        elif state == "COMPLETED" { processing = CourseProcessingState.COMPLETED; }
    }
    extraction_complete = processing is not None and processing == CourseProcessingState.COMPLETED;
    percent = (15 if base.metadata_complete else 0) + (10 if base.initial_version_valid else 0) + (10 if base.configuration_valid else 0) + (15 if len(documents) > 0 else 0) + (10 if extraction_complete else 0) + (15 if len(blueprints) > 0 else 0) + (15 if base.blueprint_review_complete else 0) + (10 if base.publication_ready else 0);
    if processing == CourseProcessingState.FAILED or track.status == LearningTrackStatus.FAILED { return (CourseReadinessState.PROCESSING_FAILED, percent, len(documents), processing, error_code); }
    if not base.metadata_complete { return (CourseReadinessState.METADATA_INCOMPLETE, percent, len(documents), processing, error_code); }
    if processing is not None and processing not in [CourseProcessingState.COMPLETED, CourseProcessingState.FAILED] { return (CourseReadinessState.PROCESSING, percent, len(documents), processing, error_code); }
    if track.status == LearningTrackStatus.REVIEW_REQUIRED or (len(blueprints) > 0 and not base.blueprint_review_complete) { return (CourseReadinessState.REVIEW_REQUIRED, percent, len(documents), processing, error_code); }
    if track.status == LearningTrackStatus.PUBLISHED and draft is not None { return (CourseReadinessState.PUBLISHED_WITH_DRAFT_UPDATE, 100, len(documents), processing, error_code); }
    if track.status == LearningTrackStatus.PUBLISHED { return (CourseReadinessState.PUBLISHED, 100, len(documents), processing, error_code); }
    if base.publication_ready { return (CourseReadinessState.READY_TO_PUBLISH, percent, len(documents), processing, error_code); }
    if len(documents) > 0 { return (CourseReadinessState.DOCUMENT_UPLOADED, percent, len(documents), processing, error_code); }
    return (CourseReadinessState.READY_FOR_DOCUMENT, percent, 0, processing, error_code);
}

def _permissions(track: LearningTrack, can_publish: bool) -> CourseDashboardPermissions {
    archived = track.status == LearningTrackStatus.ARCHIVED;
    return CourseDashboardPermissions(can_view=True, can_edit_metadata=not archived and track.status != LearningTrackStatus.PUBLISHED, can_upload_document=not archived and track.status != LearningTrackStatus.PUBLISHED, can_start_processing=not archived, can_retry_processing=not archived, can_review_blueprint=not archived, can_publish=can_publish and not archived, can_open_enrollment=can_publish and track.status == LearningTrackStatus.PUBLISHED, can_close_enrollment=can_publish and track.is_enrollment_open, can_view_learners=track.status == LearningTrackStatus.PUBLISHED, can_archive=not archived, can_restore=archived and track.published_at is None);
}

def _action(state: CourseReadinessState, permissions: CourseDashboardPermissions) -> CourseDashboardAction {
    if state == CourseReadinessState.METADATA_INCOMPLETE and permissions.can_edit_metadata { return CourseDashboardAction.COMPLETE_METADATA; }
    if state == CourseReadinessState.READY_FOR_DOCUMENT and permissions.can_upload_document { return CourseDashboardAction.UPLOAD_DOCUMENT; }
    if state == CourseReadinessState.DOCUMENT_UPLOADED and permissions.can_start_processing { return CourseDashboardAction.START_PROCESSING; }
    if state == CourseReadinessState.PROCESSING { return CourseDashboardAction.VIEW_PROCESSING; }
    if state == CourseReadinessState.PROCESSING_FAILED and permissions.can_retry_processing { return CourseDashboardAction.RETRY_PROCESSING; }
    if state == CourseReadinessState.REVIEW_REQUIRED and permissions.can_review_blueprint { return CourseDashboardAction.REVIEW_BLUEPRINT; }
    if state == CourseReadinessState.READY_TO_PUBLISH and permissions.can_publish { return CourseDashboardAction.PUBLISH_COURSE; }
    if state == CourseReadinessState.PUBLISHED_WITH_DRAFT_UPDATE { return CourseDashboardAction.CONTINUE_DRAFT_UPDATE; }
    if state == CourseReadinessState.ARCHIVED and permissions.can_restore { return CourseDashboardAction.RESTORE_COURSE; }
    return CourseDashboardAction.VIEW_COURSE if permissions.can_view else CourseDashboardAction.NONE;
}

def get_lecturer_dashboard_service(actor: ActorContext, display_name: str, can_publish: bool, query: LecturerDashboardQuery) -> ServiceResult {
    if actor.lecturer_id is None { return service_error("LECTURER_PROFILE_REQUIRED", "An active lecturer profile is required."); }
    if query.page < 1 or query.page_size < 1 or query.page_size > 100 { return service_error("DASHBOARD_QUERY_INVALID", "Dashboard pagination is invalid."); }
    search = query.search.strip().lower() if query.search is not None else "";
    if len(search) > 120 { return service_error("DASHBOARD_QUERY_INVALID", "Dashboard search is too long."); }
    raw = repository_list_owned(actor.lecturer_id, PageRequest(limit=100, cursor=None)); all_items: list[LecturerCourseDashboardItem] = [];
    subjects: list[str] = []; statuses: list[LearningTrackStatus] = []; visibilities = [];
    generated = service_now(); summary = LecturerDashboardSummary(lecturer_id=actor.lecturer_id, display_name=display_name, generated_at=generated);
    for value in raw.items {
        if not isinstance(value, LearningTrack) or value.track_type != LearningTrackType.LECTURER_COURSE { continue; }
        track = value as LearningTrack; versions = repository_versions(track); (state, percent, document_count, processing, error_code) = _readiness(track, versions);
        if track.status == LearningTrackStatus.ARCHIVED and not query.include_archived { continue; }
        summary.total_courses += 1;
        if track.status == LearningTrackStatus.ARCHIVED { summary.archived_courses += 1; }
        elif track.status == LearningTrackStatus.PUBLISHED { summary.published_courses += 1; }
        else { summary.draft_courses += 1; }
        if state == CourseReadinessState.PROCESSING { summary.processing_courses += 1; }
        if state == CourseReadinessState.REVIEW_REQUIRED { summary.review_required_courses += 1; }
        if state in [CourseReadinessState.PROCESSING_FAILED, CourseReadinessState.METADATA_INCOMPLETE] { summary.failed_courses += 1; }
        if track.status not in statuses { statuses.append(track.status); }
        if track.visibility not in visibilities { visibilities.append(track.visibility); }
        if track.subject_area is not None and track.subject_area not in subjects { subjects.append(track.subject_area); }
        if search != "" and search not in track.title.lower() and search not in (track.course_code or "").lower() and search not in track.slug.lower() and search not in (track.subject_area or "").lower() { continue; }
        if len(query.statuses) > 0 and track.status not in query.statuses { continue; }
        if len(query.readiness_states) > 0 and state not in query.readiness_states { continue; }
        if len(query.visibilities) > 0 and track.visibility not in query.visibilities { continue; }
        if len(query.subject_areas) > 0 and (track.subject_area is None or track.subject_area not in query.subject_areas) { continue; }
        draft: TrackVersion | None = None; active: TrackVersion | None = None;
        for version in versions { if track.active_version_id == version.track_version_id { active = version; } elif version.status in [TrackVersionStatus.DRAFT, TrackVersionStatus.REVIEW_REQUIRED, TrackVersionStatus.APPROVED] { draft = version; } }
        permissions = _permissions(track, can_publish);
        draft_id: str | None = None; draft_number: int | None = None; active_number: int | None = None;
        if draft is not None { current_draft = draft as TrackVersion; draft_id = current_draft.track_version_id; draft_number = current_draft.version_number; }
        if active is not None { current_active = active as TrackVersion; active_number = current_active.version_number; }
        all_items.append(LecturerCourseDashboardItem(track_id=track.track_id, title=track.title, slug=track.slug, short_description=track.short_description, track_type=track.track_type, status=track.status, visibility=track.visibility, created_at=track.created_at, updated_at=track.updated_at, actor_permissions=permissions, readiness_state=state, next_action=_action(state, permissions), readiness_percent=percent, source_document_count=document_count, active_version_id=track.active_version_id, draft_version_id=draft_id, course_code=track.course_code, subject_area=track.subject_area, academic_level=track.academic_level, is_enrollment_open=track.is_enrollment_open, active_version_number=active_number, draft_version_number=draft_number, processing_state=processing, processing_error_code=error_code, published_at=track.published_at, archived_at=track.archived_at));
    }
    if query.sort_by == LecturerCourseSort.TITLE { all_items.sort(key=lambda i: LecturerCourseDashboardItem : i.title.lower(), reverse=query.sort_direction == SortDirection.DESC); }
    elif query.sort_by == LecturerCourseSort.CREATED_AT { all_items.sort(key=lambda i: LecturerCourseDashboardItem : i.created_at, reverse=query.sort_direction == SortDirection.DESC); }
    else { all_items.sort(key=lambda i: LecturerCourseDashboardItem : i.updated_at, reverse=query.sort_direction == SortDirection.DESC); }
    total = len(all_items); start = (query.page - 1) * query.page_size; pages = (total + query.page_size - 1) // query.page_size;
    return ServiceResult(ok=True, value=LecturerDashboardResponse(summary=summary, courses=all_items[start:start + query.page_size], available_filters=LecturerDashboardFilterOptions(statuses=statuses, readiness_states=list(CourseReadinessState), visibilities=visibilities, subject_areas=sorted(subjects)), generated_at=generated, page=query.page, page_size=query.page_size, total_items=total, total_pages=pages));
}
