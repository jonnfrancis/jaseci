"""Canonical server-only storage key construction."""

import re;

obj StorageKeyBuilder {
    has namespace: str = "course-documents";
    has temp_prefix: str = "_tmp";
    has trash_prefix: str = "_trash";

    def _safe_id(value: str) -> str {
        clean = value.strip();
        if clean == "" or ".." in clean or "\x00" in clean or "/" in clean or "\\" in clean or re.match(r"^[A-Za-z]:", clean) is not None { raise ValueError("STORAGE_KEY_INVALID"); }
        if re.fullmatch(r"[A-Za-z0-9_-]+", clean) is None { raise ValueError("STORAGE_KEY_INVALID"); }
        return clean;
    }

    def extension(value: str) -> str {
        clean = value.lower().strip().lstrip(".");
        if clean not in ["pdf", "docx"] { raise ValueError("STORAGE_KEY_INVALID"); }
        return clean;
    }

    def build_course_document_key(track_id: str, track_version_id: str, document_id: str, extension: str) -> str {
        return self.namespace + "/" + self._safe_id(track_id) + "/" + self._safe_id(track_version_id) + "/" + self._safe_id(document_id) + "/source." + self.extension(extension);
    }

    def build_temp_key(upload_id: str, extension: str) -> str { return self.temp_prefix + "/" + self._safe_id(upload_id) + "/source." + self.extension(extension); }

    def build_trash_key(document_id: str, timestamp: str, extension: str) -> str {
        safe_timestamp = re.sub(r"[^0-9A-Za-z_-]", "", timestamp);
        if safe_timestamp == "" { raise ValueError("STORAGE_KEY_INVALID"); }
        return self.trash_prefix + "/" + self._safe_id(document_id) + "/" + safe_timestamp + "/source." + self.extension(extension);
    }

    def validate_key(storage_key: str) -> bool {
        if storage_key == "" or "\x00" in storage_key or "\\" in storage_key or storage_key.startswith("/") or ".." in storage_key { return False; }
        return storage_key.startswith(self.namespace + "/") or storage_key.startswith(self.temp_prefix + "/") or storage_key.startswith(self.trash_prefix + "/");
    }
}
