# 43-document-content-chunking.md

## Overview

Implement a deterministic document-content chunking subsystem that converts the structured extraction artifacts produced by `42-document-text-extraction.md` into bounded, ordered, provenance-preserving content chunks suitable for later:

- byLLM course-blueprint generation;
- topic and skill extraction;
- prerequisite inference;
- grounded lesson generation;
- grounded quiz generation;
- source citation;
- lecturer review;
- regeneration and auditing.

This specification defines the bridge between:

```text
DocumentExtraction + ExtractionBlock[]
```

and:

```text
CourseContentChunk[]
```

The core rule is:

```text
Do not chunk raw PDF/DOCX bytes.
Do not chunk directly from parser-specific objects.
Chunk only normalized extraction artifacts.
```

Chunking must be deterministic, structural where possible, bounded by size/token limits, and fully traceable to source-document locations.

---

## Status

- **Feature type:** Document processing / chunking
- **Priority:** Critical
- **Depends on:** `42-document-text-extraction.md`
- **Blocks:** `45-course-blueprint-byllm-contracts.md`
- **Blocks:** `46-course-blueprint-generation.md`
- **Breaking changes allowed:** No
- **Primary implementation:** Chunking service + chunk nodes + provenance edges

---

# Goals

Implement chunking that:

1. Consumes only successful extraction artifacts.
2. Preserves source order.
3. Preserves heading and section context.
4. Uses structural boundaries before arbitrary character splits.
5. Keeps chunks within configured size/token limits.
6. Uses controlled overlap only when necessary.
7. Prevents accidental loss of context across boundaries.
8. Preserves page and source provenance.
9. Produces deterministic output for the same extraction/version/configuration.
10. Avoids duplicate or near-empty chunks.
11. Keeps repeated headers/footers out of semantic chunks where appropriate.
12. Supports PDF and DOCX through the same downstream chunk model.
13. Stores chunk metadata separately from extraction blocks.
14. Supports chunking-version changes and re-chunking.
15. Supports idempotent retries.
16. Prevents duplicate concurrent chunking jobs.
17. Provides quality metrics and warnings.
18. Produces output ready for batched byLLM analysis.
19. Prevents unbounded prompt sizes.
20. Preserves a traceable path from generated curriculum back to source notes.

---

# Non-goals

This specification does not implement:

- byLLM calls;
- summarization;
- topic extraction;
- course-blueprint generation;
- embeddings;
- vector search;
- semantic retrieval;
- OCR;
- file parsing;
- document validation;
- course publication;
- learner-facing citations;
- automatic correction of lecturer content.

---

# Chunking architecture

```text
CourseDocument
   │
   ▼
DocumentExtraction
   │
   └── ExtractionBlock[]
          │
          ▼
DocumentContentChunkingService
          │
          ├── filter non-semantic blocks
          ├── build structural sections
          ├── inherit heading context
          ├── accumulate blocks
          ├── enforce size/token budgets
          ├── split oversized content
          ├── apply controlled overlap
          ├── validate provenance
          └── persist chunks
                 │
                 ▼
CourseContentChunk[]
                 │
                 ▼
45/46 byLLM course analysis
```

Downstream AI services must consume:

```text
CourseContentChunk
```

rather than raw extraction text.

---

# Chunking status

Introduce:

```jac
enum DocumentChunkingStatus {
    NOT_STARTED,
    QUEUED,
    CHUNKING,
    CHUNKED,
    CHUNKING_FAILED
}
```

Meaning:

| Status | Meaning |
|---|---|
| `NOT_STARTED` | Extraction completed but chunking not started |
| `QUEUED` | Chunking scheduled |
| `CHUNKING` | Chunk generation running |
| `CHUNKED` | Chunk generation completed successfully |
| `CHUNKING_FAILED` | Chunking failed and can potentially be retried |

Only:

```text
CHUNKED
```

may proceed to blueprint-generation workflows.

---

# Chunking version

Use explicit versioning:

```text
DOCUMENT_CHUNKING_SCHEMA_VERSION = 1
```

Also persist a chunking configuration fingerprint.

Example:

```text
chunking_strategy = "structural-v1"
chunking_config_hash = sha256(config)
```

This allows:

- reproducibility;
- migration;
- comparison;
- forced re-chunking;
- deterministic reuse.

---

# Core chunk node

Create:

