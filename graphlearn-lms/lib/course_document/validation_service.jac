"""Deterministic trust boundary for immutable lecturer course documents."""

import os;
import re;
import time;
import lib.course_document.secure_inspection as inspection;
import from lib.course_document.malware_scanner { ConfiguredDocumentMalwareScanner, DocumentMalwareScanner }
import from lib.course_document.repositories { CourseDocumentRepository }
import from lib.course_document.storage_service { CourseDocumentStorageService }
import from lib.course_document.validation_metrics { record_document_validation }
import from lib.learning_track.application_services { service_now }
import from lib.learning_track.repositories { repository_find_track, repository_find_version, repository_version_belongs_to }
import from lib.observability.events { ObservabilityEvent }
import from lib.observability.logger { emit_event }
import from nodes.curriculum {
    CourseDocument, CourseDocumentUploadStatus, DocumentValidationCheck, DocumentValidationContext,
    DocumentValidationResult, DocumentValidationStatus, MalwareScanStatus
}
import from nodes.learning_track { TrackVersion }

glob DOCUMENT_VALIDATION_POLICY_VERSION: int = 1;
glob PDF_MIME_TYPE: str = "application/pdf";
glob DOCX_MIME_TYPE: str = "application/vnd.openxmlformats-officedocument.wordprocessingml.document";

def _message(code: str) -> str {
    if code in ["DOCUMENT_TOO_SMALL", "DOCUMENT_TOO_LARGE"] { return "This file is outside the allowed size range. Please upload a smaller valid document."; }
    if code == "DOCUMENT_ENCRYPTED_UNSUPPORTED" { return "This document is password-protected or encrypted. Please upload an unprotected PDF or DOCX version."; }
    if code in ["DOCUMENT_MACRO_CONTENT_DETECTED", "DOCUMENT_ACTIVE_CONTENT_DETECTED", "DOCUMENT_EMBEDDED_EXECUTABLE_DETECTED"] { return "This document contains unsupported active or embedded content. Please upload a clean PDF or DOCX version."; }
    if code in ["DOCUMENT_MALWARE_DETECTED", "DOCUMENT_MALWARE_SUSPICIOUS", "DOCUMENT_QUARANTINED"] { return "This file could not be accepted for security reasons. Please upload a clean copy of the document."; }
    if code in ["MALWARE_SCAN_UNAVAILABLE", "DOCUMENT_VALIDATION_FAILED", "DOCUMENT_VALIDATION_RESOURCE_LIMIT", "DOCUMENT_STORAGE_INTEGRITY_FAILED"] { return "Security validation could not be completed. Please retry later."; }
    return "Please upload a valid PDF or DOCX file.";
}

def _result(document: CourseDocument, checks: list[DocumentValidationCheck], timestamp: str) -> DocumentValidationResult {
    return DocumentValidationResult(document_id=document.document_id, status=document.validation_status, policy_version=document.validation_version,
        size_bytes=document.file_size_bytes, validated_at=timestamp, detected_file_type=document.detected_file_type,
        detected_mime_type=document.detected_mime_type, page_count=document.page_count, encrypted=document.is_encrypted,
        macro_content=document.has_macros, malware_status=document.malware_scan_status, checks=checks,
        error_code=document.validation_error_code, user_message=document.validation_error_message);
}

