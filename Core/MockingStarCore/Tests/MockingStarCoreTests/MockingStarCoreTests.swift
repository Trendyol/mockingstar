import XCTest
import CommonKit
import CommonKitTestSupport
import MockingStarCoreTestSupport
@testable import MockingStarCore
import Foundation

final class MockingStarCoreTests: XCTestCase {
    private var mockingStarCore: MockingStarCore!
    
    override func setUp() {
        super.setUp()
        mockingStarCore = MockingStarCore()
    }
    
    override func tearDown() {
        mockingStarCore = nil
        super.tearDown()
    }
    
    // MARK: - executeMockFilterForShouldSave Tests
    
    func test_executeMockFilterForShouldSave_EmptyFilters_ReturnsTrue() {
        // Given
        let request = createURLRequest(path: "/api/users", method: "GET")
        let mockFilters: [MockFilterConfigModel] = []
        
        // When
        let result = mockingStarCore.executeMockFilterForShouldSave(
            for: request,
            scenario: "test",
            statusCode: 200,
            mockFilters: mockFilters
        )
        
        // Then
        XCTAssertTrue(result)
    }
    
    func test_executeMockFilterForShouldSave_SingleFilterMockAction_MatchingFilter_ReturnsTrue() {
        // Given
        let request = createURLRequest(path: "/api/users", method: "GET")
        let mockFilters = [
            MockFilterConfigModel(
                selectedLocation: .path,
                selectedFilter: .contains,
                inputText: "users",
                logicType: .mock
            )
        ]
        
        // When
        let result = mockingStarCore.executeMockFilterForShouldSave(
            for: request,
            scenario: "test",
            statusCode: 200,
            mockFilters: mockFilters
        )
        
        // Then
        XCTAssertTrue(result)
    }
    
    func test_executeMockFilterForShouldSave_SingleFilterMockAction_NotMatchingFilter_ReturnsFalse() {
        // Given
        let request = createURLRequest(path: "/api/products", method: "GET")
        let mockFilters = [
            MockFilterConfigModel(
                selectedLocation: .path,
                selectedFilter: .contains,
                inputText: "users",
                logicType: .mock
            )
        ]
        
        // When
        let result = mockingStarCore.executeMockFilterForShouldSave(
            for: request,
            scenario: "test",
            statusCode: 200,
            mockFilters: mockFilters
        )
        
        // Then
        XCTAssertFalse(result)
    }
    
    func test_executeMockFilterForShouldSave_SingleFilterDoNotMockAction_MatchingFilter_ReturnsFalse() {
        // Given
        let request = createURLRequest(path: "/api/users", method: "GET")
        let mockFilters = [
            MockFilterConfigModel(
                selectedLocation: .path,
                selectedFilter: .contains,
                inputText: "users",
                logicType: .doNotMock
            )
        ]
        
        // When
        let result = mockingStarCore.executeMockFilterForShouldSave(
            for: request,
            scenario: "test",
            statusCode: 200,
            mockFilters: mockFilters
        )
        
        // Then
        XCTAssertFalse(result)
    }
    
    func test_executeMockFilterForShouldSave_SingleFilterDoNotMockAction_NotMatchingFilter_ReturnsTrue() {
        // Given
        let request = createURLRequest(path: "/api/products", method: "GET")
        let mockFilters = [
            MockFilterConfigModel(
                selectedLocation: .path,
                selectedFilter: .contains,
                inputText: "users",
                logicType: .doNotMock
            )
        ]
        
        // When
        let result = mockingStarCore.executeMockFilterForShouldSave(
            for: request,
            scenario: "test",
            statusCode: 200,
            mockFilters: mockFilters
        )
        
        // Then
        XCTAssertTrue(result)
    }
    