```jac
node CourseContentChunk {
    has chunk_id: str;

    has document_id: str;
    has extraction_id: str;

    has track_id: str;
    has track_version_id: str;

    has chunking_schema_version: int = 1;
    has chunking_strategy: str;

    has order_index: int;

    has title: str | None = None;
    has heading_path_json: str | None = None;

    has content: str;

    has character_count: int;
    has word_count: int;
    has estimated_token_count: int;

    has page_start: int | None = None;
    has page_end: int | None = None;

    has source_block_ids_json: str;
    has source_locator_json: str | None = None;

    has overlap_prefix_characters: int = 0;
    has overlap_suffix_characters: int = 0;

    has content_hash: str;

    has created_at: str;
}
```

---

# Chunk identity

`chunk_id` must be stable within one chunking run.

Recommended:

```text
chk_<uuid>
```

For deterministic regeneration/testing, optionally derive an internal deterministic key from:

```text
extraction_id
chunking schema version
order index
content hash
```

Do not use chunk title as identity.

---

# Chunk graph

Suggested relationships:

```text
DocumentExtraction
└── HAS_CONTENT_CHUNK
    ├── CourseContentChunk 0
    ├── CourseContentChunk 1
    └── CourseContentChunk N
```

Edge:

```jac
edge HAS_CONTENT_CHUNK {
    has order_index: int;
}
```

Optional provenance relationship:

```text
CourseContentChunk
└── DERIVED_FROM_BLOCK
    └── ExtractionBlock
```

If direct chunk-to-block edges create excessive graph density, store source block IDs on the chunk and keep bounded repository methods for provenance resolution.

Choose one consistent approach.

---

# Source-order invariant

Chunk order must preserve source order.

If extraction blocks are:

```text
0, 1, 2, 3, 4
```

chunks may group them:

```text
chunk 0 → blocks 0,1
chunk 1 → blocks 2,3
chunk 2 → block 4
```

Do not reorder content based on semantic similarity during this phase.

Semantic reordering belongs to later analysis, if ever needed.

---

# Structural-first chunking

Preferred boundary hierarchy:

```text
1. major heading / section
2. subheading
3. paragraph boundary
4. list/table boundary
5. sentence boundary
6. hard character/token split as last resort
```

Do not split arbitrarily at fixed character count when cleaner structural boundaries exist.

---

# Heading context

Chunks must retain hierarchical heading context.

Example source:

```text
Heading 1: Database Design
Heading 2: Normalization
Heading 3: Third Normal Form
Paragraphs...
```

Chunk metadata:

```json
{
  "heading_path": [
    "Database Design",
    "Normalization",
    "Third Normal Form"
  ]
}
```

This heading path should be inherited by body chunks until the next heading change.

---

# Heading path model

Represent:

```jac
obj HeadingPathItem {
    has level: int;
    has text: str;
}
```

Persist as typed object or serialized JSON according to project conventions.

Example:

```json
[
  {"level": 1, "text": "Database Design"},
  {"level": 2, "text": "Normalization"}
]
```

---

# Section builder

Before final chunking, build logical sections from extraction blocks.

Conceptual:

```text
ExtractionBlock[]
→ LogicalSection[]
→ CourseContentChunk[]
```

A logical section contains:

```text
heading path
ordered body blocks
page range
source locators
```

This intermediate structure may remain in memory and does not require persistence.

---

# Logical section type

```jac
obj LogicalSection {
    has heading_path: list[HeadingPathItem];
    has blocks: list[ExtractionBlock];

    has page_start: int | None;
    has page_end: int | None;

    has character_count: int;
}
```

---

# Heading-state algorithm

Maintain active heading state.

Example:

```text
H1 A
  H2 B
    H3 C
  H2 D
H1 E
```

Heading paths become:

```text
A
A > B
A > B > C
A > D
E
```

When a new heading at level `N` appears:

- replace existing heading at level `N`;
- remove deeper headings;
- preserve shallower headings.

---

# Heading blocks in content

Do not rely only on metadata.

Include useful heading text in the chunk body or a clearly structured wrapper used later for LLM input.

Example canonical chunk representation:

```text
Section: Database Design > Normalization

Normalization reduces redundancy...

...
```

But keep `content` focused on source content.

A later prompt builder may prepend heading metadata.

Do not repeatedly inject headings into overlapping text if it distorts provenance.

---

# Non-semantic block filtering

By default exclude from semantic chunk bodies:

```text
HEADER
FOOTER
PAGE_BREAK
empty OTHER blocks
```

Potentially retain:

```text
FOOTNOTE
CAPTION
TABLE_TEXT
```

depending on content.

