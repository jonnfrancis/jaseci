"""Feature 43 deterministic structure, bounds, overlap, coverage, and config tests."""
import json;
import lib.course_document.chunking_engine as engine;
import from lib.course_document.chunking_service { TokenEstimator }

def _config(target: int = 40, maximum: int = 60, characters: int = 240, overlap: int = 8) -> dict[str, object] { return {"target_tokens": target, "max_tokens": maximum, "min_tokens": 5, "overlap_tokens": overlap, "max_characters": characters, "max_chunks": 100, "include_footnotes": True, "include_captions": True, "include_headers": False, "include_footers": False, "strategy_name": "structural-v1", "schema_version": 1}; }
def _block(identifier: str, order: int, kind: str, text: str, level: int | None = None, page: int | None = None) -> dict[str, object] { return {"id": identifier, "order_index": order, "block_type": kind, "text": text, "heading_level": level, "heading_text": text if kind == "HEADING" else None, "page_start": page, "page_end": page, "source_locator": "fixture:" + identifier}; }

test "heading hierarchy is inherited in source order" {
    blocks = [_block("h1", 0, "HEADING", "A", 1), _block("p1", 1, "PARAGRAPH", "First paragraph."), _block("h2", 2, "HEADING", "B", 2), _block("p2", 3, "PARAGRAPH", "Second paragraph."), _block("h3", 4, "HEADING", "C", 3), _block("p3", 5, "PARAGRAPH", "Third paragraph."), _block("h2d", 6, "HEADING", "D", 2), _block("p4", 7, "PARAGRAPH", "Fourth paragraph.")];
    result = engine.build_chunks(blocks, _config(4, 20, 100, 0)); chunks = result["chunks"] as list[dict[str, object]];
    paths: list[str] = []; for item in chunks { heading_items = item["heading_path"] as list[dict[str, object]]; paths.append(" > ".join([entry["text"] as str for entry in heading_items])); }
    assert "A" in paths and "A > B" in paths and "A > B > C" in paths and "A > D" in paths;
}

test "oversized paragraph remains bounded and retains full source coverage" {
    text = "Sentence number one explains databases clearly. Sentence number two explains normalization carefully. Sentence number three explains transactions fully. Sentence number four finishes the material safely.";
    result = engine.build_chunks([_block("long", 0, "PARAGRAPH", text, None, 7)], _config(20, 25, 100, 4)); chunks = result["chunks"] as list[dict[str, object]];
    assert len(chunks) > 1 and (result["coverage"] as float) == 1.0;
    for item in chunks { content = item["content"] as str; assert len(content) <= 100 and TokenEstimator().estimate(content) <= 25 and item["page_start"] == 7; }
}

test "overlap is source derived and only crosses compatible split chunks" {
    blocks = [_block("h", 0, "HEADING", "Databases", 1), _block("a", 1, "PARAGRAPH", "Alpha material has enough words to form the first bounded evidence unit."), _block("b", 2, "PARAGRAPH", "Beta material has enough words to form the second bounded evidence unit."), _block("h2", 3, "HEADING", "Networks", 1), _block("c", 4, "PARAGRAPH", "Network material belongs to another major section entirely.")];
    chunks = (engine.build_chunks(blocks, _config(15, 30, 140, 6))["chunks"] as list[dict[str, object]]);
    assert len(chunks) >= 3 and (chunks[1]["overlap_prefix"] as int) > 0;
    network_first: dict[str, object] | None = None; for item in chunks { if item["title"] == "Networks" { network_first = item; break; } }
    assert network_first is not None and ((network_first as dict[str, object])["overlap_prefix"] as int) == 0;
}

test "headers footers and page breaks are filtered without reducing eligible coverage" {
    blocks = [_block("header", 0, "HEADER", "Repeated Header"), _block("body", 1, "PARAGRAPH", "Semantic lesson content."), _block("break", 2, "PAGE_BREAK", "page"), _block("footer", 3, "FOOTER", "Repeated Footer")];
    result = engine.build_chunks(blocks, _config()); chunks = result["chunks"] as list[dict[str, object]];
    assert len(chunks) == 1 and chunks[0]["content"] == "Semantic lesson content." and (result["coverage"] as float) == 1.0;
}

test "configuration and content fingerprints are deterministic" {
    config = _config(); assert engine.config_hash(config) == engine.config_hash(config);
    headings: list[dict[str, object]] = [{"level": 1, "text": "A"}]; ids = ["b1"];
    assert engine.content_hash("content", headings, ids, 1) == engine.content_hash("content", headings, ids, 1);
    changed = _config(41); assert engine.config_hash(config) != engine.config_hash(changed);
}
