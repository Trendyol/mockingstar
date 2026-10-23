# Mockingstar CLI

Use every workspace operation without opening the macOS app. The CLI depends on CommonKit, MockingStarCore, Server and PluginCore, with no SwiftUI dependency. The headless package requires macOS 13 or later; the GUI retains its existing minimum version. Linux supports storage, rules, proxying, diagnostics and server management; JavaScript execution is unavailable there.

## Build and install

```sh
swift build -c release --package-path MockingStarExecutable
python3 MockingStarExecutable/scripts/install.py --binary MockingStarExecutable/.build/release/mockingstar
export PATH="$HOME/.local/bin:$PATH"
mockingstar --help
```

Release archives contain `mockingstar`, the historical `MockingStar` command, this guide and `install.py`. Extract the archive and run `python3 install.py [--prefix /your/prefix]`. Build an archive with `python3 MockingStarExecutable/scripts/package.py`. The macOS release artifact is built for the runner's architecture.

## Import into another CLI

The repository root is a Swift package. It exports `MockingstarEngine`, `MockingStarCore`, `CommonKit` and the standalone `mockingstar` executable. A host such as SimCLI can link the engine into its own executable; no companion binary or GUI process is required. For an unpublished fork, pin its exact commit:

```swift
.package(url: "https://github.com/YOUR_ORG/mockingstar.git", revision: "FULL_COMMIT_SHA")
// Host target dependencies:
.product(name: "MockingstarEngine", package: "mockingstar")
```

`try await MockingstarEngine.execute(arguments)` returns the command's data and throws `MockingstarEngineError` with stable `code` and `message`. It is intended for finite commands returning data. Streaming commands and foreground startup still write readiness/JSONL; use `await MockingstarEngine.runCLI(arguments)` to forward CLI output and receive its exit status. The host supplies an explicit `--workspace PATH` to each call for independent sessions.

For managed background startup, the host must intercept `MockingstarEngine.runtimeArgument` **before its own argument parser**. The engine relaunches the current executable with this marker followed by `server start` arguments:

```swift
import MockingstarEngine
// Inside the host's async main, before normal command parsing:
var input = Array(CommandLine.arguments.dropFirst())
if input.first == MockingstarEngine.runtimeArgument {
    input.removeFirst()
    exit(await MockingstarEngine.runCLI(input))
}
// Normal host command group then forwards its engine arguments to execute/runCLI.
```

Run `python3 MockingStarEngine/Tests/consumer.py` to build an independent host package and prove that matching, diagnostics, rule repair and background serving work inside one host binary. Add `--url FORK_URL --revision COMMIT_SHA` to verify a remote dependency. Both the root `swift build` and historical `swift build --package-path MockingStarExecutable` build the same standalone wrapper. Open the root `Package.swift` separately in Xcode for headless development; the GUI workspace uses its existing nested packages and excludes the CLI package to avoid duplicate core module identities.

## Workspace and server

```sh
mockingstar workspace init ./mocks --name development
mockingstar domain create --domain Dev
mockingstar mock apply --domain Dev --file docs/examples/page-one.json
mockingstar server start --background
mockingstar server status
mockingstar server stop
```

Use `--workspace PATH` to select a workspace for one command. Otherwise the CLI uses its registry at `$XDG_CONFIG_HOME/mockingstar/workspaces.json` or `~/.config/mockingstar/workspaces.json`. The GUI's workspace defaults remain independent. `workspace add|use|remove PATH` register, select or unregister a directory; remove keeps its files. `workspace list` shows the registry. Domain operations require `--domain NAME`; `domain list` lists domains.

`server start` runs in the foreground by default. It emits readiness only after both listeners start. `--background` starts one managed instance per workspace. The data listener defaults to port 8008; authenticated control binds only `127.0.0.1:8009`. Override both with `--port` and `--control-port`. Runtime identity and token are stored under `.mockingstar` with private permissions. Stop drains active handlers and their journal writes, up to 120 seconds, before closing listeners. SIGINT and SIGTERM use the same shutdown path. Start rejects an active workspace instance or occupied port. Stale unlocked runtime records are replaced on start or removed on stop, without signalling the stored PID.

