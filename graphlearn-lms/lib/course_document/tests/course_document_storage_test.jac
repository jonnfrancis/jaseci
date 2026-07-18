"""Feature 40 provider-neutral storage, integrity, and recovery tests."""

import hashlib;
import from tempfile { TemporaryDirectory }
import from lib.course_document.storage { LocalCourseDocumentStorage }
import from lib.course_document.storage_key_builder { StorageKeyBuilder }
import from lib.course_document.storage_service { CourseDocumentStorageService }
import from lib.course_document.storage_types { StoreCourseDocumentRequest, StorageHealthStatus }
import from nodes.curriculum { CourseDocument, CourseDocumentProcessingStatus, CourseDocumentUploadStatus }

def _document(key: str, payload: bytes) -> CourseDocument {
    return CourseDocument(document_id="doc_test", track_id="trk_test", track_version_id="trv_test", original_filename="Notes.pdf", normalized_filename="notes.pdf", mime_type="application/pdf", file_extension="pdf", file_size_bytes=len(payload), storage_provider="local", storage_key=key, checksum_algorithm="sha256", checksum=hashlib.sha256(payload).hexdigest(), upload_status=CourseDocumentUploadStatus.STORED, processing_status=CourseDocumentProcessingStatus.NOT_STARTED, uploaded_by="user_test", uploaded_at="2026-07-18T00:00:00+00:00", updated_at="2026-07-18T00:00:00+00:00", idempotency_scope="test");
}

test "storage keys are canonical and reject traversal" {
    keys = StorageKeyBuilder(); valid = keys.build_course_document_key("trk_123", "trv_123", "doc_123", ".PDF");
    assert valid == "course-documents/trk_123/trv_123/doc_123/source.pdf" and "Notes" not in valid;
    for invalid in ["../track", "track/id", "C:\\track", "bad\x00id"] {
        try { _ = keys.build_course_document_key(invalid, "trv_123", "doc_123", "pdf"); assert False, "unsafe id accepted"; }
        except ValueError { assert True; }
    }
    try { _ = keys.build_course_document_key("trk_123", "trv_123", "doc_123", "exe"); assert False, "invalid extension accepted"; }
    except ValueError { assert True; }
}

test "local adapter writes reads metadata copies moves and deletes" {
    with TemporaryDirectory() as directory {
        storage = LocalCourseDocumentStorage(base_directory=directory as str); payload = b"%PDF-storage"; source = "_tmp/upl_test/source.pdf"; copy = "_trash/doc_test/copy/source.pdf"; final = "course-documents/trk_test/trv_test/doc_test/source.pdf";
        assert storage.put(source, payload) and storage.exists(source) and storage.read(source) == payload and storage.metadata(source).size_bytes == len(payload);
        assert storage.copy(source, copy) and storage.move(source, final) and not storage.exists(source) and storage.exists(final);
        assert len(storage.list_objects("course-documents")) == 1 and storage.delete(copy) and storage.delete(final);
    }
}

test "service stages immutable bytes and verifies integrity" {
    with TemporaryDirectory() as directory {
        storage = LocalCourseDocumentStorage(base_directory=directory as str); service = CourseDocumentStorageService(storage=storage); payload = b"%PDF-integrity";
        stored = service.store_document(StoreCourseDocumentRequest(document_id="doc_test", track_id="trk_test", track_version_id="trv_test", canonical_extension="pdf", client_upload_id="upl_test", uploaded_by="user_test", payload=payload));
        document = _document(stored.storage_key, payload); valid = service.verify_integrity(document);
        assert valid.valid and valid.object_exists and valid.size_matches and valid.checksum_matches;
        document.checksum = "0" * 64; corrupt = service.verify_integrity(document);
        assert not corrupt.valid and corrupt.error_code == "STORAGE_CHECKSUM_MISMATCH";
        try { _ = storage.put(stored.storage_key, payload); assert False, "immutable object overwritten"; }
        except FileExistsError { assert True; }
    }
}

test "health probe leaves no permanent object" {
    with TemporaryDirectory() as directory {
        storage = LocalCourseDocumentStorage(base_directory=directory as str); health = CourseDocumentStorageService(storage=storage).health_check();
        assert health.status == StorageHealthStatus.HEALTHY and len(storage.list_objects()) == 0;
    }
}
