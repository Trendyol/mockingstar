import XCTest
@testable import MockList
import CommonKit
import MockingStarCoreTestSupport

final class MockImportViewModelTests: XCTestCase {
    var viewModel: MockImportViewModel!
    var fileSaver: MockFileSaverActor!
    var mockingStarCore: MockMockingStarCore!

    override func setUp() {
        super.setUp()
        fileSaver = MockFileSaverActor()
        mockingStarCore = MockMockingStarCore()
        viewModel = MockImportViewModel(mockingStarCore: mockingStarCore, fileSaver: fileSaver)
    }
    
    override func tearDown() {
        viewModel = nil
        fileSaver = nil
        mockingStarCore = nil
        super.tearDown()
    }
    
    func test_importMock_withValidCurlCommand_importsMock() async {
        let mockDomain = "TestDomain"
        viewModel.mockImportStyle = .cURL
        viewModel.importInput = "curl https://www.example.com"
        mockingStarCore.stubbedImportMockResult = .mocked

        await viewModel.importMock(for: mockDomain)
        
        XCTAssertTrue(mockingStarCore.invokedImportMock)
        XCTAssertEqual(mockingStarCore.invokedImportMockParametersList.map(\.url.absoluteString), ["https://www.example.com"])
        XCTAssertEqual(mockingStarCore.invokedImportMockParametersList.map(\.method), ["GET"])
        XCTAssertTrue(viewModel.shouldShowImportDone)
        XCTAssertTrue(viewModel.importFailedMessage.isEmpty)
    }
    
    func test_importMock_withCurlThatCreatesAlreadyMockedRequest_showsError() async {
        let mockDomain = "TestDomain"
        viewModel.mockImportStyle = .cURL
        viewModel.importInput = "curl https://www.example.com"
        mockingStarCore.stubbedImportMockResult = .alreadyMocked
        
        await viewModel.importMock(for: mockDomain)
        
        XCTAssertTrue(mockingStarCore.invokedImportMock)
        XCTAssertFalse(viewModel.shouldShowImportDone)
        XCTAssertEqual(viewModel.importFailedMessage, "Import failed: Already mocked\nalreadyMocked")
    }
    
    func test_importMock_withCurlThatIsIgnoredByConfigs_showsError() async {
        let mockDomain = "TestDomain"
        viewModel.mockImportStyle = .cURL
        viewModel.importInput = "curl https://www.example.com"
        mockingStarCore.stubbedImportMockResult = .domainIgnoredByConfigs
        
        await viewModel.importMock(for: mockDomain)
        
        XCTAssertTrue(mockingStarCore.invokedImportMock)
        XCTAssertFalse(viewModel.shouldShowImportDone)
        XCTAssertEqual(viewModel.importFailedMessage, "Import failed: Domain ignored by configs\ndomainIgnoredByConfigs")
    }
    
    func test_importMock_withInvalidCurlCommand_showsError() async {
        let mockDomain = "TestDomain"
        viewModel.mockImportStyle = .cURL
        viewModel.importInput = "curl %&/"  // Invalid URL
        
        await viewModel.importMock(for: mockDomain)
        
        XCTAssertFalse(mockingStarCore.invokedImportMock)
        XCTAssertFalse(viewModel.shouldShowImportDone)
        XCTAssertEqual(viewModel.importFailedMessage, "Import failed: Valid URL not found. Make sure the URL starts with http:// or https://.\ninvalidURL")
    }

    func test_importMock_withValidFileContent_importsMock() async {
        let mockDomain = "TestDomain"
        viewModel.mockImportStyle = .file

        viewModel.importInput = """
{
  "metaData" : {
    "appendTime" : "28.03.2025 12:10:31",
    "httpStatus" : 200,
    "id" : "AEADEB3F-EAC1-4AF8-83CF-F284B66F08A8",
    "method" : "GET",
    "responseTime" : 0.15,
    "scenario" : "",
    "updateTime" : "28.03.2025 12:44:14",
    "url" : "https://api.github.com/search/repositories?q=Apple"
  },
  "requestBody" : null,
  "requestHeader" : {

  },
  "responseBody" : {
    "incomplete_results" : false
  },
  "responseHeader" : {
    "Accept-Ranges" : "bytes",
    "Access-Control-Allow-Origin" : "*",
    "Cache-Control" : "no-cache",
    "Content-Encoding" : "gzip"
  }
}
"""

        await viewModel.importMock(for: mockDomain)
        
        XCTAssertTrue(fileSaver.invokedSaveFile)
        XCTAssertEqual(fileSaver.invokedSaveFileParametersList.map(\.mockDomain), ["TestDomain"])
        XCTAssertTrue(viewModel.shouldShowImportDone)
        XCTAssertTrue(viewModel.importFailedMessage.isEmpty)
    }
    
    func test_importMock_withInvalidFileContent_showsError() async {
        let mockDomain = "TestDomain"
        viewModel.mockImportStyle = .file
        viewModel.importInput = "{invalid json}"
        
        await viewModel.importMock(for: mockDomain)
        
        XCTAssertFalse(fileSaver.invokedSaveFile)
        XCTAssertFalse(viewModel.shouldShowImportDone)
        XCTAssertFalse(viewModel.importFailedMessage.isEmpty)
    }
    
    func test_importMock_withFileSaverError_showsError() async {
        let mockDomain = "TestDomain"
        viewModel.mockImportStyle = .file
        
        viewModel.importInput = """
{
  "metaData" : {
    "appendTime" : "28.03.2025 12:10:31",
    "httpStatus" : 200,
    "id" : "AEADEB3F-EAC1-4AF8-83CF-F284B66F08A8",
    "method" : "GET",
    "responseTime" : 0.15,
    "scenario" : "",
    "updateTime" : "28.03.2025 12:44:14",
    "url" : "https://api.github.com/search/repositories?q=Apple"
  },
  "requestBody" : null,
  "requestHeader" : {

  },
  "responseBody" : {
    "incomplete_results" : false
  },
  "responseHeader" : {
    "Accept-Ranges" : "bytes",
    "Access-Control-Allow-Origin" : "*",
    "Cache-Control" : "no-cache",
    "Content-Encoding" : "gzip"
  }
}
"""

        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "File saving error" }
        }
        fileSaver.stubbedSaveFileError = TestError()
        
        await viewModel.importMock(for: mockDomain)
        
        XCTAssertTrue(fileSaver.invokedSaveFile)
        XCTAssertFalse(viewModel.shouldShowImportDone)
        XCTAssertFalse(viewModel.importFailedMessage.isEmpty)
        XCTAssertTrue(viewModel.importFailedMessage.contains("File saving error"))
    }
}
