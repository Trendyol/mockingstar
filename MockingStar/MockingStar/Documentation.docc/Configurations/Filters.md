# Mock Filters

Mock Filters determines which request should mock or not.

## Overview

Mock Filters in Mocking Star are essential for precisely defining which requests undergo mocking and which ones proceed without mocking. When a mock is not found, Mocking Star sends the original request to your server. Mock Decider then consults Mock Filters to determine whether the request should be mocked or remain not mocked. In the absence of specific filters, Mocking Star defaults to mocking all requests.

#### Filterable Items
- Path
- Query
- Scenario
- Method
- Status Code

#### Filter Style
- Contains
- Not Contains
- Starts with
- End with
- Equal
- Not Equal

## Example:

Suppose you want to exclude all HTTP GET requests from being mocked:

- Location: Method
- Filtering Style: Equal
- Filter Text: GET

By applying this filter, all GET requests will bypass the mocking mechanism.