    func test_executeMockFilterForShouldSave_MultipleFiltersWithAndLogic_AllMatching_ReturnsTrue() {
        // Given
        let request = createURLRequest(path: "/api/users", method: "GET", query: "page=1")
        let mockFilters = [
            MockFilterConfigModel(
                selectedLocation: .path,
                selectedFilter: .contains,
                inputText: "users",
                logicType: .or
            ),
            MockFilterConfigModel(
                selectedLocation: .query,
                selectedFilter: .contains,
                inputText: "page",
                logicType: .and
            ),
            MockFilterConfigModel(
                selectedLocation: .method,
                selectedFilter: .equal,
                inputText: "GET",
                logicType: .mock
            )
        ]
        
        // When
        let result = mockingStarCore.executeMockFilterForShouldSave(
            for: request,
            scenario: "test",
            statusCode: 200,
            mockFilters: mockFilters
        )
        
        // Then
        XCTAssertTrue(result)
    }
    
    func test_executeMockFilterForShouldSave_MultipleFiltersWithAndLogic_OneNotMatching_ReturnsFalse() {
        // Given
        let request = createURLRequest(path: "/api/users", method: "GET", query: "page=1")
        let mockFilters = [
            MockFilterConfigModel(
                selectedLocation: .path,
                selectedFilter: .contains,
                inputText: "users",
                logicType: .and
            ),
            MockFilterConfigModel(
                selectedLocation: .query,
                selectedFilter: .contains,
                inputText: "nonexistent",
                logicType: .and
            ),
            MockFilterConfigModel(
                selectedLocation: .method,
                selectedFilter: .equal,
                inputText: "GET",
                logicType: .mock
            )
        ]
        
        // When
        let result = mockingStarCore.executeMockFilterForShouldSave(
            for: request,
            scenario: "test",
            statusCode: 200,
            mockFilters: mockFilters
        )
        
        // Then
        XCTAssertFalse(result)
    }
    
    func test_executeMockFilterForShouldSave_MultipleFiltersWithOrLogic_OneMatching_ReturnsTrue() {
        // Given
        let request = createURLRequest(path: "/api/products", method: "POST")
        let mockFilters = [
            MockFilterConfigModel(
                selectedLocation: .path,
                selectedFilter: .contains,
                inputText: "users",
                logicType: .or
            ),
            MockFilterConfigModel(
                selectedLocation: .method,
                selectedFilter: .equal,
                inputText: "POST",
                logicType: .or
            ),
            MockFilterConfigModel(
                selectedLocation: .path,
                selectedFilter: .contains,
                inputText: "nonexistent",
                logicType: .mock
            )
        ]
        
        // When
        let result = mockingStarCore.executeMockFilterForShouldSave(
            for: request,
            scenario: "test",
            statusCode: 200,
            mockFilters: mockFilters
        )
        
        // Then
        XCTAssertTrue(result)
    }
    
    // MARK: - mockFilterResult Tests
    
    func test_mockFilterResult_FilterLocationAll_ContainsPath_ReturnsTrue() {
        // Given
        let request = createURLRequest(path: "/api/users", method: "GET")
        let filter = MockFilterConfigModel(
            selectedLocation: .all,
            selectedFilter: .contains,
            inputText: "users",
            logicType: .or
        )
        
        // When
        let result = mockingStarCore.mockFilterResult(
            filter,
            request: request,
            scenario: "test",
            statusCode: 200
        )
        
        // Then
        XCTAssertTrue(result)
    }
    
    func test_mockFilterResult_FilterLocationAll_ContainsQuery_ReturnsTrue() {
        // Given
        let request = createURLRequest(path: "/api/data", method: "GET", query: "page=1&size=10")
        let filter = MockFilterConfigModel(
            selectedLocation: .all,
            selectedFilter: .contains,
            inputText: "page",
            logicType: .or
        )
        
        // When
        let result = mockingStarCore.mockFilterResult(
            filter,
            request: request,
            scenario: "test",
            statusCode: 200
        )
        
        // Then
        XCTAssertTrue(result)
    }
    
