# Partial Mocking with Merlin

Use the same scenario logic for manual exploration in Mocking Star and automated UI testing in Merlin.

Read <doc:PartialMocking> for the concept and authoring recommendations, and <doc:Modifiers>
for Mocking Star's control API. This guide documents the shared contract and the differences
that matter when moving a modifier into a Merlin workspace.

## Why both tools have a modifier UI

Mocking Star and Merlin have separate mock servers and workspaces. A modifier created in
Mocking Star is not automatically available to Merlin's test runner. Sharing the JavaScript
contract lets us reuse the transformation logic, but files, domains, and sample mock references
still belong to their respective workspaces.

Without Merlin Studio's modifier editor, we could author in Mocking Star, copy the `.js`
file into Merlin, adapt its metadata/sample reference, and then run the flow. For repeated
authoring, that introduces manual synchronization and makes it easier to preview one version
while testing another. Studio allows authoring and previewing in the test's own workspace,
so the saved file is the definition the CLI loads for that test.

This removes the need to move a file for every edit. It does not create an automatic
synchronization service between the two tools. A deliberate transfer is still possible.

## Shared contract and important differences

| Area | Mocking Star | Merlin |
| --- | --- | --- |
| Executing server | Mocking Star server | Merlin CLI's in-process mock server during `merlin run` |
| Definition path | `<workspace>/Domains/<domain>/Modifiers/<id>.js` | `<modifiers_dir>/<domain>/<id>.js`, usually `contracts/modifiers/<domain>/<id>.js` |
| Function | Synchronous `transformer(req, chain)` | Synchronous `transformer(req, chain)` |
| JavaScript engine | JavaScriptCore on macOS | Goja in the Go CLI |
| Matching | Exact path, case-insensitive method, optional exact scenario | Same matching contract |
| Ordering | Ascending Order, then filename ID; response edits unwind in reverse | Same ordering contract |
| Source for app traffic | Per-device Off/Mock/Live controls or activation API | Flow `setup.modifiers[].source` |
| Editor Source | Also changes application activation; Off still allows Run using the last preview terminal | Preview only; Off disables Run and does not change flow activation |
| Preview composition | Unsaved draft plus other matching active modifiers in the device context | Current Studio handler executes one draft modifier by itself |
| Sample mock reference | Stored Mocking Star mock ID | Relative imported mock path under `mocks_dir` |
| Runtime base mock selection | Normal request matching; sample ID is a preview reference | Normal request matching; sample path is validated/used for preview, not a runtime selector |
| Strict source override | `disableLiveEnvironment=true` forces a matched chain to Mock | `miss_policy: fail` forces a matched chain to Mock even if a modifier requests Live |
| Device identity | Exact lowercase `deviceId`; never-configured named clients inherit the UI default | `X-Merlin-Device`; current CLI activation buckets do not inherit the default |
| Cleanup | Client-managed teardown; process restart loses active sets | Executor installs the flow's set and defers removal on success/failure |
| Linux | Shared chain compiles but does not execute transformers; preview unsupported | Goja execution is in the CLI; validate the target platform and application integration |

Do not infer identical behavior from identical control labels. In particular, a successful
single-modifier Studio preview does not prove that a multi-modifier flow has the intended
ordering or route matching.

Merlin's current Goja execution uses a five-second JavaScript execution budget, paused
while `chain.proceed` waits for the next link/terminal. This is separate from a flow's UI
timeouts or final presentation delay; do not assume the same budget exists in JavaScriptCore.

## File metadata and portability

Both tools read the common route metadata:

