"""Deterministic, provider-neutral structural chunking primitives."""
from __future__ import annotations

import hashlib
import json
import re
from typing import Any


def estimate_tokens(text: str) -> int:
    return max(1, (len(text) + 3) // 4) if text else 0


def config_hash(config: dict[str, Any]) -> str:
    payload = json.dumps(config, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def content_hash(content: str, headings: list[dict[str, Any]], block_ids: list[str], schema: int) -> str:
    payload = json.dumps({"content": content, "headings": headings, "blocks": block_ids, "schema": schema}, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def _split_text(text: str, max_chars: int, max_tokens: int) -> list[str]:
    limit = max(1, min(max_chars, max_tokens * 4))
    if len(text) <= limit:
        return [text]
    sentences = re.split(r"(?<=[.!?])\s+", text)
    pieces: list[str] = []
    current = ""
    for sentence in sentences:
        if len(sentence) > limit:
            words = sentence.split()
            for word in words:
                candidate = (current + " " + word).strip()
                if current and len(candidate) > limit:
                    pieces.append(current); current = word
                elif len(word) > limit:
                    if current: pieces.append(current); current = ""
                    pieces.extend(word[i:i + limit] for i in range(0, len(word), limit))
                else: current = candidate
        else:
            candidate = (current + " " + sentence).strip()
            if current and len(candidate) > limit:
                pieces.append(current); current = sentence
            else: current = candidate
    if current: pieces.append(current)
    return pieces


def build_chunks(blocks: list[dict[str, Any]], config: dict[str, Any]) -> dict[str, Any]:
    include = {"FOOTNOTE": config["include_footnotes"], "CAPTION": config["include_captions"], "HEADER": config["include_headers"], "FOOTER": config["include_footers"]}
    eligible = [b for b in blocks if b["block_type"] != "PAGE_BREAK" and include.get(b["block_type"], True) and b["text"].strip()]
    denominator = sum(len(b["text"]) for b in eligible)
    headings: dict[int, str] = {}
    units: list[dict[str, Any]] = []
    for block in eligible:
        if block["block_type"] == "HEADING":
            level = block.get("heading_level") or 1
            headings = {k: v for k, v in headings.items() if k < level}
            headings[level] = block.get("heading_text") or block["text"]
        path = [{"level": k, "text": headings[k]} for k in sorted(headings)]
        for piece in _split_text(block["text"], config["max_characters"], config["max_tokens"]):
            units.append({"text": piece, "block": block, "path": path})
    chunks: list[dict[str, Any]] = []
    current: list[dict[str, Any]] = []
    def finalize() -> None:
        nonlocal current
        if not current: return
        content = "\n\n".join(u["text"] for u in current)
        block_ids = list(dict.fromkeys(u["block"]["id"] for u in current))
        locators = list(dict.fromkeys(u["block"].get("source_locator") for u in current if u["block"].get("source_locator")))
        pages = [p for u in current for p in (u["block"].get("page_start"), u["block"].get("page_end")) if p is not None]
        path = current[0]["path"]
        chunks.append({"content": content, "heading_path": path, "title": path[-1]["text"] if path else None, "block_ids": block_ids, "locators": locators[:100], "page_start": min(pages) if pages else None, "page_end": max(pages) if pages else None, "overlap_prefix": 0, "represented": sum(len(u["text"]) for u in current)})
        current = []
    for unit in units:
        candidate = "\n\n".join([u["text"] for u in current] + [unit["text"]])
        major_changed = bool(current and current[0]["path"] and unit["path"] and current[0]["path"][0] != unit["path"][0])
        if current and (len(candidate) > config["max_characters"] or estimate_tokens(candidate) > config["target_tokens"] or major_changed): finalize()
        current.append(unit)
    finalize()
    # Controlled source-derived overlap only between chunks sharing a major heading.
    for i in range(1, len(chunks)):
        previous, item = chunks[i - 1], chunks[i]
        if previous["heading_path"] and item["heading_path"] and previous["heading_path"][0] == item["heading_path"][0]:
            budget = config["overlap_tokens"] * 4
            prefix = previous["content"][-budget:].lstrip() if budget else ""
            candidate = prefix + ("\n\n" if prefix else "") + item["content"]
            if prefix and len(candidate) <= config["max_characters"] and estimate_tokens(candidate) <= config["max_tokens"]:
                item["content"] = candidate; item["overlap_prefix"] = len(prefix)
    represented_ids = {identifier for chunk in chunks for identifier in chunk["block_ids"]}
    represented = sum(len(block["text"]) for block in eligible if block["id"] in represented_ids)
    return {"chunks": chunks, "eligible_characters": denominator, "coverage": 1.0 if denominator == 0 and not chunks else (represented / denominator if denominator else 0.0)}
