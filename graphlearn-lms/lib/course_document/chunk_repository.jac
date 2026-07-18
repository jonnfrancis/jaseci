"""Immutable graph repository for document chunk sets and ordered chunks."""
import from edges.domain_edges { HAS_CHUNK_SET, HAS_CONTENT_CHUNK }
import from nodes.curriculum { CourseContentChunk, DocumentChunkSet, DocumentChunkingStatus, DocumentExtraction }

obj DocumentChunkRepository {
    def list_chunk_sets(extraction: DocumentExtraction) -> list[DocumentChunkSet] { return [extraction ->:HAS_CHUNK_SET:->[?:DocumentChunkSet]]; }
    def find_matching_chunk_set(extraction: DocumentExtraction, schema_version: int, config_hash: str) -> DocumentChunkSet | None {
        for item in self.list_chunk_sets(extraction) { if item.schema_version == schema_version and item.config_hash == config_hash and item.source_checksum_sha256 == extraction.source_checksum_sha256 { return item; } }
        return None;
    }
    def find_active_chunk_set(extraction: DocumentExtraction) -> DocumentChunkSet | None { for item in self.list_chunk_sets(extraction) { if item.is_active and item.status == DocumentChunkingStatus.CHUNKED { return item; } } return None; }
    def list_chunks(chunk_set: DocumentChunkSet) -> list[CourseContentChunk] { chunks: list[CourseContentChunk] = [chunk_set ->:HAS_CONTENT_CHUNK:->[?:CourseContentChunk]]; return sorted(chunks, key=lambda item: CourseContentChunk : item.order_index); }
    def save_chunk_set(extraction: DocumentExtraction, chunk_set: DocumentChunkSet) -> bool { if chunk_set.extraction_id != extraction.extraction_id or chunk_set.source_checksum_sha256 != extraction.source_checksum_sha256 { return False; } extraction +>:HAS_CHUNK_SET(created_at=chunk_set.created_at):+> chunk_set; return True; }
    def save_chunks(chunk_set: DocumentChunkSet, chunks: list[CourseContentChunk]) -> bool { for index in range(len(chunks)) { item = chunks[index]; if item.order_index != index or item.extraction_id != chunk_set.extraction_id { return False; } chunk_set +>:HAS_CONTENT_CHUNK(order_index=index):+> item; } return True; }
    def mark_chunked(extraction: DocumentExtraction, chunk_set: DocumentChunkSet, completed_at: str) { for old in self.list_chunk_sets(extraction) { old.is_active = False; } chunk_set.status = DocumentChunkingStatus.CHUNKED; chunk_set.is_active = True; chunk_set.completed_at = completed_at; chunk_set.error_code = None; }
    def mark_failed(chunk_set: DocumentChunkSet, code: str, completed_at: str) { chunk_set.status = DocumentChunkingStatus.CHUNKING_FAILED; chunk_set.is_active = False; chunk_set.error_code = code; chunk_set.completed_at = completed_at; }
    def delete_partial_chunk_set(chunk_set: DocumentChunkSet) { chunk_set.is_active = False; }
}
