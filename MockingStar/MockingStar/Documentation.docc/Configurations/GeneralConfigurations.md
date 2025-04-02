# General Configurations

Mocking Star provides essential general configurations to fine-tune its behavior and adapt to the specific needs of your project.

## Query Execution Style

This setting determines how query parameters are processed in requests. This configuration applies application-wide, but can be customized for specific paths.

You can use mocks by ignoring all query parameters in a request. Conversely, you can use your mocks by matching all query parameters. This setting is default behavior for all paths, you can change this behavior for particular path using `Path Configs`.

For example, if you want to mock all queries for /api/v1/users, you can set this option to `Match All Query Items`. With this setting `/api/v1/users?id=1` and `/api/v1/users?id=2` are different mocks. If you set this option to `Ignore All Query Items`, both of them are treated as the same mock.

### Query Filter Default Style Ignore
By default, Mocking Star's query filter executes with the "ignore" style. This means Mocking Star only considers the URL path for matching. You can change this behavior at any time in the configuration settings.

## Header Execution Style

This setting determines how header parameters are processed in requests. This configuration applies application-wide, but can be customized for specific paths.

You can use mocks by ignoring all header parameters in a request. Conversely, you can use your mocks by matching all header parameters. This setting is default behavior for all paths, you can change this behavior for particular path using `Path Configs`.

For example, if you want to mock all headers for /api/v1/users, you can set this option to `Match All Header Items`. With this setting `Authorization: Bearer 123` and `Authorization: Bearer 456` are different mocks. If you set this option to `Ignore All Header Items`, both of them are treated as the same mock.

### Header Filter Default Style Ignore
Similarly, Mocking Star's default header filter executes with the "ignore" style, focusing on the URL path for matching. This can be modified in the configuration settings.

## Domains
Mocking Star clients pass all requests to Mocking Star. You can configure Mocking Star to mock only specified domains. This allows you to selectively choose which network traffic is processed by the mocking system.

## Path Matching Ratio
In the app-wide configurations, instead of writing the entire path, you can enable the usage of configurations based on a minimum path matching ratio starting from the end. This means that if there is a minimum match ratio of paths from the end, the configuration will be used.

For instance:

```
Request:
/tr-TR-1/product/v2/102030/return-conditions
```

```
Config:
/tr-TR-1/product/v2/*/return-conditions
```

In the example above, the two paths are identical with a 100% Path Matching Ratio.

However:

```
Request:
/tr-TR-1/product/v2/102030/return-conditions
```

```
Config:
/v2/*/return-conditions
```

In this case, the paths are different because they do not match 100%. If we set the matching ratio to 50%, Mocking Star would consider these two paths as equivalent, allowing the provided config to be used for this request.
