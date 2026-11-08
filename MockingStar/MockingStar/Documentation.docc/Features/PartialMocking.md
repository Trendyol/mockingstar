# Partial Mocking

Control the request or selected response fields that define a test scenario, while reusing a stored response or the current API response.

This guide covers the motivation, design, authoring workflow, runtime rules, limitations,
demonstration cases, and adoption considerations presented in **Partial Mock · Merlin &
Mocking Star**. Use <doc:Modifiers> for the API and editor reference, and
<doc:PartialMocking-Merlin> for the differences between the two tools and Merlin flow setup.

## What is a partial mock?

A partial mock starts with an existing response and changes only the fields your test needs.
For example, you can keep a product's name, price, and images while setting its stock to zero
to test an out-of-stock screen. The other fields retain the values from the response source.

Mocking Star implements partial mocking through **Modifiers**: small JavaScript functions
that transform a stored mock or a live API response before your application receives it.
This is useful for testing empty lists, unavailable products, missing optional fields, or
different account states without maintaining a separate full response for every variation.

Choose a stored **Mock** when you need repeatable input. Choose **Live** when you want to
change selected fields in the API's current response; the unchanged fields can vary between runs.

## Why we introduced partial mocking

A test often needs a state that is difficult to obtain from real backend data: an out-of-stock
product, an empty list, an absent optional field, a specific widget, or a particular account
state. Waiting for that state slows test preparation. Saving a complete JSON fixture for
each small variation makes the scenario harder to read and creates repeated data to maintain.

A recorded response represents the API at the moment it was captured. If the API evolves,
that file does not update itself. Teams can spend time bringing old fixtures back into line
with the application instead of adding new regression coverage. Partial mocking lets us
keep the scenario's intended difference explicit and choose where the remaining data comes from.

For example, a full-fixture approach might maintain:

```text
product.json
product-no-stock.json
product-no-images.json
```

With partial mocking, the same variations can use:

```text
product.json
no-stock.js
no-images.js
```

These filenames illustrate the maintenance model; they are not installed sample files.
When the base response changes, update it and review modifiers that depend on changed fields.
With Live, the base response comes from the API on every call, but a modifier still needs
maintenance if its target field or business meaning changes.

### Design decisions and their purpose

| Decision | Purpose |
| --- | --- |
| Express the scenario difference in a small JavaScript function | Reduce repeated full-response data and make the test condition visible in review. |
| Support both Mock and Live terminals | Choose between a controlled recorded input and the API's current response. |
| Use `transformer(req, chain)` in both Mocking Star and Merlin | Reuse scenario logic during manual exploration and automated UI testing. |
| Identify modifiers by filename and select them explicitly | Make each test's data dependencies discoverable and allow reuse across flows. |
| Keep activation separate from saved definitions | Saving reusable code does not implicitly enable it for application traffic. |
| Scope activation to domain and device context | Let clients manage their intended modifier sets independently. Integration must forward the correct device identity. |
| Surface execution failures | A broken transformer must not silently appear to succeed against an unmodified response. |

The intended benefits are less data duplication, clearer scenarios, shared manual/automation
logic, and easier access to edge cases. Improvements in preparation time and test stability
must be measured; the feature does not by itself eliminate every cause of flaky tests.

## Before you start

Start Mocking Star, select your mock domain, and route your application's requests through it.
See <doc:GettingStarted> for client integration. For this walkthrough, capture or import a
stored response for `GET /products/42`; see <doc:MockImport> for importing a request.

The examples use `https://api.example.com/products/42` as a placeholder. Use your own API URL
and a response with the following fields:

```json
{
  "id": 42,
  "name": "Travel mug",
  "price": 19.99,
  "stock": 12,
  "images": ["https://example.com/mug.jpg"]
}
```

For live requests, supply the endpoint's required headers and authentication. Personalized
endpoints can return an empty result without a logged-in session. Browser cURL import is a
convenient way to populate the request; saved cURL metadata includes its literal headers and
body, so review those values before sharing the modifier file.

## Create your first partial mock

### 1. Create a modifier from a stored mock

