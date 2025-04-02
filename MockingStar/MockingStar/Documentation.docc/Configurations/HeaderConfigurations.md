# Header Configurations

Configure how Mocking Star handles HTTP headers in requests.

## Overview

Header Configurations allow you to control how specific HTTP headers are processed when matching requests. This is particularly useful when certain headers should be ignored or when specific header values should be considered for mock selection.

### Default Behavior

By default, Mocking Star's header filter executes with the "ignore" style, meaning it only considers the URL path for matching. You can modify this behavior using Header Configurations.

## Visual Examples

### Ignore All Headers (Default Behavior)

When header filter default style is set to "Ignore," these requests are considered the same because Mocking Star ignores all headers:

```
/about-us Header: device=ios
/about-us Header: device=android
```

Both requests will use the same mock.

### Ignore All Headers with Header Config (Only Key)

When you add a Header Configuration with a specific key but no value:

```json
{
    "paths": ["/about-us"],
    "key": "userId",
    "value": ""
}
```

Mocking Star will consider the key `userId` when matching requests:

```
/about-us Header: userId=1 device=ios
/about-us Header: userId=2 device=android
```

These requests will use different mocks because the `userId` values differ, while the `device` header is still ignored.

### Ignore All Headers with Header Config (Key and Value)

When you add a Header Configuration with both key and specific value:

```json
{
    "paths": ["/about-us"],
    "key": "userId",
    "value": "1"
}
```

Mocking Star will match requests where the `userId` header equals "1" and consider them the same:

```
/about-us Header: userId=1 device=ios
/about-us Header: userId=1 device=android
```

These requests will use the same mock because both have the `userId=1` header.

### Ignore All Headers with Header Config (Key and Value - Different Values)

When you add a Header Configuration with both key and specific value, requests with different values will be treated differently:

```json
{
    "paths": ["/about-us"],
    "key": "userId",
    "value": "1"
}
```

```
/about-us Header: userId=1 device=ios
/about-us Header: userId=3 device=android
```

These requests will use different mocks because one has `userId=1` and the other has `userId=3`.

### Match All Headers

When header filter default style is set to "Match All," these requests are considered different because Mocking Star matches all headers:

```
/about-us Header: device=ios
/about-us Header: device=android
```

Each request will use a different mock.

### Match All Headers with Header Config (Only Key)

When you add a Header Configuration with a specific key but no value:

```json
{
    "paths": ["/about-us"],
    "key": "device",
    "value": ""
}
```

Mocking Star will ignore the `device` header when matching requests:

```
/about-us Header: device=ios
/about-us Header: device=android
```

These requests will use the same mock because the `device` header is ignored.

### Match All Headers with Header Config (Key and Value)

When you add a Header Configuration with both key and specific value:

```json
{
    "paths": ["/about-us"],
    "key": "device",
    "value": "ios"
}
```

Mocking Star will treat requests with different `device` values as different:

```
/about-us Header: device=ios
/about-us Header: device=android
```

These requests will use different mocks because they have different values for the `device` header.

### Match All Headers with Header Config (Key and Value - Non-matching Values)

When you add a Header Configuration with both key and specific value:

```json
{
    "paths": ["/about-us"],
    "key": "device",
    "value": "ios"
}
```

```
/about-us Header: device=android
/about-us Header: device=desktop
```

These requests will use the same mock because neither matches the specified `device=ios` value.

### Configuration Parameters

- **paths**: (optional) Array of paths where this configuration applies
- **key**: The exact header key to configure
- **value**: (optional) The exact header value to match

### Examples

#### Ignoring Specific Headers

```json
{
    "paths": ["/api/v1/products/*"],
    "key": "User-Agent",
    "value": ""
}
```

This configuration ignores the `User-Agent` header for all product-related requests.

#### Matching Specific Header Values

```json
{
    "paths": ["/api/v1/auth/*"],
    "key": "Authorization",
    "value": "Bearer admin-token"
}
```

This configuration only matches requests where the `Authorization` header equals "Bearer admin-token".

### Best Practices

1. Use empty paths array to apply configuration globally
2. Be specific with path patterns when needed
3. Only configure headers that are truly important for mock selection
4. Document any special header configurations for your team
5. Test configurations with various header combinations
6. Consider using path-specific configurations when different paths need different behaviors
7. Be careful when matching header values, as they can make mock management more complex

### Common Use Cases

1. **Authentication**: Handle different authentication tokens
2. **Platform/Device**: Manage different device or platform headers
3. **Language/Locale**: Handle different language preferences
4. **Content Type**: Manage different content type headers
5. **Custom Headers**: Handle project-specific custom headers
6. **Version Control**: Handle API version headers
7. **Cache Control**: Manage cache-related headers

```
paths: [/product/v2/102030]
key: type
value: 
```

```
paths: [/product/v2/102030]
key: OSVersion
value: 
```
