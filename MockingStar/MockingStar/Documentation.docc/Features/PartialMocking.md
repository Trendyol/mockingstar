# Partial Mocking

Change selected fields in an HTTP response to test a specific state in your application.

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

## Create your first partial mock

### 1. Create a modifier from a stored mock

In **Mock List**, right-click the product request and choose **Create Modifier**.
Set the ID to `product-out-of-stock`, keep the prefilled path and method, and set **Order** to `1`.
Keep the prefilled scenario if you want this modifier to apply only to that scenario;
leave it empty to match any scenario for the same path and method. Click **Create**.

The detail screen opens with the request URL and **Sample Mock ID** filled from the selected
mock. A new modifier starts with **Source** set to **Off**, so it is inactive for app traffic.
You can also create one using **Modifiers → New Modifier** and fill these fields yourself.

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

This example changes `stock` to `0`. The product's ID, name, price, and images keep their
original values, and the stored mock file is not rewritten by the transformation.

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
| **Save** | Saves the modifier's metadata and JavaScript. |
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
Mocking Star restarts.

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

## Troubleshooting

| Symptom | What to check |
| --- | --- |
| The preview cannot find a mock | Verify **Sample Mock ID**, the selected domain, and the preview URL/method/scenario. |
| Preview works but the app response is unchanged | Save your code, enable Mock or Live, and check the app's path, method, scenario, domain, and device context. |
| A field assignment fails | Inspect the response structure. A nested object may be absent, or the body may be text rather than JSON. |
| The preview says **Stale** | Run it again after changing the code or request to see the latest result. |
| The preview says **No original** | Your function returned a response without calling `chain.proceed(req)`. Call it when you want to modify an existing response. |

For the complete API and editor reference, see <doc:Modifiers>.
