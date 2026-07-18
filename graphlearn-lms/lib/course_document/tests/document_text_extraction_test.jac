"""Feature 42 maintained-parser, normalization, provenance, and lifecycle tests."""

import base64;
import os;
import lib.course_document.tests.security_fixtures as fixtures;
import from uuid { uuid4 }
import from lib.course_document.extraction_repository { DocumentExtractionRepository }
import from lib.course_document.extraction_service { DocumentTextExtractionService }
import from lib.course_document.repositories { CourseDocumentRepository }
import from lib.course_document.service { CourseDocumentUploadService, DOCX_MIME, PDF_MIME }
import from lib.learning_track.course_management { create_course_service }
import from lib.learning_track.repositories { repository_find_track, repository_versions }
import from lib.learning_track.repository_types { ActorContext }
import from nodes.curriculum { DocumentExtractionStatus, DocumentValidationStatus, ExtractionRequestContext, UploadCourseDocumentInput }
import from nodes.learning_track { CreateCourseTrackInput, LearningTrack, LecturerCourseDetail }

def _setup(suffix: str) -> tuple[ActorContext, LearningTrack, str] {
    actor = ActorContext(user_id="extract_user_" + suffix, lecturer_id="extract_lecturer_" + suffix, request_id="extract_request_" + suffix, roles=["LECTURER"]);
    created = create_course_service(actor, CreateCourseTrackInput(title="Extraction Course " + suffix[:6], client_request_id="extract_course_" + suffix));
    detail = created.value as LecturerCourseDetail; track = repository_find_track(detail.track.track_id) as LearningTrack;
    return (actor, track, repository_versions(track)[0].track_version_id);
}

def _upload(actor: ActorContext, track: LearningTrack, version_id: str, suffix: str, payload: bytes, extension: str) {
    mime = PDF_MIME if extension == "pdf" else DOCX_MIME;
    input = UploadCourseDocumentInput(track_id=track.track_id, track_version_id=version_id, original_filename="course." + extension,
        mime_type=mime, file_size_bytes=len(payload), idempotency_key="extract_upload_" + suffix,
        content_base64=base64.b64encode(payload).decode("ascii"));
    os.environ["DOCUMENT_EXTRACTION_AUTO_START"] = "false"; result = CourseDocumentUploadService().upload(actor, input); os.environ["DOCUMENT_EXTRACTION_AUTO_START"] = "true"; assert result.ok;
}

def _context(document_id: str, track: LearningTrack, version_id: str, suffix: str, force: bool = False) -> ExtractionRequestContext {
    return ExtractionRequestContext(document_id=document_id, track_id=track.track_id, track_version_id=version_id,
        request_id="extract_request_" + suffix, actor_id="system" if force else "extract_user_" + suffix, force_reextract=force);
}

test "extracts validated multi-page PDF with exact provenance and offsets" {
    suffix = uuid4().hex; (actor, track, version_id) = _setup(suffix);
    payload = fixtures.text_pdf(["Database systems explain relational models and normalization concepts for reliable course design.", "Transactions use atomicity consistency isolation and durability for safe database operations."]) as bytes;
    _upload(actor, track, version_id, suffix, payload, "pdf"); version = repository_versions(track)[0]; document = CourseDocumentRepository().find_active_for_version(version); assert document is not None and document.validation_status == DocumentValidationStatus.VALIDATED;
    service = DocumentTextExtractionService(); result = service.extract_document(document.document_id, _context(document.document_id, track, version_id, suffix));
    extraction = DocumentExtractionRepository().find_active_for_document(document); assert result.status == DocumentExtractionStatus.EXTRACTED and extraction is not None and extraction.total_pages == 2;
    blocks = DocumentExtractionRepository().list_blocks(extraction); assert len(blocks) == 2 and blocks[0].source_locator == "pdf:page=1:block=1" and blocks[1].page_start == 2;
    assert extraction.plain_text is not None and (extraction.plain_text as str)[blocks[0].character_start:blocks[0].character_end] == blocks[0].text;
    assert service.can_chunk(document.document_id, _context(document.document_id, track, version_id, suffix));
}

