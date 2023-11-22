//
//  PluginTests.swift
//
//
//  Created by Yusuf Özgül on 3.11.2023.
//

import XCTest
@testable import PluginCore
import CommonKitTestSupport
import CommonKit
import AnyCodable

final class PluginTests: XCTestCase {
    var plugin: Plugin!
    var fileUrlBuilder: MockFileUrlBuilder!
    var fileManager: MockFileManager!
    var domainFileStructureMonitor: MockFileStructureMonitor!
    var commonFileStructureMonitor: MockFileStructureMonitor!
    let defaults = UserDefaults()

    override func setUp() {
        super.setUp()

        fileUrlBuilder = .init()
        fileManager = .init()
        domainFileStructureMonitor = .init()
        commonFileStructureMonitor = .init()

        fileUrlBuilder.stubbedPluginFolderUrlResult = URL(string: "test")!
        fileUrlBuilder.stubbedCommonPluginFolderUrlResult = URL(string: "test")!

        defaults.dictionaryRepresentation().keys.forEach(defaults.removeObject(forKey:))
    }

    override func tearDown() {
        super.tearDown()
        defaults.dictionaryRepresentation().keys.forEach(defaults.removeObject(forKey:))
    }

    func initPlugin() {
        plugin = .init(fileUrlBuilder: fileUrlBuilder,
                       fileManager: fileManager,
                       domainFileStructureMonitor: domainFileStructureMonitor,
                       commonFileStructureMonitor: commonFileStructureMonitor,
                       mockDomain: "Dev")
    }

    func test_requestReloaderPlugin_InvokesPlugin() throws {
        fileManager.stubbedFileExistResult = true
        fileManager.stubbedReadFileResult = """
var config = []

function updateRequest(request) {
    var req = request
    req.url = "https://jsonplaceholder.typicode.com/todos/1"

    return req
}
"""

        XCTAssertFalse(fileUrlBuilder.invokedPluginFolderUrl)
        XCTAssertFalse(fileUrlBuilder.invokedCommonPluginFolderUrl)
        XCTAssertFalse(fileManager.invokedFileExist)
        XCTAssertFalse(fileManager.invokedReadFile)

        initPlugin()

        XCTAssertTrue(fileUrlBuilder.invokedPluginFolderUrl)
        XCTAssertTrue(fileUrlBuilder.invokedCommonPluginFolderUrl)
        XCTAssertEqual(fileUrlBuilder.invokedPluginFolderUrlCount, 5)
        XCTAssertEqual(fileUrlBuilder.invokedCommonPluginFolderUrlCount, 5)
        XCTAssertTrue(fileManager.invokedFileExist)
        XCTAssertEqual(fileManager.invokedFileExistCount, 4)
        XCTAssertTrue(fileManager.invokedReadFile)
        XCTAssertEqual(fileManager.invokedReadFileCount, 4)

        let result = try plugin.requestReloaderPlugin(request: .init(url: "https://www.trendyol.com/aboutus",
                                                                     headers: ["key1": "value1"],
                                                                     body: "",
                                                                     method: "GET"))

        XCTAssertEqual(result, .init(url: "https://jsonplaceholder.typicode.com/todos/1",
                                     headers: ["key1": "value1"],
                                     body: "",
                                     method: "GET"))
    }

