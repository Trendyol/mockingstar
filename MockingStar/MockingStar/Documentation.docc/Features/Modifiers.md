# Modifiers

Modifiers let you transform mock or live HTTP responses with JavaScript `transformer(req, chain)` functions.

## Identity and ordering

- Modifier ID is the `.js` filename without extension (for example `discount.js` → `discount`).
- JavaScript files no longer persist `id`, `enabled`, or `priority`.
- Use ascending `order` starting at `1`. Lower order runs first (outermost).

## Device isolation

Activation is ephemeral and scoped by `(domain, deviceId)`:

```bash
# Activate modifiers for a device (default domain Dev when omitted)
curl -X PUT "http://localhost:8008/modifiers?domain=Dev" \
  -H "Content-Type: application/json" \
  -H "deviceId: maestro-device-1" \
  -d '["discount","latency"]'

# Clear active modifiers for that device
curl -X PUT "http://localhost:8008/modifiers?domain=Dev" \
  -H "Content-Type: application/json" \
  -H "deviceId: maestro-device-1" \
  -d '[]'
```

Missing `deviceId` targets the default instance (same as `/mock` when the header is omitted).
The macOS UI Active toggle writes that default (`""`) set.

Only the exact header/flag name `deviceId` (Maestro) is used for activation. Android advertising’s
`DeviceId` is ignored so app traffic stays on the UI default set.

Clients that send an explicit `deviceId` inherit the default set **until** that device receives an
explicit `PUT /modifiers` (including `[]`, which clears inheritance for that device). Maestro shards that
manage their own set are unchanged.

**Important:** When a modifier matches and the request does **not** send `disableLiveEnvironment=true`,
the chain terminal is **live**, not the stored mock. Preview with Mock source is a different path —
to exercise modifiers against a mock over `/mock`, send `disableLiveEnvironment: true`.

Activation state is lost when the MockingStar process restarts.

## Runtime behavior

1. `/mock` remains the only ingress.
2. If the device has no matching active modifiers, existing mock-first / live-fallback behavior is unchanged.
3. If matching active modifiers exist, they wrap a **live** terminal by default.
4. If the request sends `disableLiveEnvironment=true`, that safety flag wins and the chain receives the stored mock terminal instead of contacting live.
5. A transformer may return a response without calling `chain.proceed(req)`.

## Detail editor

The modifier detail screen uses a horizontal split:

- **Left:** Response pane (status, headers, body). Larger by default; body is read-only.
- **Right:** JavaScript editor with **Ask Claude** and **Run**, plus Metadata and Preview Request forms.

### Ask Claude

**Ask Claude** opens a sheet where you paste a Trendyol GenAI Gateway (MLP) API key (stored in `UserDefaults` under `modifierGenAIGatewayAPIKey` — avoids Keychain permission prompts) and describe the desired transformer change. MockingStar calls the OpenAI-compatible Chat Completions API (`https://mlplatform.gcp.trendyol.com/piper/genai/chat/completions`, `Authorization: Bearer`, model `gemini-3.5-flash`) with metadata, the current JS, and a **schema-only** summary of the latest preview JSON (types/structure, no real values, to reduce tokens), then replaces the right-hand editor with the returned `function transformer(req, chain) { ... }`. The change stays unsaved until you press **Save**; it does not auto-Run.

### Run (preview)

**Run** (`⌘↩`) calls `POST /modifiers/preview` with the current unsaved draft. It does **not** write the `.js` file and does **not** change any device activation set.

Preview request fields (URL, method, scenario, headers, body, source) and the preview response are **ephemeral**. They are not written to disk. The only preview-related field persisted on the modifier definition is `sampleMockRequestId`.

### Mock and Live sources

| Source | Terminal | `sampleMockRequestId` |
| --- | --- | --- |
| `mock` | Loads the **exact** stored mock file whose id equals `sampleMockRequestId` (matched with the preview URL/method/scenario). Never contacts live. | Required and non-empty |
| `live` | Sends one live HTTP request through the configured live terminal. Does not create or update a mock file. | Optional (unused for the terminal) |

`sampleMockRequestId` is an optional string on the modifier definition. It is a UI/preview reference to a mock id — it does not change `/mock` matching by itself. When source is `mock`, the server loads that id via the stored-mock loader; a missing or unknown id fails the preview.

### Save and rename

**Save** persists metadata + transformer code. If the draft `id` differs from the path `{id}`, the update is a rename:

- The file is rewritten as `{newId}.js` and `{oldId}.js` is removed.
- Every device activation set that contained the old id is updated to the new id (all devices for that domain).
- If the target id already exists, the server returns `409` and leaves the old file, route, and activation sets unchanged.

### Mock List → Create Modifier

From Mock List, right-click a single mock and choose **Create Modifier**:

1. The create sheet is prefilled from the mock (path, method, scenario, `sampleMockRequestId`).
2. Create writes the new `.js` file; the modifier starts **inactive** (`enabled` is not persisted; it is not added to any device activation set).
3. Detail opens with the creation seed so **Preview Request** defaults to Mock source and the mock’s URL/headers/body.

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

# List (enabled reflects the calling deviceId)
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
  "bodyBase64": "eyJvaCI6MX0="
}
```

### Preview error statuses

Errors return `ModifierAPIErrorResponse` (`code` + `message`):

| Status | `code` | Typical cause |
| --- | --- | --- |
| `400` | `invalid_request` | Invalid payload, Base64, order, match failure, or missing sample mock id for Mock source |
| `404` | `not_found` | `currentModifierId` or sample mock not found |
| `409` | `conflict` | Draft id rename target already exists |
| `422` | `execution_failed` | Transformer threw or chain execution failed |
| `502` | `live_proxy_failed` | Live terminal request failed |

Preview does not persist the draft, the preview request, or the preview output. Only saving the modifier writes definition fields (including `sampleMockRequestId`) to disk.

## Maestro / UI-test setup

Use the HTTP control plane before launching the app under test:

1. Start MockingStar (`./MockingStar start -p 8008 /path/to/mocks`).
2. Create/update modifiers once in the workspace.
3. For each parallel device/shard, set a unique `deviceId` and `PUT /modifiers` with the IDs that shard needs.
4. Launch the app with the same `DeviceID` / `deviceId` header behavior your client already uses for `/mock`.
5. Tear down with `PUT /modifiers` and `[]` for that `deviceId`.
