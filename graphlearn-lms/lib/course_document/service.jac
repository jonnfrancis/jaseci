"""Secure, staged course-document upload application service."""

import base64;
import hashlib;
import os;
import re;
import uuid;
import from lib.course_document.repositories { CourseDocumentRepository }
import from lib.course_document.storage_service { CourseDocumentStorageService }
import from lib.course_document.storage_types { StoreCourseDocumentRequest }
import from lib.course_document.validation_service { DocumentSecurityValidationService, DOCUMENT_VALIDATION_POLICY_VERSION }
import from lib.course_document.extraction_service { DOCUMENT_EXTRACTION_SCHEMA_VERSION, DocumentTextExtractionService }
import from lib.learning_track.application_services { service_now }
import from lib.learning_track.repositories { repository_find_track, repository_find_version, repository_version_belongs_to }
import from lib.learning_track.repository_types { ActorContext }
import from lib.observability.events { ObservabilityEvent }
import from lib.observability.logger { emit_event }
import from nodes.curriculum {
    CourseDocument, CourseDocumentError, CourseDocumentProcessingStatus, DocumentValidationContext,
    DocumentValidationStatus, ExtractionRequestContext,
    CourseDocumentUploadResult, CourseDocumentUploadStatus, UploadCourseDocumentInput
}
import from nodes.learning_track { LearningTrackStatus, TrackVersionStatus }

glob PDF_MIME: str = "application/pdf";
glob DOCX_MIME: str = "application/vnd.openxmlformats-officedocument.wordprocessingml.document";

def _error(code: str, message: str, details: dict[str, str] | None = None) -> CourseDocumentUploadResult {
    return CourseDocumentUploadResult(ok=False, error=CourseDocumentError(code=code, message=message, details={} if details is None else details));
}

def _normalized_filename(filename: str) -> str | None {
    if "\x00" in filename { return None; }
    leaf = filename.replace("\\", "/").split("/")[-1].strip();
    if leaf == "" or len(leaf) > 180 or "." not in leaf { return None; }
    pieces = leaf.rsplit(".", 1); stem = re.sub(r"[^a-z0-9]+", "-", pieces[0].lower()).strip("-"); extension = pieces[1].lower();
    if stem == "" { return None; }
    return stem[:150].strip("-") + "." + extension;
}

def _payload(input: UploadCourseDocumentInput) -> tuple[bytes | None, CourseDocumentUploadResult | None] {
    if input.file_size_bytes <= 0 { return (None, _error("COURSE_DOCUMENT_EMPTY", "Course documents cannot be empty.")); }
    maximum = int(os.getenv("COURSE_DOCUMENT_MAX_BYTES", str(25 * 1024 * 1024)));
    minimum = int(os.getenv("COURSE_DOCUMENT_MIN_BYTES", "1"));
    if input.file_size_bytes < minimum { return (None, _error("COURSE_DOCUMENT_EMPTY", "Course documents cannot be empty.")); }
    if input.file_size_bytes > maximum { return (None, _error("COURSE_DOCUMENT_TOO_LARGE", "Course document exceeds the configured size limit.", {"max_bytes": str(maximum)})); }
    try { decoded = base64.b64decode(input.content_base64, validate=True); }
    except Exception { return (None, _error("COURSE_DOCUMENT_UPLOAD_FAILED", "The uploaded document payload is invalid.")); }
    if not isinstance(decoded, bytes) or len(decoded) != input.file_size_bytes { return (None, _error("COURSE_DOCUMENT_CHECKSUM_FAILED", "The uploaded size does not match the document metadata.")); }
    return (decoded as bytes, None);
}

def _result(document: CourseDocument, duplicate: bool = False, replaced_id: str | None = None) -> CourseDocumentUploadResult {
    return CourseDocumentUploadResult(
        ok=True, document_id=document.document_id, track_id=document.track_id,
        track_version_id=document.track_version_id, filename=document.normalized_filename,
        mime_type=document.mime_type, file_size_bytes=document.file_size_bytes,
        upload_status=str(document.upload_status), processing_status=str(document.processing_status),
        duplicate=duplicate, replaced_document_id=replaced_id
    );
}