    func test_mockFilterResult_FilterLocationAll_ContainsScenario_ReturnsTrue() {
        // Given
        let request = createURLRequest(path: "/api/data", method: "GET")
        let filter = MockFilterConfigModel(
            selectedLocation: .all,
            selectedFilter: .contains,
            inputText: "production",
            logicType: .or
        )
        
        // When
        let result = mockingStarCore.mockFilterResult(
            filter,
            request: request,
            scenario: "production-scenario",
            statusCode: 200
        )
        
        // Then
        XCTAssertTrue(result)
    }
    
    func test_mockFilterResult_FilterLocationAll_ContainsMethod_ReturnsTrue() {
        // Given
        let request = createURLRequest(path: "/api/data", method: "POST")
        let filter = MockFilterConfigModel(
            selectedLocation: .all,
            selectedFilter: .contains,
            inputText: "POST",
            logicType: .or
        )
        
        // When
        let result = mockingStarCore.mockFilterResult(
            filter,
            request: request,
            scenario: "test",
            statusCode: 200
        )
        
        // Then
        XCTAssertTrue(result)
    }
    
    func test_mockFilterResult_FilterLocationAll_ContainsStatusCode_ReturnsTrue() {
        // Given
        let request = createURLRequest(path: "/api/data", method: "GET")
        let filter = MockFilterConfigModel(
            selectedLocation: .all,
            selectedFilter: .contains,
            inputText: "201",
            logicType: .or
        )
        
        // When
        let result = mockingStarCore.mockFilterResult(
            filter,
            request: request,
            scenario: "test",
            statusCode: 201
        )
        
        // Then
        XCTAssertTrue(result)
    }
    
    func test_mockFilterResult_FilterLocationPath_Contains_ReturnsTrue() {
        // Given
        let request = createURLRequest(path: "/api/users/123", method: "GET")
        let filter = MockFilterConfigModel(
            selectedLocation: .path,
            selectedFilter: .contains,
            inputText: "users",
            logicType: .or
        )
        
        // When
        let result = mockingStarCore.mockFilterResult(
            filter,
            request: request,
            scenario: "test",
            statusCode: 200
        )
        
        // Then
        XCTAssertTrue(result)
    }
    
    func test_mockFilterResult_FilterLocationPath_NotContains_ReturnsTrue() {
        // Given
        let request = createURLRequest(path: "/api/products/456", method: "GET")
        let filter = MockFilterConfigModel(
            selectedLocation: .path,
            selectedFilter: .notContains,
            inputText: "users",
            logicType: .or
        )
        
        // When
        let result = mockingStarCore.mockFilterResult(
            filter,
            request: request,
            scenario: "test",
            statusCode: 200
        )
        
        // Then
        XCTAssertTrue(result)
    }
    
    func test_mockFilterResult_FilterLocationPath_StartsWith_ReturnsTrue() {
        // Given
        let request = createURLRequest(path: "/api/users/123", method: "GET")
        let filter = MockFilterConfigModel(
            selectedLocation: .path,
            selectedFilter: .startWith,
            inputText: "/api",
            logicType: .or
        )
        
        // When
        let result = mockingStarCore.mockFilterResult(
            filter,
            request: request,
            scenario: "test",
            statusCode: 200
        )
        
        // Then
        XCTAssertTrue(result)
    }
    
    func test_mockFilterResult_FilterLocationPath_EndsWith_ReturnsTrue() {
        // Given
        let request = createURLRequest(path: "/api/users/profile", method: "GET")
        let filter = MockFilterConfigModel(
            selectedLocation: .path,
            selectedFilter: .endWith,
            inputText: "profile",
            logicType: .or
        )
        
        // When
        let result = mockingStarCore.mockFilterResult(
            filter,
            request: request,
            scenario: "test",
            statusCode: 200
        )
        
        // Then
        XCTAssertTrue(result)
    }
    
    func test_mockFilterResult_FilterLocationPath_Equal_ReturnsTrue() {
        // Given
        let request = createURLRequest(path: "/api/users", method: "GET")
        let filter = MockFilterConfigModel(
            selectedLocation: .path,
            selectedFilter: .equal,
            inputText: "/api/users",
            logicType: .or
        )
        
        // When
        let result = mockingStarCore.mockFilterResult(
            filter,
            request: request,
            scenario: "test",
            statusCode: 200
        )
        
        // Then
        XCTAssertTrue(result)
    }
    
