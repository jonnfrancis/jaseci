"""Graph-safe repositories for version-owned course documents."""

import from edges.domain_edges { HAS_LECTURER_PROFILE, HAS_SOURCE_DOCUMENT, HAS_STORAGE_ORPHAN, HAS_TRACK_VERSION, OWNS_TRACK }
import from lib.learning_track.repositories { repository_version_belongs_to }
import from nodes.curriculum { CourseDocument, CourseDocumentProcessingStatus, CourseDocumentUploadStatus, DocumentExtractionStatus, DocumentValidationStatus, StorageOrphanCandidate }
import from nodes.learning_track { LearningTrack, TrackVersion }
import from nodes.identity { LecturerProfile }

obj CourseDocumentRepository {
    def list_for_version(version: TrackVersion, include_inactive: bool = False) -> list[CourseDocument] {
        documents: list[CourseDocument] = [version ->:HAS_SOURCE_DOCUMENT:->[?:CourseDocument]];
        return [item for item in documents if item.track_version_id == version.track_version_id and (include_inactive or item.is_active)];
    }
    def find_active_for_version(version: TrackVersion) -> CourseDocument | None {
        for item in self.list_for_version(version) { if item.upload_status == CourseDocumentUploadStatus.STORED { return item; } }
        return None;
    }
    def find_by_checksum(version: TrackVersion, checksum: str) -> CourseDocument | None {
        for item in self.list_for_version(version, True) { if item.checksum == checksum { return item; } }
        return None;
    }
    def find_by_idempotency(version: TrackVersion, scope: str) -> CourseDocument | None {
        for item in self.list_for_version(version, True) { if item.idempotency_scope == scope { return item; } }
        return None;
    }
    def find_by_id(version: TrackVersion, document_id: str) -> CourseDocument | None {
        for item in self.list_for_version(version, True) { if item.document_id == document_id { return item; } }
        return None;
    }
    def mark_validation_started(document: CourseDocument, policy_version: int, timestamp: str) -> bool {
        if document.validation_status == DocumentValidationStatus.VALIDATING { return False; }
        document.validation_status = DocumentValidationStatus.VALIDATING; document.validation_version = policy_version;
        document.validation_error_code = None; document.validation_error_message = None; document.updated_at = timestamp;
        return True;
    }
    def mark_validated(document: CourseDocument, timestamp: str) {
        document.validation_status = DocumentValidationStatus.VALIDATED; document.validated_at = timestamp;
        document.validated_by_service = "document-security-validation"; document.validation_error_code = None;
        document.validation_error_message = None; document.updated_at = timestamp;
    }
    def mark_rejected(document: CourseDocument, code: str, message: str, timestamp: str) {
        document.validation_status = DocumentValidationStatus.REJECTED; document.validation_error_code = code;
        document.validation_error_message = message; document.validated_at = timestamp; document.updated_at = timestamp;
    }
    def mark_quarantined(document: CourseDocument, code: str, message: str, timestamp: str) {
        document.validation_status = DocumentValidationStatus.QUARANTINED; document.validation_error_code = code;
        document.validation_error_message = message; document.validated_at = timestamp; document.updated_at = timestamp;
    }
    def mark_validation_failed(document: CourseDocument, code: str, message: str, timestamp: str) {
        document.validation_status = DocumentValidationStatus.VALIDATION_FAILED; document.validation_error_code = code;
        document.validation_error_message = message; document.validated_at = timestamp; document.updated_at = timestamp;
    }
    def get_validation_state(version: TrackVersion, document_id: str) -> DocumentValidationStatus | None {
        item = self.find_by_id(version, document_id); return None if item is None else item.validation_status;
    }
    def find_validation_candidates(version: TrackVersion) -> list[CourseDocument] {
        return [item for item in self.list_for_version(version, True) if item.validation_status in [DocumentValidationStatus.PENDING, DocumentValidationStatus.VALIDATION_FAILED]];
    }
    def find_duplicate_for_version(version: TrackVersion, checksum: str, exclude_document_id: str = "") -> CourseDocument | None {
        for item in self.list_for_version(version, True) { if item.checksum == checksum and item.document_id != exclude_document_id { return item; } }
        return None;
    }
    def mark_extraction_queued(document: CourseDocument) { document.extraction_status = DocumentExtractionStatus.QUEUED; document.processing_status = CourseDocumentProcessingStatus.QUEUED; }
    def mark_extracting(document: CourseDocument) -> bool {
        if document.extraction_status == DocumentExtractionStatus.EXTRACTING { return False; }
        document.extraction_status = DocumentExtractionStatus.EXTRACTING; document.processing_status = CourseDocumentProcessingStatus.EXTRACTING; return True;
    }
    def mark_extracted(document: CourseDocument, timestamp: str) { document.extraction_status = DocumentExtractionStatus.EXTRACTED; document.processing_status = CourseDocumentProcessingStatus.EXTRACTED; document.processing_error_code = None; document.processing_error_message = None; document.updated_at = timestamp; }
    def mark_ocr_required(document: CourseDocument, code: str, message: str, timestamp: str) { document.extraction_status = DocumentExtractionStatus.OCR_REQUIRED; document.processing_status = CourseDocumentProcessingStatus.OCR_REQUIRED; document.processing_error_code = code; document.processing_error_message = message; document.updated_at = timestamp; }
    def mark_no_extractable_text(document: CourseDocument, code: str, message: str, timestamp: str) { document.extraction_status = DocumentExtractionStatus.NO_EXTRACTABLE_TEXT; document.processing_status = CourseDocumentProcessingStatus.NO_EXTRACTABLE_TEXT; document.processing_error_code = code; document.processing_error_message = message; document.updated_at = timestamp; }
    def mark_extraction_failed(document: CourseDocument, code: str, message: str, timestamp: str) { document.extraction_status = DocumentExtractionStatus.EXTRACTION_FAILED; document.processing_status = CourseDocumentProcessingStatus.FAILED; document.processing_error_code = code; document.processing_error_message = message; document.updated_at = timestamp; }
    def attach_to_version(track: LearningTrack, version: TrackVersion, document: CourseDocument, actor_id: str, attached_at: str) -> bool {
        if not repository_version_belongs_to(track, version) or document.track_id != track.track_id or document.track_version_id != version.track_version_id { return False; }
        if document in [version ->:HAS_SOURCE_DOCUMENT:->[?:CourseDocument]] { return True; }
        version +>:HAS_SOURCE_DOCUMENT(attached_at=attached_at, attached_by=actor_id):+> document;
        return True;
    }
    def mark_inactive(document: CourseDocument, replacement_id: str, timestamp: str) {
        document.is_active = False; document.replaced_document_id = replacement_id;
        document.upload_status = CourseDocumentUploadStatus.REPLACED; document.updated_at = timestamp;
    }

    def record_orphan(candidate: StorageOrphanCandidate) { root +>:HAS_STORAGE_ORPHAN():+> candidate; }
    def orphan_candidates -> list[StorageOrphanCandidate] { return [root ->:HAS_STORAGE_ORPHAN:->[?:StorageOrphanCandidate]]; }
    def storage_key_is_referenced(storage_key: str) -> bool {
        for profile in [root ->:HAS_LECTURER_PROFILE:->[?:LecturerProfile]] {
            for track in [profile ->:OWNS_TRACK:->[?:LearningTrack]] {
                for version in [track ->:HAS_TRACK_VERSION:->[?:TrackVersion]] {
                    for document in self.list_for_version(version, True) { if document.storage_key == storage_key and document.upload_status != CourseDocumentUploadStatus.DELETED { return True; } }
                }
            }
        }
        return False;
    }
}
