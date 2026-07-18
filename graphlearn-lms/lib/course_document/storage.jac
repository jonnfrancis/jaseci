"""Storage boundary for immutable course-document source objects."""

import from pathlib { Path }

obj CourseDocumentStorage {
    def put(storage_key: str, payload: bytes) -> bool { raise NotImplementedError("Course document storage is not configured."); }
    def exists(storage_key: str) -> bool { raise NotImplementedError("Course document storage is not configured."); }
    def read(storage_key: str) -> bytes { raise NotImplementedError("Course document storage is not configured."); }
    def move(source_key: str, target_key: str) -> bool { raise NotImplementedError("Course document storage is not configured."); }
    def delete(storage_key: str) -> bool { raise NotImplementedError("Course document storage is not configured."); }
    def provider_name -> str { return "abstract"; }
}

obj LocalCourseDocumentStorage(CourseDocumentStorage) {
    has base_directory: str = ".jac/data/uploads";
    def _path(storage_key: str) -> Path {
        base = Path(self.base_directory).resolve(); target = (base / storage_key).resolve();
        if base != target and base not in target.parents { raise ValueError("Invalid storage key."); }
        return target;
    }
    override def put(storage_key: str, payload: bytes) -> bool {
        target = self._path(storage_key); target.parent.mkdir(parents=True, exist_ok=True);
        with open(target, "wb") as handle { _ = handle.write(payload); }
        return target.exists() and target.stat().st_size == len(payload);
    }
    override def exists(storage_key: str) -> bool { return self._path(storage_key).is_file(); }
    override def read(storage_key: str) -> bytes { return self._path(storage_key).read_bytes(); }
    override def move(source_key: str, target_key: str) -> bool {
        source = self._path(source_key); target = self._path(target_key); target.parent.mkdir(parents=True, exist_ok=True); source.replace(target); return target.exists();
    }
    override def delete(storage_key: str) -> bool {
        target = self._path(storage_key);
        if target.exists() { target.unlink(); }
        return not target.exists();
    }
    override def provider_name -> str { return "local"; }
}
