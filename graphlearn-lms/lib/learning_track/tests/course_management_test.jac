"""Feature 37 lecturer course management service tests."""

import from uuid { uuid4 }
import from lib.learning_track.course_management {
    archive_course_service, create_course_service, get_course_service,
    restore_course_service, update_course_service
}
import from lib.learning_track.repositories { repository_find_track, repository_versions }
import from lib.learning_track.repository_types { ActorContext }
import from lib.learning_track.service { track_configuration }
import from nodes.learning_track {
    CreateCourseTrackInput, LearningTrack, LearningTrackStatus,
    LearningTrackType, LearningTrackVisibility, LecturerCourseDetail,
    TrackOwnershipType, UpdateCourseTrackInput
}

def _actor(suffix: str) -> ActorContext {
    return ActorContext(user_id="user_" + suffix, lecturer_id="lecturer_" + suffix, request_id="request_" + suffix, roles=["LECTURER"]);
}

test "course creation builds a private draft aggregate" {
    suffix = str(uuid4()).replace("-", ""); actor = _actor(suffix);
    result = create_course_service(actor, CreateCourseTrackInput(title="Database Management Systems", short_description="Relational design and query fundamentals.", client_request_id="create_" + suffix));
    assert result.ok; assert isinstance(result.value, LecturerCourseDetail);
    detail = result.value as LecturerCourseDetail;
    track = repository_find_track(detail.track.track_id);
    assert track is not None;
    created = track as LearningTrack;
    assert created.track_type == LearningTrackType.LECTURER_COURSE;
    assert created.ownership_type == TrackOwnershipType.LECTURER;
    assert created.owner_id == actor.lecturer_id;
    assert created.status == LearningTrackStatus.DRAFT;
    assert created.visibility == LearningTrackVisibility.PRIVATE;
    assert not created.is_enrollment_open;
    assert created.active_version_id is None;
    assert len(repository_versions(created)) == 1;
    assert track_configuration(created) is not None;
}

test "course creation is idempotent and rejects changed payload" {
    suffix = str(uuid4()).replace("-", ""); actor = _actor(suffix); key = "idem_" + suffix;
    first = create_course_service(actor, CreateCourseTrackInput(title="Operating Systems", client_request_id=key));
    replay = create_course_service(actor, CreateCourseTrackInput(title="Operating Systems", client_request_id=key));
    conflict = create_course_service(actor, CreateCourseTrackInput(title="Distributed Systems", client_request_id=key));
    assert first.ok and replay.ok and replay.replayed;
    assert (first.value as LecturerCourseDetail).track.track_id == (replay.value as LecturerCourseDetail).track.track_id;
    assert not conflict.ok and conflict.error is not None and conflict.error.code == "IDEMPOTENCY_KEY_PAYLOAD_CONFLICT";
}

test "course updates enforce optimistic revision" {
    suffix = str(uuid4()).replace("-", ""); actor = _actor(suffix);
    created = create_course_service(actor, CreateCourseTrackInput(title="Computer Networks", client_request_id="revision_" + suffix));
    detail = created.value as LecturerCourseDetail;
    updated = update_course_service(actor, UpdateCourseTrackInput(track_id=detail.track.track_id, expected_revision=1, title="Advanced Computer Networks"));
    stale = update_course_service(actor, UpdateCourseTrackInput(track_id=detail.track.track_id, expected_revision=1, title="Stale title"));
    assert updated.ok and (updated.value as LecturerCourseDetail).track.revision == 2;
    assert not stale.ok and stale.error is not None and stale.error.code == "COURSE_REVISION_CONFLICT";
}

test "unpublished course archives and restores without opening enrollment" {
    suffix = str(uuid4()).replace("-", ""); actor = _actor(suffix);
    created = create_course_service(actor, CreateCourseTrackInput(title="Data Structures", client_request_id="lifecycle_" + suffix));
    detail = created.value as LecturerCourseDetail;
    archived = archive_course_service(actor, detail.track.track_id, detail.track.revision, "Semester complete");
    archived_detail = archived.value as LecturerCourseDetail;
    assert archived.ok and archived_detail.track.status == LearningTrackStatus.ARCHIVED and not archived_detail.track.is_enrollment_open;
    restored = restore_course_service(actor, detail.track.track_id, archived_detail.track.revision);
    assert restored.ok and (restored.value as LecturerCourseDetail).track.status == LearningTrackStatus.DRAFT;
    assert not (restored.value as LecturerCourseDetail).track.is_enrollment_open;
}
