//
//  CurlParserTests.swift
//  MockListTests
//
//  Created by Yusuf Özgül on 28.03.2025.
//

import XCTest
@testable import MockList

final class CurlParserTests: XCTestCase {
    func test_buildRequest_simpleGetRequest_returnsValidUrlRequest() throws {
        let curlCommand = "curl https://www.example.com"
        let parser = CurlParser(curlCommand)

        let request = try parser.buildRequest()

        XCTAssertEqual(request.url?.absoluteString, "https://www.example.com")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertNil(request.httpBody)
        XCTAssertTrue(request.allHTTPHeaderFields?.isEmpty ?? true)
    }
    
    func test_buildRequest_withUrlOption_returnsValidUrlRequest() throws {
        let curlCommand = "curl --url https://www.example.com"
        let parser = CurlParser(curlCommand)

        let request = try parser.buildRequest()

        XCTAssertEqual(request.url?.absoluteString, "https://www.example.com")
        XCTAssertEqual(request.httpMethod, "GET")
    }
    
    func test_buildRequest_withPostMethod_returnsRequestWithPostMethod() throws {
        let curlCommand = "curl -X POST https://www.example.com"
        let parser = CurlParser(curlCommand)

        let request = try parser.buildRequest()

        XCTAssertEqual(request.url?.absoluteString, "https://www.example.com")
        XCTAssertEqual(request.httpMethod, "POST")
    }
    
    func test_buildRequest_withLongFormMethod_returnsRequestWithCorrectMethod() throws {
        let curlCommand = "curl --request PUT https://www.example.com"
        let parser = CurlParser(curlCommand)

        let request = try parser.buildRequest()

        XCTAssertEqual(request.url?.absoluteString, "https://www.example.com")
        XCTAssertEqual(request.httpMethod, "PUT")
    }

    func test_buildRequest_withSingleHeader_includesHeaderInRequest() throws {
        let curlCommand = "curl -H 'Content-Type: application/json' https://www.example.com"
        let parser = CurlParser(curlCommand)

        let request = try parser.buildRequest()

        XCTAssertEqual(request.url?.absoluteString, "https://www.example.com")
        XCTAssertEqual(request.allHTTPHeaderFields?["Content-Type"], "application/json")
    }
    
    func test_buildRequest_withMultipleHeaders_includesAllHeadersInRequest() throws {
        let curlCommand = """
        curl -H 'Content-Type: application/json' -H 'Authorization: Bearer token123' https://www.example.com
        """
        let parser = CurlParser(curlCommand)

        let request = try parser.buildRequest()

        XCTAssertEqual(request.url?.absoluteString, "https://www.example.com")
        XCTAssertEqual(request.allHTTPHeaderFields?["Content-Type"], "application/json")
        XCTAssertEqual(request.allHTTPHeaderFields?["Authorization"], "Bearer token123")
    }
    
    func test_buildRequest_withLongFormHeaders_includesAllHeadersInRequest() throws {
        let curlCommand = """
        curl --header 'Content-Type: application/json' --header 'Accept: application/json' https://www.example.com
        """
        let parser = CurlParser(curlCommand)

        let request = try parser.buildRequest()

        XCTAssertEqual(request.url?.absoluteString, "https://www.example.com")
        XCTAssertEqual(request.allHTTPHeaderFields?["Content-Type"], "application/json")
        XCTAssertEqual(request.allHTTPHeaderFields?["Accept"], "application/json")
    }
    
    func test_buildRequest_withDataOption_includesBodyInRequest() throws {
        let curlCommand = """
        curl -X POST -d '{"name":"John","age":30}' https://www.example.com
        """
        let parser = CurlParser(curlCommand)

        let request = try parser.buildRequest()

        XCTAssertEqual(request.url?.absoluteString, "https://www.example.com")
        XCTAssertEqual(request.httpMethod, "POST")
        
        let bodyString = String(data: request.httpBody ?? Data(), encoding: .utf8)
        XCTAssertEqual(bodyString, "{\"name\":\"John\",\"age\":30}")
    }
    
    func test_buildRequest_withDataRawOption_includesBodyInRequest() throws {
        let curlCommand = """
        curl -X POST --data-raw '{"name":"John","age":30}' https://www.example.com
        """
        let parser = CurlParser(curlCommand)

        let request = try parser.buildRequest()

        XCTAssertEqual(request.url?.absoluteString, "https://www.example.com")
        XCTAssertEqual(request.httpMethod, "POST")
        
        let bodyString = String(data: request.httpBody ?? Data(), encoding: .utf8)
        XCTAssertEqual(bodyString, "{\"name\":\"John\",\"age\":30}")
    }

    func test_buildRequest_complexRequest_returnsCorrectlyConfiguredRequest() throws {
        let curlCommand = """
        curl -X POST 'https://api.example.com/users' \\
          -H 'Content-Type: application/json' \\
          -H 'Authorization: Bearer token123' \\
          -H 'User-Agent: Mozilla/5.0' \\
          -d '{"name":"John Doe","email":"john@example.com","age":30}'
        """
        let parser = CurlParser(curlCommand)

        let request = try parser.buildRequest()

        XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/users")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.allHTTPHeaderFields?["Content-Type"], "application/json")
        XCTAssertEqual(request.allHTTPHeaderFields?["Authorization"], "Bearer token123")
        XCTAssertEqual(request.allHTTPHeaderFields?["User-Agent"], "Mozilla/5.0")
        
        let bodyString = String(data: request.httpBody ?? Data(), encoding: .utf8)
        XCTAssertEqual(bodyString, "{\"name\":\"John Doe\",\"email\":\"john@example.com\",\"age\":30}")
    }
    
    func test_buildRequest_invalidURL_throwsInvalidURLError() {
        let curlCommand = "curl %&/"
        let parser = CurlParser(curlCommand)

        XCTAssertThrowsError(try parser.buildRequest()) { error in
            XCTAssertEqual(error as? CURLError, .invalidURL)
        }
    }
    
    func test_buildRequest_missingURL_throwsInvalidURLError() {
        let curlCommand = "curl -X GET"
        let parser = CurlParser(curlCommand)

        XCTAssertThrowsError(try parser.buildRequest()) { error in
            XCTAssertEqual(error as? CURLError, .invalidURL)
        }
    }
} 
