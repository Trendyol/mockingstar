# Query Configurations

Configure how Mocking Star handles query parameters in requests.

## Overview

Query Configurations allow you to control how specific query parameters are processed when matching requests. This is particularly useful when certain query parameters should be ignored or when specific query parameter values should be considered for mock selection.

### Default Behavior

By default, Mocking Star's query filter executes with the "ignore" style, meaning it only considers the URL path for matching. You can modify this behavior using Query Configurations.

## Visual Examples

### Ignore All Queries (Default Behavior)

When query filter default style is set to "Ignore," these requests are considered the same because Mocking Star ignores all query parameters:

```
/about-us?device=ios
/about-us?device=android
```

Both requests will use the same mock.

### Ignore All Queries with Query Config (Only Key)

When you add a Query Configuration with a specific key but no value:

```json
{
    "paths": ["/about-us"],
    "key": "userId",
    "value": ""
}
```

Mocking Star will consider the key `userId` when matching requests:

```
/about-us?userId=1&device=ios
/about-us?userId=2&device=android
```

These requests will use different mocks because the `userId` values differ, while the `device` parameter is still ignored.

### Ignore All Queries with Query Config (Key and Value)

When you add a Query Configuration with both key and specific value:

```json
{
    "paths": ["/about-us"],
    "key": "userId",
    "value": "1"
}
```

Mocking Star will only match requests where `userId` equals "1":

```
/about-us?userId=1&device=ios    (matches the config)
/about-us?userId=2&device=android  (doesn't match the config)
```

### Match All Queries

When query filter default style is set to "Match All," these requests are considered different because Mocking Star matches all query parameters:

```
/about-us?device=ios
/about-us?device=android
```

Each request will use a different mock.

### Match All Queries with Query Config (Only Key)

When you add a Query Configuration with a specific key but no value:

```json
{
    "paths": ["/about-us"],
    "key": "device",
    "value": ""
}
```

Mocking Star will ignore the `device` parameter when matching requests:

```
/about-us?device=ios
/about-us?device=android
```

These requests will use the same mock because the `device` parameter is ignored.

### Match All Queries with Query Config (Key and Value)

When you add a Query Configuration with both key and specific value:

```json
{
    "paths": ["/about-us"],
    "key": "device",
    "value": "ios"
}
```

Mocking Star will only match requests where `device` equals "ios":

```
/about-us?device=ios    (matches the config)
/about-us?device=android  (doesn't match the config)
```

Requests with `device=android` and `device=desktop` will use the same mock, but requests with `device=ios` will use a different mock.

### Configuration Parameters

- **paths**: (optional) Array of paths where this configuration applies
- **key**: The exact query parameter key to configure
- **value**: (optional) The exact query parameter value to match

### Examples

#### Ignoring Specific Query Parameters

```json
{
    "paths": ["/api/v1/products/*"],
    "key": "timestamp",
    "value": ""
}
```

This configuration ignores the `timestamp` query parameter for all product-related requests.

#### Matching Specific Query Values

```json
{
    "paths": ["/api/v1/users/*"],
    "key": "role",
    "value": "admin"
}
```

This configuration only matches requests where the `role` query parameter equals "admin".

#### Multiple Paths Configuration

```json
{
    "paths": [
        "/api/v1/products/*",
        "/api/v2/products/*"
    ],
    "key": "cache",
    "value": ""
}
```

This configuration ignores the `cache` query parameter for both v1 and v2 product endpoints.

#### Global Configuration

```json
{
    "paths": [],
    "key": "version",
    "value": ""
}
```

This configuration ignores the `version` query parameter for all requests.

### Best Practices

1. Use empty paths array to apply configuration globally
2. Be specific with path patterns when needed
3. Only configure query parameters that are truly important for mock selection
4. Document any special query configurations for your team
5. Test configurations with various query parameter combinations
6. Consider using path-specific configurations when different paths need different behaviors
7. Be careful when matching query values, as they can make mock management more complex

### Common Use Cases

1. **Version Control**: Ignore version query parameters
2. **Timestamp Handling**: Ignore timestamp or cache-busting parameters
3. **User-Specific Data**: Match specific user roles or permissions
4. **Device/Platform**: Handle different device or platform parameters
5. **Pagination**: Ignore page number or limit parameters
6. **Sorting**: Handle different sorting parameters
7. **Filtering**: Manage different filter parameters
8. **Search**: Handle search query parameters
