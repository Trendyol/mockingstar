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

    func test_execute_MutatesJSONResponseBody() throws {
        let code = """
        var id = "m"; var path = "/x"; var method = "GET"; var scenario = null;
        var enabled = true; var priority = 0; var sampleMockRequestId = null;
        function transformer(req, chain) {
          var res = chain.proceed(req);
          res.body.injected = true;
          return res;
        }
        """
        let model = try ModifierParser().parse(jsCode: code)

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
        let code = """
        var id = "m"; var path = "/x"; var method = "GET"; var scenario = null;
        var enabled = true; var priority = 0; var sampleMockRequestId = null;
        function transformer(req, chain) {
          var res = chain.proceed(req);
          res.status = 201;
          return res;
        }
        """
        let model = try ModifierParser().parse(jsCode: code)

        let result = try executor.execute(modifier: model, request: request()) { _ in
            HTTPResult(status: 200, body: Data("{}".utf8), headers: ["X-Test": "1"])
        }

        XCTAssertEqual(result.status, 201)
        XCTAssertEqual(result.headers["X-Test"], "1")
    }

    func test_execute_JSException_Throws() throws {
        let code = """
        var id = "m"; var path = "/x"; var method = "GET"; var scenario = null;
        var enabled = true; var priority = 0; var sampleMockRequestId = null;
        function transformer(req, chain) { throw new Error("boom"); }
        """
        let model = try ModifierParser().parse(jsCode: code)

        XCTAssertThrowsError(try executor.execute(modifier: model, request: request()) { _ in
            HTTPResult(status: 200, body: Data(), headers: [:])
        }) { error in
            guard case ModifierExecutionError.jsException = error else {
                return XCTFail("unexpected \(error)")
            }
        }
    }

    func test_execute_MissingTransformer_Throws() throws {
        let code = """
        var id = "m"; var path = "/x"; var method = "GET"; var scenario = null;
        var enabled = true; var priority = 0; var sampleMockRequestId = null;
        """
        let model = try ModifierParser().parse(jsCode: code)

        XCTAssertThrowsError(try executor.execute(modifier: model, request: request()) { _ in
            HTTPResult(status: 200, body: Data(), headers: [:])
        }) { error in
            guard case ModifierExecutionError.missingTransformer = error else {
                return XCTFail("unexpected \(error)")
            }
        }
    }
}
