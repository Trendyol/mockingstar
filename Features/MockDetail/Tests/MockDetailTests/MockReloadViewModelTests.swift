//
//  MockReloadViewModelTests.swift
//  
//
//  Created by Yusuf Özgül on 4.12.2023.
//

@testable import MockDetail
import CommonKit
import XCTest
import PluginCoreTestSupport
import CommonKitTestSupport
import CommonViewsKitTestSupport

final class MockReloadViewModelTests: XCTestCase {
    private var viewModel: MockReloadViewModel!
    private var pluginCore: MockPluginCoreActor!
    private var urlSession: MockURLSession!
    private var pasteBoard: MockNSPasteboard!
    private var notificationManager: MockNotificationManager!

    override func setUpWithError() throws {
        try super.setUpWithError()

        pluginCore = .init()
        urlSession = .init()
        pasteBoard = .init()
        notificationManager = .init()

        let url = try XCTUnwrap(URL(string: "https://www.trendyol.com/aboutus"))
        let model = MockModel(metaData: .init(url: url,
                                              method: "GET",
                                              appendTime: .init(),
                                              updateTime: .init(),
                                              httpStatus: 200,
                                              responseTime: 0.15,
                                              scenario: "EmptyCase",
                                              id: "9271C0BE-9326-443F-97B8-1ECA29571FC3"),
                              requestHeader: "{}",
                              responseHeader: "",
                              requestBody: .init(""),
                              responseBody: .init(""))
        model.fileURL = URL(filePath: "/foo/bar/file/path/mock.json")

        viewModel = .init(mockModel: model,
                          mockDomain: "Test",
                          pluginCoreActor: pluginCore,
                          urlSession: urlSession,
                          pasteBoard: pasteBoard,
                          notificationManager: notificationManager)

    }

    func test_updatedRequest_ReturnsRequest() async {
        let plugin = MockPlugin()
        pluginCore.stubbedPluginCoreResult = plugin
        plugin.stubbedRequestReloaderPluginResult = .init(url: "https://www.trendyol.com",
                                                          headers: ["version": "1.0.0"],
                                                          body: "BodyTest123",
                                                          method: "HEAD")
        await viewModel.loadPlugin()

        XCTAssertFalse(plugin.invokedRequestReloaderPlugin)

        let request = viewModel.updatedRequest()

        XCTAssertEqual(request.url?.absoluteString, "https://www.trendyol.com")
        XCTAssertEqual(request.allHTTPHeaderFields, ["version": "1.0.0"])
        XCTAssertEqual(request.httpBody, "BodyTest123".data(using: .utf8))
        XCTAssertEqual(request.httpMethod, "HEAD")
    }

    func test_reloadMock_ReloadsMock() async throws {
        let url = try XCTUnwrap(URL(string: "https://www.trendyol.com/"))

        urlSession.stubbedDataResult = ("Hello".data(using: .utf8)!,
                                        HTTPURLResponse(url: url,
                                                        statusCode: 200,
                                                        httpVersion: "1.1",
                                                        headerFields: [:])!)

        XCTAssertFalse(urlSession.invokedData)
        XCTAssertFalse(viewModel.isMockReloadingProgress)
        XCTAssertEqual(viewModel.mockReloadSelectedInspectorState, .requestSummary)

        await viewModel.reloadMock()

        XCTAssertTrue(urlSession.invokedData)
        XCTAssertFalse(viewModel.isMockReloadingProgress)
        XCTAssertEqual(urlSession.invokedDataParametersList.map(\.request.url?.absoluteString), ["https://www.trendyol.com/aboutus"])
        XCTAssertEqual(urlSession.invokedDataParametersList.map(\.request.allHTTPHeaderFields), [[:]])
        XCTAssertEqual(urlSession.invokedDataParametersList.map(\.request.httpMethod), ["GET"])
        XCTAssertEqual(urlSession.invokedDataParametersList.map(\.request.httpBody), [nil])
        XCTAssertEqual(viewModel.mockReloadSelectedInspectorState, .response)
    }

    func test_shareButtonTapped_Curl_CopyExport() {
        pasteBoard.stubbedClearContentsResult = 0
        pasteBoard.stubbedSetStringResult = true

        XCTAssertFalse(pasteBoard.invokedClearContents)
        XCTAssertFalse(pasteBoard.invokedSetString)
        XCTAssertFalse(notificationManager.invokedShow)

        viewModel.shareButtonTapped(shareStyle: .curl)

        XCTAssertTrue(pasteBoard.invokedClearContents)
        XCTAssertTrue(pasteBoard.invokedSetString)
        XCTAssertTrue(notificationManager.invokedShow)
        XCTAssertEqual(pasteBoard.invokedSetStringParametersList.map(\.string), ["curl --request GET \\\n--url \'https://www.trendyol.com/aboutus\' \\\n"])
        XCTAssertEqual(pasteBoard.invokedSetStringParametersList.map(\.dataType), [.string])
        XCTAssertEqual(notificationManager.invokedShowParametersList.map(\.title), ["Request copied to clipboard"])
        XCTAssertEqual(notificationManager.invokedShowParametersList.map(\.color), [.green])
    }

    func test_loadPlugin_InvokesPluginCoreActor() async {
        pluginCore.stubbedPluginCoreResult = MockPlugin()

        XCTAssertFalse(pluginCore.invokedPluginCore)

        await viewModel.loadPlugin()

        XCTAssertTrue(pluginCore.invokedPluginCore)
        XCTAssertEqual(pluginCore.invokedPluginCoreParametersList.map(\.mockDomain), ["Test"])
    }
}