Filtering must be configurable.

Do not permanently delete extraction blocks.

Chunking merely chooses whether to include them.

---

# Repeated header/footer handling

If `42` marked blocks as:

```text
HEADER
FOOTER
```

exclude them by default.

If not marked, chunking may use conservative repeated-content detection.

Never remove content solely because it repeats across chapters.

---

# Target chunk size

Use token-aware targets.

Recommended initial configuration:

```text
CHUNK_TARGET_TOKENS=800
CHUNK_MAX_TOKENS=1200
CHUNK_MIN_TOKENS=150
CHUNK_OVERLAP_TOKENS=100
```

These are starting values only.

Adjust based on:

- chosen LLM context window;
- blueprint-generation batching;
- cost;
- course document characteristics.

---

# Character fallback

Because exact model tokenization may vary, also maintain character limits.

Example:

```text
CHUNK_MAX_CHARACTERS=6000
```

A chunk must satisfy both operational limits where configured.

---

# Token estimation

Create a token estimator abstraction:

```text
TokenEstimator
```

Methods:

```text
estimate(text)
```

Avoid coupling chunking to one model provider.

Possible implementation:

- approximate character/word heuristic;
- tokenizer compatible with selected LLM family.

The estimator is for budgeting.

It does not need exact billing-token precision.

---

# Chunk accumulation algorithm

Conceptual:

```text
for each logical section:
    current chunk = empty

    for each block:
        if adding block stays under target:
            append
        else:
            finalize current chunk
            start next chunk with context/overlap

        if single block > max:
            split oversized block safely
```

Prefer keeping paragraphs intact.

---

# Small sections

If a section is below `CHUNK_MIN_TOKENS`, combine it with an adjacent compatible section when:

```text
same major heading
same logical topic context
combined size <= max
```

Do not combine unrelated major sections only to satisfy minimum size.

A short but meaningful section may remain a small chunk.

---

# Oversized sections

A section larger than maximum must be split.

Preferred split order:

```text
paragraph boundaries
list boundaries
table row groups
sentence boundaries
hard split
```

Keep heading path identical across resulting chunks.

---

# Oversized paragraphs

If one paragraph exceeds maximum:

1. sentence-split;
2. accumulate sentences;
3. preserve original order;
4. use controlled overlap.

If sentence segmentation is unavailable or unsafe:

```text
hard split at whitespace near boundary
```

Never split in the middle of a Unicode code point.

---

# Sentence segmentation

Use a deterministic sentence segmentation approach.

Avoid language assumptions where possible.

For multilingual support:

- use a library with multilingual sentence boundaries;
- or conservative punctuation-based splitting.

Do not fail chunking solely because sentence segmentation is imperfect.

---

# Table chunking

Tables may exceed maximum size.

Split by:

```text
row groups
```

while repeating lightweight header context if useful.

Example:

```text
Table: SQL commands
Columns: Command | Purpose

chunk A rows 1–30
chunk B rows 31–60
```

Record overlap/repeated headers as metadata when generated by the chunker.

Do not alter source facts.

---

# Lists

Keep list items together when possible.

Avoid:

```text
chunk ends after bullet 1
next chunk begins bullet 2
```

unless the list itself exceeds maximum.

For oversized lists:

- split at item boundaries;
- retain heading path.

---

# Overlap policy

Overlap helps preserve local continuity.

Use overlap only when a section is split.

Do not overlap unrelated sections.

Recommended:

```text
100 estimated tokens
```

or configurable.

---

# Overlap source

Overlap should come from actual prior source text.

Do not create summaries or synthetic context during chunking.

Possible overlap unit:

```text
last paragraph
last N sentences
last N tokens
```

Prefer paragraph/sentence boundaries.

---

# Overlap metadata

Record:

```text
overlap_prefix_characters
overlap_suffix_characters
```

or equivalent.

This helps later deduplicate evidence across chunks.

---

# Duplicate-analysis risk

Overlapping text can cause later LLM stages to infer duplicate concepts.

Therefore later prompt aggregation should know:

```text
chunk overlap exists
```

Chunk metadata must allow deduplication.

---

# No overlap for complete structural sections

If one section fits cleanly in one chunk:

```text
overlap = 0
```

Do not add unnecessary duplicate text.

---

# Chunk title

A chunk title may be derived deterministically from:

```text
deepest active heading
```

Example:

```text
"Third Normal Form"
```

Fallback:

```text
"Database Design"
```

If no heading exists:

```text
null
```

Do not generate titles with an LLM.

