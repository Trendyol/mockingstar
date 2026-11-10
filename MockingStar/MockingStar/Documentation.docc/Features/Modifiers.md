# Modifiers

Modifiers let you edit requests before they reach a source and transform stored or live
HTTP responses with synchronous JavaScript `transformer(req, chain)` functions.

For an introduction to partial mocking and a step-by-step macOS walkthrough, see <doc:PartialMocking>.
For Merlin Studio and automated-flow integration, see <doc:PartialMocking-Merlin>.

## Definition format and metadata

Definitions live at `<workspace>/Domains/<domain>/Modifiers/<id>.js`. For example:

```javascript
// Domains/Dev/Modifiers/product-out-of-stock.js
var path = "/products/42";
var method = "GET";
var scenario = null;
var order = 1;
var sampleMockRequestId = null;

function transformer(req, chain) {
  var res = chain.proceed(req);
  res.body.stock = 0;
  return res;
}
```

| Field | Meaning |
| --- | --- |
| Filename `<id>.js` | Identity used by activation, API calls, and copying. |
| `path` | Original request's exact path, including a gateway prefix if present. |
| `method` | HTTP method, matched case-insensitively. |
| `scenario` | Optional exact scenario filter; empty/`null` matches all request scenarios. |
| `order` | Positive chain order. Default is `1`; smaller is outermost. |
| `sampleMockRequestId` | Stored Mocking Star mock ID used by Mock preview, not by runtime request matching. |
| `previewCurl` | Optional saved editor URL, method, headers, and body encoded as a cURL command. |
| `previewSource` | Optional saved Mock/Live editor terminal; not runtime activation. |
| `previewScenario` | Optional saved editor scenario, including intentionally empty values. |
| `transformer` | Synchronous function returning the final response object. |

Keep the transformer declaration at a line boundary. Metadata is evaluated while loading
the file; executable transformer source is extracted from the declaration onward. Helpers
before that declaration can be lost during execution. Put helpers inside the function or
after the declaration. The tools do not install browser or Node.js modules for scripts.

## Identity and ordering

- Modifier ID is the `.js` filename without extension (for example `discount.js` → `discount`).
- JavaScript files no longer persist `id`, `enabled`, or `priority`.
- Use ascending `order` starting at `1`. Lower order runs first (outermost).

Legacy `priority` is accepted as a fallback when `order` is absent; serialization writes
Order. Nonpositive Order values are normalized to `1`, so do not use `0` as a sequencing
mechanism. Equal orders are sorted by filename ID, not activation-list position.

IDs are single filenames, not directory paths. Use a descriptive scenario name and avoid
path separators or traversal-like IDs. Renaming changes that identity; see Save and rename.

## Matching and chain execution

Only active modifiers in the request's domain/device context are considered. They match
the original path, method, and optional scenario, then are sorted by Order and ID.
Modifier path matching is exact; a fuzzy mock matching configuration does not make a
modifier's path fuzzy. The query is not part of the path matcher. Check `req.url` inside
the function if the transformation should apply only to a specific query.

An absolute full-service URL still has a path and method and can be intercepted normally.
The API gateway prefix is part of that path. `/search/widgets` and
`/tmcdiscovery-msearch-mcwidgets-santral/tr-TR-1/search/widgets` are different modifier paths.

For A with Order `1` and B with Order `2`:

```text
A: edit request -> B: edit request -> terminal
A: edit response <- B: edit response <- terminal response
```

After `chain.proceed(req)`, B changes the response first and A last. The activation API
array order does not define execution order. Changing `req.url` or `req.method` inside
the chain does not rematch the modifier list or reselect its source.

### JavaScript request and response contract

| Object field | Representation and use |
| --- | --- |
| `req.url` | Full URL string. Assign an updated URL before proceeding. |
| `req.method` | HTTP method string. |
| `req.headers` | Request header dictionary with string values. |
| `req.body` | UTF-8 text string; use `JSON.parse`/`JSON.stringify` for a JSON request. |
| `res.status` | HTTP status code. |
| `res.headers` | Response header dictionary with string values. |
| `res.body` | Parsed JSON object/array/value when the response is JSON; otherwise text. |

