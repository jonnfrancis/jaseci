"""Bounded, network-free inspection helpers for untrusted PDF/DOCX bytes."""

from __future__ import annotations

import io
import re
import zipfile
from pathlib import PurePosixPath, PureWindowsPath


def inspect_pdf(payload: bytes, max_pages: int) -> dict[str, object]:
    result: dict[str, object] = {
        "valid": False, "page_count": 0, "encrypted": False,
        "active": False, "embedded_executable": False, "code": None,
    }
    if not payload.startswith(b"%PDF-"):
        result["code"] = "DOCUMENT_SIGNATURE_MISMATCH"
        return result
    if b"%%EOF" not in payload[-4096:]:
        result["code"] = "DOCUMENT_PDF_INVALID"
        return result
    result["encrypted"] = b"/Encrypt" in payload
    if result["encrypted"]:
        result["code"] = "DOCUMENT_ENCRYPTED_UNSUPPORTED"
        return result
    pages = len(re.findall(rb"/Type\s*/Page(?!s)\b", payload))
    result["page_count"] = pages
    if pages <= 0:
        result["code"] = "DOCUMENT_PDF_INVALID"
        return result
    if pages > max_pages:
        result["code"] = "DOCUMENT_PAGE_LIMIT_EXCEEDED"
        return result
    active_markers = (b"/JavaScript", b"/JS", b"/Launch", b"/OpenAction", b"/SubmitForm")
    result["active"] = any(marker in payload for marker in active_markers)
    result["embedded_executable"] = b"/EmbeddedFile" in payload and any(
        marker in payload.lower() for marker in (b".exe", b".dll", b".bat", b".cmd", b".ps1", b".sh")
    )
    result["valid"] = True
    return result


def inspect_docx(payload: bytes, max_entries: int, max_uncompressed: int, max_ratio: float) -> dict[str, object]:
    result: dict[str, object] = {
        "valid": False, "macros": False, "active": False,
        "external_relationships": False, "xml_violation": False, "code": None,
    }
    if not payload.startswith(b"PK"):
        result["code"] = "DOCUMENT_SIGNATURE_MISMATCH"
        return result
    try:
        with zipfile.ZipFile(io.BytesIO(payload)) as package:
            infos = package.infolist()
            if len(infos) > max_entries:
                result["code"] = "DOCUMENT_ARCHIVE_LIMIT_EXCEEDED"
                return result
            total_compressed = 0
            total_uncompressed = 0
            names: set[str] = set()
            for info in infos:
                name = info.filename.replace("\\", "/")
                names.add(name)
                posix = PurePosixPath(name)
                windows = PureWindowsPath(info.filename)
                if "\x00" in name or posix.is_absolute() or windows.is_absolute() or ".." in posix.parts:
                    result["code"] = "DOCUMENT_ARCHIVE_PATH_TRAVERSAL"
                    return result
                total_compressed += info.compress_size
                total_uncompressed += info.file_size
                if info.file_size > 0 and info.compress_size == 0:
                    result["code"] = "DOCUMENT_ARCHIVE_BOMB_RISK"
                    return result
                if info.compress_size > 0 and info.file_size / info.compress_size > max_ratio:
                    result["code"] = "DOCUMENT_ARCHIVE_BOMB_RISK"
                    return result
            if total_uncompressed > max_uncompressed:
                result["code"] = "DOCUMENT_ARCHIVE_LIMIT_EXCEEDED"
                return result
            if total_compressed > 0 and total_uncompressed / total_compressed > max_ratio:
                result["code"] = "DOCUMENT_ARCHIVE_BOMB_RISK"
                return result
            required = {"[Content_Types].xml", "_rels/.rels", "word/document.xml"}
            if not required.issubset(names):
                result["code"] = "DOCUMENT_DOCX_INVALID"
                return result
            lowered = {name.lower() for name in names}
            result["macros"] = any("vbaproject.bin" in name or name.endswith(".docm") for name in lowered)
            result["active"] = any(
                name.startswith("word/embeddings/") or name.endswith((".exe", ".dll", ".js", ".bat", ".cmd", ".ps1"))
                for name in lowered
            )
            xml_names = [name for name in names if name.lower().endswith((".xml", ".rels"))]
            for name in xml_names:
                data = package.read(name)
                upper = data.upper()
                if b"<!DOCTYPE" in upper or b"<!ENTITY" in upper:
                    result["xml_violation"] = True
                    result["code"] = "DOCUMENT_XML_SECURITY_VIOLATION"
                    return result
                if name.lower().endswith(".rels") and b'TARGETMODE="EXTERNAL"' in upper:
                    result["external_relationships"] = True
            result["valid"] = True
            return result
    except (zipfile.BadZipFile, RuntimeError, ValueError, OSError):
        result["code"] = "DOCUMENT_DOCX_INVALID"
        return result
