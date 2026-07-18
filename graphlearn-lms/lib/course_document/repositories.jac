"""Graph-safe repositories for version-owned course documents."""

import from edges.domain_edges { HAS_SOURCE_DOCUMENT }
import from lib.learning_track.repositories { repository_version_belongs_to }
import from nodes.curriculum { CourseDocument, CourseDocumentUploadStatus }
import from nodes.learning_track { LearningTrack, TrackVersion }

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
    def attach_to_version(track: LearningTrack, version: TrackVersion, document: CourseDocument, actor_id: str, attached_at: str) -> bool {
        if not repository_version_belongs_to(track, version) or document.track_id != track.track_id or document.track_version_id != version.track_version_id { return False; }
        if document in [version ->:HAS_SOURCE_DOCUMENT:->[?:CourseDocument]] { return True; }
        version +>:HAS_SOURCE_DOCUMENT(attached_at=attached_at, attached_by=actor_id):+> document;
        return True;
    }
    def mark_inactive(document: CourseDocument, timestamp: str) { document.is_active = False; document.updated_at = timestamp; }
}
