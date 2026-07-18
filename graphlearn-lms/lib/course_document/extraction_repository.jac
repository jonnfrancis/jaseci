"""Graph repository for versioned extraction artifacts and ordered blocks."""

import from edges.domain_edges { HAS_EXTRACTION, HAS_EXTRACTION_BLOCK }
import from nodes.curriculum { DocumentExtraction, DocumentExtractionStatus, ExtractionBlock, CourseDocument }

obj DocumentExtractionRepository {
    def list_for_document(document: CourseDocument) -> list[DocumentExtraction] {
        return [document ->:HAS_EXTRACTION:->[?:DocumentExtraction]];
    }
    def find_active_for_document(document: CourseDocument) -> DocumentExtraction | None {
        for extraction in self.list_for_document(document) { if extraction.is_active { return extraction; } }
        return None;
    }
    def find_by_id(document: CourseDocument, extraction_id: str) -> DocumentExtraction | None {
        for extraction in self.list_for_document(document) { if extraction.extraction_id == extraction_id { return extraction; } }
        return None;
    }
    def find_by_source_and_schema_version(document: CourseDocument, checksum: str, schema_version: int) -> DocumentExtraction | None {
        for extraction in self.list_for_document(document) {
            if extraction.source_checksum_sha256 == checksum and extraction.schema_version == schema_version and extraction.is_active { return extraction; }
        }
        return None;
    }
    def list_blocks(extraction: DocumentExtraction) -> list[ExtractionBlock] {
        blocks: list[ExtractionBlock] = [extraction ->:HAS_EXTRACTION_BLOCK:->[?:ExtractionBlock]];
        return sorted(blocks, key=lambda item: ExtractionBlock : item.order_index);
    }
    def save_extraction(document: CourseDocument, extraction: DocumentExtraction, created_at: str) -> bool {
        if extraction.document_id != document.document_id or extraction.track_id != document.track_id or extraction.track_version_id != document.track_version_id or extraction.source_checksum_sha256 != document.checksum { return False; }
        document +>:HAS_EXTRACTION(created_at=created_at):+> extraction; return True;
    }
    def save_blocks(extraction: DocumentExtraction, blocks: list[ExtractionBlock]) -> bool {
        for index in range(len(blocks)) {
            block = blocks[index];
            if block.extraction_id != extraction.extraction_id or block.order_index != index { return False; }
            extraction +>:HAS_EXTRACTION_BLOCK(order_index=index):+> block;
        }
        return True;
    }
    def deactivate(extraction: DocumentExtraction) { extraction.is_active = False; }
    def mark_extracted(extraction: DocumentExtraction, completed_at: str) { extraction.status = DocumentExtractionStatus.EXTRACTED; extraction.completed_at = completed_at; extraction.error_code = None; extraction.error_message = None; }
    def mark_failed(extraction: DocumentExtraction, code: str, message: str, completed_at: str) { extraction.status = DocumentExtractionStatus.EXTRACTION_FAILED; extraction.error_code = code; extraction.error_message = message; extraction.completed_at = completed_at; }
    def delete_partial_extraction(extraction: DocumentExtraction) { extraction.is_active = False; }
}