Return `res` after modifying it. The engine serializes the result back into an HTTP body;
untouched field values are preserved, but JSON formatting/key order need not be identical.
This is a JSON/text transformation interface, not a general binary-body editing API.

Use `chain.proceed(req)` synchronously to call the next modifier or terminal. Keep normal
partial transformations to one proceed call. Do not add `async`, `await`, a Promise return,
or call an external API from browser/Node-only helpers.

A transformer can also return a generated response without calling the source:

```javascript
function transformer(req, chain) {
  return {
    status: 200,
    headers: { "Content-Type": "application/json" },
    body: { products: [] }
  };
}
```

This is a complete response stub rather than a partial edit of an existing body. Preview
then has no original terminal response to compare. Supply a valid response object; syntax
errors, exceptions, or invalid return values fail the executing chain.

## Device isolation

Activation is ephemeral and scoped by `(domain, deviceId)`:

Each activation entry carries a per-modifier `source` (`mock` or `live`) that decides whether the
wrapped terminal reads the stored mock or the live server:

```bash
# Activate modifiers for a device (default domain Dev when omitted)
curl -X PUT "http://localhost:8008/modifiers?domain=Dev" \
  -H "Content-Type: application/json" \
  -H "deviceId: maestro-device-1" \
  -d '[{"id":"discount","source":"mock"},{"id":"latency","source":"live"}]'

# Clear active modifiers for that device
curl -X PUT "http://localhost:8008/modifiers?domain=Dev" \
  -H "Content-Type: application/json" \
  -H "deviceId: maestro-device-1" \
  -d '[]'
```

Missing `deviceId` targets the default instance (same as `/mock` when the header is omitted).
The macOS modifiers list and detail **Off / Mock / Live** controls write that default (`""`) set. Mock and Live also choose the preview terminal.

Only the exact header/flag name `deviceId` (Maestro) is used for activation. Android advertising’s
`DeviceId` is ignored so app traffic stays on the UI default set.

Clients that send an explicit `deviceId` inherit the default set **until** that device receives an
explicit `PUT /modifiers` (including `[]`, which clears inheritance for that device). Maestro shards that
manage their own set are unchanged.

**Terminal selection:** For a matched chain the terminal is chosen from the matched modifiers' sources.
If **any** matched modifier requested `live`, the chain terminal is **live**. If **all** matched modifiers
requested `mock`, the terminal reads the **stored mock**. `disableLiveEnvironment=true` (`onlyMock`) is a
safety flag that always forces the mock terminal and never contacts live, overriding a `live` source.

Activation state is lost when the MockingStar process restarts.

`PUT /modifiers` **replaces the entire set** for that domain/device; it does not append.
Send all IDs that should remain active. An unknown or duplicated ID rejects the update.
Definition files remain on disk after clearing activation. Use a unique lowercase `deviceId`
for parallel clients and explicitly install/clear their sets; do not rely on the UI default
as isolation between independent test devices.

Scenario selection is independent: `scenario` can come from the request flag/header or
scenario registrations. An empty modifier scenario matches any selected scenario. A named
scenario does not automatically force a stored mock; source selection still follows the
matched modifiers and strict override.

## Runtime behavior

1. `/mock` remains the only ingress.
2. If the device has no matching active modifiers, existing mock-first / live-fallback behavior is unchanged.
3. If matching active modifiers exist, the chain terminal is `live` when at least one matched modifier requested `live`, otherwise the stored mock (all matched `mock`).
4. If the request sends `disableLiveEnvironment=true`, that safety flag wins and the chain receives the stored mock terminal instead of contacting live, regardless of the per-modifier source.
5. A transformer may return a response without calling `chain.proceed(req)`.

