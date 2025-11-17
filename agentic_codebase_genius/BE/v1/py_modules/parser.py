# BE/py_modules/parser.py
import ast
import os
from typing import Dict, Any, List

def parse_python_file(path: str) -> Dict[str, Any]:
    """Extract top-level funcs/classes & their docstrings/signatures using ast."""
    res = {"file": path, "functions": [], "classes": [], "errors": None}
    try:
        with open(path, "r", encoding="utf-8") as f:
            src = f.read()
        tree = ast.parse(src)
        for node in tree.body:
            if isinstance(node, ast.FunctionDef):
                args = [a.arg for a in node.args.args]
                doc = ast.get_docstring(node) or ""
                res["functions"].append({
                    "name": node.name,
                    "lineno": node.lineno,
                    "args": args,
                    "doc": doc
                })
            elif isinstance(node, ast.ClassDef):
                doc = ast.get_docstring(node) or ""
                bases = [ast.unparse(b) if hasattr(ast, "unparse") else getattr(b, "id", str(b)) for b in node.bases]
                res["classes"].append({
                    "name": node.name,
                    "lineno": node.lineno,
                    "bases": bases,
                    "doc": doc
                })
    except Exception as e:
        res["errors"] = str(e)
    return res

def find_candidate_entrypoints(root_path: str) -> List[str]:
    """Heuristic: files named main.py, app.py, run.py, or files with '__main__'."""
    candidates = []
    for dirpath, dirs, files in os.walk(root_path):
        for f in files:
            if f.endswith(".py") and f.lower() in {"main.py", "app.py", "run.py"}:
                candidates.append(os.path.join(dirpath, f))
            elif f.endswith(".py"):
                # light heuristic: check for __main__ guard
                try:
                    p = os.path.join(dirpath, f)
                    with open(p, "r", encoding="utf-8") as fh:
                        txt = fh.read()
                    if "if __name__" in txt and "__main__" in txt:
                        candidates.append(p)
                except Exception:
                    continue
    return sorted(list(set(candidates)))