---

# Chunk content format

Store clean source-derived text.

Recommended content assembly:

```text
paragraph

paragraph

- list item
- list item

table text
```

Heading hierarchy is metadata.

Avoid excessive synthetic formatting.

---

# Provenance

Every chunk must preserve:

```text
document_id
extraction_id
source block IDs
page range
source locators
heading path
```

Required provenance chain:

```text
CourseContentChunk
→ ExtractionBlock(s)
→ DocumentExtraction
→ CourseDocument
→ storage source
```

---

# Page ranges

For PDF-derived chunks:

```text
page_start
page_end
```

must reflect all included source blocks.

For DOCX:

```text
page_start/page_end may be null
```

unless reliable pagination exists.

Do not fabricate DOCX page numbers.

---

# Source locators

Examples:

```text
pdf:page=12:block=3
pdf:page=13:block=1

docx:body=paragraph:128
docx:body=table:7:row=12
```

Store bounded locator lists.

If a chunk spans many blocks, use:

```text
source block IDs
page range
first/last locator
```

rather than enormous metadata payloads.

---

# Character provenance

Optionally record extraction-level character range:

```text
source_character_start
source_character_end
```

when chunk content maps cleanly to canonical plain text.

This improves:

- source highlighting;
- debugging;
- future citation rendering.

If overlap or block filtering makes one continuous range impossible, store multiple ranges or rely on source block IDs.

---

# Chunk content hash

Compute:

```text
SHA-256(normalized chunk content + relevant structural metadata)
```

Suggested inputs:

```text
content
heading path
source block IDs
chunking schema version
```

Uses:

- idempotency;
- duplicate detection;
- re-chunk comparison;
- caching.

---

# Exact duplicate detection

Within one extraction:

```text
same content hash
```

may indicate:

- repeated headers not filtered;
- duplicated extraction blocks;
- legitimate repeated course content.

Do not automatically delete all exact duplicates.

Classification:

```text
likely noise duplicate
legitimate duplicate
unknown
```

Use conservative rules.

---

# Near-duplicate handling

Near-duplicate semantic detection is out of scope.

Do not add embeddings solely for chunking.

Later blueprint analysis can deduplicate concepts.

---

# Chunk quality checks

For each chunk verify:

```text
non-empty content
minimum meaningful characters
within max token limit
within max character limit
valid source provenance
monotonic order
no invalid control characters
```

---

# Chunk quality warnings

Possible:

```text
CHUNK_TOO_SMALL
CHUNK_COMPLEX_TABLE
CHUNK_LOW_TEXT_DENSITY
CHUNK_NO_HEADING_CONTEXT
CHUNK_LARGE_OVERLAP
CHUNK_SOURCE_GAP
CHUNK_REPEATED_CONTENT
```

Warnings do not always fail chunking.

---

# Document-level chunk quality

Calculate:

```text
chunk_count
average token count
min token count
max token count
overlap ratio
chunks without headings
source coverage ratio
```

---

# Source coverage ratio

Measure:

```text
semantic extraction characters represented in chunks
/
semantic extraction characters eligible for chunking
```

Expected:

```text
near 100%
```

excluding intentionally filtered headers/footers/page breaks.

If coverage falls below a threshold:

```text
CHUNKING_FAILED
DOCUMENT_CHUNK_SOURCE_COVERAGE_LOW
```

Do not silently drop major content.

---

# Chunk count limits

Config:

```text
DOCUMENT_MAX_CHUNKS
```

Example:

```text
10,000
```

If exceeded:

```text
CHUNKING_FAILED
DOCUMENT_CHUNK_LIMIT_EXCEEDED
```

This protects later AI pipelines.

---

# Chunking configuration

Centralize:

```jac
obj ChunkingConfig {
    has target_tokens: int;
    has max_tokens: int;
    has min_tokens: int;
    has overlap_tokens: int;

    has max_characters: int;
    has max_chunks: int;

    has include_footnotes: bool;
    has include_captions: bool;
    has include_headers: bool = False;
    has include_footers: bool = False;

    has strategy_name: str;
    has schema_version: int;
}
```

---

# Configuration validation

Enforce:

```text
target_tokens > 0
max_tokens >= target_tokens
min_tokens <= target_tokens
overlap_tokens < target_tokens
max_characters > 0
max_chunks > 0
```

Reject invalid config before chunking.

---

# Configuration fingerprint

Compute:

```text
chunking_config_hash
```

from canonical serialized config.

Reuse existing chunks only when:

```text
same extraction_id
same source checksum
same schema version
same config hash
```

---

# Chunking service

Create:

```text
DocumentContentChunkingService
```

Responsibilities:

```text
assert_chunkable
load_extraction
load_blocks
resolve_existing_chunk_set
acquire_chunking_lock
build_logical_sections
filter_blocks
split_sections
apply_overlap
estimate_tokens
validate_chunks
calculate_coverage
persist_chunks
update_status
emit_events
release_lock
```

---

# Service contract

Conceptual:

```jac
obj DocumentContentChunkingService {
    def chunk_document(
        document_id: str,
        context: ChunkingRequestContext
    ) -> DocumentChunkingResult;

    def get_chunks(
        document_id: str
    ) -> list[CourseContentChunk];

    def retry_chunking(
        document_id: str,
        context: ChunkingRequestContext
    ) -> DocumentChunkingResult;

    def can_generate_blueprint(
        document_id: str
    ) -> bool;
}
```

---

# Chunking request context

```jac
obj ChunkingRequestContext {
    has document_id: str;
    has track_id: str;
    has track_version_id: str;

    has extraction_id: str;

    has request_id: str;
    has actor_id: str | None;

    has config: ChunkingConfig;

    has force_rechunk: bool = False;
}
```

---

# Chunking result

```jac
obj DocumentChunkingResult {
    has document_id: str;
    has extraction_id: str;

    has status: DocumentChunkingStatus;

    has chunk_count: int;
    has total_characters: int;
    has total_words: int;
    has total_estimated_tokens: int;

    has average_chunk_tokens: float;
    has source_coverage_ratio: float;

    has warnings: list[str];

    has error_code: str | None;
}
```

---

# Chunk-set identity

A successful chunk set is defined by:

```text
extraction_id
chunking schema version
config hash
```

Persist this identity either on:

- a `DocumentChunkSet` node; or
- the `DocumentExtraction`/chunk metadata.

Recommended for clarity:

```jac
node DocumentChunkSet {
    has chunk_set_id: str;

    has document_id: str;
    has extraction_id: str;

    has track_id: str;
    has track_version_id: str;

    has schema_version: int;
    has strategy_name: str;
    has config_hash: str;

    has status: DocumentChunkingStatus;

    has chunk_count: int;

    has created_at: str;
    has completed_at: str | None = None;
}
```

Graph:

```text
DocumentExtraction
└── HAS_CHUNK_SET
    └── DocumentChunkSet
        └── HAS_CONTENT_CHUNK
            └── CourseContentChunk[]
```

This is preferable if re-chunking history must be retained.

---

# Re-chunking

When chunking rules change:

```text
new schema version or config hash
→ new chunk set
```

Do not mutate old chunks in place.

This preserves:

- blueprint reproducibility;
- audit history;
- published-version stability.

---

# Active chunk set

A draft course may have one active chunk set used for downstream generation.

Published blueprint provenance must remember the exact chunk set used.

Do not automatically switch a published course blueprint to a newer chunk set.

---

# Idempotency

If matching successful chunk set exists:

```text
return/reuse it
```

Do not regenerate identical chunks.

---

# Concurrency

Only one active chunking operation per:

```text
extraction_id + schema version + config hash
```

Duplicate requests should reuse current state.

---

# Chunking lock

Use:

```text
compare-and-set status
unique active job
job lock
```

Prevent duplicate writes.

---

# Persistence sequence

Recommended:

```text
1. assert extraction == EXTRACTED
2. resolve/reuse matching chunk set
3. mark CHUNKING
4. load ordered extraction blocks
5. build sections
6. create chunks in staging
7. validate sizes/provenance
8. calculate source coverage
9. persist chunk set
10. persist chunks
11. connect ordered edges
12. mark CHUNKED
13. update document processing state
14. emit completion
```

If persistence fails:

```text
mark CHUNKING_FAILED
clean partial chunk set safely
```

---

# Partial-failure behavior

Raw extraction remains unchanged.

A failed chunking run must not:

- delete extraction;
- alter source document;
- mark course ready for blueprint generation;
- overwrite older valid chunk set.

---

# Blueprint eligibility guard

Create:

```text
assert_document_ready_for_blueprint(document_id)
```

Required:

```text
validation_status == VALIDATED
extraction_status == EXTRACTED
chunking_status == CHUNKED
active chunk set valid
source coverage acceptable
no fatal chunk warnings
```

This guard will be used by `46-course-blueprint-generation.md`.