| Matched runtime chain | Terminal |
| --- | --- |
| All matched activations request Mock | Stored mock only; a missing mock fails rather than silently calling live. |
| At least one matched activation requests Live | Live, unless `disableLiveEnvironment=true`. |
| `disableLiveEnvironment=true` | Stored mock terminal regardless of matched Live activations. |
| No matching active modifier | Existing normal mock-first/live-fallback routing, including its configured flags and filters. |

The source choice belongs to the matched route's chain. Other requests in the same screen,
such as JFY products, images, or another endpoint, retain their own normal resolution.
The terminal resolves a request rewritten by a modifier; no new matching modifier chain
is built for the changed URL. Transforms do not rewrite the stored base mock file.

On an executing runtime chain, an execution error is logged and returned as HTTP `500`.
There is no successful unmodified-response fallback for an executing JavaScript failure.
Inspect logs for `modifier chain`, matched IDs, terminal, execution mode, and failure details.

### Supported platforms

The macOS implementation uses JavaScriptCore. The Linux chain is currently a no-op that
calls the terminal without running transformers, and Linux preview returns unsupported
execution feedback. A successful Linux build does not demonstrate modifier execution.
Merlin uses Goja independently; see <doc:PartialMocking-Merlin> for compatibility details.

## Detail editor

The modifier detail screen uses a horizontal split:

- **Left:** Response pane (status, headers, body). Larger by default; body is read-only.
- **Right:** JavaScript editor with **Run**, plus Metadata and Preview Request forms.

Drag the divider to resize the panes. Metadata and Preview Request are scrollable form
sections. TipKit onboarding explains the response pane, JavaScript, and request settings.
The response body is read-only; its context actions generate code in the editable JavaScript pane.

### Find, navigate, and format

- Focus Original or Modified and use `⌘F` to find text in that pane. Each side has its own search.
- Use supported JSON folding to navigate large bodies. Diff highlighting shows changed lines;
  it does not mean every response field is an editable link.
- Right-click a response key/value and choose **Edit in JavaScript**. The clicked location
  resolves one field and inserts its assignment into the JavaScript draft. A multi-selection
  is not promoted into editing the entire response.
- Choose **Format** in JavaScript, or invoke Monaco's `⇧⌥F` action with focus in that editor.
  Formatting preserves editor undo behavior and changes the draft, not the saved file.
- **Run** uses `⌘Return`; **Save** uses `⌘S`. From the list, `⌘F` focuses search and `⌘R` refreshes.

Success notifications are green. Errors are red and can also appear as field validation or
an error dialog. If formatting or preview fails, correct the reported error and run again.

### Run (preview)

**Run** (`⌘↩`) evaluates the current unsaved draft directly in the macOS app. It does **not** write the `.js` file. API clients can run the same preview through `POST /modifiers/preview`.

**Save** stores the preview URL, method, headers and body as `previewCurl` in the modifier's `.js` file, with `previewSource` and `previewScenario` alongside it. Reopening restores this request, including an intentionally empty scenario. Saved file metadata takes precedence over a creation seed or an older local `UserDefaults` entry. Existing modifiers without preview metadata can still use their local preview settings; the next Save makes those settings portable. The preview response remains ephemeral.

**Source** (Off / Mock / Live) is the same device activation as the modifiers list. Mock and Live turn the modifier on for `/mock` traffic and select the preview terminal. Off removes it from the activation set; Run still uses the last Mock or Live terminal.

**Preview chain versus runtime chain:** preview substitutes the draft for `currentModifierId`
and includes the other matching active modifiers in that device context. Its terminal is
selected by the preview request's `source`, not by aggregating those activations' sources.
Runtime aggregates the matched activation sources as described above. A preview is therefore
evidence for that draft, source, and device context, not proof that every application route
will see the same result.

When preview settings or JavaScript change after a successful run, the editor marks the
output **Stale**. If the transformer never called the terminal, it shows **No original**.

### Mock and Live sources

