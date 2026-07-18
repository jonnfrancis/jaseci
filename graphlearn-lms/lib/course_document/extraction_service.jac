"""Secure deterministic document text extraction application service."""

import json;
import os;
import time;
import uuid;
import lib.course_document.extraction_engine as engine;
import from lib.course_document.extraction_metrics { record_document_extraction }
import from lib.course_document.extraction_repository { DocumentExtractionRepository }
import from lib.course_document.extractors { DOCXDocumentExtractor, DocumentExtractor, PDFDocumentExtractor }
import from lib.course_document.repositories { CourseDocumentRepository }
import from lib.course_document.storage_service { CourseDocumentStorageService }
import from lib.course_document.validation_service { DocumentSecurityValidationService }
import from lib.learning_track.application_services { service_now }
import from lib.learning_track.repositories { repository_find_track, repository_find_version }
import from lib.observability.events { ObservabilityEvent }
import from lib.observability.logger { emit_event }
import from nodes.curriculum {
    CourseDocument, DocumentExtraction, DocumentExtractionResult, DocumentExtractionStatus,
    DocumentValidationContext, ExtractionBlock, ExtractionContext, ExtractionQuality,
    ExtractionRequestContext, RawExtractionBlock, RawExtractionResult
}
import from nodes.learning_track { TrackVersion }

glob DOCUMENT_EXTRACTION_SCHEMA_VERSION: int = 1;

def _safe_message(code: str) -> str {
    if code == "DOCUMENT_OCR_REQUIRED" { return "This document appears to be scanned or image-based. Please upload a text-based PDF or DOCX version."; }
    if code in ["DOCUMENT_NO_EXTRACTABLE_TEXT", "DOCUMENT_EXTRACTION_EMPTY"] { return "We could not find enough readable text in this document. Please upload a document containing selectable text."; }
    return "We could not process this document right now. Please retry the extraction.";
}

def _to_result(extraction: DocumentExtraction, reused: bool = False) -> DocumentExtractionResult {
    warnings = json.loads(extraction.warnings_json) as list[str];
    return DocumentExtractionResult(document_id=extraction.document_id, extraction_id=extraction.extraction_id,
        status=extraction.status, reused=reused, quality=extraction.extraction_quality, total_pages=extraction.total_pages,
        total_characters=extraction.total_characters, total_words=extraction.total_words,
        total_blocks=extraction.total_blocks, warnings=warnings, error_code=extraction.error_code,
        user_message=extraction.error_message);
}

