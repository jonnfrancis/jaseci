"""Feature 39 course-document upload tests."""

import base64;
import from uuid { uuid4 }
import from lib.course_document.repositories { CourseDocumentRepository }
import from lib.course_document.service { CourseDocumentUploadService, PDF_MIME }
import from lib.learning_track.course_management { create_course_service }
import from lib.learning_track.repositories { repository_find_track, repository_versions }
import from lib.learning_track.repository_types { ActorContext }
import from nodes.curriculum { CourseDocumentUploadStatus, UploadCourseDocumentInput }
import from nodes.learning_track { CreateCourseTrackInput, LearningTrack, LecturerCourseDetail, TrackVersionStatus }

def _actor(suffix: str) -> ActorContext { return ActorContext(user_id="user_" + suffix, lecturer_id="lecturer_" + suffix, request_id="request_" + suffix, roles=["LECTURER"]); }

def _setup(suffix: str) -> tuple[ActorContext, LearningTrack, str] {
    actor = _actor(suffix); created = create_course_service(actor, CreateCourseTrackInput(title="Document Course " + suffix[:6], client_request_id="course_" + suffix));
    detail = created.value as LecturerCourseDetail; track = repository_find_track(detail.track.track_id) as LearningTrack; version = repository_versions(track)[0];
    return (actor, track, version.track_version_id);
}

def _pdf_input(track_id: str, version_id: str, key: str, body: bytes = b"%PDF-1.7\nGraphLearn notes") -> UploadCourseDocumentInput {
    return UploadCourseDocumentInput(track_id=track_id, track_version_id=version_id, original_filename="Database Notes.pdf", mime_type=PDF_MIME, file_size_bytes=len(body), idempotency_key=key, content_base64=base64.b64encode(body).decode("ascii"));
}

test "valid PDF is stored and attached to its draft version" {
    suffix = uuid4().hex; (actor, track, version_id) = _setup(suffix); result = CourseDocumentUploadService().upload(actor, _pdf_input(track.track_id, version_id, "upload_" + suffix));
    version = repository_versions(track)[0]; active = CourseDocumentRepository().find_active_for_version(version);
    assert result.ok and result.document_id is not None and result.upload_status == "STORED" and result.processing_status == "NOT_STARTED";
    assert active is not None and active.document_id == result.document_id and active.upload_status == CourseDocumentUploadStatus.STORED;
    assert active.track_id == track.track_id and active.track_version_id == version_id and "/" + active.document_id + "/source.pdf" in active.storage_key;
}

test "duplicate retry and checksum are idempotent" {
    suffix = uuid4().hex; (actor, track, version_id) = _setup(suffix); input = _pdf_input(track.track_id, version_id, "retry_" + suffix); service = CourseDocumentUploadService();
    first = service.upload(actor, input); replay = service.upload(actor, input); version = repository_versions(track)[0];
    assert first.ok and replay.ok and replay.duplicate and first.document_id == replay.document_id;
    assert len(CourseDocumentRepository().list_for_version(version)) == 1;
}

test "replacement is explicit and preserves one active document" {
    suffix = uuid4().hex; (actor, track, version_id) = _setup(suffix); service = CourseDocumentUploadService(); first = service.upload(actor, _pdf_input(track.track_id, version_id, "first_" + suffix));
    second_input = _pdf_input(track.track_id, version_id, "second_" + suffix, b"%PDF-1.7\nReplacement notes"); denied = service.upload(actor, second_input);
    assert not denied.ok and denied.error is not None and denied.error.code == "COURSE_DOCUMENT_REPLACEMENT_REQUIRED";
    second_input.replace_existing = True; replaced = service.upload(actor, second_input); version = repository_versions(track)[0];
    assert replaced.ok and replaced.replaced_document_id == first.document_id and len(CourseDocumentRepository().list_for_version(version)) == 1 and len(CourseDocumentRepository().list_for_version(version, True)) == 2;
}

test "unsupported and immutable uploads fail safely" {
    suffix = uuid4().hex; (actor, track, version_id) = _setup(suffix); service = CourseDocumentUploadService(); bad = _pdf_input(track.track_id, version_id, "bad_" + suffix); bad.original_filename = "notes.exe"; bad.mime_type = "application/octet-stream";
    rejected = service.upload(actor, bad); assert not rejected.ok and rejected.error is not None and rejected.error.code == "COURSE_DOCUMENT_UNSUPPORTED_TYPE";
    version = repository_versions(track)[0]; version.status = TrackVersionStatus.PUBLISHED; immutable = service.upload(actor, _pdf_input(track.track_id, version_id, "published_" + suffix));
    assert not immutable.ok and immutable.error is not None and immutable.error.code == "TRACK_VERSION_IMMUTABLE";
}