In **Mock List**, right-click the product request and choose **Create Modifier**.
Set the ID to `product-out-of-stock`, keep the prefilled path and method, and set **Order** to `1`.
Keep the prefilled scenario if you want this modifier to apply only to that scenario;
leave it empty to match any scenario for the same path and method. Click **Create**.

The detail screen opens with the request URL and **Sample Mock ID** filled from the selected
mock. A new modifier starts with **Source** set to **Off**, so it is inactive for app traffic.
You can also create one using **Modifiers → New Modifier** and fill these fields yourself.

To start from a request rather than a recording, use **Import cURL → Fill fields from cURL**.
Path, Method, a suggested ID, and a recognized scenario header are populated from the request;
the selected domain and existing manual ID/Order are preserved. The complete request is saved
for preview. See <doc:Modifiers> for supported flags and import limitations.

### 2. Change one response field

Replace the code in the JavaScript editor with:

```javascript
function transformer(req, chain) {
  var res = chain.proceed(req);
  res.body.stock = 0;
  return res;
}
```

`req` contains the intercepted request. `chain.proceed(req)` gets a response from the next
matching modifier, or from the chosen Mock/Live source when there are no more modifiers.
For a JSON response, `res.body` is a JavaScript object or array that you can edit directly.
Return `res` to send the transformed response onward. The function is synchronous;
use `chain.proceed(req)` directly without `async` or `await`.

The resulting product still has ID `42`, name `Travel mug`, price `19.99`, and the same
images; its stock changes from `12` to `0`. JSON may be reserialized, so preservation means
field values, not byte-for-byte formatting or key order.

The transformation does not rewrite the stored mock file.

### 3. Preview the result

Check the **Preview Request** URL, method, and scenario against the modifier's metadata.
When created from a mock, the preview uses that mock as its initial source even while the
modifier is Off. Click **Run** or press **⌘Return**.

The response pane shows the original body on the left and the transformed body on the right.
Confirm that `stock` changed from `12` to `0` and the other fields stayed the same.
**Run** evaluates your current unsaved code; it does not save the modifier or activate it.
Other active modifiers matching the preview request also participate in the preview.

For larger responses, right-click a key or value on the right and choose **Edit in JavaScript**
to insert an assignment for that field. **Copy Object Notation** in the toolbar copies a
compact summary of the response's field types. The same action in the context menu copies
only the selected field's enclosing object and its JavaScript path. See <doc:Modifiers>
for optional fields, merged array shapes, and type unions.

### 4. Save and enable it for your application

Click **Save** or press **⌘S** to persist the modifier. Then choose **Mock** in the **Source**
control to activate it using stored responses. Trigger `GET /products/42` in your application:
the matching response now has `stock: 0`, so you can test the out-of-stock UI.

| Action | Effect |
| --- | --- |
| **Run** | Tests the unsaved draft with the preview request. |
| **Save** | Saves metadata, JavaScript, and the preview request as cURL with its source/scenario. |
| **Source: Mock** | Activates it for app traffic using stored mock responses. |
| **Source: Live** | Activates it for app traffic using live API responses. |
| **Source: Off** | Removes it from the active set for app traffic. |

Source changes take effect immediately for app traffic. Save your code before enabling the
modifier so your application receives the version you previewed. **Sample Mock ID** selects
the stored response for previews; app traffic uses the normal request matching rules.

To try a live response instead, choose **Live**, enter your API's real URL and required headers,
and click **Run**. Live previews make a real network request. An app request configured with
`disableLiveEnvironment=true` always uses stored mocks, even when a modifier is set to Live.

### 5. Turn it off when finished

Set **Source** to **Off** in the detail screen or the **Active** control in the modifiers list.
The definition remains saved so you can reuse it. Active selections are cleared when
the Mocking Star process restarts.

## Matching and combining modifiers

A modifier matches an exact request path and HTTP method. A non-empty **Scenario** also
requires that scenario to match. For example, `/products/42` does not match `/products/43`.
The modifier must be active in the same mock domain and device context as the request.

When several modifiers match, lower **Order** values run first on the way into the chain.
Response changes after `chain.proceed(req)` run in reverse order as the response returns.
For orders `1` and `2`, the response change in modifier `2` happens before the one in modifier `1`.
If both change the same field after `chain.proceed(req)`, modifier `1` makes the final change.

