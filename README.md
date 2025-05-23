# Mocking Star

[![Unit Tests](https://github.com/Trendyol/mockingstar/actions/workflows/unit-tests.yml/badge.svg)](https://github.com/Trendyol/mockingstar/actions/workflows/unit-tests.yml) 
[![Release App](https://github.com/Trendyol/mockingstar/actions/workflows/release-app.yml/badge.svg)](https://github.com/Trendyol/mockingstar/actions/workflows/release-app.yml)
[![Release CLI](https://github.com/Trendyol/mockingstar/actions/workflows/release-cli.yml/badge.svg)](https://github.com/Trendyol/mockingstar/actions/workflows/release-cli.yml)
[![Build and Publish DocC](https://github.com/Trendyol/mockingstar/actions/workflows/build-and-publish-docc.yml/badge.svg)](https://github.com/Trendyol/mockingstar/actions/workflows/build-and-publish-docc.yml)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/Trendyol/mockingstar/badge)](https://scorecard.dev/viewer/?uri=github.com/Trendyol/mockingstar)

Mocking Star is a powerful request mocking tool designed to simplify the process of http request mocking, network debugging, and using UI tests for your applications.

![](https://github.com/Trendyol/mockingstar/blob/main/.github/resources/MockingStarDemo.gif)

## Installation

You can download the latest version at the following link:

- [Mocking Star macOS App](https://github.com/Trendyol/mockingstar/releases/latest) <br>
- [Mocking Star CLI](https://github.com/Trendyol/mockingstar/releases/latest)

The latest binary can also be found on the releases page or clone and compile in Xcode.

### Key Features

- **Mocking Requests**: Easily mock requests and test different cases with scenarios.
- **Modifying Requests**: Modify intercepted requests to test different edge cases, allowing you to assess your application's performance under different conditions.
- **Debugging Support**: Use Mocking Star to debug your network requests on your mac.
- **UI Testing**: Integrate Mocking Star into your UI tests, creating a reliable and controlled testing environment to validate your mobile application's functionality.
- **Plugins**: Write your own plugins and extend functionality.

## Integrate with your project

- [iOS Client Library](https://github.com/Trendyol/mockingstar-ios)
- [Android Client Library](https://github.com/Trendyol/mockingstar-android)
- You can check the document for other clients: [Documentation](https://trendyol.github.io/mockingstar/documentation/mockingstar/gettingstarted-customclient)

## Documentations
Browse the documentation to explore Mocking Star, integrate it into your project, and more.
- [Documentation](https://trendyol.github.io/mockingstar/documentation/mockingstar/documentation)

---
### Optimizing UI Testing Efficiency at Trendyol iOS App:
[Trendyol iOS](https://apps.apple.com/tr/app/trendyol-fashion-trends/id524362642?l=en) Application has nearly 1000 UI tests running with Mocking Star. 
Our UI tests are executed approximately 20k times every day, and Mocking Star handles approximately 1 million requests.

### Libraries and Frameworks

Mocking Star relies on these amazing open-source libraries:

- [AnyCodable](https://github.com/yusufozgul/AnyCodable) - Flexible type for encoding and decoding of JSON
- [FileMonitor](https://github.com/aus-der-Technik/FileMonitor) - File monitoring utility
- [FlyingFox](https://github.com/swhitty/FlyingFox) - Lightweight HTTP server
- [Sparkle](https://github.com/sparkle-project/Sparkle) - Software update framework
- [Swift Argument Parser](https://github.com/apple/swift-argument-parser) - Command-line argument parsing
- [Swift Log](https://github.com/apple/swift-log) - Logging API for Swift
- [Swift Syntax](https://github.com/apple/swift-syntax) - Swift syntax parsing
- [SwiftyJS](https://github.com/yusufozgul/SwiftyJS) - JavaScript evaluation in Swift

## License

This application is released under the MIT license. See [LICENSE](LICENSE) for details.
