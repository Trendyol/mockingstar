# Path Configurations
_

Normally, Mocking Star uses exact matching of request paths to determine mocks. However, there are cases where path components can be ignored. Path Configurations allow you to modify the path matching style.

In the typical scenario, these requests are considered different because their paths do not match:

```
url: https://...../productDetail/v2/102030/return-conditions
url: https://...../productDetail/v2/98765/return-conditions
```

If we add a new Path Configuration with:

```
/productDetail/v2/*/return-conditions
```

Now, Mocking Star can recognize these two requests as the same, enabling the use of the same mock.

> Important: Each * serves as a placeholder for only one path component, and you can use multiple * for one configuration.

### Headers and Queries for one path
All queries and headers can be ignored or marked for exact matching.

> Important: Mocking Star's default query and header execution style is set to ignore. However, this can be changed at any time with the following configurations:
> - Query Filter Default Style Ignore
> - Header Filter Default Style Ignore
> 
> 

- **executeAllQueries**:  If the default style is set to ignore, Mocking Star can break this rule for a given path. Otherwise, if the default style is not set to ignore, Mocking Star can ignore all queries for a given path.

- **executeAllHeaders**: If the default style is set to ignore, Mocking Star can break this rule for a given path. Otherwise, if the default style is not set to ignore, Mocking Star can ignore all headers for a given path.
