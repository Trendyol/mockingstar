# 🛠️ Integrate with Swift Application

Integrate Mocking Star with your Swift applications for iOS, iPadOS, macOS, watchOS, tvOS, and visionOS.

@Metadata {
    @PageImage(
               purpose: icon, 
               source: "Swift_logo.png")
    @PageColor(orange)
}

To use Mocking Star in your Swift applications, we recommend integrating it as a Swift Package and injecting it into your app.

```swift
import MockingStar

MockingStar.shared.inject()
```

**For Xcode project**

You can add [mockingstar-ios](https://github.com/Trendyol/mockingstar-ios) to your project as a package.

> `https://github.com/Trendyol/mockingstar-ios`

**For Swift Package Manager**

In `Package.swift` add:

``` swift
dependencies: [
    .package(url: "https://github.com/Trendyol/mockingstar-ios", from: "1.0.0"),
]
```

**Note**

Mocking Star injected default  URLSessionConfiguration, if you have custom URLSessionConfiguration you should inject to your configuration using
```swift 
MockingStar.shared.inject(configuration: URLSessionConfiguration)
```

After injection, run your application, and Mocking Star will work alongside it. Your requests will automatically appear in Mocking Star, allowing you to modify them. Whenever your app uses the same request, Mocking Star will respond with the modified mock.

> Tip:
Feel free to clone repository and explore the demo project inside. 
