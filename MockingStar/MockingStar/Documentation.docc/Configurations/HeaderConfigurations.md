# Header Configurations

Header configurations ignore or check given header parameters.

## Overview

> Config: If Header Filter Default Style is Ignore

These two request are same in default configuration. Because Mocking Star ignores all headers normally. If there is a important keys only given request, you can change this rule. 

```
- url: https://...../productDetail/v2/102030/return-conditions
    Headers:
        "Platform": "iphone",
        "OSVersion": "17.0.1",
        "Content-Type": "application/json"
- url: https://...../productDetail/v2/102030/return-conditions
    Headers:
        "Platform": "iphone",
        "OSVersion": "14.2.1",
        "Content-Type": "application/json"
```

> You can apply header configurations for all requests or specific paths. If the value is empty, only the key is considered; otherwise, Mocking Star attempts key-value matching.


```
paths: [/product/v2/102030]
key: type
value: 
```

> Config: If Header Filter Default Style is NOT Ignore

These two request are different in default configuration. Because Mocking Star tires exact matching all headers. If there is a ignorable keys only given request, you can change this rule. 

```
- url: https://...../productDetail/v2/102030/return-conditions
    Headers:
        "Platform": "iphone",
        "OSVersion": "17.0.1",
        "Content-Type": "application/json"
- url: https://...../productDetail/v2/102030/return-conditions
    Headers:
        "Platform": "iphone",
        "OSVersion": "14.2.1",
        "Content-Type": "application/json"
```

```
paths: [/product/v2/102030]
key: OSVersion
value: 
```

Now the requests are same, because Mocking Star ignores headers with key: `OSVersion` in  `/product/v2/102030` path.

### Configuration Parameters
- **paths**: (optional) Paths for header configs
- **key**: Exact key for header
- **value**: (optional) Exact value for header