    func test_requestReloaderPlugin_WithConfig_InvokesPlugin() throws {
        fileManager.stubbedFileExistResult = true
        fileManager.stubbedReadFileResult = """
var config = [
    {
        key: "requestPath",
        valueType: "text",
        value: ""
    }
]

function updateRequest(request) {
    var req = request
    req.url = "https://jsonplaceholder.typicode.com/todos" + config[0].value

    return req
}
"""

        XCTAssertFalse(fileUrlBuilder.invokedPluginFolderUrl)
        XCTAssertFalse(fileUrlBuilder.invokedCommonPluginFolderUrl)
        XCTAssertFalse(fileManager.invokedFileExist)
        XCTAssertFalse(fileManager.invokedReadFile)

        initPlugin()

        XCTAssertTrue(fileUrlBuilder.invokedPluginFolderUrl)
        XCTAssertTrue(fileUrlBuilder.invokedCommonPluginFolderUrl)
        XCTAssertEqual(fileUrlBuilder.invokedPluginFolderUrlCount, 5)
        XCTAssertEqual(fileUrlBuilder.invokedCommonPluginFolderUrlCount, 5)
        XCTAssertTrue(fileManager.invokedFileExist)
        XCTAssertEqual(fileManager.invokedFileExistCount, 4)
        XCTAssertTrue(fileManager.invokedReadFile)
        XCTAssertEqual(fileManager.invokedReadFileCount, 4)

        @UserDefaultStorage("TestStorage", userDefaults: defaults) var configStorage: [PluginConfiguration] = []
        configStorage = [
            .init(key: "requestPath",
                  valueType: .text,
                  value: AnyCodableModel("/product"))
        ]

        plugin.storage[.requestReloader] = _configStorage

        let result = try plugin.requestReloaderPlugin(request: .init(url: "https://www.trendyol.com/aboutus",
                                                                     headers: ["key1": "value1"],
                                                                     body: "",
                                                                     method: "GET"))

        XCTAssertEqual(result, .init(url: "https://jsonplaceholder.typicode.com/todos/product",
                                     headers: ["key1": "value1"],
                                     body: "",
                                     method: "GET"))
    }

    func test_liveRequestPlugin_InvokesPlugin() throws {
        fileManager.stubbedFileExistResult = true
        fileManager.stubbedReadFileResult = """
var config = []

function updateRequest(request) {
    var req = request
    req.url = "https://jsonplaceholder.typicode.com/todos/2"

    return req
}
"""

        XCTAssertFalse(fileUrlBuilder.invokedPluginFolderUrl)
        XCTAssertFalse(fileUrlBuilder.invokedCommonPluginFolderUrl)
        XCTAssertFalse(fileManager.invokedFileExist)
        XCTAssertFalse(fileManager.invokedReadFile)

        initPlugin()

        XCTAssertTrue(fileUrlBuilder.invokedPluginFolderUrl)
        XCTAssertTrue(fileUrlBuilder.invokedCommonPluginFolderUrl)
        XCTAssertEqual(fileUrlBuilder.invokedPluginFolderUrlCount, 5)
        XCTAssertEqual(fileUrlBuilder.invokedCommonPluginFolderUrlCount, 5)
        XCTAssertTrue(fileManager.invokedFileExist)
        XCTAssertEqual(fileManager.invokedFileExistCount, 4)
        XCTAssertTrue(fileManager.invokedReadFile)
        XCTAssertEqual(fileManager.invokedReadFileCount, 4)

        let result = try plugin.liveRequestPlugin(request: .init(url: "https://www.trendyol.com/aboutus",
                                                                 headers: ["key1": "value1"],
                                                                 body: "",
                                                                 method: "GET"))

        XCTAssertEqual(result, .init(url: "https://jsonplaceholder.typicode.com/todos/2",
                                     headers: ["key1": "value1"],
                                     body: "",
                                     method: "GET"))
    }

    func test_liveRequestPlugin_WithConfig_InvokesPlugin() throws {
        fileManager.stubbedFileExistResult = true
        fileManager.stubbedReadFileResult = """
var config = [
    {
        key: "requestPath",
        valueType: "text",
        value: ""
    }
]

function updateRequest(request) {
    var req = request
    req.url = "https://jsonplaceholder.typicode.com/todos/2" + config[0].value

    return req
}
"""

        XCTAssertFalse(fileUrlBuilder.invokedPluginFolderUrl)
        XCTAssertFalse(fileUrlBuilder.invokedCommonPluginFolderUrl)
        XCTAssertFalse(fileManager.invokedFileExist)
        XCTAssertFalse(fileManager.invokedReadFile)

        initPlugin()

        XCTAssertTrue(fileUrlBuilder.invokedPluginFolderUrl)
        XCTAssertTrue(fileUrlBuilder.invokedCommonPluginFolderUrl)
        XCTAssertEqual(fileUrlBuilder.invokedPluginFolderUrlCount, 5)
        XCTAssertEqual(fileUrlBuilder.invokedCommonPluginFolderUrlCount, 5)
        XCTAssertTrue(fileManager.invokedFileExist)
        XCTAssertEqual(fileManager.invokedFileExistCount, 4)
        XCTAssertTrue(fileManager.invokedReadFile)
        XCTAssertEqual(fileManager.invokedReadFileCount, 4)

        @UserDefaultStorage("TestStorage", userDefaults: defaults) var configStorage: [PluginConfiguration] = []
        configStorage = [
            .init(key: "requestPath",
                  valueType: .text,
                  value: AnyCodableModel("/product"))
        ]

        plugin.storage[.liveRequestUpdater] = _configStorage

        let result = try plugin.liveRequestPlugin(request: .init(url: "https://www.trendyol.com/aboutus",
                                                                 headers: ["key1": "value1"],
                                                                 body: "",
                                                                 method: "GET"))

        XCTAssertEqual(result, .init(url: "https://jsonplaceholder.typicode.com/todos/2/product",
                                     headers: ["key1": "value1"],
                                     body: "",
                                     method: "GET"))
    }

