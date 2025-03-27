//
//  FileUrlBuilderTests.swift
//  
//
//  Created by Yusuf Özgül on 2.09.2023.
//

import XCTest
import CommonKitTestSupport
@testable import CommonKit

final class FileUrlBuilderTests: XCTestCase {
    private var builder: FileUrlBuilder!
    private let defaults = UserDefaults()

    override func setUp() {
        super.setUp()

        @UserDefaultStorage("workspaces", userDefaults: defaults) var workspaces: [Workspace] = []
        workspaces = [Workspace(name: "Workspace", path: "/MockServer/", bookmark: Data())]

        builder = FileUrlBuilder()
    }

    override func tearDown() {
        super.tearDown()
        defaults.dictionaryRepresentation().keys.forEach(defaults.removeObject(forKey:))
    }

    func test_mocksFolderUrl_ReturnsMocksFolderUrl() throws {
        let url = try builder.mocksFolderUrl(for: "LocalDevelopment")
        XCTAssertEqual(url, URL(string: "/MockServer/Domains/LocalDevelopment/Mocks"))
    }

    func test_configsFolderUrl_ReturnsConfigsFolderUrl() throws {
        let url = try builder.configsFolderUrl(for: "LocalDevelopment")
        XCTAssertEqual(url, URL(filePath: "/MockServer/Domains/LocalDevelopment/Configs"))
    }
}
