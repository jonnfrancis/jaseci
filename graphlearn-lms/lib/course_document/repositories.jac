"""Graph-safe repositories for version-owned course documents."""

import from edges.domain_edges { HAS_LECTURER_PROFILE, HAS_SOURCE_DOCUMENT, HAS_STORAGE_ORPHAN, HAS_TRACK_VERSION, OWNS_TRACK }
import from lib.learning_track.repositories { repository_version_belongs_to }
import from nodes.curriculum { CourseDocument, CourseDocumentUploadStatus, StorageOrphanCandidate }
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
