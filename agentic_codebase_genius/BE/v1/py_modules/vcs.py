# BE/py_modules/vcs.py
import os
import tempfile
import shutil
from datetime import datetime
from git import Repo, GitCommandError

IGNORED_DIRS = {".git", "node_modules", "__pycache__", "venv", ".venv"}

def clone_repo(url: str, depth: int = 1) -> dict:
    """Clone repo to a temp directory. Return dict with path and metadata."""
    out = {"ok": False, "path": "", "error": None}
    try:
        tmpdir = tempfile.mkdtemp(prefix="codegen_")
        Repo.clone_from(url, tmpdir, depth=depth)
        out["ok"] = True
        out["path"] = tmpdir
        out["cloned_at"] = datetime.utcnow().isoformat()
        return out
    except GitCommandError as e:
        out["error"] = str(e)
        if os.path.exists(tmpdir):
            shutil.rmtree(tmpdir, ignore_errors=True)
        return out
    except Exception as e:
        out["error"] = str(e)
        if os.path.exists(tmpdir):
            shutil.rmtree(tmpdir, ignore_errors=True)
        return out

def build_file_tree(root_path: str) -> dict:
    """Return a JSON-ish tree of files (skip IGNORED_DIRS)."""
    def node(path):
        rel = os.path.relpath(path, root_path)
        if os.path.isdir(path):
            children = []
            for name in sorted(os.listdir(path)):
                if name in IGNORED_DIRS:
                    continue
                children.append(node(os.path.join(path, name)))
            return {"path": rel, "type": "dir", "children": children}
        else:
            size = os.path.getsize(path)
            return {"path": rel, "type": "file", "size": size}
    return node(root_path)

def cleanup_path(path: str):
    try:
        shutil.rmtree(path)
    except Exception:
        pass
