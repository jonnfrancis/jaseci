"""Low-cardinality extraction metrics."""

glob DOCUMENT_EXTRACTION_METRICS: dict[str, int] = {};

def record_document_extraction(result: str, duration_ms: int, characters: int = 0, pages: int = 0, blocks: int = 0) {
    keys = ["document_extraction_total", "document_extraction_" + result.lower() + "_total"];
    for key in keys { DOCUMENT_EXTRACTION_METRICS[key] = DOCUMENT_EXTRACTION_METRICS.get(key, 0) + 1; }
    DOCUMENT_EXTRACTION_METRICS["document_extraction_duration_ms_total"] = DOCUMENT_EXTRACTION_METRICS.get("document_extraction_duration_ms_total", 0) + duration_ms;
    DOCUMENT_EXTRACTION_METRICS["document_extraction_characters_total"] = DOCUMENT_EXTRACTION_METRICS.get("document_extraction_characters_total", 0) + characters;
    DOCUMENT_EXTRACTION_METRICS["document_extraction_pages_total"] = DOCUMENT_EXTRACTION_METRICS.get("document_extraction_pages_total", 0) + pages;
    DOCUMENT_EXTRACTION_METRICS["document_extraction_blocks_total"] = DOCUMENT_EXTRACTION_METRICS.get("document_extraction_blocks_total", 0) + blocks;
}

def document_extraction_metric(name: str) -> int { return DOCUMENT_EXTRACTION_METRICS.get(name, 0); }
