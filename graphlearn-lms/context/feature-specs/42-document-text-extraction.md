# 42-document-text-extraction.md

## Overview

Implement a secure, deterministic text-extraction subsystem for lecturer-uploaded course documents.

This specification begins only after a document has:

1. been uploaded through `39-course-document-upload.md`;
2. been persisted through `40-course-document-storage.md`;
3. passed the security and validation pipeline in `41-document-security-and-validation.md`.

The extraction subsystem converts validated PDF and DOCX files into normalized, structured text while preserving enough provenance for later:

- chunking;
- course-blueprint generation;
- topic extraction;
- skill graph generation;
- source citations;
- lecturer review;
- regeneration;
- auditing.

The core rule is:

```text
Validated document bytes
→ deterministic structured extraction
→ normalized extraction artifact
→ later chunking

No byLLM calls occur in this specification.
```

---

## Status

- **Feature type:** Document processing / extraction
- **Priority:** Critical
- **Depends on:** `40-course-document-storage.md`
- **Depends on:** `41-document-security-and-validation.md`
- **Blocks:** `43-document-content-chunking.md`
- **Blocks:** `45-course-blueprint-byllm-contracts.md`
- **Breaking changes allowed:** No
- **Primary implementation:** Extraction service + typed artifacts + processing-state integration

---

# Goals

Implement an extraction pipeline that:

1. Reads only security-validated course documents.
2. Supports PDF and DOCX initially.
3. Preserves page, paragraph, heading, and section provenance where possible.
4. Produces deterministic normalized text.
5. Separates extraction from AI interpretation.
6. Detects low-text or empty-content documents.
7. Detects image-only/scanned PDFs and reports OCR requirements without performing OCR.
8. Handles malformed but previously accepted edge cases safely.
9. Prevents parser crashes from corrupting course state.
10. Applies memory, time, page, and output-size limits.
11. Stores extraction artifacts separately from raw document metadata.
12. Supports idempotent retries.
13. Supports extraction-version tracking.
14. Prevents duplicate concurrent extraction jobs.
15. Produces structured errors and observability events.
16. Makes later chunking independent of PDF/DOCX parser details.
17. Preserves enough source mapping for learner-visible citations later.
18. Avoids leaking temporary paths or raw parser internals.
19. Allows future extraction engines to replace the initial implementation without changing downstream contracts.
20. Keeps published course versions reproducible.

---

# Non-goals

This specification does not implement:

- OCR;
- image understanding;
- handwritten-note recognition;
- table semantic reconstruction beyond safe text extraction;
- chart interpretation;
- equation OCR;
- document summarization;
- embeddings;
- chunking;
- byLLM calls;
- blueprint generation;
- topic extraction;
- skill generation;
- course publication;
- lecturer editing of extracted text;
- PowerPoint extraction;
- legacy `.doc` extraction.

---

# Extraction architecture

```text
CourseDocument
(validation_status = VALIDATED)
        │
        ▼
DocumentTextExtractionService
        │
        ├── resolve metadata
        ├── verify extraction eligibility
        ├── open immutable source from storage
        ├── select extractor
        │      ├── PDFExtractor
        │      └── DOCXExtractor
        ├── normalize structure
        ├── calculate extraction metrics
        ├── classify extraction quality
        └── persist extraction artifact
                │
                ▼
DocumentExtraction
        │
        └── ExtractionBlock[]
                │
                ▼
43-document-content-chunking.md
```

Downstream consumers must depend on:

```text
DocumentExtraction
ExtractionBlock
```

rather than PDF- or DOCX-specific parser objects.

---

# Processing-state integration

Extend the document processing lifecycle.

Recommended high-level flow:

```text
UPLOADED
→ STORED
→ VALIDATING
→ VALIDATED
→ EXTRACTING
→ EXTRACTED
→ CHUNKING
→ CHUNKED
```

Failure states:

```text
EXTRACTION_FAILED
OCR_REQUIRED
NO_EXTRACTABLE_TEXT
```

A document must not move to chunking unless extraction has completed successfully.

---

# Extraction status enum

```jac
enum DocumentExtractionStatus {
    NOT_STARTED,
    QUEUED,
    EXTRACTING,
    EXTRACTED,
    OCR_REQUIRED,
    NO_EXTRACTABLE_TEXT,
    EXTRACTION_FAILED
}
```

Meaning:

| Status | Meaning |
|---|---|
| `NOT_STARTED` | Validation passed but extraction has not started |
| `QUEUED` | Extraction is scheduled |
| `EXTRACTING` | Extraction currently running |
| `EXTRACTED` | Structured extraction completed successfully |
| `OCR_REQUIRED` | Document is likely scanned/image-only |
| `NO_EXTRACTABLE_TEXT` | Parser completed but meaningful text was not found |
| `EXTRACTION_FAILED` | Infrastructure/parser failure prevented completion |

