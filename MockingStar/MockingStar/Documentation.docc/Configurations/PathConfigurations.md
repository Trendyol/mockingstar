# Path Configurations

Control how Mocking Star matches and processes request paths.

## Overview

Path Configurations allow you to customize how Mocking Star handles path matching in requests. By default, Mocking Star uses exact path matching, but you can configure it to be more flexible using wildcards and path matching ratios.

### Path Matching Styles

Mocking Star supports two main path matching styles:

1. **Exact Matching**: The default behavior where paths must match exactly
2. **Wildcard Matching**: Using `*` as a placeholder for path components

### Examples

#### Basic Path Matching

By default, these requests are considered different because their paths don't match exactly:

```
Request 1: https://api.example.com/productDetail/v2/102030/return-conditions
Request 2: https://api.example.com/productDetail/v2/98765/return-conditions
```

#### Using Wildcards

You can use wildcards to make paths more flexible:

```
Path Configuration: /productDetail/v2/*/return-conditions
```

This configuration will match both requests above because the `*` wildcard matches any value in that position.

> Important: Each `*` serves as a placeholder for only one path component.

### Path Matching Ratio

The Path Matching Ratio allows you to control how strict the path matching should be. This is particularly useful when you want to match paths that are similar but not exactly the same.

For example:

```
Request: /tr-TR-1/product/v2/102030/return-conditions
Config: /v2/*/return-conditions
```

- With 100% ratio: These paths are considered different
- With 50% ratio: These paths are considered the same

> Important: Matching always starts from the end of the path.

### Query and Header Behavior

Path Configurations allow you to control how queries and headers are handled for specific paths. This is particularly useful when you want to override the default behavior for certain paths.

#### Query Execution Style

The `queryExecuteStyle` parameter controls how query parameters are handled for a specific path:

- **ignoreAll**: Ignore all query parameters when matching requests
- **matchAll**: Consider all query parameters when matching requests

Example:
```json
{
    "path": "/api/v1/products/*",
    "queryExecuteStyle": "matchAll",
    "headerExecuteStyle": "ignoreAll"
}
```

With this configuration:
- `/api/v1/products/123?type=digital` and `/api/v1/products/123?type=fashion` will be treated as different requests
- All query parameters will be considered in the matching process

#### Header Execution Style

The `headerExecuteStyle` parameter controls how HTTP headers are handled for a specific path:

- **ignoreAll**: Ignore all headers when matching requests
- **matchAll**: Consider all headers when matching requests

Example:
```json
{
    "path": "/api/v1/auth/*",
    "queryExecuteStyle": "ignoreAll",
    "headerExecuteStyle": "matchAll"
}
```

With this configuration:
- Requests with different headers will be treated as different requests
- All headers will be considered in the matching process

> Important: These settings override the default behavior defined in General Configurations.

## Configuration Parameters

- **path**: The path pattern to match (can include wildcards)
- **queryExecuteStyle**: How to handle query parameters for this path
  - `ignoreAll`: Ignore all query parameters
  - `matchAll`: Consider all query parameters
- **headerExecuteStyle**: How to handle headers for this path
  - `ignoreAll`: Ignore all headers
  - `matchAll`: Consider all headers

## Examples

### Basic Configuration

```json
{
    "path": "productDetail/v2/*/return-conditions",
    "queryExecuteStyle": "ignoreAll",
    "headerExecuteStyle": "ignoreAll"
}
```

### With Query Matching

```json
{
    "path": "api/v1/users/*",
    "queryExecuteStyle": "matchAll",
    "headerExecuteStyle": "ignoreAll"
}
```

### With Header Matching

```json
{
    "path": "api/v1/auth/*",
    "queryExecuteStyle": "ignoreAll",
    "headerExecuteStyle": "matchAll"
}
```

## Best Practices

1. Use wildcards (`*`) for dynamic path components
2. Set appropriate path matching ratios based on your needs
3. Configure query and header behavior based on the importance of these parameters
4. Keep path configurations simple and maintainable
5. Document any special path configurations for your team
6. Use `matchAll` only when necessary, as it can make mock management more complex
7. Consider using path-specific configurations when different paths need different behaviors