obj DocumentSecurityValidationService {
    has storage_service: CourseDocumentStorageService = CourseDocumentStorageService();
    has repository: CourseDocumentRepository = CourseDocumentRepository();
    has scanner: DocumentMalwareScanner = ConfiguredDocumentMalwareScanner();

    def _finish(document: CourseDocument, status: DocumentValidationStatus, code: str | None, checks: list[DocumentValidationCheck], started: float, request_id: str) -> DocumentValidationResult {
        timestamp = service_now(); safe_message = None if code is None else _message(code as str);
        if status == DocumentValidationStatus.VALIDATED { self.repository.mark_validated(document, timestamp); }
        elif status == DocumentValidationStatus.REJECTED { self.repository.mark_rejected(document, code as str, safe_message as str, timestamp); }
        elif status == DocumentValidationStatus.QUARANTINED { self.repository.mark_quarantined(document, code as str, safe_message as str, timestamp); }
        else { self.repository.mark_validation_failed(document, code as str, safe_message as str, timestamp); }
        duration = int((time.monotonic() - started) * 1000);
        record_document_validation(str(status), "" if code is None else code as str, duration);
        event_name = "document.validation_passed" if status == DocumentValidationStatus.VALIDATED else ("document.validation_rejected" if status == DocumentValidationStatus.REJECTED else ("document.validation_quarantined" if status == DocumentValidationStatus.QUARANTINED else "document.validation_failed"));
        emit_event(ObservabilityEvent(timestamp=timestamp, level="info" if status == DocumentValidationStatus.VALIDATED else "warning", event=event_name, status=str(status), message="Document security validation completed.", request_id=request_id, correlation_id=request_id, duration_ms=duration, error_code="" if code is None else code as str, entity_ids={"document_id": document.document_id, "track_id": document.track_id, "track_version_id": document.track_version_id}, attributes={"validation_policy_version": document.validation_version, "scanner_status": document.malware_scan_status or "NOT_RUN"}));
        return _result(document, checks, timestamp);
    }

    def validate_document(document_id: str, context: DocumentValidationContext) -> DocumentValidationResult {
        started = time.monotonic(); checks: list[DocumentValidationCheck] = [];
        track = repository_find_track(context.track_id); version = None if track is None else repository_find_version(track, context.track_version_id);
        if track is None or version is None or not repository_version_belongs_to(track, version) { raise ValueError("DOCUMENT_CONTEXT_INVALID"); }
        document = self.repository.find_by_id(version, document_id);
        if document is None or document.document_id != context.document_id or document.track_id != context.track_id or document.track_version_id != context.track_version_id { raise ValueError("DOCUMENT_CONTEXT_INVALID"); }
        if document.validation_status == DocumentValidationStatus.VALIDATED and document.validation_version == context.validation_policy_version { return _result(document, checks, document.validated_at or service_now()); }
        if document.validation_status == DocumentValidationStatus.VALIDATING { return DocumentValidationResult(document_id=document.document_id, status=DocumentValidationStatus.VALIDATING, policy_version=document.validation_version, size_bytes=document.file_size_bytes, validated_at=service_now(), error_code="DOCUMENT_VALIDATION_IN_PROGRESS", user_message="Document validation is already in progress."); }
        if not self.repository.mark_validation_started(document, context.validation_policy_version, service_now()) { return _result(document, checks, service_now()); }
        emit_event(ObservabilityEvent(timestamp=service_now(), level="info", event="document.validation_started", status="started", message="Document security validation started.", request_id=context.request_id, correlation_id=context.request_id, entity_ids={"document_id": document.document_id, "track_id": document.track_id, "track_version_id": document.track_version_id}, attributes={"validation_policy_version": context.validation_policy_version}));
        if document.upload_status != CourseDocumentUploadStatus.STORED or not document.is_active or not re.fullmatch(r"[A-Za-z0-9_-]+", document.document_id) or document.checksum_algorithm != "sha256" or re.fullmatch(r"[0-9a-f]{64}", document.checksum) is None or not document.storage_key.startswith("course-documents/" + document.track_id + "/" + document.track_version_id + "/" + document.document_id + "/") {
            checks.append(DocumentValidationCheck(name="metadata", status="FAILED", required=True, code="DOCUMENT_VALIDATION_FAILED"));
            return self._finish(document, DocumentValidationStatus.VALIDATION_FAILED, "DOCUMENT_VALIDATION_FAILED", checks, started, context.request_id);
        }
        checks.append(DocumentValidationCheck(name="metadata", status="PASSED", required=True));
        integrity = self.storage_service.verify_integrity(document);
        if not integrity.valid { checks.append(DocumentValidationCheck(name="storage_integrity", status="FAILED", required=True, code="DOCUMENT_STORAGE_INTEGRITY_FAILED")); return self._finish(document, DocumentValidationStatus.VALIDATION_FAILED, "DOCUMENT_STORAGE_INTEGRITY_FAILED", checks, started, context.request_id); }
        checks.append(DocumentValidationCheck(name="storage_integrity", status="PASSED", required=True));
        payload = self.storage_service.storage.read(document.storage_key); actual_size = len(payload);
        minimum = int(os.getenv("COURSE_DOCUMENT_MIN_BYTES", "100")); maximum = int(os.getenv("COURSE_DOCUMENT_MAX_BYTES", str(50 * 1024 * 1024)));
        if actual_size < minimum { checks.append(DocumentValidationCheck(name="size", status="FAILED", required=True, code="DOCUMENT_TOO_SMALL")); return self._finish(document, DocumentValidationStatus.REJECTED, "DOCUMENT_TOO_SMALL", checks, started, context.request_id); }
        if actual_size > maximum { checks.append(DocumentValidationCheck(name="size", status="FAILED", required=True, code="DOCUMENT_TOO_LARGE")); return self._finish(document, DocumentValidationStatus.REJECTED, "DOCUMENT_TOO_LARGE", checks, started, context.request_id); }
        checks.append(DocumentValidationCheck(name="size", status="PASSED", required=True));
        extension = document.file_extension.lower(); expected_mime = PDF_MIME_TYPE if extension == "pdf" else (DOCX_MIME_TYPE if extension == "docx" else "");
        if expected_mime == "" { return self._finish(document, DocumentValidationStatus.REJECTED, "DOCUMENT_EXTENSION_UNSUPPORTED", checks, started, context.request_id); }
        leaf = document.normalized_filename.lower(); suspicious = any(leaf.endswith("." + item) for item in ["exe", "dll", "bat", "cmd", "ps1", "sh", "js", "jar", "scr", "docm", "dotm"]);
        if suspicious or leaf.rsplit(".", 1)[-1] != extension { return self._finish(document, DocumentValidationStatus.REJECTED, "DOCUMENT_FILENAME_INVALID", checks, started, context.request_id); }
        detected_type = "PDF" if payload.startswith(b"%PDF-") else ("DOCX" if payload.startswith(b"PK") else "UNKNOWN");
        document.detected_file_type = detected_type; document.detected_mime_type = PDF_MIME_TYPE if detected_type == "PDF" else (DOCX_MIME_TYPE if detected_type == "DOCX" else "application/octet-stream");
        if detected_type != extension.upper() { return self._finish(document, DocumentValidationStatus.REJECTED, "DOCUMENT_SIGNATURE_MISMATCH", checks, started, context.request_id); }
        if document.mime_type != expected_mime or document.detected_mime_type != expected_mime { return self._finish(document, DocumentValidationStatus.REJECTED, "DOCUMENT_MIME_MISMATCH", checks, started, context.request_id); }
        checks.append(DocumentValidationCheck(name="type_consistency", status="PASSED", required=True));
        inspected: dict[str, object];
        if extension == "pdf" { inspected = inspection.inspect_pdf(payload, int(os.getenv("COURSE_DOCUMENT_MAX_PDF_PAGES", "1000"))) as dict[str, object]; }
        else { inspected = inspection.inspect_docx(payload, int(os.getenv("DOCX_MAX_ENTRY_COUNT", "10000")), int(os.getenv("DOCX_MAX_UNCOMPRESSED_BYTES", str(200 * 1024 * 1024))), float(os.getenv("DOCX_MAX_COMPRESSION_RATIO", "100"))) as dict[str, object]; }
        if extension == "pdf" { document.page_count = inspected.get("page_count", 0) as int; document.is_encrypted = inspected.get("encrypted", False) as bool; }
        else { document.has_macros = inspected.get("macros", False) as bool; }
        code_value = inspected.get("code"); code = None if code_value is None else str(code_value);
        if not (inspected.get("valid", False) as bool) { return self._finish(document, DocumentValidationStatus.REJECTED, code or ("DOCUMENT_PDF_INVALID" if extension == "pdf" else "DOCUMENT_DOCX_INVALID"), checks, started, context.request_id); }
        if extension == "docx" and document.has_macros { return self._finish(document, DocumentValidationStatus.QUARANTINED, "DOCUMENT_MACRO_CONTENT_DETECTED", checks, started, context.request_id); }
        if inspected.get("active", False) as bool { return self._finish(document, DocumentValidationStatus.QUARANTINED, "DOCUMENT_ACTIVE_CONTENT_DETECTED", checks, started, context.request_id); }
        if inspected.get("embedded_executable", False) as bool { return self._finish(document, DocumentValidationStatus.QUARANTINED, "DOCUMENT_EMBEDDED_EXECUTABLE_DETECTED", checks, started, context.request_id); }
        checks.append(DocumentValidationCheck(name="structure", status="PASSED", required=True));
        scanner_required = os.getenv("DOCUMENT_MALWARE_SCANNER_REQUIRED", "false").lower() in ["1", "true", "yes", "on"];
        if scanner_required {
            scan = self.scanner.scan(payload); document.malware_scan_status = str(scan.status); document.malware_scan_provider = scan.provider;
            if scan.status == MalwareScanStatus.INFECTED { return self._finish(document, DocumentValidationStatus.QUARANTINED, "DOCUMENT_MALWARE_DETECTED", checks, started, context.request_id); }
            if scan.status == MalwareScanStatus.SUSPICIOUS { return self._finish(document, DocumentValidationStatus.QUARANTINED, "DOCUMENT_MALWARE_SUSPICIOUS", checks, started, context.request_id); }
            if scan.status != MalwareScanStatus.CLEAN { return self._finish(document, DocumentValidationStatus.VALIDATION_FAILED, "MALWARE_SCAN_UNAVAILABLE", checks, started, context.request_id); }
        } else { document.malware_scan_status = str(MalwareScanStatus.NOT_RUN); document.malware_scan_provider = "disabled-by-policy"; }
        checks.append(DocumentValidationCheck(name="malware_scan", status="PASSED" if scanner_required else "NOT_REQUIRED", required=scanner_required));
        duplicate = self.repository.find_duplicate_for_version(version as TrackVersion, document.checksum, document.document_id);
        if duplicate is not None and duplicate.is_active { return self._finish(document, DocumentValidationStatus.REJECTED, "DOCUMENT_DUPLICATE", checks, started, context.request_id); }
        checks.append(DocumentValidationCheck(name="duplicate", status="PASSED", required=True));
        timeout = int(os.getenv("DOCUMENT_VALIDATION_TIMEOUT_SECONDS", "60"));
        if time.monotonic() - started > timeout { return self._finish(document, DocumentValidationStatus.VALIDATION_FAILED, "DOCUMENT_VALIDATION_RESOURCE_LIMIT", checks, started, context.request_id); }
        return self._finish(document, DocumentValidationStatus.VALIDATED, None, checks, started, context.request_id);
    }

    def retry_validation(document_id: str, context: DocumentValidationContext) -> DocumentValidationResult {
        track = repository_find_track(context.track_id); version = None if track is None else repository_find_version(track, context.track_version_id);
        if version is None { raise ValueError("DOCUMENT_CONTEXT_INVALID"); }
        document = self.repository.find_by_id(version, document_id);
        if document is None { raise ValueError("DOCUMENT_CONTEXT_INVALID"); }
        if document.validation_status == DocumentValidationStatus.VALIDATION_FAILED { document.validation_status = DocumentValidationStatus.PENDING; }
        return self.validate_document(document_id, context);
    }

    def can_extract(document_id: str, context: DocumentValidationContext) -> bool {
        try { _ = self.assert_document_extractable(document_id, context); return True; } except Exception { return False; }
    }

    def assert_document_extractable(document_id: str, context: DocumentValidationContext) -> CourseDocument {
        track = repository_find_track(context.track_id); version = None if track is None else repository_find_version(track, context.track_version_id);
        if version is None { raise PermissionError("DOCUMENT_NOT_EXTRACTABLE"); }
        document = self.repository.find_by_id(version, document_id);
        if document is None or document.track_id != context.track_id or document.track_version_id != context.track_version_id or document.upload_status != CourseDocumentUploadStatus.STORED or document.validation_status != DocumentValidationStatus.VALIDATED or not document.is_active or not self.storage_service.verify_integrity(document).valid { raise PermissionError("DOCUMENT_NOT_EXTRACTABLE"); }
        return document;
    }
}

def assert_document_extractable(document_id: str, context: DocumentValidationContext) -> CourseDocument {
    return DocumentSecurityValidationService().assert_document_extractable(document_id, context);
}
