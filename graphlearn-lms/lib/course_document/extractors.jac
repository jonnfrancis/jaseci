"""Parser-neutral document extractor contracts and maintained-library adapters."""

import lib.course_document.extraction_engine as engine;
import from nodes.curriculum { ExtractionContext, RawExtractionBlock, RawExtractionResult }

obj DocumentExtractor {
    def supports(_detected_file_type: str) -> bool { return False; }
    def extractor_name -> str { return "unsupported"; }
    def extractor_version -> str { return "0"; }
    def extract(_source: bytes, _context: ExtractionContext) -> RawExtractionResult { raise NotImplementedError("DOCUMENT_EXTRACTION_UNSUPPORTED_TYPE"); }

    def _convert(raw: dict[str, object]) -> RawExtractionResult {
        blocks: list[RawExtractionBlock] = [];
        for item_value in raw.get("blocks", []) as list[object] {
            item = item_value as dict[str, object];
            blocks.append(RawExtractionBlock(block_type=str(item.get("block_type", "OTHER")), text=str(item.get("text", "")),
                page_start=(item.get("page_start") as int | None), page_end=(item.get("page_end") as int | None),
                heading_level=(item.get("heading_level") as int | None), heading_text=(item.get("heading_text") as str | None),
                source_locator=(item.get("source_locator") as str | None), metadata_json=(item.get("metadata_json") as str | None)));
        }
        warning_values = raw.get("warnings", []) as list[object]; warnings: list[str] = [];
        for warning in warning_values { warnings.append(str(warning)); }
        return RawExtractionResult(blocks=blocks, warnings=warnings,
            total_pages=(raw.get("total_pages") as int | None), parser_metadata_json=(raw.get("parser_metadata_json") as str | None),
            pages_with_text=raw.get("pages_with_text", 0) as int, pages_without_text=raw.get("pages_without_text", 0) as int,
            pages_with_images=raw.get("pages_with_images", 0) as int);
    }
}

obj PDFDocumentExtractor(DocumentExtractor) {
    override def supports(detected_file_type: str) -> bool { return detected_file_type.upper() == "PDF"; }
    override def extractor_name -> str { return "pdf:pypdf"; }
    override def extractor_version -> str { return engine.pdf_version() as str; }
    override def extract(source: bytes, _context: ExtractionContext) -> RawExtractionResult { return self._convert(engine.extract_pdf(source) as dict[str, object]); }
}

obj DOCXDocumentExtractor(DocumentExtractor) {
    override def supports(detected_file_type: str) -> bool { return detected_file_type.upper() == "DOCX"; }
    override def extractor_name -> str { return "docx:python-docx"; }
    override def extractor_version -> str { return engine.docx_version() as str; }
    override def extract(source: bytes, _context: ExtractionContext) -> RawExtractionResult { return self._convert(engine.extract_docx(source) as dict[str, object]); }
}
