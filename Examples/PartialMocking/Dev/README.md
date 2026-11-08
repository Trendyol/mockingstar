# Dev partial mocking demos

These are MockingStar versions of the four Merlin demos. They target domain
`Dev` and GET `/tmcdiscovery-msearch-mcwidgets-santral/tr-TR-1/search/widgets`.
This is the route in the Dev workspace's recorded Android Elbise request.

Copy `Modifiers/` into `<mock-workspace>/Domains/Dev/Modifiers/`. For an Android
Maestro workspace, this is:

```text
Trendyol_v2/maestro/mockingstar/Domains/Dev/Modifiers/
```

The existing `sample-mock.js` is preserved. The four new modifiers start Off.
Preview requests contain a clean cURL and use Live; no authentication headers
were copied. The sample mock ID points to the existing Dev widgets recording.

## Prepare the device

1. Open the current MockingStar build and select workspace **Maestro Mocks**,
   domain **Dev**, and **Modifiers**.
2. Enable MockingStar in the Android debug menu. Enabling the switch restarts
   the Android app. Ensure requests reach this Mac's MockingStar server on 8008.
3. Use Live for the modifiers in the selected demo and Off for the other
   modifiers on this route, including `sample-mock`.
4. Return home and search for Elbise again after changing the active set or
   scenario, so the app makes a new widgets request.

Use a logged-in account for the JFY demos; the personalized products endpoint can
return an empty list without a session. The slider's full-service URL triggers a
separate products request. Live on the search widgets modifier applies only to
the widgets route; the products route still follows normal mock matching.

The modifiers match the full API gateway path above. A direct Mars service URL
whose path is only `/tr-TR-1/search/widgets` requires updating all selected
modifiers' Path fields to that observed path.

The commands below target the UI's default device context. A client that sends
an explicit lowercase `deviceId` inherits default activations until it sets its
own activation list. Scenario registrations need that client's exact device ID;
replace the empty `deviceId` below and use the same header on activation calls
if your client has an explicit device context.

## 1. Insert the JFY slider

Set `SearchJfySlider` to Live. It replaces the first widgets response entry with
`SEARCH_JFY`; the JFY products request then loads real products.

```bash
curl --fail-with-body -X PUT 'http://localhost:8008/modifiers?domain=Dev' \
  -H 'Content-Type: application/json' \
  -d '[{"id":"SearchJfySlider","source":"live"}]'
```

## 2. Chain two response modifiers

Set `SearchJfySlider` and `DemoJfyHideFavorites` to Live. The slider appears with
favorite buttons hidden. Distinct supported orders make the chain independent
of the modifier names:

```text
DemoJfyHideFavorites (order 1) enters
  SearchJfySlider (order 2) enters
    Backend returns its response
  SearchJfySlider inserts JFY with favorite buttons enabled
DemoJfyHideFavorites disables those buttons
```

```bash
curl --fail-with-body -X PUT 'http://localhost:8008/modifiers?domain=Dev' \
  -H 'Content-Type: application/json' \
  -d '[{"id":"SearchJfySlider","source":"live"},{"id":"DemoJfyHideFavorites","source":"live"}]'
```

## 3. Select the response modifier by scenario

Activate `SearchJfySlider` and `DemoJfyScenarioHideFavorites` with Live:

```bash
curl --fail-with-body -X PUT 'http://localhost:8008/modifiers?domain=Dev' \
  -H 'Content-Type: application/json' \
  -d '[{"id":"SearchJfySlider","source":"live"},{"id":"DemoJfyScenarioHideFavorites","source":"live"}]'

curl --fail-with-body -X PUT 'http://localhost:8008/scenario' \
  -H 'Content-Type: application/json' \
  -d '{"deviceId":"","mockDomain":"Dev","path":"/tmcdiscovery-msearch-mcwidgets-santral/tr-TR-1/search/widgets","method":"GET","scenario":"demo_jfy_favorites_visible"}'
```

Search for Elbise: JFY favorites are visible. Then select the matching scenario:

```bash
curl --fail-with-body -X PUT 'http://localhost:8008/scenario' \
  -H 'Content-Type: application/json' \
  -d '{"deviceId":"","mockDomain":"Dev","path":"/tmcdiscovery-msearch-mcwidgets-santral/tr-TR-1/search/widgets","method":"GET","scenario":"demo_jfy_favorites_hidden"}'
```

Reopen search: JFY favorites are hidden. `SearchJfySlider` has no scenario filter
and matches both. `DemoJfyScenarioHideFavorites` matches only the hidden scenario.
Both use live responses; no named mock JSON files are needed for these scenarios.

## 4. Rewrite Elbise to Pantolon before chain.proceed

Set only `SearchElbiseToPantolon` to Live:

```bash
curl --fail-with-body -X PUT 'http://localhost:8008/modifiers?domain=Dev' \
  -H 'Content-Type: application/json' \
  -d '[{"id":"SearchElbiseToPantolon","source":"live"}]'
```

Search for Elbise. The modifier changes `q=elbise` or the encoded deeplink's
`Query=Elbise` to Pantolon before `chain.proceed(req)`. The backend receives the
Pantolon request, and its response is returned unchanged. Other search values
and other routes remain unchanged. The modifier does not edit the input field.

## Finish the demo

```bash
curl --fail-with-body -X PUT 'http://localhost:8008/modifiers?domain=Dev' \
  -H 'Content-Type: application/json' -d '[]'

curl --fail-with-body -X DELETE 'http://localhost:8008/scenario' \
  -H 'Content-Type: application/json' \
  -d '{"deviceId":"","mockDomain":"Dev","path":"/tmcdiscovery-msearch-mcwidgets-santral/tr-TR-1/search/widgets","method":"GET","scenario":"demo_jfy_favorites_hidden"}'
```

`PUT /modifiers` replaces the activation list for that context; the empty list
turns all modifiers Off. `DELETE /scenario` clears all scenario registrations
for the specified device in Dev. Activation and scenarios also clear when the
MockingStar server restarts. `disableLiveEnvironment=true` forces mock responses
even with Live selected, so keep it disabled for these live demos.

## Verification

The current macOS Debug build succeeded. Five checks passed through MockingStar's
Live Preview API: JFY insertion, the two-modifier chain, both scenario outcomes,
and the Elbise-to-Pantolon request rewrite. The isolated verification activation
list was cleared, and the default UI's four modifiers remain Off. The Android UI
demonstration has not been run for these MockingStar copies.