Only:

```text
EXTRACTED
```

may proceed to chunking.

---

# Extraction versioning

Use an explicit extractor contract version.

```text
DOCUMENT_EXTRACTION_SCHEMA_VERSION = 1
```

Also record extractor implementation version:

```text
extractor_name
extractor_version
```

Example:

```text
pdf: pymupdf-1.x
docx: python-docx-1.x
```

Do not make downstream logic depend on exact library names.

Versioning allows:

- parser upgrades;
- normalization changes;
- reproducibility;
- selective re-extraction.

---

# Core extraction node

Create a separate extraction artifact.

```jac
node DocumentExtraction {
    has extraction_id: str;

    has document_id: str;
    has track_id: str;
    has track_version_id: str;

    has status: DocumentExtractionStatus;

    has schema_version: int = 1;

    has extractor_name: str;
    has extractor_version: str;

    has source_checksum_sha256: str;

    has total_characters: int = 0;
    has total_words: int = 0;
    has total_blocks: int = 0;
    has total_pages: int | None = None;

    has detected_language: str | None = None;

    has extraction_quality: str | None = None;

    has plain_text: str | None = None;

    has started_at: str | None = None;
    has completed_at: str | None = None;

    has error_code: str | None = None;
    has error_message: str | None = None;
}
```

---

# Why extraction is separate from `CourseDocument`

`CourseDocument` represents:

```text
the immutable source artifact
```

`DocumentExtraction` represents:

```text
a derived interpretation of the source bytes
```

This separation allows:

- re-extraction with a newer parser;
- extraction-version comparison;
- preserving original source;
- failure retries;
- reproducibility.

Do not overwrite raw document metadata with parser-specific output.

---

# Extraction block model

Create structured blocks.

```jac
node ExtractionBlock {
    has extraction_block_id: str;
    has extraction_id: str;

    has order_index: int;

    has block_type: str;

    has text: str;

    has page_start: int | None = None;
    has page_end: int | None = None;

    has heading_level: int | None = None;
    has heading_text: str | None = None;

    has paragraph_index: int | None = None;

    has source_locator: str | None = None;

    has character_start: int;
    has character_end: int;

    has word_count: int;

    has metadata_json: str | None = None;
}
```

Possible `block_type` values:

```text
HEADING
PARAGRAPH
LIST_ITEM
TABLE_TEXT
CAPTION
FOOTNOTE
HEADER
FOOTER
PAGE_BREAK
OTHER
```

Use an enum if the project prefers strict typing.

---

# Extraction graph

Suggested graph:

```text
CourseDocument
└── HAS_EXTRACTION
    └── DocumentExtraction
        └── HAS_EXTRACTION_BLOCK
            ├── ExtractionBlock 1
            ├── ExtractionBlock 2
            └── ExtractionBlock N
```

Edges:

```jac
edge HAS_EXTRACTION {
    has created_at: str;
}

edge HAS_EXTRACTION_BLOCK {
    has order_index: int;
}
```

One active extraction should exist per:

```text
document_id
source checksum
extraction schema version
```

Historical extraction artifacts may be retained.

---

# Source checksum binding

Every extraction must record:

```text
source_checksum_sha256
```

Before reuse, verify:

```text
DocumentExtraction.source_checksum_sha256
==
CourseDocument.checksum_sha256
```

If they differ:

```text
stale extraction
→ do not reuse
```

---

# Extraction eligibility

Create:

```text
assert_document_ready_for_extraction(document_id)
```

Required:

```text
document exists
upload_status == STORED
validation_status == VALIDATED
storage integrity valid
document not deleted
document not quarantined
document is allowed for processing
```

Do not start extraction based only on `validation_status`.

---

# Extractor interface

Create one common abstraction.

```jac
obj DocumentExtractor {
    def supports(
        detected_file_type: str
    ) -> bool;

    def extract(
        source: DocumentBinarySource,
        context: ExtractionContext
    ) -> RawExtractionResult;
}
```

Implement:

```text
PDFDocumentExtractor
DOCXDocumentExtractor
```

Downstream code must not import parser-library objects directly.

---

# Extraction context

```jac
obj ExtractionContext {
    has extraction_id: str;

    has document_id: str;
    has track_id: str;
    has track_version_id: str;

    has source_checksum_sha256: str;

    has request_id: str;
    has schema_version: int;

    has max_characters: int;
    has max_blocks: int;
    has timeout_seconds: int;
}
```

---

# Raw extraction result

```jac
obj RawExtractionResult {
    has blocks: list[RawExtractionBlock];

    has total_pages: int | None;

    has parser_metadata_json: str | None;

    has warnings: list[str];
}
```

