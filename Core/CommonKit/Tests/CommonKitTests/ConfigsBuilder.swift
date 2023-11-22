//
//  MockPathBuilderTests.swift
//
//
//  Created by Yusuf Özgül on 2.09.2023.
//

import XCTest
@testable import CommonKit

final class MockPathBuilderTests: XCTestCase {
    private var builder: ConfigsBuilder!
    private let mockUrl = URL(string: "https://www.trendyol.com/aboutus/foo/bar/test?id=123&trackingKey=test&trackingParam=1")!

    override func setUp() {
        super.setUp()

        builder = .init()
    }

    func test_findProperPathConfigs_Ratio1_ReturnsProperConfigs() {
        let pathConfigs: [PathConfigModel] = [
            .init(path: "/aboutus/foo/bar/test",
                  executeAllQueries: false,
                  executeAllHeaders: false),
            .init(path: "/aboutus/foo/bar/*",
                  executeAllQueries: false,
                  executeAllHeaders: false),
            .init(path: "/foo/bar/test",
                  executeAllQueries: false,
                  executeAllHeaders: false),
            .init(path: "/aboutus/foo/bar",
                  executeAllQueries: false,
                  executeAllHeaders: false),
            .init(path: "/aboutus/foo/*",
                  executeAllQueries: false,
                  executeAllHeaders: false),
        ]
        let configs = builder.findProperPathConfigs(mockUrl: mockUrl,
                                                    pathConfigs: pathConfigs,
                                                    pathMatchingRatio: 1)

        let expected: [PathConfigModel] = [
            .init(path: "/aboutus/foo/bar/test",
                  executeAllQueries: false,
                  executeAllHeaders: false),
            .init(path: "/aboutus/foo/bar/*",
                  executeAllQueries: false,
                  executeAllHeaders: false),
            .init(path: "/foo/bar/test",
                  executeAllQueries: false,
                  executeAllHeaders: false),
        ]
        XCTAssertEqual(configs, expected)
    }

    func test_findProperPathConfigs_Ratio05_ReturnsProperConfigs() {
        let pathConfigs: [PathConfigModel] = [
            .init(path: "/aboutus/foo/bar/test",
                  executeAllQueries: false,
                  executeAllHeaders: false),
            .init(path: "/aboutus/foo/bar/*",
                  executeAllQueries: false,
                  executeAllHeaders: false),
            .init(path: "/foo/bar/test",
                  executeAllQueries: false,
                  executeAllHeaders: false),
            .init(path: "/aboutus/foo/bar",
                  executeAllQueries: false,
                  executeAllHeaders: false),
            .init(path: "/aboutus/foo/*",
                  executeAllQueries: false,
                  executeAllHeaders: false),
        ]
        let configs = builder.findProperPathConfigs(mockUrl: mockUrl,
                                                    pathConfigs: pathConfigs,
                                                    pathMatchingRatio: 0.5)

        let expected: [PathConfigModel] = [
            .init(path: "/aboutus/foo/bar/test",
                  executeAllQueries: false,
                  executeAllHeaders: false),
            .init(path: "/aboutus/foo/bar/*",
                  executeAllQueries: false,
                  executeAllHeaders: false),
            .init(path: "/foo/bar/test",
                  executeAllQueries: false,
                  executeAllHeaders: false),
        ]
        XCTAssertEqual(configs, expected)
    }

    func test_findProperPathConfigs_EmptyConfigs_ReturnsProperConfigs() {
        let pathConfigs: [PathConfigModel] = []
        let configs = builder.findProperPathConfigs(mockUrl: mockUrl,
                                                    pathConfigs: pathConfigs,
                                                    pathMatchingRatio: 1)

        let expected: [PathConfigModel] = []
        XCTAssertEqual(configs, expected)
    }

    func test_findProperQueryConfigs_Ratio1_ReturnsProperConfigs() {
        let queryConfigs: [QueryConfigModel] = [
            .init(path: [],
                  key: "id",
                  value: nil),
            .init(path: [],
                  key: "trackingKey",
                  value: "test"),
            .init(path: ["/aboutus/foo/bar/test"],
                  key: "trackingParam",
                  value: nil),
            .init(path: ["/aboutus/foo/bar/test"],
                  key: "trackingParam",
                  value: "1"),
            .init(path: ["/bar/test"],
                  key: "trackingParam",
                  value: "1"),
            .init(path: ["/demo/foo/bar/test"],
                  key: "contentId",
                  value: nil),
        ]

        let configs = builder.findProperQueryConfigs(mockUrl: mockUrl,
                                                     queryConfigs: queryConfigs,
                                                     pathMatchingRatio: 1)

        let expected: [QueryConfigModel] = [
            .init(path: [],
                  key: "id",
                  value: nil),
            .init(path: [],
                  key: "trackingKey",
                  value: "test"),
            .init(path: ["/aboutus/foo/bar/test"],
                  key: "trackingParam",
                  value: nil),
            .init(path: ["/aboutus/foo/bar/test"],
                  key: "trackingParam",
                  value: "1"),
            .init(path: ["/bar/test"],
                  key: "trackingParam",
                  value: "1"),
        ]
        XCTAssertEqual(configs, expected)
    }

