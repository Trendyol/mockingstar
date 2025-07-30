import XCTest
import Foundation
@testable import MockingStarCore

final class URLExtensionTests: XCTestCase {
    
    // MARK: - Normal Path Tests (under 256 characters)
    func testScenario_normalPathWithScenario() {
        let url = URL(fileURLWithPath: "/Users/test/MocksFolder/Dev/Mocks/about-us/GET/about-us_test-scenario_12345.json")
        
        XCTAssertEqual(url.scenario, "test-scenario")
        XCTAssertTrue(url.hasScenario)
    }
    
    func testScenario_normalPathWithoutScenario() {
        let url = URL(fileURLWithPath: "/Users/test/MocksFolder/Dev/Mocks/about-us/GET/about-us_12345.json")
        
        XCTAssertNil(url.scenario)
        XCTAssertFalse(url.hasScenario)
    }
    
    func testScenario_normalPathWithMultipleUnderscores() {
        let url = URL(fileURLWithPath: "/Users/test/MocksFolder/Dev/Mocks/user-profile/POST/user-profile_create_user_scenario_67890.json")
        
        XCTAssertEqual(url.scenario, "create_user_scenario")
        XCTAssertTrue(url.hasScenario)
    }
    
    func testScenario_normalPathWithSpecialCharacters() {
        let url = URL(fileURLWithPath: "/Users/test/MocksFolder/Dev/Mocks/api-v2/GET/api-v2_special-scenario_abc123.json")
        
        XCTAssertEqual(url.scenario, "special-scenario")
        XCTAssertTrue(url.hasScenario)
    }
    
    // MARK: - Long Path Tests (over 256 characters)
    
    func testScenario_longPathWithScenario() {
        let longPath = "/Users/test/MocksFolder/Dev/Mocks/very-long-path-that-exceeds-256-characters/very-long-subdirectory-name/another-very-long-subdirectory/yet-another-long-directory-name/extremely-long-directory-name/another-extremely-long-directory-name/GET/test-scenario_12345.json"
        let url = URL(fileURLWithPath: longPath)
        
        XCTAssertEqual(url.scenario, "test-scenario")
        XCTAssertTrue(url.hasScenario)
    }
    
    func testScenario_longPathWithoutScenario() {
        let longPath = "/Users/test/MocksFolder/Dev/Mocks/very-long-path-that-exceeds-256-characters/very-long-subdirectory-name/another-very-long-subdirectory/yet-another-long-directory-name/extremely-long-directory-name/another-extremely-long-directory-name/GET/12345.json"
        let url = URL(fileURLWithPath: longPath)
        
        XCTAssertNil(url.scenario)
        XCTAssertFalse(url.hasScenario)
    }
    
    func testScenario_emptyScenario() {
        let url = URL(fileURLWithPath: "/Users/test/MocksFolder/Dev/Mocks/test/GET/test__12345.json")
        
        XCTAssertNil(url.scenario)
        XCTAssertFalse(url.hasScenario)
    }

    func testScenario_apiEndpointWithScenario() {
        let url = URL(fileURLWithPath: "/Users/test/MocksFolder/Dev/Mocks/api/v1/users/POST/api+v1+users_registration-success_uuid123.json")
        
        XCTAssertEqual(url.scenario, "registration-success")
        XCTAssertTrue(url.hasScenario)
    }
    
    func testScenario_nestedApiPathWithoutScenario() {
        let url = URL(fileURLWithPath: "/Users/test/MocksFolder/Dev/Mocks/api/v2/products/search/GET/api+v2+products+search_uuid456.json")
        
        XCTAssertNil(url.scenario)
        XCTAssertFalse(url.hasScenario)
    }
    
    func testScenario_complexScenarioName() {
        let url = URL(fileURLWithPath: "/Users/test/MocksFolder/Dev/Mocks/payment/POST/payment_error-invalid-card-details_uuid789.json")
        
        XCTAssertEqual(url.scenario, "error-invalid-card-details")
        XCTAssertTrue(url.hasScenario)
    }
} 