```javascript
// product-out-of-stock.js
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

The filename supplies ID `product-out-of-stock`. Activation and its runtime source are
not saved as `id`, `enabled`, or `source` bindings. Optional `previewCurl`, `previewSource`,
and `previewScenario` metadata restore editor requests; **previewSource is not activation**.

Use positive Order values starting at `1`. Older `priority` metadata is accepted as a fallback
when Order is absent, but new files should use Order. Zero/negative values are normalized;
do not use Order `0` to express a dependency. Helpers before the transformer declaration
can be excluded when executable source is extracted, so put helpers inside the function or
after its declaration. Avoid assuming browser/Node APIs are available in either engine.

When transferring a file:

1. Copy it into the target domain's modifier directory.
2. Confirm the original application's actual path and method; API gateway and direct-service
   paths may differ even when they reach the same backend service.
3. Review the scenario filter and Order relative to other target modifiers.
4. Replace `sampleMockRequestId` with the target workspace's reference if using Mock preview
   or a Merlin flow with `source: mock`.
5. Review the saved cURL, endpoint, headers, and preview source for the target environment.
6. Preview locally, then validate and run the complete flow. Preserve only engine features
   verified in both tools when sharing the script.

## Configure Merlin's mock server

Example project configuration in `contracts/merlin.yaml`:

```yaml
project:
  package: trendyol.com.stage
  shared_prefs_file: PREF.xml
  mock_server:
    port: 8008
    mocks_dir: mocks
    modifiers_dir: modifiers
    miss_policy: proxy

fixtures:
  verify_mock_routing: { kind: bridge }
  clear_mock_routing: { kind: bridge }
```

Use the application's actual package and preferences filename. The declared adapter
fixtures require compatible Android integration. `set_mock_scenario` and `set_shared_pref`
are CLI built-ins and must not be redeclared in the project fixture registry.

Paths are relative to `merlin.yaml` unless absolute. This layout resolves to:

```text
contracts/
  merlin.yaml
  modifiers/
    msearch/
      product-out-of-stock.js
  mocks/
    msearch/
      GET/
        default/
          products+42.json
```

If `modifiers_dir` is omitted, Merlin uses the `modifiers` sibling beside `mocks_dir`.
`miss_policy: proxy` allows unmatched traffic to fall through to the API.
`miss_policy: fail` exposes missing mocks and forces the base terminal of matched modifier
chains to stored mocks. Choosing Live in a flow does not override this strict policy.

The run starts Merlin's mock server and arranges the device port mapping. Mocking Star.app
is not required for Merlin flows. If both servers would bind port `8008`, stop the other
server or deliberately configure distinct ports consistently in the CLI and APK. The run's
bridge port, Studio UI port, and mock server port are separate settings.

### Import recorded mocks when needed

From the Android repository root:

```bash
merlin import-mocks \
  --from maestro/mockingstar/Domains \
  --to contracts/mocks \
  --domain msearch
```

This imports mock data; it is not automatic modifier-file synchronization. Review the
imported filenames and source domain. A modifier copied from Dev to msearch must use the
msearch sample reference in Merlin.

For the illustrative product fixture above, Merlin metadata would contain:

```javascript
var sampleMockRequestId = "msearch/GET/default/products+42.json";
```

That path is relative to `mocks_dir`, not to the modifier file. It is an example reference:
create/import the actual mock before selecting Mock. Do not paste a Mocking Star UUID into
this field and expect it to identify an imported Merlin mock.

## Author in Merlin Studio

From a configured project directory, run:

```bash
merlin studio --config contracts/merlin.yaml --port 9879
```

Open `http://127.0.0.1:9879/modifiers/` and select the required domain.

1. **Create from a mock** to populate domain, path, method, and sample reference, or use
   the creation form/cURL import for a new request.
2. **Edit JavaScript** and populate Preview Request. Use Mock for a selected recorded response
   or Live for the current API response with the required authentication/headers.
3. **Run** and compare Original/Transformed. The current Studio preview evaluates one draft
   modifier; use a flow to verify chain composition.
4. **Save** the definition and preview metadata into the test workspace.
5. **Select the modifier in the flow** with its ID and runtime source. Preview source does not
   enable a modifier for the application.