obj CourseDocumentUploadService {
    has storage_service: CourseDocumentStorageService = CourseDocumentStorageService();
    has repository: CourseDocumentRepository = CourseDocumentRepository();

    def upload(actor: ActorContext, input: UploadCourseDocumentInput) -> CourseDocumentUploadResult {
        if actor.lecturer_id is None { return _error("LECTURER_NOT_AUTHORIZED", "An active lecturer profile is required."); }
        track = repository_find_track(input.track_id);
        if track is None { return _error("TRACK_NOT_FOUND", "Learning track was not found."); }
        version = repository_find_version(track, input.track_version_id);
        if version is None { return _error("TRACK_VERSION_NOT_FOUND", "Track version was not found."); }
        if not repository_version_belongs_to(track, version) { return _error("TRACK_VERSION_MISMATCH", "Track version does not belong to this course."); }
        if track.status == LearningTrackStatus.ARCHIVED { return _error("TRACK_ARCHIVED", "Archived courses cannot accept documents."); }
        if version.status not in [TrackVersionStatus.DRAFT, TrackVersionStatus.REVIEW_REQUIRED, TrackVersionStatus.FAILED] { return _error("TRACK_VERSION_IMMUTABLE", "This track version cannot be modified."); }
        normalized = _normalized_filename(input.original_filename);
        if normalized is None { return _error("COURSE_DOCUMENT_INVALID_FILENAME", "The document filename is invalid."); }
        extension = normalized.rsplit(".", 1)[1]; expected_mime = PDF_MIME if extension == "pdf" else (DOCX_MIME if extension == "docx" else "");
        if expected_mime == "" { return _error("COURSE_DOCUMENT_UNSUPPORTED_TYPE", "Only PDF and DOCX course documents are supported.", {"allowed_extensions": "pdf,docx"}); }
        if input.mime_type != expected_mime { return _error("COURSE_DOCUMENT_MIME_MISMATCH", "The document MIME type does not match its extension."); }
        (payload, payload_error) = _payload(input);
        if payload_error is not None or payload is None { return payload_error as CourseDocumentUploadResult; }
        content = payload as bytes;
        if (extension == "pdf" and not content.startswith(b"%PDF-")) or (extension == "docx" and not content.startswith(b"PK")) { return _error("COURSE_DOCUMENT_SIGNATURE_INVALID", "The document signature is not valid for its declared type."); }
        checksum = hashlib.sha256(content).hexdigest(); scope = actor.user_id + ":" + version.track_version_id + ":" + input.idempotency_key.strip();
        if input.idempotency_key.strip() == "" or len(input.idempotency_key) > 160 { return _error("COURSE_DOCUMENT_UPLOAD_FAILED", "A valid idempotency key is required."); }
        replay = self.repository.find_by_idempotency(version, scope);
        if replay is not None { return _result(replay, True) if replay.checksum == checksum else _error("COURSE_DOCUMENT_IDEMPOTENCY_CONFLICT", "The idempotency key was already used for another document."); }
        duplicate = self.repository.find_by_checksum(version, checksum);
        if duplicate is not None and duplicate.is_active { return _result(duplicate, True); }
        active = self.repository.find_active_for_version(version);
        if active is not None and not input.replace_existing { return _error("COURSE_DOCUMENT_REPLACEMENT_REQUIRED", "Confirm replacement of the current source document."); }
        document_id = "doc_" + uuid.uuid4().hex; upload_id = "upl_" + uuid.uuid4().hex; timestamp = service_now();
        emit_event(ObservabilityEvent(timestamp=timestamp, level="info", event="course_document.upload_started", status="started", message="Course document upload started.", request_id=actor.request_id, correlation_id=actor.request_id, walker_name="upload_course_document", entity_ids={"track_id": track.track_id, "track_version_id": version.track_version_id}, attributes={"mime_type": input.mime_type, "file_size_bytes": input.file_size_bytes}));
        try {
            stored = self.storage_service.store_document(StoreCourseDocumentRequest(document_id=document_id, track_id=track.track_id, track_version_id=version.track_version_id, canonical_extension=extension, client_upload_id=upload_id, uploaded_by=actor.user_id, payload=content));
        } except Exception {
            emit_event(ObservabilityEvent(timestamp=service_now(), level="error", event="course_document.upload_failed", status="failed", message="Course document storage failed.", request_id=actor.request_id, correlation_id=actor.request_id, walker_name="upload_course_document", error_code="COURSE_DOCUMENT_STORAGE_FAILED", entity_ids={"track_id": track.track_id, "track_version_id": version.track_version_id}));
            return _error("STORAGE_WRITE_FAILED", "The course document could not be stored. Retry with the same request key.");
        }
        document = CourseDocument(document_id=document_id, track_id=track.track_id, track_version_id=version.track_version_id, original_filename=input.original_filename, normalized_filename=normalized, mime_type=input.mime_type, file_extension=extension, file_size_bytes=stored.size_bytes, storage_provider=self.storage_service.storage.provider_name(), storage_key=stored.storage_key, checksum_algorithm="sha256", checksum=stored.checksum_sha256, upload_status=CourseDocumentUploadStatus.STORED_PENDING_COMMIT, processing_status=CourseDocumentProcessingStatus.NOT_STARTED, uploaded_by=actor.user_id, uploaded_at=timestamp, updated_at=timestamp, idempotency_scope=scope);
        # Re-check the one-active invariant immediately before graph attachment.
        concurrent = self.repository.find_active_for_version(version);
        if concurrent is not None and (active is None or concurrent.document_id != active.document_id) {
            _ = self.storage_service.register_orphan(stored.storage_key, upload_id, document_id, "CONCURRENT_ACTIVATION_LOST"); return _error("COURSE_DOCUMENT_ALREADY_EXISTS", "Another source document became active. Reload and retry.");
        }
        if not self.repository.attach_to_version(track, version, document, actor.user_id, timestamp) {
            _ = self.storage_service.register_orphan(stored.storage_key, upload_id, document_id, "METADATA_COMMIT_FAILED"); return _error("TRACK_VERSION_MISMATCH", "Document could not be attached to the requested version.");
        }
        document.upload_status = CourseDocumentUploadStatus.STORED;
        replaced_id: str | None = None;
        if active is not None { replaced_id = active.document_id; self.repository.mark_inactive(active, document.document_id, timestamp); }
        # Validate the immutable stored object, never the client byte stream. The service
        # persists a terminal non-processable state on every policy/infrastructure failure.
        validation_result = DocumentSecurityValidationService(storage_service=self.storage_service, repository=self.repository).validate_document(
            document.document_id,
            DocumentValidationContext(document_id=document.document_id, track_id=document.track_id,
                track_version_id=document.track_version_id, actor_id=actor.user_id,
                request_id=actor.request_id, validation_policy_version=DOCUMENT_VALIDATION_POLICY_VERSION)
        );
        if validation_result.status == DocumentValidationStatus.VALIDATED and os.getenv("DOCUMENT_EXTRACTION_AUTO_START", "true").lower() in ["1", "true", "yes", "on"] {
            self.repository.mark_extraction_queued(document);
            _ = DocumentTextExtractionService(storage_service=self.storage_service, document_repository=self.repository).extract_document(
                document.document_id,
                ExtractionRequestContext(document_id=document.document_id, track_id=document.track_id,
                    track_version_id=document.track_version_id, request_id=actor.request_id, actor_id=actor.user_id,
                    extraction_schema_version=DOCUMENT_EXTRACTION_SCHEMA_VERSION)
            );
        }
        emit_event(ObservabilityEvent(timestamp=service_now(), level="info", event="course_document.upload_completed", status="completed", message="Course document upload completed.", request_id=actor.request_id, correlation_id=actor.request_id, walker_name="upload_course_document", entity_ids={"document_id": document.document_id, "track_id": track.track_id, "track_version_id": version.track_version_id}, attributes={"mime_type": document.mime_type, "file_size_bytes": document.file_size_bytes, "checksum_prefix": checksum[:12]}));
        return _result(document, False, replaced_id);
    }
}