| Source | Terminal | `sampleMockRequestId` |
| --- | --- | --- |
| `mock` | Loads the **exact** stored mock file whose id equals `sampleMockRequestId` (matched with the preview URL/method/scenario). Never contacts live. | Required and non-empty |
| `live` | Sends one live HTTP request through the configured live terminal. Does not create or update a mock file. | Optional (unused for the terminal) |

`sampleMockRequestId` is an optional string on the modifier definition. It is a UI/preview reference to a mock id — it does not change `/mock` matching by itself. When source is `mock`, the server loads that id via the stored-mock loader; a missing or unknown id fails the preview.

Mock preview uses the original preview URL/method/scenario plus the selected sample ID,
even when JavaScript edits the request before proceeding. Live preview sends the request
that reaches the terminal after those edits. Verify request rewrites with Live or actual
runtime traffic rather than expecting Mock preview to choose a different sample automatically.

The response toolbar's **Copy** copies the output body; **Copy cURL** copies the current
preview URL/method/headers/body without running or saving. Saved cURL uses literal values,
including pasted authentication headers. Review shared definitions for environment-specific
or sensitive values; preview persistence is not credential storage or automatic token renewal.

### Copy Object Notation

After running a JSON preview, **Copy Object Notation** in the response toolbar copies the
transformed response structure with `int`, `double`, `string`, `bool`, and `null` type names.
Objects in the same array are merged recursively into one shape: fields missing from some
objects are marked optional, and scalar types are joined with `|`.

For example, `[{"a":1},{"a":null,"b":"x"}]` becomes
`[{"a":"int|null","b":"string (optional)"}]`.
Optional object/array fields use `{"$optional": ...}` to retain their structure.
Fields containing both containers and scalars use `{"$types": [...]}`.
These describe the observed preview response, rather than a complete API contract.

An empty array contains no item-type evidence. Absent fields and unobserved variants cannot
be inferred from one response. Use the endpoint's actual contract for exhaustive validation.
The notation action requires a current JSON preview; it does not manufacture a schema from
an absent/non-JSON output. Click a specific object to avoid copying an unrelated array item.

To copy only the part you need, right-click a field in the transformed response and choose
**Copy Object Notation**. A scalar field selects its nearest enclosing object; an object key
selects that object. The clipboard includes its JavaScript path, followed by its notation:

```text
Path: res.body.widgets[1]
{"name":"string","products":[{"id":"int|null","label":"string (optional)"}]}
```

### Save and rename

**Save** persists metadata, transformer code and the Preview Request. Preview edits show the unsaved indicator. Modifiers without a preview URL can still be saved; a nonempty preview URL must be HTTP(S), with headers represented as a JSON string dictionary. If the draft `id` differs from the path `{id}`, the update is a rename:

- The file is rewritten as `{newId}.js` and `{oldId}.js` is removed.
- Every device activation set that contained the old id is updated to the new id (all devices for that domain).
- If the target id already exists, the server returns `409` and leaves the old file, route, and activation sets unchanged.

### Mock List → Create Modifier

From Mock List, right-click a single mock and choose **Create Modifier**:

1. The create sheet is prefilled from the mock (path, method, scenario, `sampleMockRequestId`).
2. Create writes the new `.js` file; the modifier starts **inactive** (`enabled` is not persisted; it is not added to any device activation set).
3. Detail opens with the creation seed so **Preview Request** defaults to Mock source and the mock’s URL/headers/body.

### Create Modifier → Import cURL

1. Open **New Modifier**, choose **Import cURL**, and paste a request.
2. Choose **Fill fields from cURL** to fill Path, Method and a suggested ID. Existing manual ID and Order values are preserved. `X-Merlin-Scenario` or `scenario` headers also populate Scenario. The selected domain remains unchanged.
3. Review the fields and choose **Create**. The full request is saved as cURL and restored in Preview Request. The new modifier stays inactive until activated; imports without a matching sample mock use the Live preview terminal.

