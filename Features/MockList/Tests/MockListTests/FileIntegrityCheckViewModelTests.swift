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
    private let exp = XCTestExpectation(description: "MockListViewModelTests")
    private var mockDiscoverResult: AsyncStream<MockDiscoverResult>!
    private var mockDiscoverResultContinuation: AsyncStream<MockDiscoverResult>.Continuation!

    override func setUpWithError() throws {
        try super.setUpWithError()
        (mockDiscoverResult, mockDiscoverResultContinuation) = AsyncStream<MockDiscoverResult>.makeStream()

        fileManager = .init()
        mockDiscover = .init()
        mockDiscover.stubbedMockDiscoverResult = mockDiscoverResult

        viewModel = .init(fileManager: fileManager,
                          mockDiscover: mockDiscover)
        mockDiscoverResultContinuation.yield(.result(mockModels))
    }

    func test_searchFileViolates_isLoading() {
        XCTAssertFalse(viewModel.isLoading)

        mockDiscoverResultContinuation.yield(.loading)

        let exp = XCTestExpectation(description: "FileIntegrityCheckViewModelTests")

        Task {
            while !viewModel.isLoading {
                try? await Task.sleep(nanoseconds: 50_000_000)
            }

            exp.fulfill()
        }

        wait(for: [exp], timeout: 10)
        XCTAssertTrue(viewModel.isLoading)
    }

    func test_searchFileViolates_NoResult() async {
        XCTAssertEqual(viewModel.violatedMocks.count, 0)

        await viewModel.searchFileViolates("Dev")
        mockDiscoverResultContinuation.yield(.result(mockModels))

        while viewModel.violatedMocks.isEmpty {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        XCTAssertEqual(viewModel.violatedMocks.count, 2)
    }

    func test_fixViolations_InvokesNecessaryMethods() {
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(fileManager.invokedMoveFile)
        XCTAssertFalse(fileManager.invokedUpdateFileContent)

        mockDiscoverResultContinuation.yield(.result(mockModels))

        let exp = XCTestExpectation(description: "FileIntegrityCheckViewModelTests")

        Task {
            while viewModel.violatedMocks.isEmpty {
                try? await Task.sleep(nanoseconds: 50_000_000)
            }

            exp.fulfill()
        }

        wait(for: [exp], timeout: 10)

        viewModel.fixViolations()


        XCTAssertFalse(viewModel.isLoading)
        XCTAssertTrue(fileManager.invokedMoveFile)
        XCTAssertTrue(fileManager.invokedUpdateFileContent)
        XCTAssertEqual(fileManager.invokedMoveFileParametersList.map(\.path), ["/foo/bar/file/path/mock.json", "/MockServerDomains//Mocks/product/102030/PUT/product+102030_EmptyCase_9271C0BE-9326-443F-97B8-1ECA29571FC3.json"])
        XCTAssertEqual(fileManager.invokedMoveFileParametersList.map(\.newPath).count, 2)
        XCTAssertEqual(fileManager.invokedUpdateFileContentParametersList.map(\.path), ["/MockServerDomains//Mocks/product/102030/PUT/product+102030_EmptyCase_9271C0BE-9326-443F-97B8-1ECA29571FC3.json"])
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