The navigation tree can be collapsed to provide more editor space. Response panes support
JSON folding, focused-pane `⌘F`/`Ctrl+F`, Edit in JavaScript, and Copy Object Notation.
Format updates the JavaScript draft; Save persists it. Field editing adds a selected field
assignment, rather than treating a multi-selection as an instruction to edit the whole body.

Off disables Run in Studio. Saving a file does not arm a flow. A Live preview can succeed
while a strict Mock flow fails because its recorded input or sample reference is missing.

## Select modifiers explicitly in a flow

The following is a **setup fragment**, not a standalone executable test. Add it to a flow
with actual navigation and assertions:

```yaml
setup:
  mock_server:
    domain: msearch
  modifiers:
    - id: product-out-of-stock
      source: mock
```

The corresponding definition is
`contracts/modifiers/msearch/product-out-of-stock.js`. The project must configure its mock
server. ID and source are required; `source` must be `mock` or `live`, and duplicate IDs
in the flow are rejected.

`merlin validate` checks the activation entries, loads modifier files, validates route
metadata, and, for Mock source, checks `sampleMockRequestId` and the referenced file.
It cannot prove that a future application request will match or that the UI shows the result.
At runtime, the source mock is selected by normal URL/method/domain/scenario matching, not
by the sample reference alone.

Use:

```bash
merlin validate --accounts .merlin/accounts.json path/to/flow.yaml

env ANDROID_SERIAL=emulator-5554 merlin run \
  --accounts .merlin/accounts.json \
  --culture TR \
  --retry 0 \
  --port 9877 \
  --verbose-mockserver \
  --output /tmp/partial-mock.xml \
  --output-html /tmp/partial-mock.html \
  --output-json /tmp/partial-mock.json \
  path/to/flow.yaml
```

Replace the flow path and device serial. Account references belong in the configured
accounts file, not in the flow or modifier. Use the CLI/APK versions that implement the
required bridge, mock routing, and modifier functionality.

## Chain, scenario, and mixed-route examples

Both response modifiers can use Live:

```yaml
setup:
  mock_server:
    domain: msearch
  modifiers:
    - id: SearchJfySlider
      source: live
    - id: DemoJfyScenarioHideFavorites
      source: live
  fixtures:
    - name: set_mock_scenario
      args:
        path: "/tmcdiscovery-msearch-mcwidgets-santral/tr-TR-1/search/widgets"
        method: GET
        domain: msearch
        scenario: demo_jfy_favorites_hidden
```

This is another setup fragment. Scenario selects the matching favorite-button modifier;
it does not select a stored response. A scenario-independent SearchJfySlider matches both
visible and hidden scenarios. Runtime source remains Live unless strict policy forces Mock.

For two matching modifiers, smaller Order is outermost; after `chain.proceed`, larger Order
edits the response first. Use explicit positive orders rather than relying on YAML list order
or filename ties. Review the metadata in each workspace: the bundled Mocking Star Dev example
uses insertion Order `2` and favorite-hiding Order `1`; a copied Merlin definition may differ.

Live is selected for a **matched route's chain**, not globally for every route in the test.
To mock another route, keep/import that route's recorded mock and select its domain/scenario
through the flow or a per-path fixture. Its own normal resolution still applies. The JFY
widget's absolute full-service products URL creates a separate request and can need login;
Live on search widgets does not force that products route to Live.

## Flow lifecycle and device compatibility

The executor installs `setup.modifiers` for the flow's device/domain, and uses deferred
cleanup to remove that set when the flow returns, including a failed run. A flow with an
empty list gets an explicit empty activation set so it does not inherit a prior flow's
modifiers. The server's activation state is process-local.

The inspected Android interceptor also checks the request host and seeded routing intent.
Flow defaults or a per-path scenario must resolve a routing selection; otherwise that
request proceeds directly to the backend. Only its allowed API hosts and stage-host suffix
are eligible. An absolute JFY URL is a separate route, but an arbitrary absolute URL is not
automatically routed through Merlin. Check the installed APK's host rules, original path,
and seeded domain/scenario when a request never reaches the mock server.