Block:

```jac
obj RawExtractionBlock {
    has block_type: str;
    has text: str;

    has page_start: int | None;
    has page_end: int | None;

    has heading_level: int | None;
    has heading_text: str | None;

    has source_locator: str | None;

    has metadata_json: str | None;
}
```

The normalization layer converts raw blocks to canonical `ExtractionBlock`.

---

# PDF extraction

Initial PDF extraction should use a maintained library capable of:

- page iteration;
- text extraction;
- text blocks where possible;
- page count;
- metadata-free safe parsing.

A typical implementation may use:

```text
PyMuPDF
```

or another maintained parser.

Do not couple the domain contract to the library.

---

# PDF extraction goals

For every page:

1. extract text;
2. preserve page number;
3. preserve approximate block order;
4. remove obvious empty blocks;
5. identify repeated headers/footers where feasible;
6. retain page-level provenance;
7. avoid running embedded actions or scripts.

---

# PDF source locator

Use source locators such as:

```text
pdf:page=12:block=4
```

Example:

```text
pdf:page=33
pdf:page=33:block=2
```

Later source citations may use:

```text
pages 33–34
```

Do not expose parser-internal object IDs.

---

# Page numbering

Use:

```text
1-based human page numbers
```

internally for user-facing provenance where possible.

If parser APIs use zero-based indices, normalize before persistence.

---

# PDF reading order

PDF text order can be imperfect.

Use parser-provided block coordinates/order where available.

The first release does not need sophisticated multi-column reconstruction.

However:

- do not randomly concatenate blocks;
- preserve deterministic order;
- flag suspicious layouts.

Possible warning:

```text
PDF_COMPLEX_LAYOUT
```

---

# PDF headers and footers

Repeated page headers/footers can pollute later chunking.

Implement conservative detection.

Candidate repeated text:

```text
appears on large percentage of pages
appears in similar page position
short text
```

Possible behavior:

```text
mark as HEADER or FOOTER
```

Do not necessarily delete automatically.

The chunking stage may exclude them.

---

# PDF tables

Do not attempt full semantic table reconstruction in this specification.

At minimum:

- extract available cell/text content;
- preserve page provenance;
- mark block type as `TABLE_TEXT` where confidently detected.

If detection is unreliable:

```text
block_type = OTHER
```

Do not fabricate table structure.

---

# PDF images

Image extraction is out of scope.

If a page contains images plus extractable text:

```text
extract text only
```

If most/all pages contain no text:

```text
OCR_REQUIRED
```

---

# Scanned/image-only PDF detection

Use heuristics.

Example:

```text
page_count > 0
AND extracted text characters below threshold
AND pages contain image objects or no text layer
```

Config:

```text
DOCUMENT_MIN_EXTRACTABLE_CHARACTERS
DOCUMENT_MIN_TEXT_CHARACTERS_PER_PAGE
```

Example thresholds:

```text
minimum total characters = 100
average meaningful characters/page = configurable
```

Do not rely on one heuristic alone.

---

# OCR-required result

When likely scanned:

```text
status = OCR_REQUIRED
error_code = DOCUMENT_OCR_REQUIRED
```

User-facing message:

```text
This PDF appears to contain scanned images rather than selectable text.
Please upload a text-based PDF or DOCX version.
```

OCR may be added later.

---

# PDF text quality

Track:

```text
pages_with_text
pages_without_text
characters_per_page
```

This helps identify:

- scanned appendices;
- corrupted text layers;
- partial extraction.

Warnings may include:

```text
PARTIAL_TEXT_LAYER
LOW_TEXT_DENSITY
COMPLEX_LAYOUT
```

Warnings do not automatically fail extraction unless thresholds require it.

---

# DOCX extraction

DOCX extraction should preserve:

- headings;
- paragraphs;
- list items;
- tables;
- captions where detectable;
- section order.

Typical implementation may use:

```text
python-docx
```

or another maintained parser.

The exact parser is hidden behind the extractor interface.

---

# DOCX reading order

Iterate document body elements in actual document order.

Do not process:

```text
all paragraphs first
then all tables
```

because this destroys ordering.

Use a body-element iterator that interleaves:

```text
paragraph
table
paragraph
list
```

in source order.

---

# DOCX headings

Map Word styles where available:

```text
Heading 1 → heading_level 1
Heading 2 → heading_level 2
...
```

Preserve heading text.

Example:

```json
{
  "block_type": "HEADING",
  "heading_level": 2,
  "heading_text": "Database Normalization",
  "text": "Database Normalization"
}
```

---

# DOCX paragraphs

Each meaningful paragraph becomes a block.

Normalize:

- trailing spaces;
- repeated internal whitespace conservatively;
- empty paragraphs.

Do not remove meaningful blank separation before structural normalization is complete.