    func test_mockFilterResult_FilterLocationPath_NotEqual_ReturnsTrue() {
        // Given
        let request = createURLRequest(path: "/api/users", method: "GET")
        let filter = MockFilterConfigModel(
            selectedLocation: .path,
            selectedFilter: .notEqual,
            inputText: "/api/products",
            logicType: .or
        )
        
        // When
        let result = mockingStarCore.mockFilterResult(
            filter,
            request: request,
            scenario: "test",
            statusCode: 200
        )
        
        // Then
        XCTAssertTrue(result)
    }
    
    func test_mockFilterResult_FilterLocationQuery_Contains_ReturnsTrue() {
        // Given
        let request = createURLRequest(path: "/api/search", method: "GET", query: "q=swift&category=programming")
        let filter = MockFilterConfigModel(
            selectedLocation: .query,
            selectedFilter: .contains,
            inputText: "swift",
            logicType: .or
        )
        
        // When
        let result = mockingStarCore.mockFilterResult(
            filter,
            request: request,
            scenario: "test",
            statusCode: 200
        )
        
        // Then
        XCTAssertTrue(result)
    }
    
    func test_mockFilterResult_FilterLocationQuery_NotContains_ReturnsTrue() {
        // Given
        let request = createURLRequest(path: "/api/search", method: "GET", query: "q=swift&category=programming")
        let filter = MockFilterConfigModel(
            selectedLocation: .query,
            selectedFilter: .notContains,
            inputText: "python",
            logicType: .or
        )
        
        // When
        let result = mockingStarCore.mockFilterResult(
            filter,
            request: request,
            scenario: "test",
            statusCode: 200
        )
        
        // Then
        XCTAssertTrue(result)
    }
    
    func test_mockFilterResult_FilterLocationScenario_Equal_ReturnsTrue() {
        // Given
        let request = createURLRequest(path: "/api/data", method: "GET")
        let filter = MockFilterConfigModel(
            selectedLocation: .scenario,
            selectedFilter: .equal,
            inputText: "production",
            logicType: .or
        )
        
        // When
        let result = mockingStarCore.mockFilterResult(
            filter,
            request: request,
            scenario: "production",
            statusCode: 200
        )
        
        // Then
        XCTAssertTrue(result)
    }
    
    func test_mockFilterResult_FilterLocationMethod_Equal_ReturnsTrue() {
        // Given
        let request = createURLRequest(path: "/api/data", method: "DELETE")
        let filter = MockFilterConfigModel(
            selectedLocation: .method,
            selectedFilter: .equal,
            inputText: "DELETE",
            logicType: .or
        )
        
        // When
        let result = mockingStarCore.mockFilterResult(
            filter,
            request: request,
            scenario: "test",
            statusCode: 200
        )
        
        // Then
        XCTAssertTrue(result)
    }
    
    func test_mockFilterResult_FilterLocationStatusCode_Equal_ReturnsTrue() {
        // Given
        let request = createURLRequest(path: "/api/data", method: "GET")
        let filter = MockFilterConfigModel(
            selectedLocation: .statusCode,
            selectedFilter: .equal,
            inputText: "404",
            logicType: .or
        )
        
        // When
        let result = mockingStarCore.mockFilterResult(
            filter,
            request: request,
            scenario: "test",
            statusCode: 404
        )
        
        // Then
        XCTAssertTrue(result)
    }
    
    func test_mockFilterResult_FilterLocationStatusCode_NotEqual_ReturnsTrue() {
        // Given
        let request = createURLRequest(path: "/api/data", method: "GET")
        let filter = MockFilterConfigModel(
            selectedLocation: .statusCode,
            selectedFilter: .notEqual,
            inputText: "500",
            logicType: .or
        )
        
        // When
        let result = mockingStarCore.mockFilterResult(
            filter,
            request: request,
            scenario: "test",
            statusCode: 200
        )
        
        // Then
        XCTAssertTrue(result)
    }
    
