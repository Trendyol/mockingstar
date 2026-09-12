import CommonKit
import Foundation
import XCTest
@testable import PluginCore

final class ModifierExecutorTests: XCTestCase {
    private let executor = ModifierExecutor()

    private func request(url: String = "https://example.com/x", method: String = "GET") -> URLRequest {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = method
        return request
    }

    private func model(code: String, id: String = "m") -> ModifierModel {
        ModifierModel(id: id, path: "/x", method: "GET", order: 1, transformerCode: code)
    }

    func test_execute_MutatesJSONResponseBody() throws {
        let model = model(code: """
        function transformer(req, chain) {
          var res = chain.proceed(req);
          res.body.injected = true;
          return res;
        }
        """)

        let result = try executor.execute(modifier: model, request: request()) { _ in
            let body = try! JSONSerialization.data(withJSONObject: ["name": "a"])
            return HTTPResult(status: 200, body: body, headers: ["Content-Type": "application/json"])
        }

        let json = try JSONSerialization.jsonObject(with: result.body) as! [String: Any]
        XCTAssertEqual(result.status, 200)
        XCTAssertEqual(json["injected"] as? Bool, true)
        XCTAssertEqual(json["name"] as? String, "a")
    }

    func test_execute_PassesThroughStatusAndHeaders() throws {
        let model = model(code: """
        function transformer(req, chain) {
          var res = chain.proceed(req);
          res.status = 201;
          return res;
        }
        """)

        let result = try executor.execute(modifier: model, request: request()) { _ in
            HTTPResult(status: 200, body: Data("{}".utf8), headers: ["X-Test": "1"])
        }

        XCTAssertEqual(result.status, 201)
        XCTAssertEqual(result.headers["X-Test"], "1")
    }

    func test_execute_MutatesRequestBeforeProceed() throws {
        let model = model(code: """
        function transformer(req, chain) {
          req.url = "https://example.com/mutated";
          return chain.proceed(req);
        }
        """)

        var receivedURL: String?
        let result = try executor.execute(modifier: model, request: request()) { req in
            receivedURL = req.url?.absoluteString
            return HTTPResult(status: 200, body: Data("{}".utf8), headers: [:])
        }

        XCTAssertEqual(result.status, 200)
        XCTAssertEqual(receivedURL, "https://example.com/mutated")
    }

    func test_execute_JSException_Throws() throws {
        let model = model(code: "function transformer(req, chain) { throw new Error(\"boom\"); }")

        XCTAssertThrowsError(try executor.execute(modifier: model, request: request()) { _ in
            HTTPResult(status: 200, body: Data(), headers: [:])
        }) { error in
            guard case ModifierExecutionError.jsException = error else {
                return XCTFail("unexpected \(error)")
            }
        }
    }

    func test_execute_MissingTransformer_Throws() throws {
        let model = model(code: "var unused = 1")

        XCTAssertThrowsError(try executor.execute(modifier: model, request: request()) { _ in
            HTTPResult(status: 200, body: Data(), headers: [:])
        }) { error in
            guard case ModifierExecutionError.missingTransformer = error else {
                return XCTFail("unexpected \(error)")
            }
        }
    }

    func test_execute_LogsModifierIdAndRequestPath() throws {
        let model = model(code: """
        function transformer(req, chain) { return chain.proceed(req); }
        """, id: "discount")

        let result = try executor.execute(modifier: model, request: request(url: "https://example.com/cart")) { _ in
            HTTPResult(status: 200, body: Data("{}".utf8), headers: [:])
        }

        XCTAssertEqual(result.status, 200)
    }
}