---

# DOCX lists

Preserve list items when detectable.

Example:

```text
LIST_ITEM
```

Metadata may include:

```text
ordered
unordered
nesting level
```

Do not fabricate numbering if the parser cannot reliably resolve numbering definitions.

---

# DOCX tables

Extract text row-by-row.

Preserve a deterministic text representation.

Example normalized form:

```text
Name | Description
DBMS | Database Management System
SQL | Structured Query Language
```

Store:

```text
block_type = TABLE_TEXT
```

Metadata may contain:

```text
rows
columns
```

Do not overcomplicate semantic reconstruction.

---

# DOCX headers and footers

Extract optionally as:

```text
HEADER
FOOTER
```

Do not mix them blindly into main body text.

Chunking should generally exclude them unless explicitly useful.

---

# DOCX footnotes/endnotes

If supported safely by the parser:

- extract as separate blocks;
- preserve source locator;
- mark as `FOOTNOTE`.

If unsupported:

- record a warning;
- do not fail the entire extraction.

---

# DOCX comments/revisions

Initial policy:

```text
comments not part of canonical learning text
tracked-deletion text excluded
accepted/current visible text preferred
```

If parser behavior cannot distinguish revisions reliably:

- document limitation;
- preserve visible text as parser returns it;
- emit warning when revision metadata detected.

---

# DOCX embedded objects

Security validation already blocks suspicious active content.

Extraction must not:

- execute embedded objects;
- open OLE files;
- follow links;
- fetch external templates.

Only extract safe text directly available in the document body.

---

# Plain-text normalization

Create one deterministic normalization pipeline.

Goals:

```text
consistent Unicode
consistent line endings
controlled whitespace
no parser-specific artifacts
preserved meaningful structure
```

---

# Unicode normalization

Use a documented Unicode normalization form.

Recommended:

```text
NFC
```

Do not aggressively transliterate or strip non-English characters.

The LMS may support multilingual courses later.

---

# Line endings

Normalize:

```text
\r\n
\r
```

to:

```text
\n
```

---

# Whitespace

Rules:

- strip leading/trailing whitespace per block;
- collapse excessive spaces where safe;
- preserve meaningful paragraph boundaries;
- avoid merging words across line breaks incorrectly;
- remove zero-width artifacts where safe.

---

# Hyphenation

PDFs may contain line-break hyphenation.

Example:

```text
data-
base
```

Do not aggressively dehyphenate all cases.

A conservative normalizer may join when:

```text
hyphen at line end
next token begins lowercase
no obvious list/bullet boundary
```

If uncertain, preserve original form.

Determinism is more important than speculative correction.

---

# Ligatures

Normalize common ligatures where parser output allows.

Examples:

```text
ﬁ → fi
ﬂ → fl
```

Do not alter domain-specific symbols unnecessarily.

---

# Control characters

Remove or replace unsafe control characters except:

```text
\n
\t where intentionally preserved
```

Record warning if large amounts are removed.

---

# Empty-block removal

Remove blocks that contain only:

```text
whitespace
zero-width characters
page-number-only noise when confidently identified
```

Do not remove short educational content such as:

```text
SQL
ACID
1NF
```

based solely on length.

---

# Repeated-content detection

Identify repeated header/footer candidates.

Do not remove repeated main-body concepts merely because they occur often.

Use positional/context evidence where available.

---

# Canonical plain text

Build:

```text
DocumentExtraction.plain_text
```

from normalized body blocks.

Recommended separators:

```text
HEADING → "\n\n"
PARAGRAPH → "\n\n"
LIST_ITEM → "\n"
TABLE_TEXT → "\n\n"
```

This field is a convenience artifact.

The canonical structured blocks remain authoritative for chunking.

---

# Output-size limits

Config:

```text
DOCUMENT_EXTRACTION_MAX_CHARACTERS
DOCUMENT_EXTRACTION_MAX_BLOCKS
```

Example initial limits:

```text
max characters = 5,000,000
max blocks = 100,000
```

Tune operationally.

If exceeded:

```text
EXTRACTION_FAILED
DOCUMENT_EXTRACTION_LIMIT_EXCEEDED
```

Do not silently truncate unless policy explicitly allows it.

Silent truncation would make course generation incomplete.

---

# Timeout

Config:

```text
DOCUMENT_EXTRACTION_TIMEOUT_SECONDS
```

Recommended:

```text
60–300 seconds
```

depending on document size and deployment.

On timeout:

```text
EXTRACTION_FAILED
DOCUMENT_EXTRACTION_TIMEOUT
```

The job must be retryable.

---

# Resource isolation

Where practical:

- bound memory;
- use isolated temporary directories;
- clean up temporary files;
- disable network access;
- avoid shell commands;
- use least privilege.

