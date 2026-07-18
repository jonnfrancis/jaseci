"""Replaceable blob-store adapter; filesystem details remain inside this boundary."""

import os;
import shutil;
import from io { BytesIO }
import from datetime { datetime, timezone }
import from pathlib { Path }
import from jaclang.runtimelib.storage.storage { Storage }
import from lib.course_document.storage_key_builder { StorageKeyBuilder }
import from lib.course_document.storage_types { StorageObjectMetadata }

obj CourseDocumentStorage {
    def put(_storage_key: str, _payload: bytes) -> bool { raise NotImplementedError("STORAGE_UNAVAILABLE"); }
    def exists(_storage_key: str) -> bool { raise NotImplementedError("STORAGE_UNAVAILABLE"); }
    def read(_storage_key: str) -> bytes { raise NotImplementedError("STORAGE_UNAVAILABLE"); }
    def metadata(_storage_key: str) -> StorageObjectMetadata { raise NotImplementedError("STORAGE_UNAVAILABLE"); }
    def list_objects(_prefix: str = "") -> list[StorageObjectMetadata] { raise NotImplementedError("STORAGE_UNAVAILABLE"); }
    def copy(_source_key: str, _target_key: str) -> bool { raise NotImplementedError("STORAGE_UNAVAILABLE"); }
    def move(_source_key: str, _target_key: str) -> bool { raise NotImplementedError("STORAGE_UNAVAILABLE"); }
    def delete(_storage_key: str) -> bool { raise NotImplementedError("STORAGE_UNAVAILABLE"); }
    def provider_name -> str { return "abstract"; }
}

obj JacCourseDocumentStorage(CourseDocumentStorage) {
    has backend: Storage | None = None;
    has base_directory: str = "";
    has key_builder: StorageKeyBuilder = StorageKeyBuilder();

    def postinit {
        if self.base_directory == "" { self.base_directory = os.getenv("COURSE_DOCUMENT_STORAGE_BASE", "storage/course-documents"); }
        if self.backend is None { self.backend = store(base_path=self.base_directory, create_dirs=True) as Storage; }
    }
    def _backend -> Storage {
        if self.backend is None { raise RuntimeError("STORAGE_UNAVAILABLE"); }
        return self.backend;
    }
    def _key(storage_key: str) -> str {
        if not self.key_builder.validate_key(storage_key) { raise ValueError("STORAGE_KEY_INVALID"); }
        return storage_key;
    }
    override def put(storage_key: str, payload: bytes) -> bool {
        key = self._key(storage_key);
        if self._backend().exists(key) { raise FileExistsError("Immutable storage object already exists."); }
        uploaded = self._backend().upload(BytesIO(payload), key, {"private": "true"});
        return uploaded != "" and self._backend().exists(key);
    }
    override def exists(storage_key: str) -> bool { return self._backend().exists(self._key(storage_key)); }
    override def read(storage_key: str) -> bytes {
        value = self._backend().download(self._key(storage_key));
        if value is None { raise IOError("STORAGE_READ_FAILED"); }
        return value;
    }
    override def metadata(storage_key: str) -> StorageObjectMetadata {
        key = self._key(storage_key); raw = self._backend().get_metadata(key);
        size = raw.get("size", raw.get("size_bytes", -1)) as int;
        return StorageObjectMetadata(storage_key=key, size_bytes=size, modified_at=str(raw.get("modified", raw.get("modified_at", ""))));
    }
    override def list_objects(prefix: str = "") -> list[StorageObjectMetadata] {
        results: list[StorageObjectMetadata] = [];
        for key in self._backend().list_files(prefix, recursive=True) { results.append(self.metadata(key)); }
        return results;
    }
    override def copy(source_key: str, target_key: str) -> bool {
        target = self._key(target_key);
        if self._backend().exists(target) { raise FileExistsError("Immutable storage object already exists."); }
        return self._backend().copy(self._key(source_key), target);
    }
    override def move(source_key: str, target_key: str) -> bool {
        target = self._key(target_key);
        if self._backend().exists(target) { raise FileExistsError("Immutable storage object already exists."); }
        return self._backend().move(self._key(source_key), target);
    }
    override def delete(storage_key: str) -> bool { return self._backend().delete(self._key(storage_key)); }
    override def provider_name -> str { return "jac-store"; }
}

