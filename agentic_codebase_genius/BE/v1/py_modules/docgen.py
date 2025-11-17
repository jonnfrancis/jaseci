# BE/py_modules/docgen.py
import os
from typing import Dict, Any
import json

def generate_markdown(repo_name: str, summary: str, file_tree: Dict, analysis_list: list, out_dir: str, code_summary: str, api_summary: str) -> Dict[str, str]:
    """
    Create outputs/<repo_name>/docs.md and manifest.json
    analysis_list is a list of parse_python_file outputs.
    """
    target_dir = os.path.join(out_dir, repo_name)
    os.makedirs(target_dir, exist_ok=True)
    docs_path = os.path.join(target_dir, "docs.md")
    manifest_path = os.path.join(target_dir, "manifest.json")

    md_lines = []
    md_lines.append(f"# Repo analysis for `{repo_name}`\n")
    md_lines.append("## Overview\n")
    md_lines.append(summary + "\n\n")

    md_lines.append("## Code Summary\n")
    md_lines.append(code_summary + "\n\n")

    md_lines.append("## API Summary\n")
    md_lines.append(api_summary + "\n\n")

    md_lines.append("## File Tree\n")
    md_lines.append("```")
    md_lines.append(json.dumps(file_tree, indent=2))
    md_lines.append("```\n")

    # md_lines.append("## Candidate entry points\n")
    # entry_points = [a["file"] for a in analysis_list if a.get("functions") or a.get("classes")]
    # if entry_points:
    #     for p in entry_points:
    #         md_lines.append(f"- `{p}`\n")
    # else:
    #     md_lines.append("No obvious candidate entry points found.\n")

    # md_lines.append("\n## API Summary\n")
    # md_lines.append("| File | Type | Name | Line | Args / Bases | Doc |\n")
    # md_lines.append("|---|---|---|---:|---|---|\n")
    # for a in analysis_list:
    #     f = a.get("file", "")
    #     for fn in a.get("functions", []):
    #         md_lines.append(f"| `{f}` | function | `{fn['name']}` | {fn['lineno']} | `{', '.join(fn['args'])}` | {short(fn['doc'])} |\n")
    #     for cl in a.get("classes", []):
    #         md_lines.append(f"| `{f}` | class | `{cl['name']}` | {cl['lineno']} | `{', '.join(cl['bases'])}` | {short(cl['doc'])} |\n")

    md_text = "\n".join(md_lines)
    with open(docs_path, "w", encoding="utf-8") as fh:
        fh.write(md_text)

    manifest = {
        "repo": repo_name,
        "generated_at": __import__("datetime").datetime.utcnow().isoformat(),
        "docs": os.path.relpath(docs_path, out_dir),
        "files": file_tree
    }

    with open(manifest_path, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2)

    # Read the content of the files to send to the frontend
    with open(docs_path, "r", encoding="utf-8") as fh:
        docs_content = fh.read()

    with open(manifest_path, "r", encoding="utf-8") as fh:
        manifest_content = fh.read()
        
    return {"docs_content": docs_content, "manifest_content": manifest_content}

def short(text: str, limit: int = 40) -> str:
    if not text:
        return ""
    txt = " ".join(text.strip().split())
    if len(txt) <= limit:
        return txt.replace("|", " ")
    return (txt[:limit].rsplit(" ", 1)[0] + "...").replace("|", " ")