Parsing hostile files was already validated, but parser bugs remain possible.

---

# Temporary files

If a parser requires a temporary file:

- create a random server-managed name;
- never use original filename as path;
- store in isolated temp directory;
- delete in `finally` cleanup;
- do not persist temp paths.

---

# Extraction quality classification

Classify extraction output.

Suggested enum:

```jac
enum ExtractionQuality {
    HIGH,
    MEDIUM,
    LOW
}
```

Possible signals:

```text
text density
empty-page ratio
parser warnings
replacement-character frequency
block count anomalies
complex layout
```

Example:

```text
HIGH
→ good text layer, few warnings

MEDIUM
→ partial layout issues, some empty pages

LOW
→ extraction technically succeeded but quality may affect curriculum generation
```

Low quality may require lecturer review before blueprint generation.

---

# Quality metrics

Record:

```text
text_character_count
word_count
pages_with_text
pages_without_text
empty_block_count
replacement_character_count
warning_count
```

Do not use quality score as a substitute for human review.

---

# Language detection

Optional lightweight language detection may be performed after extraction.

Store:

```text
detected_language
```

Examples:

```text
en
sw
fr
```

Do not reject a course because language differs from platform UI language.

Language detection should be advisory.

---

# Extraction error codes

Define:

```text
DOCUMENT_NOT_VALIDATED
DOCUMENT_NOT_READY_FOR_EXTRACTION
DOCUMENT_STORAGE_READ_FAILED
DOCUMENT_EXTRACTION_UNSUPPORTED_TYPE
DOCUMENT_EXTRACTION_PDF_FAILED
DOCUMENT_EXTRACTION_DOCX_FAILED
DOCUMENT_EXTRACTION_TIMEOUT
DOCUMENT_EXTRACTION_LIMIT_EXCEEDED
DOCUMENT_EXTRACTION_EMPTY
DOCUMENT_OCR_REQUIRED
DOCUMENT_NO_EXTRACTABLE_TEXT
DOCUMENT_EXTRACTION_STALE_SOURCE
DOCUMENT_EXTRACTION_ALREADY_RUNNING
DOCUMENT_EXTRACTION_PERSIST_FAILED
DOCUMENT_EXTRACTION_NORMALIZATION_FAILED
DOCUMENT_EXTRACTION_INTERNAL_ERROR
```

---

# Error classification

## Retryable

```text
storage read timeout
temporary parser infrastructure failure
persistence failure
worker crash
temporary resource exhaustion
```

## Non-retryable without new source

```text
OCR required
no extractable text
unsupported type
```

Parser defects may become retryable after deployment upgrade.

---

# User-facing messages

## OCR required

```text
This document appears to be scanned or image-based.
Please upload a text-based PDF or DOCX version.
```

## No text

```text
We could not find enough readable text in this document.
Please upload a document containing selectable text.
```

## Temporary failure

```text
We could not process this document right now.
Please retry the extraction.
```

Do not expose parser stack traces.

---

# Extraction service

Create:

```text
DocumentTextExtractionService
```

Responsibilities:

```text
resolve_document
assert_extractable
resolve_existing_extraction
acquire_extraction_lock
open_source
select_extractor
extract_raw_blocks
normalize_blocks
calculate_metrics
classify_quality
persist_extraction
update_processing_status
emit_events
release_lock
```

---

# Service contract

Conceptual:

```jac
obj DocumentTextExtractionService {
    def extract_document(
        document_id: str,
        context: ExtractionRequestContext
    ) -> DocumentExtractionResult;

    def get_extraction(
        document_id: str
    ) -> DocumentExtractionResult | None;

    def retry_extraction(
        document_id: str,
        context: ExtractionRequestContext
    ) -> DocumentExtractionResult;

    def can_chunk(
        document_id: str
    ) -> bool;
}
```

---

# Extraction request context

```jac
obj ExtractionRequestContext {
    has document_id: str;
    has track_id: str;
    has track_version_id: str;

    has request_id: str;
    has actor_id: str | None;

    has extraction_schema_version: int;
    has force_reextract: bool = False;
}
```

---

# Idempotency

Extraction identity:

```text
document_id
source checksum
extraction schema version
```

If a successful matching extraction exists:

```text
return existing extraction
```

Do not re-run parser unnecessarily.

---

# Force re-extraction

Allowed only when:

```text
authorized internal/admin operation
OR parser migration workflow
```

A forced re-extraction creates:

```text
new extraction_id
```

Do not mutate historical extraction in place.

---

# Concurrency

Only one extraction job may run for:

```text
document_id + schema_version
```

Duplicate requests should:

- return `EXTRACTING`; or
- attach to existing job.

Do not run duplicate parser workloads.

---

# Extraction lock

Implement one:

