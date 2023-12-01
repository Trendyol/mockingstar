# 🛠️ Integrate with Custom Client

To integrate Mocking Star with other projects, such as frontend or backend applications, follow these steps. 

@Metadata {
    @PageImage(
               purpose: icon, 
               source: "terminal_icon.png")
    @PageColor(gray)
}

Mocking Star is designed to perform all its magic within the macOS application, and clients act as interceptors. If you implement your own client code, the only requirements are as follows:

1. Intercept all HTTP traffic.
2. Collect the URL, method, headers, and HTTP body, and send them to the Mocking Star app.
3. Use the response from Mocking Star.


**Request Body**
```json
{
    "url" : URL_STRING,
    "method" : METHOD_STRING,
    "header" : {
        KEY_VALUE_HEADERS
    },
    "body": BASE64_ENCODED_BODY
}
```

**Header Values**
Mocking Star uses certain header values to determine its actions:

- **mockDomain** (optional)
You can separate all mocks with a mock domain. For example, in UI tests, each team has its own mock values, and each team controls its own mocks.

- **deviceId** (optional)
Mocking Star can serve multiple clients at a time. If you specify your request with a scenario, Mocking Star determines which client wants which scenario.

- **scenario** (optional)
Sometimes, we expect the same request to have multiple results. For example, in UI Tests, we may need multiple states for the same page, such as an empty state and different values. Generally, clients request the same endpoint, but if you specify a scenario, Mocking Star can respond with different results for same request.

- **disableLiveEnvironment** (optional)
Whenever Mocking Star handles a request for which there isn't a proper mock, it uses the original request to fetch a response and then mocks it. If you want to disable the use of the original request, you should pass the header value `disableLiveEnvironment=true`.

Example Request
```curl
curl --location 'http://localhost:8008/mock' \
--header 'mockDomain:Dev' \
--header 'deviceId:123' \
--header 'scenario:EmptyResponse' \
--header 'Content-Type: application/json' \
--header 'disableLiveEnvironment: false' \
--data '{
    "url": "https://api.github.com/search/repositories?q=MockingStar",
    "method": "GET",
    "header": {
        "Platform": "iphone",
        "OSVersion": "17.0.1",
        "Content-Type": "application/json"
    },
    "body": "TW9ja2luZ1N0YXI="
}'

```

After your request, Mocking Star automatically displays the request, and if you modify it, Mocking Star responds with the modified response next time.

### Scenarios

Scenarios allow different responses for the same request, and Mocking Star provides multiple ways to achieve this. To accomplish this, you can send a request to Mocking Star with specific parameters before or while the client sends the actual request, and Mocking Star responds with the specified scenario.

To achieve this, you need to provide the following fields in the request you send:
- deviceId
- path
- method
- scenario
- mockDomain

> To set a scenario, you should send a request with `PUT` method, and to delete an existing scenario, you should send a request with `DELETE` method.


Example Request:
```
curl --location --request PUT 'http://localhost:8008/scenario' \
--header 'Content-Type: application/json' \
--data '{
    "deviceId": "123",
    "path": "/search/repositories",
    "method": "GET",
    "scenario": "EmptyResponse"
}'
```

> Tip:
In case the desired scenario is not found, Mocking Star will send the original request to fetch the data. 
It will then mock the received result with the specified scenario. 
However, response might not match your desired scenario, and in such cases, manual modifications may be necessary.
