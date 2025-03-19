# Header Configurations

Configure how Mocking Star handles HTTP headers in requests.

## Overview

Header Configurations allow you to control how specific HTTP headers are processed when matching requests. This is particularly useful when certain headers should be ignored or when specific header values should be considered for mock selection.

### Default Behavior

By default, Mocking Star's header filter executes with the "ignore" style, meaning it only considers the URL path for matching. You can modify this behavior using Header Configurations.

### Configuration Scenarios

#### When Header Filter Default Style is "Ignore"

In this default configuration, these requests are considered the same because Mocking Star normally ignores all headers:

```
Request 1:
URL: https://api.example.com/productDetail/v2/102030/return-conditions
Headers:
  Platform: iphone
  OSVersion: 17.0.1
  Content-Type: application/json

Request 2:
URL: https://api.example.com/productDetail/v2/102030/return-conditions
Headers:
  Platform: iphone
  OSVersion: 14.2.1
  Content-Type: application/json
```

However, if specific header keys are crucial for a given request, you can modify this behavior:

```json
{
    "paths": ["/product/v2/102030"],
    "key": "Platform",
    "value": ""
}
```

#### When Header Filter Default Style is NOT "Ignore"

In this configuration, these requests are considered different because Mocking Star strictly matches all headers:

```
Request 1:
URL: https://api.example.com/productDetail/v2/102030/return-conditions
Headers:
  Platform: iphone
  OSVersion: 17.0.1
  Content-Type: application/json

Request 2:
URL: https://api.example.com/productDetail/v2/102030/return-conditions
Headers:
  Platform: iphone
  OSVersion: 14.2.1
  Content-Type: application/json
```

You can modify this behavior to ignore specific headers:

```json
{
    "paths": ["/product/v2/102030"],
    "key": "OSVersion",
    "value": ""
}
```

Now, the requests are considered the same because Mocking Star ignores headers with the key `OSVersion` in the `/product/v2/102030` path.

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
