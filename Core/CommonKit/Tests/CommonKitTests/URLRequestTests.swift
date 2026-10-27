import Foundation
import XCTest
@testable import CommonKit

final class URLRequestTests: XCTestCase {
    func test_cURL_QuotesURLHeadersAndBodyForShell() throws {
        var request = URLRequest(url: try XCTUnwrap(URL(string: "https://example.com/search?q=O'Reilly")))
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = ["X-Name": "O'Reilly"]
        request.httpBody = Data("{\"name\":\"O'Reilly\"}".utf8)
        for pretty in [false, true] {
            let curl = request.cURL(pretty: pretty)
            XCTAssertTrue(curl.contains("'https://example.com/search?q=O'\\''Reilly'"))
            XCTAssertTrue(curl.contains("'X-Name: O'\\''Reilly'"))
            XCTAssertTrue(curl.contains("--data '{\"name\":\"O'\\''Reilly\"}'"))
        }
    }

    func test_cURL_EmptyBodyOmitsDataAndDefaultsToGET() throws {
        let request = URLRequest(url: try XCTUnwrap(URL(string: "https://example.com")))
        let curl = request.cURL(pretty: true)
        XCTAssertTrue(curl.contains("--request 'GET'"))
        XCTAssertFalse(curl.contains("--data"))
    }
}
