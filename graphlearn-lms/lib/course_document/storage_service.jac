"""Trusted storage service for course-document bytes and operational recovery."""

import hashlib;
import os;
import uuid;
import from datetime { datetime, timedelta, timezone }
import from lib.course_document.repositories { CourseDocumentRepository }
import from lib.course_document.storage { CourseDocumentStorage, JacCourseDocumentStorage }
import from lib.course_document.storage_key_builder { StorageKeyBuilder }
import from lib.course_document.storage_types {
    AuthorizedDocumentContext, StorageAuditResult, StorageCleanupResult, StorageDeleteResult,
    StorageHealthResult, StorageHealthStatus, StorageIntegrityResult, StoreCourseDocumentRequest,
    StoredCourseDocument
}
import from lib.learning_track.application_services { service_now }
import from lib.learning_track.repositories { repository_find_track, repository_find_version }
import from nodes.curriculum { CourseDocument, CourseDocumentUploadStatus, StorageOrphanCandidate }
import from nodes.learning_track { TrackVersionStatus }

obj CourseDocumentStorageService {
    has storage: CourseDocumentStorage = JacCourseDocumentStorage();
    has repository: CourseDocumentRepository = CourseDocumentRepository();
    has keys: StorageKeyBuilder = StorageKeyBuilder();

    def postinit {
        self.keys.temp_prefix = os.getenv("COURSE_DOCUMENT_TMP_PREFIX", "_tmp").strip("/");
        self.keys.trash_prefix = os.getenv("COURSE_DOCUMENT_TRASH_PREFIX", "_trash").strip("/");
    }

    def store_document(request: StoreCourseDocumentRequest) -> StoredCourseDocument {
        final_key = self.keys.build_course_document_key(request.track_id, request.track_version_id, request.document_id, request.canonical_extension);
        temp_key = self.keys.build_temp_key(request.client_upload_id, request.canonical_extension);
        checksum = hashlib.sha256(request.payload).hexdigest(); size = len(request.payload);
        try {
            if self.storage.exists(final_key) { raise FileExistsError("STORAGE_DUPLICATE_DOCUMENT"); }
            if self.storage.exists(temp_key) { _ = self.storage.delete(temp_key); }
            if not self.storage.put(temp_key, request.payload) { raise IOError("STORAGE_WRITE_FAILED"); }
            temporary = self.storage.metadata(temp_key);
            if temporary.size_bytes != size { raise IOError("STORAGE_SIZE_MISMATCH"); }
            if not self.storage.move(temp_key, final_key) { raise IOError("STORAGE_MOVE_FAILED"); }
            stored = self.storage.metadata(final_key);
            if stored.size_bytes != size { raise IOError("STORAGE_SIZE_MISMATCH"); }
            if hashlib.sha256(self.storage.read(final_key)).hexdigest() != checksum { raise IOError("STORAGE_CHECKSUM_MISMATCH"); }
            return StoredCourseDocument(storage_key=final_key, size_bytes=size, checksum_sha256=checksum, stored_at=service_now());
        } except Exception {
            try { if self.storage.exists(temp_key) { _ = self.storage.delete(temp_key); } } except Exception {}
            raise;
        }
    }

    def verify_integrity(document: CourseDocument) -> StorageIntegrityResult {
        try {
            if not self.keys.validate_key(document.storage_key) or not document.storage_key.startswith("course-documents/") { return StorageIntegrityResult(valid=False, object_exists=False, size_matches=False, checksum_matches=False, error_code="STORAGE_KEY_INVALID"); }
            if not self.storage.exists(document.storage_key) { return StorageIntegrityResult(valid=False, object_exists=False, size_matches=False, checksum_matches=False, error_code="STORAGE_OBJECT_NOT_FOUND"); }
            metadata = self.storage.metadata(document.storage_key); size_matches = metadata.size_bytes == document.file_size_bytes;
            checksum_matches = hashlib.sha256(self.storage.read(document.storage_key)).hexdigest() == document.checksum;
            code: str | None = None;
            if not size_matches { code = "STORAGE_SIZE_MISMATCH"; }
            elif not checksum_matches { code = "STORAGE_CHECKSUM_MISMATCH"; }
            return StorageIntegrityResult(valid=size_matches and checksum_matches, object_exists=True, size_matches=size_matches, checksum_matches=checksum_matches, error_code=code);
        } except Exception { return StorageIntegrityResult(valid=False, object_exists=False, size_matches=False, checksum_matches=False, error_code="STORAGE_READ_FAILED"); }
    }

    def open_for_processing(document: CourseDocument, context: AuthorizedDocumentContext) -> bytes {
        if document.document_id != context.document_id or document.track_id != context.track_id or document.track_version_id != context.track_version_id { raise PermissionError("STORAGE_DOCUMENT_NOT_AVAILABLE"); }
        if document.upload_status != CourseDocumentUploadStatus.STORED or document.deleted_at is not None { raise PermissionError("STORAGE_DOCUMENT_NOT_AVAILABLE"); }
        integrity = self.verify_integrity(document);
        if not integrity.valid { raise IOError(integrity.error_code or "STORAGE_INTEGRITY_MISMATCH"); }
        return self.storage.read(document.storage_key);
    }

    def delete_document(document: CourseDocument, context: AuthorizedDocumentContext) -> StorageDeleteResult {
        if document.document_id != context.document_id or document.track_id != context.track_id or document.track_version_id != context.track_version_id { return StorageDeleteResult(ok=False, error_code="STORAGE_DOCUMENT_NOT_AVAILABLE"); }
        track = repository_find_track(context.track_id); version = None if track is None else repository_find_version(track, context.track_version_id);
        if version is None or version.status in [TrackVersionStatus.PUBLISHED, TrackVersionStatus.SUPERSEDED] or document.processing_status not in ["NOT_STARTED", "FAILED"] { return StorageDeleteResult(ok=False, error_code="STORAGE_DOCUMENT_PROTECTED"); }
        document.upload_status = CourseDocumentUploadStatus.DELETING;
        try {
            trash_key = self.keys.build_trash_key(document.document_id, service_now(), document.file_extension);
            if self.storage.exists(document.storage_key) and not self.storage.move(document.storage_key, trash_key) { raise IOError("STORAGE_MOVE_FAILED"); }
            document.upload_status = CourseDocumentUploadStatus.DELETED; document.is_active = False; document.deleted_at = service_now(); document.updated_at = document.deleted_at as str;
            return StorageDeleteResult(ok=True, deleted=True, trash_key=trash_key);
        } except Exception { document.upload_status = CourseDocumentUploadStatus.FAILED; return StorageDeleteResult(ok=False, error_code="STORAGE_DELETE_FAILED"); }
    }

    def register_orphan(storage_key: str, upload_id: str | None, document_id: str | None, reason: str) -> StorageOrphanCandidate {
        now = datetime.now(timezone.utc); grace = int(os.getenv("COURSE_DOCUMENT_ORPHAN_GRACE_MINUTES", "60"));
        candidate = StorageOrphanCandidate(orphan_id="orphan_" + uuid.uuid4().hex, storage_key=storage_key, upload_id=upload_id, document_id=document_id, reason=reason, detected_at=now.isoformat(), eligible_for_cleanup_at=(now + timedelta(minutes=grace)).isoformat());
        self.repository.record_orphan(candidate); return candidate;
    }

    def cleanup_orphan(candidate: StorageOrphanCandidate, now: str = "") -> StorageCleanupResult {
        current = now if now != "" else service_now();
        if candidate.cleanup_status != "PENDING" or current < candidate.eligible_for_cleanup_at { return StorageCleanupResult(ok=True, cleaned=False); }
        if self.repository.storage_key_is_referenced(candidate.storage_key) { return StorageCleanupResult(ok=False, error_code="STORAGE_DOCUMENT_PROTECTED"); }
        try {
            if self.storage.exists(candidate.storage_key) { _ = self.storage.delete(candidate.storage_key); }
            candidate.cleanup_status = "DELETED"; return StorageCleanupResult(ok=True, cleaned=True);
        } except Exception { candidate.cleanup_status = "FAILED"; candidate.cleanup_error_code = "STORAGE_ORPHAN_CLEANUP_FAILED"; return StorageCleanupResult(ok=False, error_code=candidate.cleanup_error_code); }
    }

    def health_check -> StorageHealthResult {
        deployment = os.getenv("COURSE_DOCUMENT_DEPLOYMENT_MODE", "development").lower();
        if deployment in ["scaled", "multi-pod", "multi-instance"] and self.storage.provider_name() == "local" { return StorageHealthResult(status=StorageHealthStatus.UNAVAILABLE, backend="local", error_code="STORAGE_CONFIGURATION_INVALID"); }
        probe = self.keys.build_temp_key("probe_" + uuid.uuid4().hex, "pdf");
        try {
            if not self.storage.put(probe, b"probe") or self.storage.read(probe) != b"probe" or not self.storage.delete(probe) { return StorageHealthResult(status=StorageHealthStatus.DEGRADED, backend=self.storage.provider_name(), error_code="STORAGE_UNAVAILABLE"); }
            return StorageHealthResult(status=StorageHealthStatus.HEALTHY, backend=self.storage.provider_name());
        } except Exception { try { _ = self.storage.delete(probe); } except Exception {} return StorageHealthResult(status=StorageHealthStatus.UNAVAILABLE, backend=self.storage.provider_name(), error_code="STORAGE_UNAVAILABLE"); }
    }

    def audit_documents(documents: list[CourseDocument]) -> StorageAuditResult {
        result = StorageAuditResult(documents_checked=len(documents), orphans=len([c for c in self.repository.orphan_candidates() if c.cleanup_status == "PENDING"]));
        for document in documents {
            integrity = self.verify_integrity(document);
            if integrity.valid { result.healthy += 1; }
            elif not integrity.object_exists { result.missing += 1; }
            else { result.integrity_mismatch += 1; }
        }
        return result;
    }
}
