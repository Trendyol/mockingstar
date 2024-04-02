//
//  MockListViewModelTests.swift
//  
//
//  Created by Yusuf Özgül on 5.12.2023.
//

@testable import MockList
import CommonKit
import CommonKitTestSupport
import MockingStarCore
import MockingStarCoreTestSupport
import XCTest

final class MockListViewModelTests: XCTestCase {
    private var viewModel: MockListViewModel!
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

    func test_handleData_IsLoading() {
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.mockModelList.isEmpty)

        mockDiscoverResultContinuation.yield(.loading)

        let exp = XCTestExpectation(description: "MockListViewModelTests")

        Task(priority: .low) {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 10)
        XCTAssertTrue(viewModel.isLoading)
        XCTAssertTrue(viewModel.mockModelList.isEmpty)
    }

    func test_searchData_NoResult() async {
        await viewModel.searchData()

        XCTAssertEqual(viewModel.mockListUIModel.count, 3)

        viewModel.searchTerm = "MockingStar"
        await viewModel.searchData()

        XCTAssertEqual(viewModel.mockListUIModel.count, 0)
    }

    func test_searchData() async {
        await viewModel.searchData()

        XCTAssertEqual(viewModel.mockListUIModel.count, 3)

        viewModel.searchTerm = "aboutus"
        await viewModel.searchData()

        XCTAssertEqual(viewModel.mockListUIModel.count, 1)
        XCTAssertEqual(viewModel.mockListUIModel.map(\.metaData.url.absoluteString), ["https://www.trendyol.com/aboutus"])
    }

    func test_searchData_EmptySearch() async {
        await viewModel.searchData()

        XCTAssertEqual(viewModel.mockListUIModel.count, 3)

        viewModel.searchTerm = ""
        await viewModel.searchData()

        XCTAssertEqual(viewModel.mockListUIModel.count, 3)
    }

    func test_searchData_FilterPath() async {
        await viewModel.searchData()

        viewModel.filterType = .path
        viewModel.searchTerm = "aboutus"
        await viewModel.searchData()

        XCTAssertEqual(viewModel.mockListUIModel.count, 1)
        XCTAssertEqual(viewModel.mockListUIModel.map(\.metaData.url.absoluteString), ["https://www.trendyol.com/aboutus"])
    }

    func test_searchData_FilterQuery() async {
        await viewModel.searchData()

        viewModel.filterType = .query
        viewModel.searchTerm = "filter=all"
        await viewModel.searchData()

        XCTAssertEqual(viewModel.mockListUIModel.count, 1)
        XCTAssertEqual(viewModel.mockListUIModel.map(\.metaData.url.absoluteString), ["https://www.trendyol.com/favorites/search?filter=all"])
    }

    func test_searchData_FilterScenario() async {
        await viewModel.searchData()

        viewModel.filterType = .scenario
        viewModel.searchTerm = "EmptyCase"
        await viewModel.searchData()

        XCTAssertEqual(viewModel.mockListUIModel.count, 3)
    }

    func test_searchData_FilterMethod() async {
        await viewModel.searchData()

        viewModel.filterType = .method
        viewModel.searchTerm = "PUT"
        await viewModel.searchData()

        XCTAssertEqual(viewModel.mockListUIModel.count, 1)
        XCTAssertEqual(viewModel.mockListUIModel.map(\.metaData.url.absoluteString), ["https://www.trendyol.com/product/102030"])
    }

    func test_searchData_FilterStatusCode() async {
        await viewModel.searchData()

        viewModel.filterType = .statusCode
        viewModel.searchTerm = "419"
        await viewModel.searchData()

        XCTAssertEqual(viewModel.mockListUIModel.count, 1)
        XCTAssertEqual(viewModel.mockListUIModel.map(\.metaData.url.absoluteString), ["https://www.trendyol.com/favorites/search?filter=all"])
    }

    func test_searchData_FilterPath_Contains() async {
        await viewModel.searchData()

        viewModel.filterType = .path
        viewModel.filterStyle = .contains
        viewModel.searchTerm = "aboutus"
        await viewModel.searchData()

        XCTAssertEqual(viewModel.mockListUIModel.count, 1)
        XCTAssertEqual(viewModel.mockListUIModel.map(\.metaData.url.absoluteString), ["https://www.trendyol.com/aboutus"])
    }

    func test_searchData_FilterPath_NotContains() async {
        await viewModel.searchData()

        viewModel.filterType = .path
        viewModel.filterStyle = .notContains
        viewModel.searchTerm = "aboutus"
        await viewModel.searchData()

        XCTAssertEqual(viewModel.mockListUIModel.count, 2)
        XCTAssertEqual(viewModel.mockListUIModel.map(\.metaData.url.absoluteString), ["https://www.trendyol.com/favorites/search?filter=all", "https://www.trendyol.com/product/102030"])
    }

    func test_searchData_FilterPath_StartWith() async {
        await viewModel.searchData()

        viewModel.filterType = .path
        viewModel.filterStyle = .startWith
        viewModel.searchTerm = "/aboutus"
        await viewModel.searchData()

        XCTAssertEqual(viewModel.mockListUIModel.count, 1)
        XCTAssertEqual(viewModel.mockListUIModel.map(\.metaData.url.absoluteString), ["https://www.trendyol.com/aboutus"])
    }

    func test_searchData_FilterPath_EndWith() async {
        await viewModel.searchData()

        viewModel.filterType = .path
        viewModel.filterStyle = .endWith
        viewModel.searchTerm = "aboutus"
        await viewModel.searchData()

        XCTAssertEqual(viewModel.mockListUIModel.count, 1)
        XCTAssertEqual(viewModel.mockListUIModel.map(\.metaData.url.absoluteString), ["https://www.trendyol.com/aboutus"])
    }

    func test_searchData_FilterPath_Equal() async {
        await viewModel.searchData()

        viewModel.filterType = .path
        viewModel.filterStyle = .equal
        viewModel.searchTerm = "/aboutus"
        await viewModel.searchData()

        XCTAssertEqual(viewModel.mockListUIModel.count, 1)
        XCTAssertEqual(viewModel.mockListUIModel.map(\.metaData.url.absoluteString), ["https://www.trendyol.com/aboutus"])
    }

    func test_searchData_FilterPath_NotEqual() async {
        await viewModel.searchData()

        viewModel.filterType = .path
        viewModel.filterStyle = .notEqual
        viewModel.searchTerm = "/aboutus"
        await viewModel.searchData()

        XCTAssertEqual(viewModel.mockListUIModel.count, 2)
        XCTAssertEqual(viewModel.mockListUIModel.map(\.metaData.url.absoluteString), ["https://www.trendyol.com/favorites/search?filter=all", "https://www.trendyol.com/product/102030"])
    }

    func test_deleteSelectedMocks_InvokesFileManager() async {
        await viewModel.searchData()

        XCTAssertFalse(fileManager.invokedRemoveFile)
        XCTAssertFalse(viewModel.shouldShowErrorMessage)
        XCTAssertEqual(viewModel.errorMessage, "")

        viewModel.selected = ["9271C0BE-9326-443F-97B8-1ECA29571FC3"]
        viewModel.deleteSelectedMocks()

        XCTAssertTrue(fileManager.invokedRemoveFile)
        XCTAssertFalse(viewModel.shouldShowErrorMessage)
        XCTAssertEqual(viewModel.errorMessage, "")
        XCTAssertEqual(fileManager.invokedRemoveFileParametersList.map(\.path), ["/foo/bar/file/path/mock.json"])
    }

    func test_deleteSelectedMocks_Failed_InvokesFileManager() async {
        fileManager.stubbedRemoveFileError = NSError(domain: "Failed", code: -1)
        await viewModel.searchData()

        XCTAssertFalse(fileManager.invokedRemoveFile)
        XCTAssertFalse(viewModel.shouldShowErrorMessage)
        XCTAssertEqual(viewModel.errorMessage, "")

        viewModel.selected = ["9271C0BE-9326-443F-97B8-1ECA29571FC3"]
        viewModel.deleteSelectedMocks()

        XCTAssertTrue(fileManager.invokedRemoveFile)
        XCTAssertTrue(viewModel.shouldShowErrorMessage)
        XCTAssertEqual(viewModel.errorMessage, """
Mock couldn't delete
Error Domain=Failed Code=-1 "(null)"
""")
        XCTAssertEqual(fileManager.invokedRemoveFileParametersList.map(\.path), ["/foo/bar/file/path/mock.json"])
    }

    func test_mockDomainChanged_InvokesMockDiscover() async {
        XCTAssertFalse(mockDiscover.invokedUpdateMockDomain)

        await viewModel.mockDomainChanged("New Domain")

        XCTAssertTrue(mockDiscover.invokedUpdateMockDomain)
        XCTAssertEqual(mockDiscover.invokedUpdateMockDomainParametersList.map(\.mockDomain), ["New Domain"])
    }
}

extension MockListViewModelTests {
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

        let url2 = try! XCTUnwrap(URL(string: "https://www.trendyol.com/favorites/search?filter=all"))
        let model2 = MockModel(metaData: .init(url: url2,
                                               method: "POST",
                                               appendTime: .init(),
                                               updateTime: .init(),
                                               httpStatus: 419,
                                               responseTime: 0.15,
                                               scenario: "EmptyCase",
                                               id: "9271C0BE-9326-443F-97B8-1ECA29571FC4"),
                               requestHeader: "",
                               responseHeader: "",
                               requestBody: .init(""),
                               responseBody: .init(""))
        model2.fileURL = URL(filePath: "/foo/bar/file/path/mock.json")

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
        model3.fileURL = URL(filePath: "/foo/bar/file/path/mock.json")



        return [model1, model2, model3]
    }
}