---

# Batch preparation for LLM

This spec does not call byLLM, but chunks should support batching.

Recommended metadata available to later prompt builder:

```text
chunk_id
order_index
heading path
page range
estimated token count
content
overlap metadata
```

---

# LLM batch limits

Later byLLM stages may combine multiple chunks.

Chunking must not assume:

```text
one chunk = one LLM call
```

Instead chunks are atomic evidence units.

---

# Prompt-safe wrappers

Later prompt builder should wrap content as data, e.g.:

```text
<course_chunk id="chk_123">
...
</course_chunk>
```

Chunk content itself remains untrusted source text.

Do not insert executable instructions into chunk content.

---

# Injection-awareness metadata

If `41` recorded document-level prompt-injection warnings, propagate a safe flag to the chunk set.

Example:

```text
contains_untrusted_instruction_like_text = true
```

Do not alter or delete legitimate course text based on this flag.

---

# Repository contracts

## `DocumentChunkRepository`

Suggested methods:

```text
find_active_chunk_set
find_matching_chunk_set
find_chunk_set_by_id
list_chunks
save_chunk_set
save_chunks
mark_chunked
mark_failed
delete_partial_chunk_set
```

## `DocumentExtractionRepository`

Required:

```text
get_extraction
list_blocks_ordered
```

---

# Walker/API boundary

Chunking is primarily internal.

Possible internal/private walkers:

```text
chunk_course_document
get_course_document_chunking_status
retry_course_document_chunking
```

Do not expose full chunks to learners.

Lecturer-facing UI may show:

```text
chunk count
processing status
warnings
```

not raw internal chunk JSON unless a later review tool needs it.

---

# Frontend states

Suggested:

```text
Preparing course sections…
Organizing your notes…
Building course content structure…
```

Failure:

```text
We could not organize the extracted text into course sections.
Retry processing or upload another document.
```

Avoid implementation jargon such as "token chunking" in normal UI.

---

# Observability

Emit:

```text
document.chunking_queued
document.chunking_started
document.chunking_completed
document.chunking_failed
document.chunking_reused
document.chunking_warning
```

Fields:

```text
document_id
extraction_id
chunk_set_id
track_id
track_version_id
schema_version
strategy
config_hash
chunk_count
avg_tokens
coverage_ratio
duration_ms
error_code
request_id
```

Do not log chunk content.

---

# Metrics

Track:

```text
document_chunking_total
document_chunking_completed_total
document_chunking_failed_total
document_chunking_reused_total

document_chunk_count
document_chunk_average_tokens
document_chunk_max_tokens
document_chunk_overlap_ratio
document_chunk_source_coverage_ratio

document_chunking_duration_ms
```

Dimensions:

```text
strategy
result
file_type
quality
```

Avoid chunk/document IDs as labels.

---

# Chunking error codes

Define:

```text
DOCUMENT_NOT_EXTRACTED
DOCUMENT_EXTRACTION_STALE
DOCUMENT_CHUNKING_ALREADY_RUNNING
DOCUMENT_CHUNKING_CONFIG_INVALID
DOCUMENT_CHUNKING_FAILED
DOCUMENT_CHUNK_LIMIT_EXCEEDED
DOCUMENT_CHUNK_TOO_LARGE
DOCUMENT_CHUNK_EMPTY
DOCUMENT_CHUNK_PROVENANCE_INVALID
DOCUMENT_CHUNK_SOURCE_COVERAGE_LOW
DOCUMENT_CHUNK_ORDER_INVALID
DOCUMENT_CHUNK_PERSIST_FAILED
DOCUMENT_CHUNKING_INTERNAL_ERROR
DOCUMENT_NOT_READY_FOR_BLUEPRINT
```

---

# Testing strategy

## Structural tests

Fixtures:

```text
heading + paragraphs
nested headings
short sections
long sections
lists
large list
small table
large table
headers/footers
footnotes
mixed content
```

Verify structural boundaries.

---

# Heading inheritance tests

Input:

```text
H1 A
P1
H2 B
P2
H3 C
P3
H2 D
P4
```

Expected paths:

```text
P1 → A
P2 → A > B
P3 → A > B > C
P4 → A > D
```

---

# Size-limit tests

Verify:

```text
chunk <= max tokens
chunk <= max chars
```

except explicit test failures.

---

# Oversized paragraph tests

Create one paragraph above maximum.

Verify:

- sentence or whitespace split;
- order preserved;
- overlap controlled;
- no lost text.

---

