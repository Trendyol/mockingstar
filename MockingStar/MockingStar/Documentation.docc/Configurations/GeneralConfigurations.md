# General Configurations

Mocking Star provides essential general configurations to fine-tune its behavior and adapt to the specific needs of your project.



### Query Filter Default Style Ignore
By default, Mocking Star's query filter executes with the "ignore" style. This means Mocking Star only considers the URL path for matching. You can change this behavior at any time with the following configuration:
- Query Filter Default Style Ignore


### Header Filter Default Style Ignore
Similarly, Mocking Star's default header filter executes with the "ignore" style, focusing on the URL path for matching. This can be modified using the following configuration:

- Header Filter Default Style Ignore

### Domains
Mocking Star clients passes all request to Mocking Star. Mocking Star can mock only given domains.

### Path Matching Ratio
In the application's overall path matching, you have the flexibility to match the entire path or use the Path Matching Ratio to match at lower percentages.

For instance:


```
Request:

/tr-TR-1/product/v2/102030/return-conditions
```

```
Config

/tr-TR-1/product/v2/*/return-conditions
```

In the example above, the two paths are identical with a 100% Path Matching Ratio.

However:

```
Request:

/tr-TR-1/product/v2/102030/return-conditions
```

```
Config

/v2/*/return-conditions
```

In this case, the paths are different because they do not match 100%. If we set the matching ratio to 50%, Mocking Star would consider these two paths as equivalent, allowing the provided config to be used for this request.