If any matching active modifier uses Live, the chain fetches a live response; if all use Mock,
it reads a stored mock. The `disableLiveEnvironment=true` flag overrides Live for app requests.

The macOS controls manage the default device context. Clients sending `deviceId` inherit
that context until they configure their own active set. See <doc:Modifiers> for device
isolation, API activation, and parallel test setup.

### Scenario is a matching condition, not a response source

Activation answers **which modifiers may run**. Scenario answers **which of those modifiers
match this request**. Mock/Live answers **where the chain obtains its base response**.
Setting a scenario does not necessarily mean the request uses a stored mock.

For the same `GET /search/widgets` route:

| Modifier scenario | Request scenario | Matches, if active? |
| --- | --- | --- |
| Empty or `null` | Empty | Yes |
| Empty or `null` | `favorites-visible` | Yes |
| Empty or `null` | `favorites-hidden` | Yes |
| `favorites-hidden` | `favorites-visible` | No |
| `favorites-hidden` | `favorites-hidden` | Yes |

A scenario-independent modifier can insert a slider for both scenarios. A second modifier
can hide its favorite buttons only for `favorites-hidden`. Both can use Live throughout.

### Understand both directions of a chain

For modifier A with Order `1` and B with Order `2`:

```text
Request -> A before proceed -> B before proceed -> Mock or Live terminal
Response <- A after proceed <- B after proceed <- terminal response
```

Request changes happen A, then B. Response changes happen B, then A. If both set `stock`
after `chain.proceed(req)`, A makes the final change. Equal orders are sorted by filename ID;
use distinct positive orders when the dependency matters. The order of IDs in an activation
payload or flow YAML does not replace the metadata's Order.

## Modify a request before it reaches the source

The function also receives a mutable request. Code before `chain.proceed(req)` can change
its URL, method, headers, or text body. Code after that call changes the returned response.

This complete modifier fragment rewrites the `q` parameter from Elbise to Pantolon:

```javascript
function transformer(req, chain) {
  req.url = req.url.replace(/([?&]q=)([^&#]*)/g, function (match, prefix, value) {
    var query = decodeURIComponent(value.replace(/\+/g, " ")).toLowerCase();
    return query === "elbise" ? prefix + "Pantolon" : match;
  });
  return chain.proceed(req);
}
```

Use metadata that matches the original search route. The backend receives Pantolon while
the application's search field can still display Elbise; the modifier changes the network
request, not the input widget. The response is returned without field edits. The bundled
`SearchElbiseToPantolon.js` also handles the encoded deeplink's `Query=Elbise` parameter.

Matching and the chain's source are selected from the original request. Changing a URL inside
the chain does not cause other modifiers to be matched again. In a Mock preview, the selected
Sample Mock ID and original preview request identify the base response; a Live preview sends
the rewritten request. Check request-rewrite behavior with Live or the actual application flow.

For a JSON request body, `req.body` is text: parse it with `JSON.parse`, change the field,
and assign `JSON.stringify(...)` back before calling `chain.proceed(req)`.

## Editor and workflow features

| Feature | How to use it |
| --- | --- |
| Modifier list search | Use the shared rich search bar to filter by All, Path, Scenario, or Method; refresh with `⌘R`. |
| Duplicate and copy/paste | Reuse a definition, including saved preview metadata; review its new ID, route, and Order. |
| Original/Modified comparison | Run the draft and compare the source response with the complete chain output. |
| Response search | Focus the required response pane and press `⌘F` on macOS. Search each side independently. |
| JSON navigation | Navigate structured JSON and fold supported object/array blocks in the response editor. |
| Edit in JavaScript | Right-click a response field to insert an editable assignment for the clicked value into the JavaScript editor. A multi-range selection does not mean "edit the entire response." |
| Format | Use Format or the editor's `⇧⌥F` action to format JavaScript. Formatting changes the draft; Save persists it. |
| Copy response | Copy the transformed response body. |
| Copy cURL | Copy the current preview request without running or saving it. |
| Copy Object Notation | Copy the observed field types for the whole response, or the selected object's types and JavaScript path. |
| Preview persistence | Save the request as cURL, including preview source and scenario; reopening restores it. The output itself remains transient. |
| Guided onboarding | TipKit explains the response pane, JavaScript editor, and preview request in the macOS detail screen. |
| Visible feedback | Errors use red feedback; successful actions use green feedback. Field validation and error dialogs explain failures. |

