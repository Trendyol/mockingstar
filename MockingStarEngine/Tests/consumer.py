#!/usr/bin/env python3
"""Build a separate host package and exercise its embedded engine, including background startup.

By default consumes the local checkout; --url and --revision verify a published fork revision.
"""
import argparse
import importlib.util
import json
from pathlib import Path
import shlex
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]

HOST = """import MockingstarEngine
#if os(Linux)
import Glibc
#else
import Darwin
#endif

@main enum Consumer {
    static func main() async {
        var input = Array(CommandLine.arguments.dropFirst())
        if input.first == MockingstarEngine.runtimeArgument {
            input.removeFirst()
            exit(await MockingstarEngine.runCLI(input))
        }
        guard input.first == "mock" else { exit(64) }
        input.removeFirst()
        exit(await MockingstarEngine.runCLI(input))
    }
}
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url")
    parser.add_argument("--revision")
    options = parser.parse_args()
    if bool(options.url) != bool(options.revision):
        parser.error("--url and --revision must be supplied together")
    dependency = (f'.package(url: {json.dumps(options.url)}, revision: {json.dumps(options.revision)})'
                  if options.url else f'.package(path: {json.dumps(str(ROOT))})')
    identity = Path(options.url or str(ROOT)).name.removesuffix(".git").lower()
    with tempfile.TemporaryDirectory(prefix="mockingstar-consumer-") as folder:
        package = Path(folder)
        sources = package / "Sources/Consumer"
        sources.mkdir(parents=True)
        (sources / "Consumer.swift").write_text(HOST)
        (package / "Package.swift").write_text(f'''// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "EngineConsumer", platforms: [.macOS(.v13)],
    dependencies: [{dependency}],
    targets: [.executableTarget(name: "Consumer", dependencies: [
        .product(name: "MockingstarEngine", package: {json.dumps(identity)})
    ])])
''')
        subprocess.run(["swift", "build", "--package-path", folder], check=True)
        location = subprocess.check_output(["swift", "build", "--package-path", folder, "--show-bin-path"], text=True).strip()
        binary = Path(location) / "Consumer"
        spec = importlib.util.spec_from_file_location("cli_contracts", ROOT / "MockingStarExecutable/Tests/integration.py")
        contracts = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(contracts)
        contracts.BINARY = binary

        class EmbeddedEngine(contracts.CLIIntegration):
            def process(self, *args, value=None, timeout=20):
                return subprocess.run([str(binary), "mock", *map(str, args)], env=self.env,
                                      input=json.dumps(value) if value is not None else None,
                                      text=True, capture_output=True, timeout=timeout)

            def test_child_uses_host_executable(self):
                self.apply([self.mock()])
                runtime = self.start()
                process = subprocess.check_output(["ps", "-p", str(runtime["pid"]), "-o", "args="], text=True)
                self.assertEqual(Path(shlex.split(process)[0]).resolve(), binary.resolve())
                self.assertIn("--mockingstar-runtime", process)
                self.assertEqual(json.loads(self.request()[1])["source"], "mock")
                self.cli("server", "stop")
                self.started = False
                self.assertEqual(self.cli("server", "status")["state"], "stopped")

        suite = unittest.TestSuite(EmbeddedEngine(name) for name in [
            "test_agent_matching_diagnose_repair_test_serve_wait", "test_child_uses_host_executable"
        ])
        if not unittest.TextTestRunner(verbosity=2).run(suite).wasSuccessful():
            raise SystemExit(1)


if __name__ == "__main__":
    main()
