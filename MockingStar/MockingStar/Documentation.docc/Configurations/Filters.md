# Mock Save Filters

Control which network requests should be automatically saved as mocks using powerful filtering rules.

@Metadata {
    @PageImage(
               purpose: icon, 
               source: "configs.png")
    @PageColor(blue)
}

## Overview

Mock Save Filters provide granular control over which network requests should be automatically saved as mocks when they are proxied through the live server. This powerful filtering system allows you to define complex rules based on request properties, ensuring only the relevant requests are mocked while avoiding unnecessary mock files.

## Key Features

- **Multi-criteria Filtering**: Filter based on path, query parameters, HTTP method, status code, or scenario
- **Logical Operations**: Combine filters using AND/OR logic for complex conditions
- **Action Control**: Choose to either Mock or Do Not Mock based on filter results
- **Case-insensitive Matching**: All text comparisons are performed case-insensitively
- **Multiple Filter Styles**: Support for contains, not contains, starts with, ends with, equals, and not equals operations

## Filter Components

### Filter Locations

Mock Save Filters can target different parts of the HTTP request:

- **All**: Matches against path, query, scenario, method, and status code combined
- **Path**: Filters based on the URL path (e.g., `/api/users/123`)
- **Query**: Filters based on query parameters (e.g., `?page=1&size=10`)
- **Scenario**: Filters based on the current mock scenario
- **Method**: Filters based on HTTP method (GET, POST, PUT, DELETE, etc.)
- **Status Code**: Filters based on the HTTP response status code

### Filter Styles

Each filter can use different matching strategies:

- **Contains**: Text contains the specified substring
- **Not Contains**: Text does not contain the specified substring
- **Starts With**: Text begins with the specified string
- **Ends With**: Text ends with the specified string
- **Equal**: Text exactly matches the specified string
- **Not Equal**: Text does not exactly match the specified string

### Logic Types

Filters can be combined using logical operations:

- **AND**: Both the current and previous filter results must be true
- **OR**: Either the current or previous filter result must be true
- **Mock**: Final action - save requests that match the filter conditions
- **Do Not Mock**: Final action - do not save requests that match the filter conditions

## How It Works

### Filter Evaluation Process

1. **Filter Processing**: Each filter is evaluated against the request properties
2. **Logic Combination**: Filter results are combined using the specified logic operations (AND/OR)
3. **Action Determination**: The final action (Mock/Do Not Mock) determines whether to save the request
4. **Result Application**: Requests are either saved as mocks or ignored based on the final result

### Example Filter Configurations

#### Basic Path Filtering
```
Filter 1: Path contains "api/users" -> OR
Filter 2: Path contains "api/products" -> Mock
```
This saves any request containing either "api/users" or "api/products" in the path.

#### Complex Multi-condition Filtering
```
Filter 1: Path contains "api" -> AND
Filter 2: Method equals "POST" -> OR
Filter 3: Status Code equals "201" -> Mock
```
This saves requests that either:
- Contain "api" in path AND are POST requests, OR
- Have a 201 status code

#### Exclude Admin Requests
```
Filter 1: Path contains "admin" -> Do Not Mock
```
This prevents any requests containing "admin" in the path from being saved.

## Configuration Examples

### Save Only API Endpoints
```json
[
  {
    "selectedLocation": "path",
    "selectedFilter": "startWith",
    "inputText": "/api/",
    "logicType": "mock"
  }
]
```

### Exclude Development and Test Data
```json
[
  {
    "selectedLocation": "query",
    "selectedFilter": "contains",
    "inputText": "debug=true",
    "logicType": "or"
  },
  {
    "selectedLocation": "scenario", 
    "selectedFilter": "equal",
    "inputText": "test",
    "logicType": "doNotMock"
  }
]
```

### Save Only Successful Responses
```json
[
  {
    "selectedLocation": "statusCode",
    "selectedFilter": "startWith", 
    "inputText": "2",
    "logicType": "mock"
  }
]
```

## Technical Implementation

### Core Methods

The filtering system is built around two key methods:

#### `executeMockFilterForShouldSave`

Evaluates a complete set of filters against a request to determine if it should be saved as a mock.

**Parameters:**
- `request`: The URLRequest being evaluated
- `scenario`: Current mock scenario name  
- `statusCode`: HTTP response status code
- `mockFilters`: Array of filter configurations

**Returns:** Boolean indicating whether the request should be saved

**Behavior:**
- Returns `true` if no filters are configured (default allow)
- Processes each filter and combines results using specified logic
- Final action (Mock/Do Not Mock) determines the return value

#### `mockFilterResult` 

Evaluates a single filter against request properties.

**Parameters:**
- `filter`: The filter configuration to apply
- `request`: The URLRequest being evaluated  
- `scenario`: Current mock scenario name
- `statusCode`: HTTP response status code

**Returns:** Boolean indicating if the filter condition is met

**Features:**
- Case-insensitive string comparisons
- Extracts relevant data based on filter location
- Supports all filter styles (contains, equals, etc.)

## Best Practices

### Filter Design

1. **Start Simple**: Begin with basic path or method filters before adding complex logic
2. **Test Thoroughly**: Verify your filters work correctly with sample requests
3. **Use Descriptive Patterns**: Make filter text clear and specific to avoid unintended matches
4. **Logical Flow**: Order filters logically and use appropriate AND/OR combinations

### Performance Considerations

1. **Minimize Complexity**: Avoid overly complex filter chains that could impact performance
2. **Specific Patterns**: Use specific filter text to reduce unnecessary processing
3. **Filter Order**: Place more restrictive filters first when possible

### Common Patterns

1. **API-Only Filtering**: `Path starts with "/api"` 
2. **Method-Specific**: `Method equals "GET"` for read-only operations
3. **Status Code Filtering**: `Status Code starts with "2"` for successful responses only
4. **Environment Exclusion**: `Query contains "env=dev"` with Do Not Mock action

## Troubleshooting

### Common Issues

- **No Mocks Being Saved**: Check if filters are too restrictive
- **Unwanted Mocks**: Add exclusion filters for paths or patterns you don't want
- **Complex Logic Not Working**: Verify AND/OR logic is correctly structured
- **Case Sensitivity**: Remember all comparisons are case-insensitive

### Debug Tips

1. **Test Individual Filters**: Start with single filters before combining
2. **Check Filter Location**: Ensure you're targeting the right request property
3. **Verify Input Text**: Make sure filter text matches actual request content
4. **Review Logic Flow**: Trace through AND/OR combinations step by step

## Integration

Mock Save Filters integrate seamlessly with:

- **Live Request Proxying**: Automatically applied when requests are proxied
- **Mock Import**: Filters can be bypassed during manual imports
- **Scenario Management**: Respect current scenario settings
- **Domain Configuration**: Work within configured mock domains 