The macOS editor uses a resizable response/JavaScript split with scrollable metadata and
preview forms. Merlin Studio additionally provides a collapsible modifier navigation tree.
These are different UIs; <doc:PartialMocking-Merlin> describes their exact activation and
preview differences.

Copy Object Notation is an observation of one preview, not a complete API schema. For example:

```json
[{"a":1},{"a":null,"b":"x"}]
```

becomes:

```json
[{"a":"int|null","b":"string (optional)"}]
```

Array items are merged into a single shape. Missing fields become optional and different
scalar types become unions. A context-menu copy includes a path such as
`res.body.widgets[1]`, followed by only that object's notation. See <doc:Modifiers> for
container unions, optional containers, and field-selection rules.

## Write modifiers that survive response changes

Prefer the smallest change that creates the required test condition. Keep unrelated fields
from the source response and give each modifier a name that describes its purpose.

When the desired widget already exists, find it by a meaningful property and reuse the object:

```javascript
function transformer(req, chain) {
  var res = chain.proceed(req);
  var widgets = res.body.widgets;
  var index = widgets.findIndex(function (widget) {
    return widget.type === "SEARCH_JFY";
  });
  if (index < 0) {
    throw new Error("Expected SEARCH_JFY in the source response");
  }
  widgets.unshift(widgets.splice(index, 1)[0]);
  return res;
}
```

This moves the existing object to the first position while preserving its payload. A fixed
index copied from a preview can become wrong when the API reorders widgets. Rebuilding a
whole widget with captured URLs and fields introduces more maintenance than changing the
existing object. If injection is the scenario itself, a captured widget can still be appropriate;
keep its required fields and URLs current and validate the resulting products request.

The presentation also shows these field-specific transformations:

| Example | Demonstrated target | Intended change |
| --- | --- | --- |
| Widget availability date | `res.body.widgets[13].startDate` | Change the date that determines the widget's displayed state. |
| Product name | A selected widget's products, then `content.name` | Set the displayed name to `"Trendyol"`. |
| Color-option images | `res.body["941606"].colorOptionImageUrls` on `/en-SA-35/search/color-option-groups` | Replace the image URL array for that color-option entry. |

The widget index, content ID, route, and paths belonged to the demonstrated responses.
The speaker notes refer to a local `deneme.js` example; that filename is not a required or
universally installed fixture. Inspect your actual JSON before using these paths, and
prefer selecting an object by a stable property over retaining a preview's numeric index.

Keep helpers inside `transformer`, or after its declaration, when sharing files between the
tools. Their parsers extract executable source starting at the transformer declaration;
a helper before that declaration can be absent during execution. Use synchronous JavaScript
and avoid browser/Node-only APIs. Each tool uses a different engine, so run the script in both.

Treat a missing object according to the test's acceptance condition. Throw when its absence
invalidates the scenario; use an explicit alternative only if the scenario intentionally
tests absence. Do not hide a failed modification behind an apparently successful pass-through.

## Demonstration cases

The repository includes four Dev definitions in `Examples/PartialMocking/Dev/Modifiers/`.
The adjacent README provides installation, activation, scenario, and cleanup commands.

| Demo | Active definitions | What to observe |
| --- | --- | --- |
| Insert JFY | `SearchJfySlider` | The first search widget becomes `SEARCH_JFY`; its products load through a separate request. |
| Combine response modifiers | `SearchJfySlider` + `DemoJfyHideFavorites` | JFY is inserted first on the response path, then its favorite buttons are hidden. |
| Select by scenario | `SearchJfySlider` + `DemoJfyScenarioHideFavorites` | Favorites stay visible for `demo_jfy_favorites_visible` and are hidden for `demo_jfy_favorites_hidden`. |
| Rewrite the request | `SearchElbiseToPantolon` | An Elbise search reaches the backend as Pantolon. |