# Short-section tests

Verify:

- compatible short sections combine;
- unrelated major sections do not combine improperly.

---

# Overlap tests

Verify:

- overlap only when split;
- overlap comes from source text;
- overlap size within config;
- overlap metadata correct.

---

# Provenance tests

For every chunk:

```text
source block IDs exist
source order valid
page range covers blocks
track/version match
```

---

# Coverage tests

Expected semantic content coverage near 100%.

Intentionally filtered:

```text
headers
footers
page breaks
```

must be excluded from denominator according to policy.

---

# Determinism tests

Run chunking twice with:

```text
same extraction
same config
same schema
```

Verify:

```text
same chunk count
same order
same content
same hashes
matching chunk set reused
```

---

# Re-chunk tests

Change:

```text
max tokens
schema version
```

Expected:

```text
new chunk set
old set preserved
```

---

# Concurrency tests

Run two identical chunk jobs.

Expected:

```text
one actual chunking operation
one successful active chunk set
```

---

# Failure-injection tests

Simulate:

```text
token estimator failure
repository write failure
coverage validation failure
service restart mid-chunking
invalid block ordering
```

Verify:

- extraction remains intact;
- no false CHUNKED state;
- retry works;
- old valid chunk set remains usable if present.

---

# PDF provenance tests

Verify:

```text
page_start/page_end
source locators
heading inheritance from extraction
```

---

# DOCX provenance tests

Verify:

```text
heading paths
paragraph/table source locators
no fabricated page numbers
```

---

# Table tests

Large table:

```text
split by row groups
header context retained if configured
no row loss
```

---

# Repeated header/footer tests

Verify repeated page headers do not become hundreds of semantic chunk entries.

---

# Example Jac test outlines

```jac
test "chunks extraction by heading boundaries" {
    # Create extraction blocks with H1/H2 structure.
    # Run chunking.
    # Assert heading paths.
    # Assert source order.
}

test "splits oversized section without losing source text" {
    # Create long section.
    # Run with low max token limit.
    # Assert multiple chunks.
    # Assert coverage near 1.0.
}

test "reuses identical chunk set" {
    # Chunk same extraction twice with same config.
    # Assert same active chunk set is returned.
}

test "rechunk preserves historical chunk set" {
    # Chunk with config A.
    # Chunk with config B.
    # Assert both sets remain.
}

test "failed chunking never marks blueprint-ready" {
    # Inject persistence failure.
    # Assert CHUNKING_FAILED.
    # Assert blueprint eligibility false.
}
```

---

# Performance considerations

Chunking is deterministic CPU/text work.

Avoid:

- one database query per block;
- one graph write per chunk when bulk operations are possible;
- repeatedly estimating tokens for unchanged content;
- loading enormous documents unnecessarily into duplicate structures.

Prefer:

```text
batch read extraction blocks
single ordered pass
batch persist chunks
bounded graph writes
```

---

# Memory strategy

For large extractions:

- iterate blocks;
- finalize chunks incrementally;
- avoid duplicating full plain text repeatedly;
- store only required staging structures.

---

# Cache behavior

Chunk sets are immutable derived artifacts.

Safe cache key:

```text
chunk-set:{extraction_id}:{schema_version}:{config_hash}
```

Do not cache only by:

```text
document_id
```

because re-extraction/re-chunking can produce different outputs.

---

# Published-version rules

If a published course blueprint references chunk set A:

```text
new chunk set B
```

must not automatically change published curriculum.

A new course version or explicit regeneration workflow is required.

---

# Auditability

Later generated blueprint data must record:

```text
chunk_set_id
source chunk IDs
```

so reviewers can answer:

```text
Which parts of the lecturer's notes produced this module or topic?
```

This is a required architectural outcome.

---

# Implementation sequence

## Step 1 — Add chunking status

Extend document processing lifecycle.

## Step 2 — Add chunk-set and chunk nodes

Implement:

```text
DocumentChunkSet
CourseContentChunk
HAS_CHUNK_SET
HAS_CONTENT_CHUNK
```

## Step 3 — Add configuration and token estimator

Centralize size policy.

## Step 4 — Implement ordered extraction loading

Read blocks once in deterministic order.

## Step 5 — Implement heading-state builder

Build structural sections.

## Step 6 — Implement block filtering

Exclude non-semantic noise safely.

## Step 7 — Implement chunk accumulation

Respect structural boundaries and target size.

## Step 8 — Implement oversized-content splitting

Use paragraphs, lists, rows, sentences, then hard splits.