Imports read literal request values without executing the command or reading local files. Escaped quotes, multiline commands, JSON bodies and common browser cURL flags are supported. Copy cURL uses literal `--data-raw` bodies, so values beginning with `@` are not treated as files. **Duplicate** and modifier copy/paste carry saved preview metadata to the new file.

The parser supports common flags including `-X`/`--request`, `-H`/`--header`, `--url`,
`-d`/`--data`, `--data-raw`, inline `--data-binary`/`--data-ascii`, `--json`, `-G`/`--get`,
`-I`/`--head`, inline `-u`/`--user`, cookie, user-agent, and referer values. Browser transport
flags such as `--compressed`, `-L`, `--http1.1`, and `--http2` can be parsed without becoming
saved request fields or guarantees about the preview HTTP client's transport settings.

File-based body/header inputs, shell command substitution, shell pipelines, malformed
quotes, unsupported options, and multiple request URLs are rejected. Paste literal values
and an inline body. Importing does not execute a shell command or fetch the response.

### List management and reuse

The list uses the same rich search layout as Mock List. Filter by All, Path, Scenario, or
Method and choose the search style from the control. Refresh reloads the definitions for
the selected domain. Duplicate creates a new identity/Order and preserves preview metadata;
review those fields before enabling it. Copy/paste carries definition data, not the source
device's active set. Deleting removes the definition and its ID from activation sets.

## CRUD examples

```bash
# Create
curl -X POST "http://localhost:8008/modifiers?domain=Dev" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "discount",
    "path": "/cart",
    "method": "GET",
    "order": 1,
    "transformerCode": "function transformer(req, chain) { var res = chain.proceed(req); res.body.discount = true; return res; }"
  }'

# List (enabled + source reflect the calling deviceId's activation set)
curl "http://localhost:8008/modifiers?domain=Dev" -H "deviceId: maestro-device-1"

# Update definition
curl -X PUT "http://localhost:8008/modifiers/discount?domain=Dev" \
  -H "Content-Type: application/json" \
  -d '{
    "path": "/cart",
    "method": "GET",
    "order": 1,
    "transformerCode": "function transformer(req, chain) { return chain.proceed(req); }"
  }'

# Rename (body id differs from path id; preserves all device activation sets)
curl -X PUT "http://localhost:8008/modifiers/discount?domain=Dev" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "discount-v2",
    "path": "/cart",
    "method": "GET",
    "order": 1,
    "sampleMockRequestId": "mock-123",
    "transformerCode": "function transformer(req, chain) { return chain.proceed(req); }"
  }'

# Delete
curl -X DELETE "http://localhost:8008/modifiers/discount?domain=Dev"
```

## Preview API

`POST /modifiers/preview` evaluates an unsaved draft in the context of the calling device’s active modifiers (substituting the draft for `currentModifierId`). HTTP `200` means the preview ran; the transformed HTTP status is in the JSON `status` field.

```bash
curl -X POST "http://localhost:8008/modifiers/preview?domain=Dev" \
  -H "Content-Type: application/json" \
  -H "deviceId: maestro-device-1" \
  -d '{
    "currentModifierId": "discount",
    "modifier": {
      "id": "discount-v2",
      "path": "/cart",
      "method": "GET",
      "scenario": "checkout",
      "order": 1,
      "sampleMockRequestId": "mock-123",
      "transformerCode": "function transformer(req, chain) { return chain.proceed(req) }"
    },
    "request": {
      "url": "https://example.com/cart",
      "method": "GET",
      "scenario": "checkout",
      "headers": { "Accept": "application/json" },
      "bodyBase64": ""
    },
    "source": "mock"
  }'
```

Example success body:

```json
{
  "status": 200,
  "headers": { "Content-Type": "application/json" },
  "bodyBase64": "eyJvaCI6MX0=",
  "originalStatus": 200,
  "originalHeaders": { "Content-Type": "application/json" },
  "originalBodyBase64": "eyJvaCI6MX0="
}
```