```text
database/job lock
optimistic state transition
unique active extraction invariant
```

Example:

```text
NOT_STARTED
→ compare-and-set EXTRACTING
```

If transition fails because already extracting:

```text
DOCUMENT_EXTRACTION_ALREADY_RUNNING
```

---

# Persistence strategy

Persist extraction only after normalized output is valid.

Recommended sequence:

```text
1. mark EXTRACTING
2. parse to temporary in-memory/staged representation
3. normalize
4. validate output invariants
5. create DocumentExtraction
6. create ExtractionBlocks
7. connect edges
8. mark extraction EXTRACTED
9. update CourseDocument extraction status
10. emit completion
```

If steps 5–8 fail:

- mark `EXTRACTION_FAILED`;
- clean partial derived graph safely;
- raw source remains unchanged.

---

# Output invariants

Before commit:

```text
extraction_id unique
document_id matches source
track_id matches document
track_version_id matches document
source checksum matches
block order contiguous
character offsets valid
total character count consistent
no block exceeds configured max
no null block text
```

---

# Character offsets

Build offsets against canonical `plain_text`.

Each block stores:

```text
character_start
character_end
```

Invariant:

```text
plain_text[character_start:character_end]
corresponds to normalized block representation
```

This supports later traceability.

If separators make exact substring mapping difficult, define a deterministic composition algorithm and test it.

---

# Block order

`order_index`:

```text
0..N-1
```

or:

```text
1..N
```

Choose one convention and use it everywhere.

Recommended:

```text
0-based internal order_index
```

Human page numbers remain 1-based.

---

# Repository contracts

## `DocumentExtractionRepository`

Suggested operations:

```text
find_active_for_document
find_by_id
find_by_source_and_schema_version
list_blocks
save_extraction
save_blocks
mark_extracted
mark_failed
delete_partial_extraction
```

## `CourseDocumentRepository`

Add:

```text
mark_extraction_queued
mark_extracting
mark_extracted
mark_ocr_required
mark_no_extractable_text
mark_extraction_failed
```

---

# Walker/API boundary

Extraction is primarily internal processing.

Possible private/internal walkers:

```text
extract_course_document
get_course_document_extraction_status
retry_course_document_extraction
```

Do not expose raw extraction blocks to ordinary learners.

Lecturer UI may receive safe status/summary only.

---

# Example status response

```json
{
  "document_id": "doc_123",
  "status": "EXTRACTED",
  "quality": "HIGH",
  "total_pages": 84,
  "total_words": 31240,
  "warnings": []
}
```

Do not return entire extracted text in dashboard APIs.

---

# Frontend behavior

After validation:

```text
Validating document...
→ Extracting course text...
→ Preparing course structure...
```

For extraction states:

## `EXTRACTING`

```text
Extracting readable text from your notes…
```

## `OCR_REQUIRED`

```text
This PDF appears to be scanned.
Upload a text-based PDF or DOCX file to continue.
```

## `NO_EXTRACTABLE_TEXT`

```text
We could not find enough readable text in this document.
```

## `EXTRACTION_FAILED`

```text
Text extraction failed.
Retry the process or upload another document.
```

---

# Cancellation

If a draft document is replaced while extraction runs:

```text
job may finish
but must not advance replaced document into active processing flow
```

Before final status transition:

```text
re-read CourseDocument state
verify still current/eligible
```

Historical extraction may remain for audit.

---

# Version immutability

Published versions may retain historical extraction artifacts.

Re-extraction for a published source:

- may occur for maintenance;
- must create a new extraction artifact;
- must not silently change existing published blueprint provenance.

Any downstream regeneration must be explicit.

---

# Provenance

Every extraction block must preserve enough source information to support:

```text
Generated concept
→ chunk
→ extraction block
→ source document
→ page/paragraph locator
```

This provenance chain is essential.

---

# Provenance examples

PDF:

```json
{
  "source_locator": "pdf:page=33:block=2",
  "page_start": 33,
  "page_end": 33
}
```

DOCX:

```json
{
  "source_locator": "docx:body=paragraph:128",
  "heading_text": "Database Normalization"
}
```

---

# Extraction warnings

Supported warnings may include:

```text
PDF_COMPLEX_LAYOUT
PDF_PARTIAL_TEXT_LAYER
PDF_LOW_TEXT_DENSITY
DOCX_TRACKED_CHANGES_PRESENT
DOCX_FOOTNOTES_PARTIALLY_SUPPORTED
DOCX_COMPLEX_TABLES
UNKNOWN_HEADING_STYLE
REPEATED_HEADER_FOOTER_DETECTED
LANGUAGE_DETECTION_UNCERTAIN
```

Warnings:

- do not automatically mean failure;
- must be available to later lecturer review/readiness projections.

---

# Observability

