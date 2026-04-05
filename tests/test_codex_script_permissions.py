import os
import stat
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT_PATHS = [
    ".codex/skills/planning-with-files/scripts/init-session.sh",
    ".codex/skills/planning-with-files/scripts/check-complete.sh",
    ".codex/skills/planning-with-files/scripts/session-catchup.py",
]


class CodexScriptPermissionTests(unittest.TestCase):
    @unittest.skipIf(os.name == "nt", "Executable mode bits are not reliable on Windows.")
    def test_codex_direct_run_scripts_are_tracked_as_executable(self) -> None:
        for path in SCRIPT_PATHS:
            with self.subTest(path=path):
                mode = (REPO_ROOT / path).stat().st_mode
                self.assertTrue(mode & stat.S_IXUSR, f"{path} is missing user execute bit")


if __name__ == "__main__":
    unittest.main()
