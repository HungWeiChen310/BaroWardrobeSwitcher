"""Behavior checks for the final source-package gate (no game installation needed)."""
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class PackageTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.workspace = tempfile.TemporaryDirectory(prefix="wardrobe-package-tests-")
        cls.clean = Path(cls.workspace.name) / "clean"
        subprocess.run([sys.executable, str(ROOT / "scripts/package_mod.py"), str(cls.clean)],
                       check=True, capture_output=True, text=True, encoding="utf-8")

    @classmethod
    def tearDownClass(cls):
        cls.workspace.cleanup()

    def setUp(self):
        self.case = tempfile.TemporaryDirectory(prefix="wardrobe-package-case-")
        self.addCleanup(self.case.cleanup)
        self.package = Path(self.case.name) / "package"
        shutil.copytree(self.clean, self.package)

    def verify(self, *extra):
        return subprocess.run([sys.executable, str(ROOT / "scripts/verify_package.py"),
                               "--package-root", str(self.package), *extra],
                              capture_output=True, text=True, encoding="utf-8")

    def test_unicode_output_path(self):
        output = Path(self.case.name) / "衣櫃模組"
        result = subprocess.run([sys.executable, str(ROOT / "scripts/package_mod.py"), str(output)],
                                capture_output=True, text=True, encoding="utf-8")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("衣櫃模組", result.stdout)

    def test_clean_candidate(self):
        result = self.verify()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_candidate_cannot_be_released(self):
        result = self.verify("--release")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("in-game matrix", result.stderr)

    def test_previous_version_is_metadata_driven(self):
        path = self.package / "version.json"
        metadata = json.loads(path.read_text(encoding="utf-8"))
        metadata["previousVerifiedGameVersion"] = "0.0.0.0"
        path.write_text(json.dumps(metadata), encoding="utf-8")
        self.assertIn("previousVerifiedGameVersion", self.verify().stderr)

    def test_config_must_be_listed(self):
        path = self.package / "filelist.xml"
        path.write_text(path.read_text(encoding="utf-8").replace(
            '  <Other file="%ModDir%/Config/SettingsClient.xml" />\n', ''), encoding="utf-8")
        self.assertIn("ModConfig.xml file is not in filelist.xml", self.verify().stderr)

    def test_runtime_data_and_binary_rejected(self):
        for relative in ["DivingProfiles.json", "CSharp/Client/stale.dll"]:
            path = self.package / relative
            path.write_bytes(b"not a package input")
            self.assertIn("Binary or runtime data", self.verify().stderr)
            path.unlink()

    def test_escape_rejected(self):
        path = self.package / "filelist.xml"
        path.write_text(path.read_text(encoding="utf-8").replace(
            "%ModDir%/Texts.xml", "%ModDir%/../outside.xml"), encoding="utf-8")
        result = self.verify()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("escapes mod directory", result.stderr)

    def test_manifest_detects_changed_source(self):
        with (self.package / "Lua/WardrobeSwitcher.lua").open("a", encoding="utf-8") as stream:
            stream.write("\n-- unexpected package modification\n")
        self.assertIn("Package hash mismatch", self.verify().stderr)


if __name__ == "__main__":
    unittest.main()
