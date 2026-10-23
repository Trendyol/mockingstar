#!/usr/bin/env python3
"""Black-box CLI contracts. No GUI, external service, or third-party Python package."""
import base64
import concurrent.futures
import datetime
import http.server
import json
import os
from pathlib import Path
import select
import signal
import socket
import subprocess
import sys
import tempfile
import threading
import time
import unittest
import urllib.error
import urllib.request

BINARY = Path(os.environ.get("MOCKINGSTAR_BINARY", "MockingStarExecutable/.build/debug/mockingstar")).resolve()


def free_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00", "Z")


class Upstream(http.server.BaseHTTPRequestHandler):
    hits = []
    def do_GET(self):
        self.hits.append(self.path)
        data = json.dumps({"source": "live", "path": self.path}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)
    do_POST = do_GET
    def log_message(self, *args):
        pass


class CLIIntegration(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not BINARY.is_file():
            raise RuntimeError(f"Build CLI first; executable missing: {BINARY}")
        cls.upstream = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Upstream)
        cls.thread = threading.Thread(target=cls.upstream.serve_forever, daemon=True)
        cls.thread.start()
        cls.url = f"http://127.0.0.1:{cls.upstream.server_port}"

    @classmethod
    def tearDownClass(cls):
        cls.upstream.shutdown()
        cls.upstream.server_close()

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="mockingstar-cli-")
        self.root = Path(self.temp.name)
        self.env = dict(os.environ, XDG_CONFIG_HOME=str(self.root / "config"))
        self.workspace = self.root / "workspace"
        self.cli("workspace", "init", str(self.workspace))
        self.cli("domain", "create", "--domain", "Dev")
        self.port, self.control_port = free_port(), free_port()
        self.started = False

    def tearDown(self):
        try:
            if self.started:
                self.cli("server", "stop", timeout=15)
        finally:
            self.temp.cleanup()

    def process(self, *args, value=None, timeout=20):
        return subprocess.run([str(BINARY), *map(str, args)], env=self.env,
                              input=json.dumps(value) if value is not None else None,
                              text=True, capture_output=True, timeout=timeout)

    def cli(self, *args, value=None, error=None, timeout=20):
        result = self.process(*args, value=value, timeout=timeout)
        try:
            envelope = json.loads(result.stdout)
        except ValueError:
            self.fail(f"Non-JSON stdout: {args}: {result.stdout!r}; stderr={result.stderr}")
        self.assertEqual(envelope["schemaVersion"], 1)
        if error:
            self.assertNotEqual(result.returncode, 0, result.stdout)
            self.assertFalse(envelope["ok"])
            self.assertEqual(envelope["error"]["code"], error, envelope)
            return envelope["error"]
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(envelope["ok"], envelope)
        return envelope["data"]

    def mock(self, id="page-one", path="/items", **extra):
        return dict(id=id, url=self.url + path, method="GET",
                    matching={"endpoint": {"method": "GET", "host": "127.0.0.1", "path": {"style": "exact", "value": path}},
                              "conditions": {"predicate": {"source": "query", "key": "page", "op": "equals", "value": "1"}}},
                    response={"status": 200, "headers": {"Content-Type": "application/json"}, "body": {"source": "mock"}}, **extra)

    def apply(self, mocks):
        return self.cli("mock", "apply", "--domain", "Dev", "--file", "-", value={"mocks": mocks})

    def start(self, *extra):
        result = self.cli("server", "start", "--background", "--port", self.port, "--control-port", self.control_port, *extra)
        self.started = True
        self.assertEqual(result["state"], "running")
        self.assertNotIn("token", result)
        return result

    def request(self, query="page=1", path="/items", body=None, url=None, headers=None, **flags):
        payload = {"method": "POST" if body is not None else "GET", "url": url or self.url + path + ("?" + query if query else ""), "header": headers or {}}
        if body is not None:
            payload["body"] = base64.b64encode(json.dumps(body).encode()).decode()
        req = urllib.request.Request(f"http://127.0.0.1:{self.port}/mock", data=json.dumps(payload).encode(),
                                     headers={"Content-Type": "application/json", "mockDomain": "Dev", **flags})
        try:
            response = urllib.request.urlopen(req, timeout=10)
        except urllib.error.HTTPError as error:
            response = error
        with response:
            data = response.read()
            return response.status, data, response.headers.get("X-Mockingstar-Request-Id")

    def test_agent_matching_diagnose_repair_test_serve_wait(self):
        self.apply([self.mock()])
        self.start()
        status, body, mocked = self.request("size=10&page=1")
        self.assertEqual(status, 200)
        self.assertEqual(json.loads(body)["source"], "mock")
        status, body, live = self.request("page=2&size=10")
        self.assertEqual(json.loads(body)["source"], "live")
        self.assertEqual(len(self.cli("mock", "list", "--domain", "Dev")), 1)
        explanation = self.cli("requests", "explain", live)
        self.assertEqual(explanation["outcome"], "live")
        self.assertEqual(explanation["decision"]["candidates"][0]["failures"][0]["field"], "query:page")
        rule = self.mock()["matching"]
        rule["conditions"]["predicate"]["value"] = "2"
        self.cli("mock", "matching", "page-one", "--domain", "Dev", "--file", "-", value=rule)
        hits = len(Upstream.hits)
        tested = self.cli("requests", "test", live)
        self.assertFalse(tested["networkSent"])
        self.assertEqual(tested["decision"]["mockId"], "page-one")
        self.assertEqual(len(Upstream.hits), hits)
        boundary = now()
        status, body, repaired = self.request("page=2")
        self.assertEqual(json.loads(body)["source"], "mock")
        served = self.cli("requests", "wait", "--mock-id", "page-one", "--since", boundary, "--timeout", "2")
        self.assertEqual(served["id"], repaired)
        self.assertEqual(served["outcome"], "mock")
        self.assertEqual(self.cli("analyze-usage")["mocks"]["page-one"], 2)
        missed_logs = [entry["line"] for entry in self.cli("logs") if "Match decision" in entry["line"] and "conditions_not_matched" in entry["line"]]
        self.assertTrue(missed_logs)
        self.assertTrue(any(live in line and "candidates=" in line and "page-one" in line for line in missed_logs))
        self.assertTrue(self.cli("trace"))

    def test_crud_bundles_import_export_reload_integrity(self):
        self.apply([self.mock(), self.mock("other", "/other")])
        before = self.cli("mock", "export", "--domain", "Dev")
        invalid = self.mock("bad"); invalid["response"]["status"] = 900
        self.cli("mock", "apply", "--domain", "Dev", "--file", "-", value={"mocks": [self.mock("new"), invalid]}, error="invalid_mock")
        self.assertEqual(self.cli("mock", "export", "--domain", "Dev"), before)
        updated = self.cli("mock", "update", "page-one", "--domain", "Dev", "--file", "-", value={"response": {"body": {"updated": True}}})
        self.assertEqual(updated["matching"], before["mocks"][0]["matching"])
        self.cli("mock", "disable", "page-one", "--domain", "Dev")
        self.assertFalse(self.cli("mock", "show", "page-one", "--domain", "Dev")["matching"]["enabled"])
        self.cli("mock", "enable", "page-one", "--domain", "Dev")
        copied = self.cli("mock", "copy", "page-one", "--domain", "Dev", "--to-domain", "Test")
        self.assertNotEqual(copied["id"], "page-one")
        self.cli("mock", "move", copied["id"], "--domain", "Test", "--to-domain", "Dev")
        self.assertEqual(self.cli("mock", "list", "--domain", "Test"), [])
        self.cli("mock", "delete", copied["id"], "--domain", "Dev")
        reloaded = self.cli("mock", "reload", "page-one", "--domain", "Dev")
        self.assertFalse(reloaded["saved"])
        self.assertEqual(self.cli("mock", "show", "page-one", "--domain", "Dev")["responseBody"], {"updated": True})
        self.cli("mock", "reload", "page-one", "--domain", "Dev", "--save")
        self.assertEqual(self.cli("mock", "show", "page-one", "--domain", "Dev")["responseBody"]["source"], "live")
        self.cli("mock", "import", "--domain", "Test", "--file", "-", value=before)
        self.assertEqual(len(self.cli("mock", "list", "--domain", "Test")), 2)
        curl = self.cli("mock", "export", "page-one", "--domain", "Dev", "--format", "curl")[0]
        result = subprocess.run([str(BINARY), "mock", "import", "--domain", "Test", "--format", "curl", "--file", "-"], env=self.env, input=curl, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        files = list((self.workspace / "Domains/Dev/Mocks").rglob("*.json"))
        duplicate = files[0].parent / "duplicate.json"
        duplicate.write_bytes(files[0].read_bytes())
        self.assertIn("duplicate_id", {x["kind"] for x in self.cli("integrity", "check", "--domain", "Dev")["issues"]})
        self.cli("integrity", "fix", "--domain", "Dev")
        self.assertEqual(self.cli("integrity", "check", "--domain", "Dev")["issues"], [])

    def test_initial_corrupt_mock_live_fallback_and_legacy_import(self):
        self.apply([self.mock()])
        native = self.cli("mock", "export", "page-one", "--domain", "Dev")["mocks"][0]
        file = next((self.workspace / "Domains/Dev/Mocks").rglob("*.json"))
        file.write_text("invalid json")
        self.start()
        status, body, request_id = self.request()
        self.assertEqual(status, 200)
        self.assertEqual(json.loads(body)["source"], "live")
        decision = self.cli("requests", "explain", request_id)["decision"]
        self.assertEqual(decision["reason"], "mock_load_failed")
        self.assertTrue(any("mock_load_failed" in failure["reason"] for candidate in decision["candidates"] for failure in candidate["failures"]))
        file.unlink()
        native.pop("matching")
        native["metaData"]["scenario"] = ""
        self.cli("mock", "import", "--domain", "Dev", "--file", "-", value=native)
        status, body, legacy_id = self.request()
        self.assertEqual(json.loads(body)["source"], "mock")
        self.assertEqual(self.cli("requests", "explain", legacy_id)["decision"]["reason"], "legacy_matched")
        self.cli("mock", "update", "page-one", "--domain", "Dev", "--file", "-", value={"response": {"body": {"legacy": True}}})
        self.assertNotIn("matching", self.cli("mock", "show", "page-one", "--domain", "Dev"))

    def test_body_matching_priority_and_concurrent_trace_stream(self):
        def predicate(source, key, op, value=None):
            result = {"source": source, "key": key, "op": op}
            if op not in ("exists", "absent"):
                result["value"] = value
            return {"predicate": result}
        rule = self.mock("body-rule")
        rule["method"] = "POST"
        rule["matching"]["endpoint"]["method"] = "POST"
        rule["matching"]["endpoint"]["path"] = {"style": "glob", "value": "/other/*"}
        rule["matching"]["conditions"] = {"all": [
            predicate("jsonBody", "/user/name", "equals", None),
            predicate("jsonBody", "/user/age", "gte", 18),
            {"not": predicate("jsonBody", "/deleted", "exists")},
            {"any": [predicate("header", "x-test", "equals", "yes"), predicate("query", "tag", "equals", ["a", "a", "b"])]}
        ]}
        second = json.loads(json.dumps(rule))
        second["id"] = "z-fallback"; second["matching"]["conditions"] = None
        second["matching"]["priority"] = -1
        second["response"]["body"] = {"source": "fallback"}
        self.apply([second, rule]); self.start()
        payload = {"user": {"age": 20, "name": None}}
        status, body, matched_id = self.request(query="tag=b&tag=a&tag=a", path="/other/42", body=payload)
        self.assertEqual(json.loads(body)["source"], "mock")
        status, body, fallback_id = self.request(query="", path="/other/42", body={"user": {"age": 20}})
        self.assertEqual(json.loads(body)["source"], "fallback")
        failures = self.cli("requests", "explain", fallback_id)["decision"]["candidates"][0]["failures"]
        self.assertTrue(any(failure["reason"] == "field_missing" for failure in failures))
        null_failure = next(failure for failure in failures if failure["field"] == "jsonBody:/user/name")
        self.assertIn("expected", null_failure)
        self.assertIsNone(null_failure["expected"])
        self.assertNotIn("actual", null_failure)
        follower = subprocess.Popen([str(BINARY), "trace", "--follow", "--limit", "0"], env=self.env, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            time.sleep(0.25)
            with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
                responses = list(pool.map(lambda _: self.request(query="", path="/other/42", body=payload, headers={"X-Test": "yes"}), range(16)))
            readable, _, _ = select.select([follower.stdout], [], [], 5)
            self.assertTrue(readable, "trace --follow did not emit a completed request")
            envelope = json.loads(follower.stdout.readline())
            self.assertTrue(envelope["ok"])
            self.assertIn(envelope["data"]["metadata"]["requestId"], {response[2] for response in responses})
            trace = self.cli("trace")
            ids = {entry["metadata"]["requestId"] for entry in trace}
            self.assertTrue({response[2] for response in responses}.issubset(ids))
        finally:
            follower.terminate(); follower.communicate(timeout=5)

    def test_scenario_concurrent_writers_preserve_assignments_and_invalid_file(self):
        def assign(index):
            return self.cli("scenario", "set", "--domain", "Dev", "--device-id", f"sim-{index}", "--path", "/items", "--scenario", "test")
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            list(pool.map(assign, range(24)))
        self.assertEqual(len(self.cli("scenario", "list", "--domain", "Dev")), 24)
        path = self.workspace / "Domains/Dev/Configs/scenarios.json"
        path.write_text("invalid json")
        self.cli("scenario", "set", "--domain", "Dev", "--device-id", "new", "--path", "/items", "--scenario", "test", error="invalid_input")
        self.assertEqual(path.read_text(), "invalid json")

    def test_journal_failure_keeps_traffic_request_id_and_reports_storage_error(self):
        self.apply([self.mock()])
        (self.workspace / ".mockingstar/requests").write_text("blocked directory")
        self.start()
        status, body, request_id = self.request()
        self.assertEqual(status, 200)
        self.assertEqual(json.loads(body)["source"], "mock")
        self.assertTrue(request_id)
        lines = "\n".join(entry["line"] for entry in self.cli("logs"))
        self.assertIn("journal_write_failed", lines)
        self.assertIn(request_id, lines)

    def test_runtime_lifecycle_conflict_auth_drain_and_restart(self):
        mock = self.mock(); mock["response"]["delay"] = 0.8
        self.apply([mock])
        initial = self.start()
        self.cli("server", "start", "--background", "--port", self.port, "--control-port", self.control_port, error="already_running")
        with self.assertRaises(urllib.error.HTTPError) as denied:
            urllib.request.urlopen(f"http://127.0.0.1:{self.control_port}/status")
        self.assertEqual(denied.exception.code, 401)
        with concurrent.futures.ThreadPoolExecutor() as pool:
            request = pool.submit(self.request)
            deadline = time.monotonic() + 3
            while not self.cli("requests", "list"):
                self.assertLess(time.monotonic(), deadline)
            self.cli("server", "stop", timeout=10)
            self.started = False
            self.assertEqual(json.loads(request.result()[1])["source"], "mock")
        self.assertEqual(self.cli("server", "status")["state"], "stopped")
        self.assertNotEqual(self.start()["id"], initial["id"])
        self.cli("server", "stop"); self.started = False
        with socket.socket() as occupied:
            self.control_port = free_port()
            occupied.bind(("127.0.0.1", self.control_port)); occupied.listen()
            self.cli("server", "start", "--background", "--port", self.port, "--control-port", self.control_port, error="port_in_use")
        self.assertEqual(self.cli("server", "status")["state"], "stopped")
        self.start()

    def test_foreground_signal_stale_record_and_arguments(self):
        self.cli("mock", "list", "--domain", "Dev", "unexpected", error="invalid_arguments")
        process = subprocess.Popen([str(BINARY), "server", "start", "--port", str(self.port), "--control-port", str(self.control_port)], env=self.env, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            ready = json.loads(process.stdout.readline())
            self.assertEqual(ready["data"]["state"], "running")
            process.send_signal(signal.SIGTERM)
            out, err = process.communicate(timeout=10)
            self.assertEqual(process.returncode, 0, out + err)
            self.assertEqual(out, "")
        finally:
            if process.poll() is None:
                process.kill(); process.communicate()
        runtime = self.workspace / ".mockingstar/runtime.json"
        stale = ready["data"] | {"token": "stale", "startedAt": "21.10.2026 16:00:00"}
        runtime.write_text(json.dumps(stale))
        self.assertEqual(self.cli("server", "status")["state"], "stale")
        self.assertTrue(self.cli("server", "stop")["staleRecordRemoved"])
        self.cli("workspace", "remove", str(self.workspace))
        self.assertTrue(self.workspace.is_dir())
        self.cli("domain", "list", error="workspace_required")

    def test_invalid_edit_retains_rule_live_failure_and_opt_in_capture(self):
        self.apply([self.mock()]); self.start()
        self.assertEqual(json.loads(self.request()[1])["source"], "mock")
        file = next((self.workspace / "Domains/Dev/Mocks").rglob("*.json"))
        original = file.read_bytes(); file.write_text("invalid json")
        self.assertEqual(json.loads(self.request()[1])["source"], "mock")
        file.write_bytes(original)
        closed = free_port()
        self.request(url=f"http://127.0.0.1:{closed}/unavailable")
        failures = self.cli("requests", "list", "--outcome", "error")
        self.assertEqual(failures[-1]["errorCode"], "live_request_failed")
        self.cli("server", "stop"); self.started = False
        self.start("--record-live")
        self.request(query="", path="/captured")
        self.assertEqual(len(self.cli("mock", "list", "--domain", "Dev")), 2)

    @unittest.skipUnless(sys.platform == "darwin", "macOS JavaScript engine")
    def test_plugins_and_scenarios_config(self):
        source = 'var config = []; function defaultResponseModel(message) { return "custom:" + message; }'
        result = subprocess.run([str(BINARY), "plugin", "set", "--domain", "Dev", "--type", "mockError", "--file", "-"], env=self.env, input=source, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.cli("plugin", "run", "--domain", "Dev", "--type", "mockError", "--message", "test"), "custom:test")
        settings = [{"key": "enabled", "valueType": "bool", "value": True}]
        self.assertEqual(self.cli("plugin", "settings", "--domain", "Dev", "--type", "mockError", "--file", "-", value=settings), settings)
        self.cli("plugin", "delete", "--domain", "Dev", "--type", "mockError")
        self.cli("scenario", "set", "--domain", "Dev", "--device-id", "sim", "--path", "/items", "--scenario", "test")
        self.assertEqual(len(self.cli("scenario", "list", "--domain", "Dev")), 1)
        self.cli("scenario", "clear", "--domain", "Dev", "--device-id", "sim")
        self.assertEqual(self.cli("scenario", "list", "--domain", "Dev"), [])
        config = self.cli("config", "get", "--domain", "Dev")
        self.assertEqual(self.cli("config", "set", "--domain", "Dev", "--file", "-", value=config), config)


if __name__ == "__main__":
    unittest.main(verbosity=2)
