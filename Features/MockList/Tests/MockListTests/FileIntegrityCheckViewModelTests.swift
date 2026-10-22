//
//  FileIntegrityCheckViewModelTests.swift
//  MockList
//
//  Created by Yusuf Özgül on 10.03.2025.
//

@testable import MockList
import CommonKit
import CommonKitTestSupport
import CommonViewsKitTestSupport
import MockingStarCore
import MockingStarCoreTestSupport
import XCTest

final class FileIntegrityCheckViewModelTests: XCTestCase {
    private var viewModel: FileIntegrityCheckViewModel!
    private var fileManager: MockFileManager!
    private var mockDiscover: MockMockDiscover!
    private var mockDiscoverResult: AsyncStream<MockDiscoverResult>!
    private var mockDiscoverResultContinuation: AsyncStream<MockDiscoverResult>.Continuation!

    override func setUp() async throws {
        try await super.setUp()
        (mockDiscoverResult, mockDiscoverResultContinuation) = AsyncStream<MockDiscoverResult>.makeStream()

        fileManager = .init()
        mockDiscover = .init()
        mockDiscover.stubbedMockDiscoverResult = mockDiscoverResult
        fileManager.stubbedReadJSONFileWithUserInfoError = NSError(domain: "", code: -2)

        viewModel = .init(fileManager: fileManager,
                          mockDiscover: mockDiscover)
        mockDiscoverResultContinuation.yield(.loading)
        await waitUntil { self.viewModel.isLoading }
        mockDiscoverResultContinuation.yield(.result(mockModels))
        await waitUntil { !self.viewModel.isLoading }
        XCTAssertEqual(fileManager.invokedReadJSONFileWithUserInfoCount, mockModels.count)
    }

    override func tearDown() async throws {
        mockDiscoverResultContinuation.finish()
        try await super.tearDown()
    }

    func test_searchFileViolates_isLoading() async {
        XCTAssertFalse(viewModel.isLoading)

        mockDiscoverResultContinuation.yield(.loading)
        await waitUntil { self.viewModel.isLoading }

        XCTAssertTrue(viewModel.isLoading)
    }

    func test_searchFileViolates_NoResult() async {
        await viewModel.searchFileViolates("Dev")
        XCTAssertEqual(viewModel.violatedMocks.count, 0)

        mockDiscoverResultContinuation.yield(.result(mockModels))
        await waitUntil { !self.viewModel.isLoading }

        XCTAssertEqual(viewModel.violatedMocks.count, 2)
    }

    func test_fixViolations_InvokesNecessaryMethods() {
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(fileManager.invokedMoveFile)
        XCTAssertFalse(fileManager.invokedUpdateFileContent)
        XCTAssertFalse(viewModel.violatedMocks.isEmpty)

        viewModel.fixViolations()

        XCTAssertFalse(viewModel.isLoading)
        XCTAssertTrue(fileManager.invokedMoveFile)
        XCTAssertTrue(fileManager.invokedUpdateFileContent)
        XCTAssertEqual(fileManager.invokedMoveFileParametersList.map(\.path), ["/foo/bar/file/path/mock.json", "/MockServerDomains//Mocks/product/102030/PUT/product+102030_EmptyCase_9271C0BE-9326-443F-97B8-1ECA29571FC3.json"])
        XCTAssertEqual(fileManager.invokedMoveFileParametersList.map(\.newPath).count, 2)
        XCTAssertEqual(fileManager.invokedUpdateFileContentParametersList.map(\.path), ["/MockServerDomains//Mocks/product/102030/PUT/product+102030_EmptyCase_9271C0BE-9326-443F-97B8-1ECA29571FC3.json"])
    }

    private func waitUntil(_ condition: @escaping () -> Bool,
                           file: StaticString = #filePath,
                           line: UInt = #line) async {
        let timeout = Date().addingTimeInterval(5)
        while !condition(), Date() < timeout {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(condition(), "Timed out waiting for file integrity check", file: file, line: line)
    }

}

extension FileIntegrityCheckViewModelTests {
    private var mockModels: [MockModel] {
        let url1 = try! XCTUnwrap(URL(string: "https://www.trendyol.com/aboutus"))
        let model1 = MockModel(metaData: .init(url: url1,
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
        model1.fileURL = URL(filePath: "/foo/bar/file/path/mock.json")

        let url2 = try! XCTUnwrap(URL(string: "https://www.trendyol.com/product/102030"))
        let model2 = MockModel(metaData: .init(url: url2,
                                               method: "PUT",
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
        model2.fileURL = URL(filePath: "/MockServerDomains//Mocks/product/102030/PUT/product+102030_EmptyCase_9271C0BE-9326-443F-97B8-1ECA29571FC3.json")

        let url3 = try! XCTUnwrap(URL(string: "https://www.trendyol.com/product/102030"))
        let model3 = MockModel(metaData: .init(url: url3,
                                               method: "PUT",
                                               appendTime: .init(),
                                               updateTime: .init(),
                                               httpStatus: 200,
                                               responseTime: 0.15,
                                               scenario: "EmptyCase",
                                               id: "9271C0BE-9326-443F-97B8-1ECA29571FC5"),
                               requestHeader: "",
                               responseHeader: "",
                               requestBody: .init(""),
                               responseBody: .init(""))
        model3.fileURL = URL(filePath: "/MockServerDomains//Mocks/product/102030/PUT/product+102030_EmptyCase_9271C0BE-9326-443F-97B8-1ECA29571FC5.json")



        return [model1, model2, model3]
    }
}