Emit:

```text
document.extraction_queued
document.extraction_started
document.extraction_completed
document.extraction_failed
document.extraction_ocr_required
document.extraction_no_text
document.extraction_reused
document.extraction_warning
```

Fields:

```text
document_id
extraction_id
track_id
track_version_id
extractor_name
schema_version
pages
characters
words
blocks
quality
duration_ms
error_code
request_id
```

Do not log extracted text.

---

# Metrics

Track:

```text
document_extraction_total
document_extraction_completed_total
document_extraction_failed_total
document_extraction_ocr_required_total
document_extraction_no_text_total
document_extraction_reused_total
document_extraction_duration_ms
document_extraction_characters_total
document_extraction_pages_total
document_extraction_blocks_total
```

Dimensions:

```text
file_type
extractor
result
quality
```

Avoid high-cardinality IDs.

---

# Performance considerations

Large documents must not create one massive in-memory string unnecessarily.

Where practical:

- process PDF page-by-page;
- iterate DOCX body elements;
- accumulate bounded block structures;
- stream to temporary staging if output is very large.

Do not send extraction output to an LLM in this phase.

---

# Memory safeguards

Estimate:

```text
raw file size
expanded DOCX size
extracted text size
block count
```

Abort safely before memory exhaustion.

Use configured limits from validation and extraction.

---

# Extraction reproducibility

Given:

```text
same source checksum
same extraction schema version
same extractor version/config
```

output should be deterministic enough for:

- stable chunking;
- test fixtures;
- provenance.

Avoid timestamps or random IDs inside normalized text.

IDs may be random, but ordering/content must remain deterministic.

---

# Testing strategy

## Eligibility tests

Attempt extraction for documents in:

```text
PENDING_VALIDATION
VALIDATING
REJECTED
QUARANTINED
VALIDATION_FAILED
```

All fail.

`VALIDATED` succeeds.

---

# PDF tests

Fixtures:

```text
simple text PDF
multi-page PDF
headings and paragraphs
table-like content
repeated headers
partial text pages
image-only PDF
mixed image/text PDF
complex multi-column PDF
```

Verify:

- correct page count;
- deterministic block order;
- page provenance;
- no OCR attempt;
- OCR-required detection;
- warnings.

---

# DOCX tests

Fixtures:

```text
headings
paragraphs
lists
tables
headers/footers
footnotes where supported
tracked changes
```

Verify source order.

Important regression:

```text
paragraph
table
paragraph
```

must remain in that order.

---

# Normalization tests

Verify:

```text
Unicode normalization
line ending normalization
whitespace normalization
ligatures
zero-width characters
hyphenation policy
control-character cleanup
```

Output must be deterministic.

---

# Empty-text tests

Test:

```text
empty DOCX
PDF with blank pages
image-only PDF
document containing only whitespace
```

Expected:

```text
OCR_REQUIRED
or NO_EXTRACTABLE_TEXT
```

according to evidence.

---

# Limit tests

Test:

```text
too many output characters
too many blocks
timeout
very large page count already validation-approved under test config
```

Ensure safe failure.

---

# Idempotency tests

Run extraction twice against:

```text
same document
same checksum
same schema version
```

Expected:

```text
existing extraction reused
```

---

# Re-extraction tests

Force re-extraction.

Verify:

```text
new extraction_id
old artifact preserved
same source checksum
new schema/version recorded
```

---

# Concurrency tests

Start two extraction jobs simultaneously.

Expected:

```text
one parser execution
one active extraction
second request returns current status/reuse
```

---

# Failure-injection tests

Simulate:

```text
storage read failure
parser exception
normalization exception
persistence failure
server restart mid-extraction
timeout
```

Verify:

- raw source untouched;
- no false `EXTRACTED`;
- retry possible;
- partial artifacts cleaned/recoverable.

---

# Provenance tests

Verify every block can trace to:

```text
document
track
track version
page/paragraph locator
```

---

# Example Jac test outlines

```jac
test "extracts validated pdf with page provenance" {
    # Store a validated multi-page PDF fixture.
    # Run extraction.
    # Assert EXTRACTED.
    # Assert total_pages matches.
    # Assert blocks contain page locators.
}

test "detects image-only pdf as OCR required" {
    # Use a scanned/image-only fixture.
    # Assert OCR_REQUIRED.
    # Assert no chunking is allowed.
}

test "docx preserves paragraph and table order" {
    # Build paragraph-table-paragraph fixture.
    # Extract.
    # Assert block order matches source.
}

test "reuses matching extraction artifact" {
    # Extract same source twice.
    # Assert one active extraction for schema version.
}

test "parser failure never marks document extracted" {
    # Inject parser exception.
    # Assert EXTRACTION_FAILED.
    # Assert retry is possible.
}
```

