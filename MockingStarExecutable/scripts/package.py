#!/usr/bin/env python3
"""Build and package the headless CLI, including its historical command name."""
import argparse
import os
from pathlib import Path
import platform
import subprocess
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument("--skip-build", action="store_true")
parser.add_argument("--output", type=Path)
args = parser.parse_args()
repository = Path(__file__).resolve().parents[2]
package = repository / "MockingStarExecutable"
if not args.skip_build:
    subprocess.run(["swift", "build", "-c", "release", "--package-path", str(package)], check=True)
binary_dir = Path(subprocess.check_output(["swift", "build", "-c", "release", "--show-bin-path", "--package-path", str(package)], text=True).strip())
binary = binary_dir / "mockingstar"
system = "macOS" if platform.system() == "Darwin" else "Linux"
output = (args.output or repository / ".build" / f"MockingStar-{system}-CLI.zip").resolve()
output.parent.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
    for name in ["mockingstar", "MockingStar"]:
        entry = zipfile.ZipInfo(name)
        entry.create_system = 3
        entry.external_attr = (0o100755 << 16)
        archive.writestr(entry, binary.read_bytes(), compress_type=zipfile.ZIP_DEFLATED)
    archive.write(package / "scripts" / "install.py", "install.py")
    archive.write(repository / "docs" / "CLI.md", "CLI.md")
    archive.write(repository / "LICENSE", "LICENSE")
print(output)