Use Live for the selected demo and turn other modifiers on that route Off. The JFY injection
has Order `2`; the dependent favorite modifiers have Order `1`, so they run after insertion
as the response unwinds. A login is required when the personalized endpoint needs a session.
The slider's full-service URL does not bypass interception merely because it is absolute;
it is a distinct route with its own normal mock/live resolution. Live on `/search/widgets`
does not force `/just-for-you/products`, or any other route, to Live.

## Boundaries and platform support

- Mock fixes the base HTTP input, not asynchronous UI timing, image/CDN availability,
  unrelated endpoints, or the entire backend environment.
- Live depends on backend access, authentication, and current data. Changing a few response
  fields does not make every unmodified field deterministic.
- Modifiers are not an automatic migration mechanism for an evolving API contract.
- Mocking Star's macOS implementation executes JavaScript through JavaScriptCore. Its Linux
  modifier chain currently forwards directly to the terminal without executing transformers;
  Linux compilation alone is not evidence of working partial mocks. Linux preview is unsupported.
- Merlin's CLI uses Goja. Sharing the function contract is not a guarantee that every engine
  feature, preview behavior, or device-routing integration is identical.
- A successful preview validates that preview context. Also validate the saved modifier
  against the application's actual route and the complete automated flow.
- A short-circuit transformer can generate a response without `chain.proceed`; no base
  response exists to compare in that case. Return a valid response object.
- Syntax errors, thrown exceptions, or invalid return objects fail the executing chain.
  See <doc:Modifiers> for the distinction between runtime `500` and preview API error codes.

## Historical mock-size findings from the presentation

The supplied presentation reports a **3 November 2026** snapshot of Android's
`maestro/mockingstar` and `contracts/mocks` JSON trees. These are historical findings from
the presentation, not a measurement performed by this guide or guaranteed current repository sizes.

| Mock tree | JSON files | Reported size (MB) |
| --- | ---: | ---: |
| Maestro / Mocking Star | 7,333 | 503 |
| Merlin | 7,008 | 434 |
| Total | 14,341 | 937 |

The reported Merlin `msearch` subset is **1,172 files / 178 MB** and is already included in
the Merlin total; do not add it again. The comparison examined `responseBody` in Maestro
files and `body` in Merlin files, comparing **6,184 variants** with the largest sibling in
their group. Merlin groups used domain, method, and filename, with scenario folders treated
as variants.

| Candidate category | Variant files | Reported file size |
| --- | ---: | ---: |
| Identical response bodies | 1,299 | 146 MB |
| At most 40 field differences | 931 | 144 MB |

These categories can overlap: **do not add their counts or MB values**. They describe
candidate file sizes before preserving a base response and accounting for replacement scripts.
The analysis also reports **5,187 variants with large differences**, with a median of
**582 leaf differences**. This is a reason to validate conversion candidates individually,
rather than assume every extra fixture is a small variation.

The presentation's **440 MB / 47%** ceiling assumes all **6,185 additional JSON files** can
be replaced by roughly **2 KB of JavaScript each**: about **452 MB of extra JSON** minus
about **12 MB of scripts**. Its reported per-tree ceilings are **210 MB for Maestro** and
**230 MB for Merlin**. The comparison count and ceiling-assumption count are reproduced as
reported; they should be reconciled in a fresh audit rather than silently treated as identical.

This is a hypothetical ceiling, not achieved repository shrinkage or proof that all variants
are suitable. Sizes and percentages were rounded in the source. Git changed-line volume is
a different metric from stored file bytes and cannot substitute for a disk-size measurement.

Prioritize identical-body and small-difference candidates by endpoint and scenario. After
conversion, measure the total retained base JSON plus modifier files again to determine actual
net savings. Keep a reproducible inventory, grouping rules, and response comparisons with the result.

## Adoption plan and success measures

The presentation proposes a rollout, not an already committed schedule or verified list
of owners. Establish released tool versions and installation steps before extending a pilot.

