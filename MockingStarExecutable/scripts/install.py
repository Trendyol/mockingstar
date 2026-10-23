#!/usr/bin/env python3
"""Install an extracted release or a binary built from source."""
import argparse
from pathlib import Path
import shutil

parser = argparse.ArgumentParser()
parser.add_argument("--prefix", type=Path, default=Path.home() / ".local")
parser.add_argument("--binary", type=Path, default=Path(__file__).resolve().parent / "mockingstar")
args = parser.parse_args()
destination = args.prefix.expanduser().resolve() / "bin"
destination.mkdir(parents=True, exist_ok=True)
target = destination / "mockingstar"
shutil.copy2(args.binary, target)
target.chmod(0o755)
alias = destination / "MockingStar"
# On case-insensitive macOS volumes the historical name already resolves to target.
if not alias.exists() or not alias.samefile(target):
    if alias.exists() or alias.is_symlink():
        alias.unlink()
    alias.symlink_to("mockingstar")
print(f"Installed {target}; add {destination} to PATH.")
