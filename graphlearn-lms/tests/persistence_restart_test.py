"""Cross-process smoke test for Jac's local durable graph store."""

from __future__ import annotations

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


PROJECT_ROOT = Path(__file__).resolve().parents[1]
JAC = PROJECT_ROOT / ".jac" / "venv" / "Scripts" / "jac.exe"
PROBE_SOURCE = PROJECT_ROOT / "lib" / "persistence" / "restart_probe.jac"


def _run_probe(workdir: Path, mode: str, probe_id: str) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env.pop("MONGODB_URI", None)
    env["PYTHONUTF8"] = "1"
    env["GRAPHLEARN_PROBE_MODE"] = mode
    env["GRAPHLEARN_PROBE_ID"] = probe_id
    return subprocess.run(
        [str(JAC), "run", str(workdir / "restart_probe.jac")],
        cwd=workdir,
        env=env,
        check=True,
        capture_output=True,
        text=True,
        timeout=60,
    )


class PersistenceRestartTest(unittest.TestCase):
    def test_graph_record_survives_a_new_process(self) -> None:
        """Write in one Jac process and restore the record in another."""
        probe_id = "restart-contract"
        with tempfile.TemporaryDirectory(prefix="graphlearn-persistence-") as directory:
            workdir = Path(directory)
            shutil.copy2(PROBE_SOURCE, workdir / "restart_probe.jac")
            (workdir / "jac.toml").write_text(
                '[project]\nname = "persistence-restart-test"\nentry-point = "restart_probe.jac"\n',
                encoding="utf-8",
            )
            first = _run_probe(workdir, "write", probe_id)
            second = _run_probe(workdir, "read", probe_id)

            self.assertIn("PERSISTENCE_PROBE_WRITE", first.stdout)
            self.assertIn("PERSISTENCE_PROBE_READ", second.stdout)
            self.assertIn(probe_id, first.stdout)
            self.assertIn(probe_id, second.stdout)


if __name__ == "__main__":
    unittest.main()