def _quality(raw: RawExtractionResult, characters: int, warnings: list[str]) -> ExtractionQuality {
    replacement_count = sum(block.text.count("�") for block in raw.blocks);
    if characters < 500 or replacement_count > max(10, characters // 100) or len(warnings) >= 3 { return ExtractionQuality.LOW; }
    if raw.pages_without_text > 0 or len(warnings) > 0 { return ExtractionQuality.MEDIUM; }
    return ExtractionQuality.HIGH;
}

obj DocumentTextExtractionService {
    has storage_service: CourseDocumentStorageService = CourseDocumentStorageService();
    has document_repository: CourseDocumentRepository = CourseDocumentRepository();
    has extraction_repository: DocumentExtractionRepository = DocumentExtractionRepository();
    has pdf_extractor: DocumentExtractor = PDFDocumentExtractor();
    has docx_extractor: DocumentExtractor = DOCXDocumentExtractor();

    def _resolve(context: ExtractionRequestContext) -> tuple[CourseDocument, TrackVersion] {
        track = repository_find_track(context.track_id); version = None if track is None else repository_find_version(track, context.track_version_id);
        if version is None { raise PermissionError("DOCUMENT_NOT_READY_FOR_EXTRACTION"); }
        validation_context = DocumentValidationContext(document_id=context.document_id, track_id=context.track_id,
            track_version_id=context.track_version_id, actor_id=context.actor_id, request_id=context.request_id);
        document = DocumentSecurityValidationService(storage_service=self.storage_service, repository=self.document_repository).assert_document_extractable(context.document_id, validation_context);
        return (document, version as TrackVersion);
    }

    def _extractor(document: CourseDocument) -> DocumentExtractor {
        detected = document.detected_file_type or document.file_extension.upper();
        if self.pdf_extractor.supports(detected) { return self.pdf_extractor; }
        if self.docx_extractor.supports(detected) { return self.docx_extractor; }
        raise ValueError("DOCUMENT_EXTRACTION_UNSUPPORTED_TYPE");
    }

    def _event(name: str, status: str, document: CourseDocument, extraction: DocumentExtraction, request_id: str, duration_ms: int = 0, code: str = "") {
        emit_event(ObservabilityEvent(timestamp=service_now(), level="info" if code == "" else "warning", event=name, status=status,
            message="Document text extraction state changed.", request_id=request_id, correlation_id=request_id, duration_ms=duration_ms,
            error_code=code, entity_ids={"document_id": document.document_id, "extraction_id": extraction.extraction_id,
            "track_id": document.track_id, "track_version_id": document.track_version_id},
            attributes={"extractor_name": extraction.extractor_name, "schema_version": extraction.schema_version,
                "pages": extraction.total_pages or 0, "characters": extraction.total_characters,
                "words": extraction.total_words, "blocks": extraction.total_blocks,
                "quality": extraction.extraction_quality or ""}));
    }

    def _fail(document: CourseDocument, extraction: DocumentExtraction, code: str, request_id: str, started: float, status: DocumentExtractionStatus = DocumentExtractionStatus.EXTRACTION_FAILED) -> DocumentExtractionResult {
        timestamp = service_now(); message = _safe_message(code); extraction.status = status; extraction.error_code = code; extraction.error_message = message; extraction.completed_at = timestamp;
        if status == DocumentExtractionStatus.OCR_REQUIRED { self.document_repository.mark_ocr_required(document, code, message, timestamp); }
        elif status == DocumentExtractionStatus.NO_EXTRACTABLE_TEXT { self.document_repository.mark_no_extractable_text(document, code, message, timestamp); }
        else { self.document_repository.mark_extraction_failed(document, code, message, timestamp); }
        duration = int((time.monotonic() - started) * 1000); metric = "ocr_required" if status == DocumentExtractionStatus.OCR_REQUIRED else ("no_text" if status == DocumentExtractionStatus.NO_EXTRACTABLE_TEXT else "failed");
        record_document_extraction(metric, duration); event_name = "document.extraction_ocr_required" if status == DocumentExtractionStatus.OCR_REQUIRED else ("document.extraction_no_text" if status == DocumentExtractionStatus.NO_EXTRACTABLE_TEXT else "document.extraction_failed");
        self._event(event_name, str(status), document, extraction, request_id, duration, code); return _to_result(extraction);
    }

    def extract_document(document_id: str, context: ExtractionRequestContext) -> DocumentExtractionResult {
        if document_id != context.document_id { raise ValueError("DOCUMENT_CONTEXT_INVALID"); }
        started = time.monotonic(); (document, _version) = self._resolve(context);
        existing = self.extraction_repository.find_by_source_and_schema_version(document, document.checksum, context.extraction_schema_version);
        if existing is not None and not context.force_reextract {
            if existing.status == DocumentExtractionStatus.EXTRACTED { record_document_extraction("reused", 0, existing.total_characters, existing.total_pages or 0, existing.total_blocks); self._event("document.extraction_reused", "reused", document, existing, context.request_id); return _to_result(existing, True); }
            if existing.status == DocumentExtractionStatus.EXTRACTING { return DocumentExtractionResult(document_id=document.document_id, extraction_id=existing.extraction_id, status=DocumentExtractionStatus.EXTRACTING, reused=True, error_code="DOCUMENT_EXTRACTION_ALREADY_RUNNING", user_message="Text extraction is already in progress."); }
        }
        if context.force_reextract and not ((context.actor_id or "") in ["system", "service"] or (context.actor_id or "").startswith("admin_")) { raise PermissionError("DOCUMENT_FORCE_REEXTRACTION_NOT_AUTHORIZED"); }
        active = self.extraction_repository.find_active_for_document(document);
        if active is not None and active.status == DocumentExtractionStatus.EXTRACTING { return DocumentExtractionResult(document_id=document.document_id, extraction_id=active.extraction_id, status=DocumentExtractionStatus.EXTRACTING, reused=True, error_code="DOCUMENT_EXTRACTION_ALREADY_RUNNING", user_message="Text extraction is already in progress."); }
        if active is not None { self.extraction_repository.deactivate(active); }
        extractor = self._extractor(document); timestamp = service_now(); extraction_id = "ext_" + uuid.uuid4().hex;
        extraction = DocumentExtraction(extraction_id=extraction_id, document_id=document.document_id, track_id=document.track_id,
            track_version_id=document.track_version_id, status=DocumentExtractionStatus.EXTRACTING,
            extractor_name=extractor.extractor_name(), extractor_version=extractor.extractor_version(), source_checksum_sha256=document.checksum,
            schema_version=context.extraction_schema_version, started_at=timestamp);
        if not self.document_repository.mark_extracting(document) { return DocumentExtractionResult(document_id=document.document_id, status=DocumentExtractionStatus.EXTRACTING, error_code="DOCUMENT_EXTRACTION_ALREADY_RUNNING", user_message="Text extraction is already in progress."); }
        if not self.extraction_repository.save_extraction(document, extraction, timestamp) { self.document_repository.mark_extraction_failed(document, "DOCUMENT_EXTRACTION_PERSIST_FAILED", _safe_message("DOCUMENT_EXTRACTION_PERSIST_FAILED"), service_now()); raise RuntimeError("DOCUMENT_EXTRACTION_PERSIST_FAILED"); }
        self._event("document.extraction_queued", "queued", document, extraction, context.request_id);
        self._event("document.extraction_started", "started", document, extraction, context.request_id);
        try { payload = self.storage_service.storage.read(document.storage_key); }
        except Exception { return self._fail(document, extraction, "DOCUMENT_STORAGE_READ_FAILED", context.request_id, started); }
        try {
            extraction_context = ExtractionContext(extraction_id=extraction_id, document_id=document.document_id,
                track_id=document.track_id, track_version_id=document.track_version_id, source_checksum_sha256=document.checksum,
                request_id=context.request_id, schema_version=context.extraction_schema_version,
                max_characters=int(os.getenv("DOCUMENT_EXTRACTION_MAX_CHARACTERS", "5000000")),
                max_blocks=int(os.getenv("DOCUMENT_EXTRACTION_MAX_BLOCKS", "100000")),
                timeout_seconds=int(os.getenv("DOCUMENT_EXTRACTION_TIMEOUT_SECONDS", "120")));
            raw = extractor.extract(payload, extraction_context);
            if time.monotonic() - started > extraction_context.timeout_seconds { return self._fail(document, extraction, "DOCUMENT_EXTRACTION_TIMEOUT", context.request_id, started); }
            minimum = int(os.getenv("DOCUMENT_MIN_EXTRACTABLE_CHARACTERS", "100"));
            raw_characters = sum(len(block.text) for block in raw.blocks);
            if raw_characters < minimum {
                if document.file_extension == "pdf" and raw.total_pages is not None and raw.total_pages > 0 and (raw.pages_with_images > 0 or raw.pages_with_text == 0) { return self._fail(document, extraction, "DOCUMENT_OCR_REQUIRED", context.request_id, started, DocumentExtractionStatus.OCR_REQUIRED); }
                return self._fail(document, extraction, "DOCUMENT_NO_EXTRACTABLE_TEXT", context.request_id, started, DocumentExtractionStatus.NO_EXTRACTABLE_TEXT);
            }
            blocks: list[ExtractionBlock] = []; parts: list[str] = []; cursor = 0; total_words = 0;
            for raw_block in raw.blocks {
                normalized_tuple = engine.normalize_text(raw_block.text) as tuple[str, int]; text = normalized_tuple[0];
                if text == "" { continue; }
                if len(blocks) >= extraction_context.max_blocks { return self._fail(document, extraction, "DOCUMENT_EXTRACTION_LIMIT_EXCEEDED", context.request_id, started); }
                if len(parts) > 0 { parts.append("\n\n"); cursor += 2; }
                start = cursor; parts.append(text); cursor += len(text); words = len(text.split()); total_words += words;
                index = len(blocks); blocks.append(ExtractionBlock(extraction_block_id="exb_" + uuid.uuid4().hex,
                    extraction_id=extraction_id, order_index=index, block_type=raw_block.block_type, text=text,
                    page_start=raw_block.page_start, page_end=raw_block.page_end, heading_level=raw_block.heading_level,
                    heading_text=raw_block.heading_text, paragraph_index=index if document.file_extension == "docx" else None,
                    source_locator=raw_block.source_locator, character_start=start, character_end=cursor,
                    word_count=words, metadata_json=raw_block.metadata_json));
                if cursor > extraction_context.max_characters { return self._fail(document, extraction, "DOCUMENT_EXTRACTION_LIMIT_EXCEEDED", context.request_id, started); }
            }
            plain_text = "".join(parts); warnings = raw.warnings;
            quality = _quality(raw, len(plain_text), warnings); extraction.plain_text = plain_text;
            extraction.total_characters = len(plain_text); extraction.total_words = total_words; extraction.total_blocks = len(blocks);
            extraction.total_pages = raw.total_pages; extraction.extraction_quality = str(quality); extraction.warnings_json = json.dumps(warnings);
            # Cancellation/stale-source gate immediately before derived graph commit.
            (current, _) = self._resolve(context);
            if current.document_id != document.document_id or current.checksum != extraction.source_checksum_sha256 or not current.is_active { return self._fail(document, extraction, "DOCUMENT_EXTRACTION_STALE_SOURCE", context.request_id, started); }
            if not self.extraction_repository.save_blocks(extraction, blocks) { return self._fail(document, extraction, "DOCUMENT_EXTRACTION_PERSIST_FAILED", context.request_id, started); }
            completed = service_now(); self.extraction_repository.mark_extracted(extraction, completed); self.document_repository.mark_extracted(document, completed);
            duration = int((time.monotonic() - started) * 1000); record_document_extraction("completed", duration, extraction.total_characters, extraction.total_pages or 0, extraction.total_blocks);
            self._event("document.extraction_completed", "completed", document, extraction, context.request_id, duration); return _to_result(extraction);
        } except PermissionError { return self._fail(document, extraction, "DOCUMENT_EXTRACTION_STALE_SOURCE", context.request_id, started); }
        except Exception { return self._fail(document, extraction, "DOCUMENT_EXTRACTION_PDF_FAILED" if document.file_extension == "pdf" else "DOCUMENT_EXTRACTION_DOCX_FAILED", context.request_id, started); }
    }

    def get_extraction(document_id: str, context: ExtractionRequestContext) -> DocumentExtractionResult | None {
        (document, _) = self._resolve(context); extraction = self.extraction_repository.find_active_for_document(document);
        return None if extraction is None or document_id != document.document_id else _to_result(extraction);
    }
    def retry_extraction(document_id: str, context: ExtractionRequestContext) -> DocumentExtractionResult {
        (document, _) = self._resolve(context);
        if document.extraction_status in [DocumentExtractionStatus.EXTRACTION_FAILED, DocumentExtractionStatus.OCR_REQUIRED, DocumentExtractionStatus.NO_EXTRACTABLE_TEXT] { document.extraction_status = DocumentExtractionStatus.NOT_STARTED; }
        return self.extract_document(document_id, context);
    }
    def can_chunk(document_id: str, context: ExtractionRequestContext) -> bool {
        try { (document, _) = self._resolve(context); extraction = self.extraction_repository.find_active_for_document(document); return document.document_id == document_id and document.extraction_status == DocumentExtractionStatus.EXTRACTED and extraction is not None and extraction.status == DocumentExtractionStatus.EXTRACTED and extraction.source_checksum_sha256 == document.checksum; } except Exception { return False; }
    }
}
