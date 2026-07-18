"""Provider-neutral course-document storage contracts."""

enum StorageHealthStatus: str { HEALTHY = "HEALTHY", DEGRADED = "DEGRADED", UNAVAILABLE = "UNAVAILABLE" }

obj StorageObjectMetadata {
    has storage_key: str;
    has size_bytes: int;
    has modified_at: str;
}

obj StoredCourseDocument {
    has storage_key: str;
    has size_bytes: int;
    has checksum_sha256: str;
    has stored_at: str;
}

obj StorageIntegrityResult {
    has valid: bool;
    has object_exists: bool;
    has size_matches: bool;
    has checksum_matches: bool;
    has error_code: str | None = None;
}

obj StorageDeleteResult {
    has ok: bool;
    has deleted: bool = False;
    has trash_key: str | None = None;
    has error_code: str | None = None;
}

obj StorageCleanupResult {
    has ok: bool;
    has cleaned: bool = False;
    has error_code: str | None = None;
}

obj StorageHealthResult {
    has status: StorageHealthStatus;
    has backend: str;
    has error_code: str | None = None;
}

obj StorageAuditResult {
    has documents_checked: int = 0;
    has healthy: int = 0;
    has missing: int = 0;
    has integrity_mismatch: int = 0;
    has orphans: int = 0;
}

obj StoreCourseDocumentRequest {
    has document_id: str;
    has track_id: str;
    has track_version_id: str;
    has canonical_extension: str;
    has client_upload_id: str;
    has uploaded_by: str;
    has payload: bytes;
}

obj AuthorizedDocumentContext {
    has document_id: str;
    has track_id: str;
    has track_version_id: str;
    has actor_id: str;
    has operation: str;
}