    func test_findProperQueryConfigs_Ratio05_ReturnsProperConfigs() {
        let queryConfigs: [QueryConfigModel] = [
            .init(path: [],
                  key: "id",
                  value: nil),
            .init(path: [],
                  key: "trackingKey",
                  value: "test"),
            .init(path: ["/aboutus/foo/bar/test"],
                  key: "trackingParam",
                  value: nil),
            .init(path: ["/aboutus/foo/bar/test"],
                  key: "trackingParam",
                  value: "1"),
            .init(path: ["/bar/test"],
                  key: "trackingParam",
                  value: "1"),
            .init(path: ["/demo/foo/bar/test"],
                  key: "contentId",
                  value: nil),
        ]

        let configs = builder.findProperQueryConfigs(mockUrl: mockUrl,
                                                     queryConfigs: queryConfigs,
                                                     pathMatchingRatio: 0.5)

        let expected: [QueryConfigModel] = [
            .init(path: [],
                  key: "id",
                  value: nil),
            .init(path: [],
                  key: "trackingKey",
                  value: "test"),
            .init(path: ["/aboutus/foo/bar/test"],
                  key: "trackingParam",
                  value: nil),
            .init(path: ["/aboutus/foo/bar/test"],
                  key: "trackingParam",
                  value: "1"),
            .init(path: ["/bar/test"],
                  key: "trackingParam",
                  value: "1"),
        ]
        XCTAssertEqual(configs, expected)
    }

    func test_findProperQueryConfigs_EmptyConfigs_ReturnsProperConfigs() {
        let queryConfigs: [QueryConfigModel] = []

        let configs = builder.findProperQueryConfigs(mockUrl: mockUrl,
                                                     queryConfigs: queryConfigs,
                                                     pathMatchingRatio: 1)

        let expected: [QueryConfigModel] = []
        XCTAssertEqual(configs, expected)
    }

    func test_findProperHeaderConfigs_Ratio1_ReturnsProperConfigs() {
        let queryConfigs: [HeaderConfigModel] = [
            .init(path: [],
                  key: "id",
                  value: nil),
            .init(path: [],
                  key: "user",
                  value: "test"),
            .init(path: ["/aboutus/foo/bar/test"],
                  key: "version",
                  value: nil),
            .init(path: ["/aboutus/foo/bar/test"],
                  key: "version",
                  value: "1"),
            .init(path: ["/bar/test"],
                  key: "isGuest",
                  value: "1"),
            .init(path: ["/demo/foo/bar/test"],
                  key: "token",
                  value: nil),
        ]
        let headers: [String: String] = [
            "id": "1",
            "user": "demo",
            "version": "1.2.3",
            "isGuest": "1",
        ]

        let configs = builder.findProperHeaderConfigs(mockUrl: mockUrl,
                                                      headers: headers,
                                                      headerConfigs: queryConfigs,
                                                      pathMatchingRatio: 1)

        let expected: [HeaderConfigModel] = [
            .init(path: [],
                  key: "id",
                  value: nil),
            .init(path: ["/aboutus/foo/bar/test"],
                  key: "version",
                  value: nil),
            .init(path: ["/bar/test"],
                  key: "isGuest",
                  value: "1"),
        ]
        XCTAssertEqual(configs, expected)
    }

    func test_findProperHeaderConfigs_Ratio05_ReturnsProperConfigs() {
        let queryConfigs: [HeaderConfigModel] = [
            .init(path: [],
                  key: "id",
                  value: nil),
            .init(path: [],
                  key: "user",
                  value: "test"),
            .init(path: ["/aboutus/foo/bar/test"],
                  key: "version",
                  value: nil),
            .init(path: ["/aboutus/foo/bar/test"],
                  key: "version",
                  value: "1"),
            .init(path: ["/bar/test"],
                  key: "isGuest",
                  value: "1"),
            .init(path: ["/demo/foo/bar/test"],
                  key: "token",
                  value: nil),
        ]
        let headers: [String: String] = [
            "id": "1",
            "user": "demo",
            "version": "1.2.3",
            "isGuest": "1",
        ]

        let configs = builder.findProperHeaderConfigs(mockUrl: mockUrl,
                                                      headers: headers,
                                                      headerConfigs: queryConfigs,
                                                      pathMatchingRatio: 0.5)

        let expected: [HeaderConfigModel] = [
            .init(path: [],
                  key: "id",
                  value: nil),
            .init(path: ["/aboutus/foo/bar/test"],
                  key: "version",
                  value: nil),
            .init(path: ["/bar/test"],
                  key: "isGuest",
                  value: "1"),
        ]
        XCTAssertEqual(configs, expected)
    }

    func test_findProperHeaderConfigs_EmptyConfigs_ReturnsProperConfigs() {
        let queryConfigs: [HeaderConfigModel] = []
        let headers: [String: String] = [:]

        let configs = builder.findProperHeaderConfigs(mockUrl: mockUrl,
                                                      headers: headers,
                                                      headerConfigs: queryConfigs,
                                                      pathMatchingRatio: 0.5)

        let expected: [HeaderConfigModel] = []
        XCTAssertEqual(configs, expected)
    }
}