`bodyBase64` is the transformed body. The optional original fields contain the first terminal
response captured before response transformations; they are absent for a generated response
that never reaches the terminal. HTTP `200` from the preview API means execution completed,
not that the wrapped `status` is necessarily `200` or that UI assertions have passed.

### Preview error statuses

Errors return `MockModifierAPIErrorResponse` (`code` + `message`):

| Status | `code` | Typical cause |
| --- | --- | --- |
| `400` | `invalid_request` | Invalid payload, Base64, order, match failure, or missing sample mock id for Mock source |
| `404` | `not_found` | `currentModifierId` or sample mock not found |
| `409` | `conflict` | Draft id rename target already exists |
| `422` | `execution_failed` | Transformer threw or chain execution failed |
| `502` | `live_proxy_failed` | Live terminal request failed |

Running a preview does not write the draft or preview output. Create and Save write definition fields, including `sampleMockRequestId` and the optional preview metadata, to disk. Preview metadata never changes device activation or runtime request matching.

## Maestro / UI-test setup

Use the HTTP control plane before launching the app under test:

1. Start MockingStar (`./MockingStar start -p 8008 /path/to/mocks`).
2. Create/update modifiers once in the workspace.
3. For each parallel device/shard, set a unique `deviceId` and `PUT /modifiers` with the IDs that shard needs.
4. Route app requests through `/mock` with the exact same lowercase `deviceId` as the control calls. Android advertising `DeviceId` is not an activation identity.
5. Tear down with `PUT /modifiers` and `[]` for that `deviceId`.

Run teardown in a finally/deferred cleanup path so failed assertions do not leave a client
set enabled. Clear scenario registrations when the test installed them; deleting scenarios
for a device clears that device's registrations in the domain, not just one path.

### HTTP control-plane reference

With the server running on its default port, open `http://localhost:8008/docs` for Swagger
UI and `http://localhost:8008/openapi.yaml` for the OpenAPI description. The registered
`/docs` route redirects to `/docs/index.html`. The modifier control endpoints are:

| Endpoint | Purpose | Success status |
| --- | --- | --- |
| `GET /modifiers?domain=Dev` | List definitions with source/enabled for the calling device context | `200` |
| `GET /modifiers/{id}?domain=Dev` | Get a definition in that device context | `200` |
| `POST /modifiers?domain=Dev` | Create a definition; body must include ID | `201` |
| `PUT /modifiers/{id}?domain=Dev` | Update a definition, or rename using body ID | `202` |
| `DELETE /modifiers/{id}?domain=Dev` | Delete definition and clean activation references | `202` |
| `PUT /modifiers?domain=Dev` | Replace the calling device's complete `{id, source}` activation array | `202` |
| `POST /modifiers/preview?domain=Dev` | Evaluate an existing definition's unsaved draft in preview | `200` with wrapped result |

CRUD payloads are definition writes; they do not persist runtime source/enabled state.
The full-set activation payload is an array of objects, not a legacy string array:
`[{"id":"product-out-of-stock","source":"mock"}]`. Use `[]` to clear it.
Malformed payloads/invalid or unknown IDs return `400`; duplicate definitions or rename
conflicts return `409`; missing definitions return `404`. Preview errors include the
structured `code`/`message` body described above. Do not assume every CRUD error uses that body.

## Implementation references

The behavior described here was checked on 8 November 2026 against the shared models and
matcher in CommonKit, the parser/bridge/executor/chain/store in PluginCore, the modifier
gateway/activation/preview services in MockingStarCore, `Server/Routes/HandleModifier.swift`,
and the list/create/detail/response views in Features/Modifiers. The Linux limitation is
explicit in `PluginCoreLinux/Modifier/ModifierChain.swift`.

For motivation, historical size findings, and the rollout proposal, see <doc:PartialMocking>.
For Studio/flow differences and the current device-routing compatibility finding, see
<doc:PartialMocking-Merlin>.