---

# Implementation sequence

## Step 1 — Add extraction status fields

Extend course-document processing state.

## Step 2 — Add extraction nodes and edges

Implement:

```text
DocumentExtraction
ExtractionBlock
HAS_EXTRACTION
HAS_EXTRACTION_BLOCK
```

## Step 3 — Add extractor interface

Create PDF and DOCX adapters.

## Step 4 — Implement eligibility guard

Reuse validation/storage integrity boundaries.

## Step 5 — Implement PDF extraction

Preserve page-level provenance.

## Step 6 — Implement DOCX extraction

Preserve body order and heading structure.

## Step 7 — Implement normalization

Create canonical block/text output.

## Step 8 — Implement quality metrics

Detect empty, low-density, and OCR-required cases.

## Step 9 — Add idempotency/concurrency protection

Prevent duplicate parser runs.

## Step 10 — Persist extraction artifact

Store structured blocks and metadata.

## Step 11 — Integrate processing status

Update lecturer dashboard/readiness state.

## Step 12 — Add tests

Run parser, provenance, normalization, concurrency, and failure tests.

---

# Acceptance criteria

## Eligibility

- [ ] Only `VALIDATED` documents can be extracted.
- [ ] Quarantined/rejected documents are blocked.
- [ ] Storage integrity is rechecked or trusted through a verified guard.
- [ ] Replaced/deleted documents cannot advance incorrectly.

## PDF

- [ ] Text is extracted page by page.
- [ ] Page provenance is retained.
- [ ] Block ordering is deterministic.
- [ ] Image-only PDFs become `OCR_REQUIRED`.
- [ ] Empty PDFs do not proceed.
- [ ] Complex-layout warnings are recorded.

## DOCX

- [ ] Headings are preserved.
- [ ] Paragraphs are preserved.
- [ ] Lists are preserved where detectable.
- [ ] Tables are extracted as text.
- [ ] Body order is preserved.
- [ ] External resources are never fetched.
- [ ] Embedded content is never executed.

## Normalization

- [ ] Unicode is normalized consistently.
- [ ] Line endings are normalized.
- [ ] Unsafe control characters are removed.
- [ ] Whitespace is normalized conservatively.
- [ ] Canonical plain text is deterministic.
- [ ] Structured blocks remain authoritative.

## Provenance

- [ ] Every extraction references source document/checksum.
- [ ] Every block has stable order.
- [ ] PDF blocks preserve page references.
- [ ] DOCX blocks preserve source locators/headings where possible.
- [ ] Later chunks can trace back to source.

## Reliability

- [ ] Extraction is idempotent.
- [ ] Duplicate concurrent jobs are prevented.
- [ ] Parser failures are recoverable.
- [ ] Partial failed artifacts do not become active.
- [ ] Forced re-extraction creates a new artifact.
- [ ] Published historical extraction can remain reproducible.

## Limits

- [ ] Extraction time limit is enforced.
- [ ] Character limit is enforced.
- [ ] Block limit is enforced.
- [ ] No silent truncation occurs.

## Quality

- [ ] `jac check` passes.
- [ ] `jac check --lint` passes.
- [ ] `jac test` passes.
- [ ] PDF fixtures pass.
- [ ] DOCX fixtures pass.
- [ ] OCR-required tests pass.
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
1. Upload a valid PDF.
2. Validation passes.
3. Extraction starts.
4. Page count is preserved.
5. Extracted text is readable.
6. Blocks contain page provenance.
7. Extraction becomes EXTRACTED.
8. Chunking eligibility becomes true.

9. Upload a valid DOCX.
10. Headings are preserved.
11. Paragraph/table order remains correct.
12. Extraction becomes EXTRACTED.

13. Upload an image-only PDF.
14. Validation may pass file security.
15. Extraction identifies OCR_REQUIRED.
16. Chunking does not start.

17. Simulate parser failure.
18. Document becomes EXTRACTION_FAILED.
19. Retry works after fixing the failure.

20. Run extraction twice.
21. Matching successful extraction is reused.

22. Replace a source file during extraction.
23. Old extraction cannot become the active processing source.

24. Verify every generated extraction block can be traced to the original document and source location.
```

---

# Expected result

After this specification is implemented:

- GraphLearn can safely convert validated PDF/DOCX source files into deterministic structured text;
- raw storage and extraction concerns remain separated;
- PDF page provenance and DOCX structural context are preserved;
- image-only documents are detected without pretending OCR support exists;
- extraction artifacts are versioned, idempotent, and reproducible;
- parser failures do not corrupt course state;
- later chunking no longer depends on PDF/DOCX parser internals;
- every later generated topic, lesson, quiz, or roadmap can eventually trace back through chunks and extraction blocks to the lecturer's original notes.