## Step 9 — Add controlled overlap

Only for split continuity.

## Step 10 — Add provenance and hashes

Every chunk traceable to source.

## Step 11 — Add coverage validation

Prevent silent content loss.

## Step 12 — Add idempotency/concurrency

Reuse identical chunk sets.

## Step 13 — Persist chunk set

Use batch writes where practical.

## Step 14 — Add blueprint-readiness guard

Require valid active chunk set.

## Step 15 — Add tests

Run structural, provenance, determinism, coverage, and failure tests.

---

# Acceptance criteria

## Input boundary

- [ ] Only successful `EXTRACTED` artifacts can be chunked.
- [ ] Chunking never reads raw PDF/DOCX directly.
- [ ] Chunking never depends on parser-specific objects.

## Structure

- [ ] Source order is preserved.
- [ ] Heading hierarchy is preserved.
- [ ] Structural boundaries are preferred.
- [ ] Lists and tables split safely.
- [ ] Headers/footers are excluded by default.
- [ ] No arbitrary reordering occurs.

## Size control

- [ ] Target token size is configurable.
- [ ] Maximum token size is enforced.
- [ ] Maximum character size is enforced.
- [ ] Oversized paragraphs split safely.
- [ ] Chunk-count limits are enforced.
- [ ] No silent truncation occurs.

## Overlap

- [ ] Overlap is configurable.
- [ ] Overlap occurs only when useful.
- [ ] Overlap is source-derived.
- [ ] Overlap metadata is recorded.
- [ ] Unrelated sections are not overlapped.

## Provenance

- [ ] Every chunk references its extraction.
- [ ] Every chunk references source blocks.
- [ ] PDF chunks preserve page range.
- [ ] DOCX chunks preserve structural locators.
- [ ] Heading path is preserved.
- [ ] Later blueprint outputs can trace to chunk IDs.

## Determinism

- [ ] Same extraction/config yields same logical chunks.
- [ ] Matching chunk sets are reused.
- [ ] Config/version changes produce new chunk sets.
- [ ] Historical chunk sets remain available when referenced.

## Quality

- [ ] Empty chunks are rejected.
- [ ] Source coverage is validated.
- [ ] Chunk order is validated.
- [ ] Warnings are recorded.
- [ ] Blueprint eligibility requires successful chunking.

## Reliability

- [ ] Concurrent duplicate jobs are controlled.
- [ ] Partial failures do not damage extraction.
- [ ] Failed chunking does not mark course blueprint-ready.
- [ ] Retry works.
- [ ] Old valid chunk sets are preserved.

## Quality gates

- [ ] `jac check` passes.
- [ ] `jac check --lint` passes.
- [ ] `jac test` passes.
- [ ] Determinism tests pass.
- [ ] Coverage tests pass.
- [ ] Provenance tests pass.
- [ ] Failure-injection tests pass.

---

# Check when done

Run:

```bash
jac check <entry-file>
jac check --lint <entry-file>
jac test
```

Then manually verify:

```text
1. Upload and validate a PDF.
2. Extraction completes.
3. Chunking starts.
4. Headings become chunk context.
5. Chunks remain within configured limits.
6. Page provenance is preserved.
7. Source coverage is near 100%.
8. Chunking becomes CHUNKED.
9. Blueprint eligibility becomes true.

10. Process a DOCX with headings, lists, and tables.
11. Structural order is preserved.
12. DOCX page numbers are not fabricated.
13. Heading hierarchy is correct.

14. Process a very large section.
15. It splits into bounded chunks.
16. Controlled overlap is present.
17. No source text is lost.

18. Run chunking again with the same config.
19. Existing chunk set is reused.

20. Change chunking configuration.
21. A new chunk set is created.
22. Old referenced chunk set remains intact.

23. Simulate chunk persistence failure.
24. Extraction remains valid.
25. Course does not become blueprint-ready.

26. Verify every chunk can trace back to extraction blocks and original lecturer source.
```

---

# Expected result

After this specification is implemented:

- GraphLearn converts extracted course text into deterministic, bounded, structurally meaningful chunks;
- headings, page references, and source locators are preserved;
- large documents can be processed safely without sending entire notes into one LLM prompt;
- chunk overlap is controlled and auditable;
- chunk sets are versioned and reproducible;
- silent source-content loss is detected through coverage validation;
- downstream byLLM workflows receive stable evidence units rather than raw document blobs;
- generated course blueprints can later trace every major output back to the lecturer's original notes.