**Version-specific integration finding, checked on 8 November 2026:** the current inspected
CLI stores activations under the executor's device serial and routes modifier lookup using
`X-Merlin-Device`. Its activation book does not provide fallback from a named device to the
header-less default. The inspected Android `MerlinMockInterceptor` stamps original URL,
domain, and scenario, but does not stamp `X-Merlin-Device`. This can prevent a named-device
activation from matching that APK's request. A device-keyed CLI needs an APK that forwards
the corresponding device identity, or an explicitly compatible routing implementation.

The supplied presentation describes an earlier default-bucket workaround and states that
parallel Android isolation had not been verified. Do not assume that workaround exists in
the current code. Confirm identity propagation, modifier matching, failure cleanup, and
cross-device isolation using the exact released versions before relying on parallel runs.
This documentation records the compatibility gap; it does not change the Android/CLI code.

## Validate the presentation demonstrations

The shared demo documentation references these Android example flow filenames:

| Demonstration | Flow under `contracts/flows/msearch/regression/` |
| --- | --- |
| Insert JFY and assert products | `test_SearchResult_openElbiseWithSearchJfySliderModifier_ShowsJfySlider.yaml` |
| Chain and hide favorites | `test_SearchResult_openElbiseWithChainedModifiers_HidesJfyFavorites.yaml` |
| Switch matching scenario | `test_SearchResult_switchModifierScenario_TogglesJfyFavorites.yaml` |
| Rewrite Elbise to Pantolon | `test_SearchResult_openElbiseWithRequestModifier_ShowsPantolonProducts.yaml` |

These are project-specific examples, not files shipped with Merlin. The four YAML files were
not present in the inspected Android feature-branch tree for this documentation update; use
the demo workspace or create the flows before running these paths. The intended demos use an
authenticated account and a five-second wait after the final assertion for the presentation.
The earlier `WithTestModifier` filename is obsolete.

Validate each flow separately. To execute all four, pass their four paths to one `merlin run`;
the runner accepts multiple paths. Use independent report filenames when running them
individually. Inspect the verbose mock-server log for the actual route, domain, scenario,
matched IDs, and resulting status; pair this with UI assertions and the HTML report.

## Source references

Scylla's [Partial mocking with Merlin](https://gitlab.trendyol.com/mobile/mobile-all/android-all/platform-subgroup/scylla/-/blob/MSEARCH-7638/MerlinPartialMockingImpl/docs/partial-mocking.md)
provides the full user workflow, examples and commands. Its
[runtime guarantees](https://gitlab.trendyol.com/mobile/mobile-all/android-all/platform-subgroup/scylla/-/blob/MSEARCH-7638/MerlinPartialMockingImpl/docs/partial-mocking-runtime.md)
describe Goja conversion and execution limits. These links target the implementation branch;
use documentation matching your installed release.

Behavior in this guide was checked against these implementation files on 8 November 2026:

- Mocking Star: `ModifierMatcher.swift`, `ModifierParser.swift`, `ModifierExecutor.swift`,
  `ModifierGateway.swift`, `ModifierPreviewService.swift`, and `ModifierActivationStore.swift`.
- Merlin CLI: `cli/internal/modifier/{model,parser,matcher,engine}.go`,
  `cli/internal/mockserver/{handler,server,activations}.go`, `cli/internal/flow/modifiers.go`,
  `cli/internal/flow/executor.go`, `cli/cmd/validate_modifiers.go`, and
  `cli/internal/yaml/project_config.go`.
- Merlin Studio: `studio/components/modifiers/modifier-editor.tsx`, `response-diff.tsx`, and
  `cli/internal/studio/handlers/modifiers.go`.
- Android integration: `MerlinMockInterceptor.kt` and `MerlinMockRoutingStore.kt` under
  `common/event-test-framework/src/main/java/com/trendyol/common/eventtesting/mock/`.

Use the source and documentation shipped with your installed versions when behavior changes.
