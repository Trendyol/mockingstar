# Query Configurations

Query configurations allow for the ignoring or checking of given query parameters.

## Overview

> Config: If Query Filter Default Style is set to Ignore

In the default configuration, these two requests are considered the same because Mocking Star normally ignores all queries. However, if only specific keys are crucial for a given request, you can alter this rule.

```
- url: https://...../productDetail/v2/102030/return-conditions?type=DigitalService
- url: https://...../productDetail/v2/102030/return-conditions?type=Fashion
```

> Query configurations can be applied to all requests or specific paths. If the value is empty, only the key is considered; otherwise, Mocking Star attempts key-value matching.

```
paths: [/product/v2/102030]
key: type
value: 
```

> Config: If Query Filter Default Style is NOT set to Ignore

In the not ignore configuration, these two requests are considered different because Mocking Star strictly matches all queries. However, if there are ignorable keys for a given request, you can modify this rule.

```
- url: https://...../productDetail/v2/102030/return-conditions?type=DigitalService
- url: https://...../productDetail/v2/102030/return-conditions?type=Fashion
```

```
paths: [/product/v2/102030]
key: type
value: 
```

Now, the requests are considered the same because Mocking Star ignores queries with the key: type in the `/product/v2/102030 path.

### Configuration Parameters
- **paths**: (optional) Paths for query configs
- **key**: Exact key for query
- **value**: (optional) Exact value for query