obj LocalCourseDocumentStorage(CourseDocumentStorage) {
    has base_directory: str = "";
    has key_builder: StorageKeyBuilder = StorageKeyBuilder();

    def postinit {
        if self.base_directory == "" { self.base_directory = os.getenv("COURSE_DOCUMENT_STORAGE_BASE", "storage/course-documents"); }
    }

    def _path(storage_key: str) -> Path {
        if not self.key_builder.validate_key(storage_key) { raise ValueError("STORAGE_KEY_INVALID"); }
        base = Path(self.base_directory).resolve(); target = (base / storage_key).resolve();
        if base != target and base not in target.parents { raise ValueError("STORAGE_KEY_INVALID"); }
        return target;
    }

    override def put(storage_key: str, payload: bytes) -> bool {
        target = self._path(storage_key);
        if target.exists() { raise FileExistsError("Immutable storage object already exists."); }
        target.parent.mkdir(parents=True, exist_ok=True);
        with open(target, "xb") as handle { _ = handle.write(payload); }
        return target.is_file() and target.stat().st_size == len(payload);
    }

    override def exists(storage_key: str) -> bool { return self._path(storage_key).is_file(); }
    override def read(storage_key: str) -> bytes {
        target = self._path(storage_key);
        if not target.is_file() { raise FileNotFoundError("STORAGE_OBJECT_NOT_FOUND"); }
        return target.read_bytes();
    }
    override def metadata(storage_key: str) -> StorageObjectMetadata {
        target = self._path(storage_key);
        if not target.is_file() { raise FileNotFoundError("STORAGE_OBJECT_NOT_FOUND"); }
        stats = target.stat();
        return StorageObjectMetadata(storage_key=storage_key, size_bytes=stats.st_size, modified_at=datetime.fromtimestamp(stats.st_mtime, timezone.utc).isoformat());
    }
    override def list_objects(prefix: str = "") -> list[StorageObjectMetadata] {
        base = Path(self.base_directory).resolve(); scan = base;
        if prefix != "" {
            if not self.key_builder.validate_key(prefix + "/probe") { raise ValueError("STORAGE_KEY_INVALID"); }
            scan = self._path(prefix + "/probe").parent;
        }
        if not scan.exists() { return []; }
        paths: list[Path] = [];
        if scan.is_file() { paths.append(scan); }
        else { for discovered in scan.rglob("*") { paths.append(discovered); } }
        results: list[StorageObjectMetadata] = [];
        for item in paths {
            if item.is_file() {
                relative = item.relative_to(base).as_posix() as str; stats = item.stat();
                results.append(StorageObjectMetadata(storage_key=relative, size_bytes=stats.st_size as int, modified_at=datetime.fromtimestamp(stats.st_mtime as float, timezone.utc).isoformat()));
            }
        }
        return results;
    }
    override def copy(source_key: str, target_key: str) -> bool {
        source = self._path(source_key); target = self._path(target_key);
        if not source.is_file() { raise FileNotFoundError("STORAGE_OBJECT_NOT_FOUND"); }
        if target.exists() { raise FileExistsError("Immutable storage object already exists."); }
        target.parent.mkdir(parents=True, exist_ok=True); _ = shutil.copyfile(source, target);
        return target.is_file() and target.stat().st_size == source.stat().st_size;
    }
    override def move(source_key: str, target_key: str) -> bool {
        if not self.copy(source_key, target_key) { return False; }
        return self.delete(source_key) and self.exists(target_key);
    }
    override def delete(storage_key: str) -> bool {
        target = self._path(storage_key);
        if target.is_file() { target.unlink(); }
        return not target.exists();
    }
    override def provider_name -> str { return "local"; }
}
