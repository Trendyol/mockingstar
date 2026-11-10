import Foundation
import XCTest
@testable import CommonKit

final class CurlParserTests: XCTestCase {
    func test_browserJSONCurl_PreservesURLHeadersAndBody() throws {
        let command = #"""
        curl 'https://example.com/widgets?q=elbise&limit=1' \
          -H 'X-Test: token:one' \
          --json '{"query":"elbise"}' --compressed -L
        """#
        let request = try CurlParser(command).buildRequest()
        XCTAssertEqual(request.url?.absoluteString, "https://example.com/widgets?q=elbise&limit=1")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Test"), "token:one")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertEqual(request.httpBody, Data(#"{"query":"elbise"}"#.utf8))
    }

    func test_cURLRoundTrip_PreservesQuotedMultilineBodyAndEmptyHeaders() throws {
        var request = URLRequest(url: try XCTUnwrap(URL(string: "https://example.com/widgets?q=elbise&limit=2")))
        request.httpMethod = "PATCH"
        request.allHTTPHeaderFields = ["X-Test": "Ömer's token", "X-Empty": "", "Content-Type": "application/json"]
        request.httpBody = Data("{\n\"text\":\"Ömer's $literal `text` function transformer\"\n}".utf8)
        for pretty in [true, false] {
            let parsed = try CurlParser(request.cURL(pretty: pretty)).buildRequest()
            XCTAssertEqual(parsed.url, request.url)
            XCTAssertEqual(parsed.httpMethod, request.httpMethod)
            XCTAssertEqual(parsed.allHTTPHeaderFields, request.allHTTPHeaderFields)
            XCTAssertEqual(parsed.httpBody, request.httpBody)
        }
    }

    func test_cURLRoundTrip_GETBodyWithNoContentTypeStaysLiteral() throws {
        var request = URLRequest(url: try XCTUnwrap(URL(string: "http://localhost:8008/widgets")))
        request.httpMethod = "GET"
        request.httpBody = Data("@literal".utf8)
        let parsed = try CurlParser(request.cURL(pretty: true)).buildRequest()
        XCTAssertEqual(parsed.httpMethod, "GET")
        XCTAssertEqual(parsed.httpBody, request.httpBody)
        XCTAssertNil(parsed.value(forHTTPHeaderField: "Content-Type"))
    }

    func test_cURLWithoutBody_HasNoTrailingContinuation() throws {
        let request = URLRequest(url: try XCTUnwrap(URL(string: "https://example.com/widgets")))
        let command = request.cURL(pretty: true)
        XCTAssertFalse(command.hasSuffix("\\\n"))
        XCTAssertNil(try CurlParser(command).buildRequest().httpBody)
    }

    func test_quotedEscapes_CRLFContinuationsAndExplicitMethod() throws {
        let command = "curl 'https://example.com/widgets' \\\r\n -X GET --data-raw 'it'\\''s $literal'"
        let request = try CurlParser(command).buildRequest()
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.httpBody, Data("it's $literal".utf8))
        XCTAssertEqual(try CurlParser(#"curl https://example.com --data-raw $'first\nsecond'"#).buildRequest().httpBody, Data("first\nsecond".utf8))
    }

    func test_rejectsMalformedShellAndFileInputs() {
        for command in [
            "curl 'https://example.com", "curl https://example.com; echo ignored",
            "curl https://example.com --data @file.json", "curl https://example.com -H @headers.txt",
            "curl https://example.com --unknown value", "curl https://example.com https://other.example.com",
            "curl $(hostname)", "curl https://example.com -H \"Authorization: $TOKEN\"", "curl ftp://example.com"
        ] {
            XCTAssertThrowsError(try CurlParser(command).buildRequest(), command)
        }
    }

    func test_getData_AppendsEncodedQueryAndRejectsMalformedValues() throws {
        let request = try CurlParser("curl 'https://example.com/widgets?limit=2#results' -G --data-raw 'q=hello%20world'").buildRequest()
        XCTAssertEqual(request.url?.absoluteString, "https://example.com/widgets?limit=2&q=hello%20world#results")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertNil(request.httpBody)
        for value in ["q=hello world", "q=%bad%", "q=Ömer", "q=value#fragment"] {
            XCTAssertThrowsError(try CurlParser("curl https://example.com -G --data-raw '\(value)'").buildRequest())
        }
    }
}