Unmatched requests continue upstream. Live responses do not create active mocks by default. `server start --record-live` enables capture using the existing save filters. Legacy `MockingStar start PATH`, `-p`, `-l`, `-v`, `--logs-folder` and `--trace-export` remain supported.

## Packages and matching

`mock apply --file -` accepts a package on stdin. A package is `{"mocks":[...]}`; `name` is optional and does not influence matching. A native Mockingstar document, a shorthand document or an array also works. Supply stable IDs for repeatable upserts. Every mock is validated before the batch is written; invalid batches leave mocks unchanged. Writers use a workspace lock and atomic replacement with rollback on write failure. The active server reloads rules on the next request; invalid direct edits are logged and the previous valid rule remains active.

Shorthand fields: `id`, `url`, `method` (GET), `headers`, `body`, `scenario`, `matching`, and `response` containing `status` (200), `headers`, `body`, `delay` (seconds, default 0). Strings represent raw bodies; objects and arrays represent JSON. Shorthand without matching gets an exact method/host/path rule. Native documents without matching retain the existing legacy matcher. Native export, copy, updates, GUI edits and lazy loading preserve matching.

Matching has `enabled` (true), `priority` (0), `endpoint` and optional `conditions`. Endpoint method and host compare without case; path uses `{"style":"exact|glob|regex","value":"..."}`. Glob `*` spans any characters including `/`, and `?` matches one character. Regex uses Foundation regular expressions and searches the path; use `^...$` for whole-path matching. Rules are indexed across the entire domain, sorted by descending priority and ascending ID. An explicit rule that fails conditions cannot re-enter the legacy matcher.

Expressions contain exactly one member: `all` (array), `any` (array), `not` (one expression), or `predicate`. For example:

```json
{
  "all": [
    {"predicate": {"source": "query", "key": "tag", "op": "equals", "value": ["a", "a", "b"]}},
    {"any": [
      {"predicate": {"source": "jsonBody", "key": "/user/age", "op": "gte", "value": 18}},
      {"predicate": {"source": "header", "key": "X-Test", "op": "equals", "value": "yes"}}
    ]},
    {"not": {"predicate": {"source": "jsonBody", "key": "/deleted", "op": "exists"}}}
  ]
}
```

Sources: `query`, `header`, `jsonBody`, `body`, `scenario`, `deviceId`. Query and header require `key`. JSON fields use JSON Pointer: `/user/name`, `/items/0/id`; an empty pointer selects the whole body. `~1` escapes `/`, `~0` escapes `~`. A missing field differs from present JSON null. Object equality ignores key order; JSON array equality keeps order. Query order is ignored and repeated values are retained: a scalar operand matches any value; array `equals` compares the full multiset including duplicates. Header names are case-insensitive.

Operators: `equals`, `contains`, `startsWith`, `endsWith`, `regex`, `exists`, `absent`, `oneOf`, `gt`, `gte`, `lt`, `lte`. Existence needs no operand; `oneOf` needs an array; numeric comparisons need a numeric operand and also accept numeric query/header text. Matching string values are case-sensitive.

## Agent diagnosis loop

1. Apply a package and start the server.
2. Trigger the request in the app using its existing Mockingstar client. `/mock`, `/search` and `/scenario` retain their mobile wire contracts.
3. Read `X-Mockingstar-Request-Id` from the response, or find it through `requests list`.
4. Run `requests explain REQUEST_ID`: the original request, candidate IDs, failed fields, expected/actual values, fallback reason and upstream error are included.
5. Edit the rule with `mock matching ID --domain Dev --file rule.json` or apply an updated package.
6. Run `requests test REQUEST_ID`. It uses the current matcher and the captured request and sends no network request.
7. Trigger the app interaction again and verify the served response with `requests wait --mock-id ID`. Start wait before the interaction, or give `--since ISO8601` for a known earlier boundary. Timeout defaults to 30 seconds.

```sh
mockingstar requests explain "$REQUEST_ID"
mockingstar mock matching items-page-one --domain Dev --file rule.json
mockingstar requests test "$REQUEST_ID"
mockingstar requests wait --mock-id items-page-one --timeout 30
```