test "blank PDF becomes OCR required and cannot chunk" {
    suffix = uuid4().hex; (actor, track, version_id) = _setup(suffix); _upload(actor, track, version_id, suffix, fixtures.blank_pdf(2) as bytes, "pdf");
    document = CourseDocumentRepository().find_active_for_version(repository_versions(track)[0]); assert document is not None;
    service = DocumentTextExtractionService(); result = service.extract_document(document.document_id, _context(document.document_id, track, version_id, suffix));
    assert result.status == DocumentExtractionStatus.OCR_REQUIRED and result.error_code == "DOCUMENT_OCR_REQUIRED" and not service.can_chunk(document.document_id, _context(document.document_id, track, version_id, suffix));
}

test "DOCX preserves heading paragraph table paragraph list order and normalization" {
    suffix = uuid4().hex; (actor, track, version_id) = _setup(suffix); _upload(actor, track, version_id, suffix, fixtures.structured_docx() as bytes, "docx");
    document = CourseDocumentRepository().find_active_for_version(repository_versions(track)[0]); assert document is not None;
    result = DocumentTextExtractionService().extract_document(document.document_id, _context(document.document_id, track, version_id, suffix)); extraction = DocumentExtractionRepository().find_active_for_document(document); assert result.status == DocumentExtractionStatus.EXTRACTED and extraction is not None;
    blocks = DocumentExtractionRepository().list_blocks(extraction); assert [block.block_type for block in blocks[:5]] == ["HEADING", "PARAGRAPH", "TABLE_TEXT", "PARAGRAPH", "LIST_ITEM"];
    assert blocks[0].heading_level == 1 and "Form | Meaning" in blocks[2].text and "fi ligature" in blocks[1].text and "  " not in blocks[1].text;
    for index in range(len(blocks)) { assert blocks[index].order_index == index and blocks[index].source_locator is not None; }
}

test "matching extraction is reused and authorized force creates history" {
    suffix = uuid4().hex; (actor, track, version_id) = _setup(suffix); _upload(actor, track, version_id, suffix, fixtures.structured_docx() as bytes, "docx");
    document = CourseDocumentRepository().find_active_for_version(repository_versions(track)[0]); assert document is not None; service = DocumentTextExtractionService(); context = _context(document.document_id, track, version_id, suffix);
    first = service.extract_document(document.document_id, context); second = service.extract_document(document.document_id, context); forced = service.extract_document(document.document_id, _context(document.document_id, track, version_id, suffix, True));
    assert first.status == DocumentExtractionStatus.EXTRACTED and second.reused and second.extraction_id == first.extraction_id;
    assert forced.status == DocumentExtractionStatus.EXTRACTED and forced.extraction_id != first.extraction_id and len(DocumentExtractionRepository().list_for_document(document)) == 2;
}

test "output limit failure is recoverable and never enables chunking" {
    suffix = uuid4().hex; (actor, track, version_id) = _setup(suffix); _upload(actor, track, version_id, suffix, fixtures.structured_docx() as bytes, "docx");
    document = CourseDocumentRepository().find_active_for_version(repository_versions(track)[0]); assert document is not None; service = DocumentTextExtractionService(); context = _context(document.document_id, track, version_id, suffix);
    os.environ["DOCUMENT_EXTRACTION_MAX_CHARACTERS"] = "20"; failed = service.extract_document(document.document_id, context);
    assert failed.status == DocumentExtractionStatus.EXTRACTION_FAILED and failed.error_code == "DOCUMENT_EXTRACTION_LIMIT_EXCEEDED" and not service.can_chunk(document.document_id, context);
    os.environ["DOCUMENT_EXTRACTION_MAX_CHARACTERS"] = "5000000"; retried = service.retry_extraction(document.document_id, context); assert retried.status == DocumentExtractionStatus.EXTRACTED;
}

test "validated upload automatically advances through extraction" {
    suffix = uuid4().hex; (actor, track, version_id) = _setup(suffix); os.environ["DOCUMENT_EXTRACTION_AUTO_START"] = "true";
    payload = fixtures.text_pdf(["Automatic extraction converts validated course material into structured source text with deterministic provenance.", "The second page provides enough educational content for later course chunking and curriculum preparation."]) as bytes;
    mime = PDF_MIME; input = UploadCourseDocumentInput(track_id=track.track_id, track_version_id=version_id, original_filename="automatic.pdf", mime_type=mime,
        file_size_bytes=len(payload), idempotency_key="automatic_" + suffix, content_base64=base64.b64encode(payload).decode("ascii"));
    uploaded = CourseDocumentUploadService().upload(actor, input); document = CourseDocumentRepository().find_active_for_version(repository_versions(track)[0]);
    assert uploaded.ok and document is not None and document.extraction_status == DocumentExtractionStatus.EXTRACTED;
}
