//
//  MockDetailInspectorViewModelTests.swift
//  
//
//  Created by Yusuf Özgül on 4.12.2023.
//

@testable import MockDetail
import CommonKit
import XCTest
import PluginCoreTestSupport

final class MockDetailInspectorViewModelTests: XCTestCase {
    private var viewModel: MockDetailInspectorViewModel!
    private var pluginCore: MockPluginCoreActor!

    override func setUpWithError() throws {
        try super.setUpWithError()

        pluginCore = .init()

        let url = try XCTUnwrap(URL(string: "https://www.trendyol.com/aboutus"))
        let model = MockModel(metaData: .init(url: url,
                                              method: "GET",
                                              appendTime: .init(),
                                              updateTime: .init(),
                                              httpStatus: 200,
                                              responseTime: 0.15,
                                              scenario: "EmptyCase",
                                              id: "9271C0BE-9326-443F-97B8-1ECA29571FC3"),
                              requestHeader: "",
                              responseHeader: "",
                              requestBody: .init(""),
                              responseBody: .init(""))
        model.fileURL = URL(filePath: "/foo/bar/file/path/mock.json")

        viewModel = .init(mockDomain: "Test",
                          mockModel: model,
                          onChange: {},
                          pluginCoreActor: pluginCore)
    }

    func test_sync_SyncModel() {
        viewModel.scenario = "scenario"
        viewModel.httpStatus = 101
        viewModel.responseTime = 10

        XCTAssertEqual(viewModel.mockModel.metaData.scenario, "EmptyCase")
        XCTAssertEqual(viewModel.mockModel.metaData.httpStatus, 200)
        XCTAssertEqual(viewModel.mockModel.metaData.responseTime, 0.15)

        viewModel.sync()

        XCTAssertEqual(viewModel.mockModel.metaData.scenario, "scenario")
        XCTAssertEqual(viewModel.mockModel.metaData.httpStatus, 101)
        XCTAssertEqual(viewModel.mockModel.metaData.responseTime, 10.0)
    }

    func test_loadPluginMessage_InvokesPlugins() async {
        let plugin = MockPlugin()
        pluginCore.stubbedPluginCoreResult = plugin
        plugin.stubbedMockDetailMessagePluginResult = "Test Sync"

        XCTAssertFalse(pluginCore.invokedPluginCore)

        await viewModel.loadPluginMessage()

        XCTAssertTrue(pluginCore.invokedPluginCore)
        XCTAssertEqual(pluginCore.invokedPluginCoreParametersList.map(\.mockDomain), ["Test"])
        XCTAssertEqual(viewModel.pluginMessages, ["Test Sync"])
    }

    func test_loadPluginMessage_WithAsyncPlugin_InvokesPlugins() async {
        let plugin = MockPlugin()
        pluginCore.stubbedPluginCoreResult = plugin
        plugin.stubbedMockDetailMessagePluginResult = "Test Sync"
        plugin.stubbedAsyncMockDetailMessagePluginResult = "Test Async"

        XCTAssertFalse(pluginCore.invokedPluginCore)

        await viewModel.loadPluginMessage(shouldLoadAsync: true)

        XCTAssertTrue(pluginCore.invokedPluginCore)
        XCTAssertEqual(pluginCore.invokedPluginCoreParametersList.map(\.mockDomain), ["Test"])
        XCTAssertEqual(viewModel.pluginMessages, ["Test Sync", "Test Async"])
    }
}