The CLI does not refresh or control app screens. An embedding host can provide that connection. A runnable black-box agent example is `python3 MockingStarExecutable/Tests/integration.py CLIIntegration.test_agent_matching_diagnose_repair_test_serve_wait`; it uses a local live upstream and verifies the complete loop, including page 1 mocked and page 2 live.

## Command reference

All mock, scenario, config, integrity and domain plugin operations use an explicit `--domain`.

- `mock list`: filter by `--id`, `--method`, `--host`, `--path` (substring) or `--scenario`.
- `mock show|delete|enable|disable ID`; `mock create --file JSON` requires one new ID.
- `mock update ID --file PATCH`: merge metadata and matching, replace supplied request/response bodies, headers and conditions. ID cannot change.
- `mock matching ID --file RULE`: replace the matching rule; JSON null restores legacy matching. Enabling/disabling a legacy mock creates an exact endpoint rule.
- `mock copy|move ID --to-domain NAME`: copy gets a new ID; move keeps it.
- `mock import --file JSON`; `--format curl` parses supported cURL text as data. It never runs a shell or reads `@file` payloads. Unsupported flags, file payloads and unquoted shell operators are rejected. `--fetch` explicitly retrieves a live response; otherwise cURL import creates an empty response for editing.
- `mock export [ID] [--format json|curl] [--output PATH]`: native JSON bundle or cURL requests. Exported requests contain their original headers and bodies.
- `mock reload ID`: run the request reloader plugin, send the saved request upstream and return old/new models and changed fields. `--save` explicitly replaces the response while preserving matching and original request.
- `scenario list`; `scenario set --device-id ID --path PATH --scenario NAME [--method METHOD]`; `scenario clear --device-id ID`. These persist per domain and device; omitted method matches all methods.
- `config get|set --file JSON`; `config filters --file ARRAY`; `config reorder --order ID,ID,...` requires every filter once.
- `plugin list|get|set|delete --type TYPE [--common]`; set takes `--file JS`. Types are `requestReloader`, `liveRequestUpdater`, `mockError`, `mockDetailMessages`. Domain and common scripts follow the existing plugin merge order.
- `plugin settings --type TYPE [--file ARRAY]`: get/set `[{"key":"enabled","valueType":"bool","value":true}]` in domain storage. Types: text, number, bool, textArray, numberArray. Scripts expose their defaults with `config` and consume overrides via `setConfig`.
- `plugin run --type TYPE`: request plugins accept `--file` with `{url,method,headers,body}` or `--id`; mock detail uses `--id`; mock error uses `--message`. Mock detail returns synchronous and asynchronous results. Linux returns `unsupported_platform` for run.
- `requests list [--domain NAME --mock-id ID --outcome mock|live|error --since ISO8601]`.
- `logs|trace [--limit N --follow --file PATH]`: inspect or stream log entries. `analyze-usage` summarizes successfully served mocks, with `--logs-folder` for legacy usage analysis.
- `integrity check|fix`: report misplaced files, duplicate IDs, malformed/invalid files and reads exceeding 0.5 seconds. Fix repairs readable valid models and assigns new IDs to duplicate copies; malformed input stays reported for manual repair.

## Output and verification

Finite commands emit one `{"schemaVersion":1,"ok":true,"data":...}` JSON result. Failures exit nonzero and emit `{"schemaVersion":1,"ok":false,"error":{"code":"...","message":"..."}}`. `--human` prints readable success JSON and errors on stderr. Follow commands emit one envelope per line (JSONL). Operational logs go to stderr; they never mix with stdout results. Request records are atomic files under `.mockingstar/requests`; logs are in `.mockingstar/logs`, traces in `.mockingstar/trace.jsonl`.

```sh
swift test --package-path Core/MockingStarCore
swift test --package-path Core/CommonKit
swift test --package-path Core/Server
swift test --package-path Core/PluginCore
swift build --package-path MockingStarExecutable
python3 MockingStarExecutable/Tests/integration.py
xcodebuild test -workspace MockingStar.xcworkspace -scheme MockingStar -testPlan TestPlan -skipMacroValidation
```

CI runs macOS package and GUI tests plus the CLI black-box suite; Linux builds the CLI and runs the same suite with JavaScript tests skipped. Journals currently retain complete captured requests until their workspace records are removed; no retention limit is imposed.