    func test_mockFilterResult_CaseInsensitiveComparison_ReturnsTrue() {
        // Given
        let request = createURLRequest(path: "/API/USERS", method: "get")
        let filter = MockFilterConfigModel(
            selectedLocation: .path,
            selectedFilter: .contains,
            inputText: "users",
            logicType: .or
        )
        
        // When
        let result = mockingStarCore.mockFilterResult(
            filter,
            request: request,
            scenario: "TEST",
            statusCode: 200
        )
        
        // Then
        XCTAssertTrue(result)
    }
    
    func test_mockFilterResult_NoMatchingItems_ReturnsFalse() {
        // Given
        let request = createURLRequest(path: "/api/products", method: "GET")
        let filter = MockFilterConfigModel(
            selectedLocation: .path,
            selectedFilter: .contains,
            inputText: "nonexistent",
            logicType: .or
        )
        
        // When
        let result = mockingStarCore.mockFilterResult(
            filter,
            request: request,
            scenario: "test",
            statusCode: 200
        )
        
        // Then
        XCTAssertFalse(result)
    }
    
    // MARK: - Complex Scenarios Tests
    
    func test_executeMockFilterForShouldSave_ComplexMultipleFiltersScenario() {
        // Given
        let request = createURLRequest(path: "/api/users/profile", method: "PUT", query: "version=v2")
        let mockFilters = [
            // First condition: path contains "users"
            MockFilterConfigModel(
                selectedLocation: .path,
                selectedFilter: .contains,
                inputText: "users",
                logicType: .or
            ),
            // AND operator
            MockFilterConfigModel(
                selectedLocation: .method,
                selectedFilter: .equal,
                inputText: "PUT",
                logicType: .and
            ),
            // OR operator
            MockFilterConfigModel(
                selectedLocation: .query,
                selectedFilter: .contains,
                inputText: "version",
                logicType: .or
            ),
            // AND operator
            MockFilterConfigModel(
                selectedLocation: .statusCode,
                selectedFilter: .equal,
                inputText: "200",
                logicType: .and
            ),
            // Final action: mock
            MockFilterConfigModel(
                selectedLocation: .all,
                selectedFilter: .contains,
                inputText: "2",
                logicType: .mock
            )
        ]
        
        // When
        let result = mockingStarCore.executeMockFilterForShouldSave(
            for: request,
            scenario: "production",
            statusCode: 200,
            mockFilters: mockFilters
        )
        
        // Then
        XCTAssertTrue(result)
    }
    
    func test_executeMockFilterForShouldSave_ComplexMultipleFiltersScenario_DoNotMock() {
        // Given
        let request = createURLRequest(path: "/api/admin/settings", method: "DELETE")
        let mockFilters = [
            // Condition: path contains "admin"
            MockFilterConfigModel(
                selectedLocation: .path,
                selectedFilter: .contains,
                inputText: "admin",
                logicType: .or
            ),
            // OR operator
            MockFilterConfigModel(
                selectedLocation: .method,
                selectedFilter: .equal,
                inputText: "DELETE",
                logicType: .or
            ),
            // Final action: do not mock
            MockFilterConfigModel(
                selectedLocation: .all,
                selectedFilter: .contains,
                inputText: "",
                logicType: .doNotMock
            )
        ]
        
        // When
        let result = mockingStarCore.executeMockFilterForShouldSave(
            for: request,
            scenario: "test",
            statusCode: 200,
            mockFilters: mockFilters
        )
        
        // Then
        XCTAssertFalse(result) // Should not mock because condition matches and action is doNotMock
    }
    
    // MARK: - Helper Methods
    
    private func createURLRequest(path: String, method: String = "GET", query: String? = nil) -> URLRequest {
        var urlString = "https://api.example.com\(path)"
        if let query = query {
            urlString += "?\(query)"
        }
        
        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = method
        return request
    }
}


