#!/usr/bin/env python3
"""Build an explicit, hash-manifested source package; never copy the repo wholesale."""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path, help="new/empty output directory")
    args = parser.parse_args()
    output = args.output.resolve()
    if output == ROOT or ROOT.is_relative_to(output):
        parser.error("output cannot contain the source repository")
    if output.exists() and any(output.iterdir()):
        parser.error("output must be empty to prevent stale files in the package")
    subprocess.run([sys.executable, str(ROOT / "scripts/verify_package.py")], check=True)
    files = {"filelist.xml", "ModConfig.xml", "version.json", "CSharp/BaroWardrobeSwitcher.csproj",
             "README.md", "ARCHITECTURE.md", "COMPATIBILITY.md", "TESTING.md", "QUALITY_REPORT.md"}
    for element in ET.parse(ROOT / "filelist.xml").getroot():
        raw = element.get("file")
        if raw:
            relative = raw.replace("%ModDir%/", "").replace("\\", "/")
            source = (ROOT / relative).resolve()
            if not source.is_relative_to(ROOT):
                parser.error(f"reference escapes repository: {raw}")
            files.add(source.relative_to(ROOT).as_posix())
    # Validate the full input list before creating any output.
    for relative in files:
        if not (ROOT / relative).is_file():
            parser.error(f"package input is missing: {relative}")
    output.mkdir(parents=True, exist_ok=True)
    hashes = {}
    for relative in sorted(files):
        destination = output / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / relative, destination)
        hashes[relative] = hashlib.sha256(destination.read_bytes()).hexdigest()
    version = json.loads((ROOT / "version.json").read_text(encoding="utf-8"))
    (output / "package-manifest.json").write_text(json.dumps({
        "modVersion": version["modVersion"], "files": hashes
    }, indent=2) + "\n", encoding="utf-8")
    subprocess.run([sys.executable, str(ROOT / "scripts/verify_package.py"),
                    "--package-root", str(output)], check=True)
    print(f"Source package: {output} ({len(hashes)} files plus SHA-256 manifest)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