    func test_mockErrorPlugin_InvokesPlugin() throws {
        fileManager.stubbedFileExistResult = true
        fileManager.stubbedReadFileResult = """
var config = []

function defaultResponseModel(message) {
    let error = {
        message: "Error: " + message,
    }

    return JSON.stringify(error)
}
"""

        XCTAssertFalse(fileUrlBuilder.invokedPluginFolderUrl)
        XCTAssertFalse(fileUrlBuilder.invokedCommonPluginFolderUrl)
        XCTAssertFalse(fileManager.invokedFileExist)
        XCTAssertFalse(fileManager.invokedReadFile)

        initPlugin()

        XCTAssertTrue(fileUrlBuilder.invokedPluginFolderUrl)
        XCTAssertTrue(fileUrlBuilder.invokedCommonPluginFolderUrl)
        XCTAssertEqual(fileUrlBuilder.invokedPluginFolderUrlCount, 5)
        XCTAssertEqual(fileUrlBuilder.invokedCommonPluginFolderUrlCount, 5)
        XCTAssertTrue(fileManager.invokedFileExist)
        XCTAssertEqual(fileManager.invokedFileExistCount, 4)
        XCTAssertTrue(fileManager.invokedReadFile)
        XCTAssertEqual(fileManager.invokedReadFileCount, 4)

        let result = try plugin.mockErrorPlugin(message: "UnitTest")

        XCTAssertEqual(result, """
{"message":"Error: UnitTest"}
""")
    }

    func test_mockErrorPlugin_WithConfig_InvokesPlugin() throws {
        fileManager.stubbedFileExistResult = true
        fileManager.stubbedReadFileResult = """
var config = [
    {
        key: "requestPath",
        valueType: "text",
        value: ""
    }
]

function defaultResponseModel(message) {
    let error = {
        message: "Error: " + message + " " + config[0].value,
    }

    return JSON.stringify(error)
}
"""

        XCTAssertFalse(fileUrlBuilder.invokedPluginFolderUrl)
        XCTAssertFalse(fileUrlBuilder.invokedCommonPluginFolderUrl)
        XCTAssertFalse(fileManager.invokedFileExist)
        XCTAssertFalse(fileManager.invokedReadFile)

        initPlugin()

        XCTAssertTrue(fileUrlBuilder.invokedPluginFolderUrl)
        XCTAssertTrue(fileUrlBuilder.invokedCommonPluginFolderUrl)
        XCTAssertEqual(fileUrlBuilder.invokedPluginFolderUrlCount, 5)
        XCTAssertEqual(fileUrlBuilder.invokedCommonPluginFolderUrlCount, 5)
        XCTAssertTrue(fileManager.invokedFileExist)
        XCTAssertEqual(fileManager.invokedFileExistCount, 4)
        XCTAssertTrue(fileManager.invokedReadFile)
        XCTAssertEqual(fileManager.invokedReadFileCount, 4)


        @UserDefaultStorage("TestStorage", userDefaults: defaults) var configStorage: [PluginConfiguration] = []
        configStorage = [
            .init(key: "requestPath",
                  valueType: .text,
                  value: AnyCodableModel("/product"))
        ]

        plugin.storage[.mockError] = _configStorage

        let result = try plugin.mockErrorPlugin(message: "UnitTest")

        XCTAssertEqual(result, """
{"message":"Error: UnitTest /product"}
""")
    }
}