1. **Choose pilot scenarios.** With a team representative, select one endpoint and two hard-to-prepare
   edge cases. Demonstrate each manually in Mocking Star and in a Merlin flow.
2. **Provide a short usage guide.** Use the authoring walkthrough, screenshots from the actual
   version, a shared demo, and pairing on the team's first modifier. Explain Run/Save/Source,
   Mock/Live, route matching, and scenario selection.
3. **Build shared examples.** Store narrowly scoped modifiers in the existing domain structure.
   Use descriptive names, explicit selection in flows, and team ownership. Prefer changing or
   moving existing objects; develop writing conventions from examples that worked in pilots.
4. **Measure and expand.** Validate device routing, CI execution, cleanup on failure, and parallel
   isolation before broader use. Expand after reviewing the pilot evidence.

Track time to the first working scenario, number of scenarios sharing a base fixture,
modifier reuse, maintenance effort after API changes, run outcomes, and backend-related
failures. Compare the same flows under comparable conditions. Record actual fixture/script
size after conversion. Do not infer reduced flakiness or preparation time from file-size
statistics alone.

## Presentation coverage

The table maps all 15 slides, including their technical speaker notes, to this documentation.

| Slide | Topic | Where it is covered |
| --- | --- | --- |
| 1 | Partial mock overview | What is a partial mock? |
| 2 | Hard-to-obtain states and repeated JSON | Why we introduced partial mocking |
| 3 | Static mock drift | Why we introduced partial mocking; Boundaries |
| 4 | Maintenance model | Base response and modifier file examples |
| 5 | Design decisions | Design decisions and their purpose |
| 6 | Mock versus Live | Authoring workflow; <doc:Modifiers>; <doc:PartialMocking-Merlin> |
| 7 | Transformer execution and field examples | Change one response field; request editing; authoring recommendations |
| 8 | Shared contract and separate runtimes | <doc:PartialMocking-Merlin> |
| 9 | Mocking Star UI | Authoring workflow; Editor and workflow features; <doc:Modifiers> |
| 10 | Merlin Studio UI | <doc:PartialMocking-Merlin> |
| 11 | Flow setup, validation, and teardown | <doc:PartialMocking-Merlin> |
| 12 | Matching, ordering, failures, and platform limits | Matching and combining; Boundaries; both reference guides |
| 13 | Benefits and pilot metrics | Motivation; Adoption plan and success measures |
| 14 | Size analysis and its assumptions | Historical mock-size findings |
| 15 | Rollout proposal and ownership | Adoption plan and success measures |

Behavior was checked against the repository sources on **8 November 2026**. Historical
presentation findings and proposed rollout items are identified separately. For engine/API
details, see <doc:Modifiers>; for version-dependent Android/CLI integration, see
<doc:PartialMocking-Merlin>.

## Troubleshooting

| Symptom | What to check |
| --- | --- |
| The preview cannot find a mock | Verify **Sample Mock ID**, the selected domain, and the preview URL/method/scenario. |
| Preview works but the app response is unchanged | Save your code, enable Mock or Live, and check the app's path, method, scenario, domain, and device context. |
| A field assignment fails | Inspect the response structure. A nested object may be absent, or the body may be text rather than JSON. |
| The preview says **Stale** | Run it again after changing the code or request to see the latest result. |
| The preview says **No original** | Your function returned a response without calling `chain.proceed(req)`. Call it when you want to modify an existing response. |
| JFY appears but its products do not | Inspect the separate products request, logged-in session, required headers, and any stored mock matching that route. |
| Changing a scenario unexpectedly uses Live | Scenario is a match selector. Inspect the active modifiers' source settings; scenario registration alone does not select Mock. |
| Chained edits appear in the wrong order | Response edits run in reverse Order. Review each definition's Order and filename tie-breaker. |
| A script works in one tool only | Check engine-specific APIs, helper placement, domain, sample reference, and the preview/runtime differences. |
| A Merlin preview works but a multi-device run does not | Verify `X-Merlin-Device` propagation and the activation key in the exact APK/CLI versions. See <doc:PartialMocking-Merlin>. |

For the complete API and editor reference, see <doc:Modifiers>.
