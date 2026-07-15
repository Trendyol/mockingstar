import CommonKit
import Foundation
import XCTest
@testable import PluginCore

final class ModifierChainTests: XCTestCase {
    private func request(url: String = "https://example.com/x", method: String = "GET") -> URLRequest {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = method
        return request
    }

    private func orderAppendingModifier(id: String, priority: Int) -> ModifierModel {
        let code = """
        var id = "\(id)"; var path = "/x"; var method = "GET"; var scenario = null;
        var enabled = true; var priority = \(priority); var sampleMockRequestId = null;
        function transformer(req, chain) {
          var res = chain.proceed(req);
          res.body.order = (res.body.order || []).concat(["\(id)"]);
          return res;
        }
        """
        return try! ModifierParser().parse(jsCode: code)
    }

    func test_chain_ZeroModifiers_CallsTerminal() async throws {
        let chain = ModifierChain(modifiers: []) { _ in
            HTTPResult(status: 200, body: Data("ok".utf8), headers: [:])
        }

        let result = try await chain.proceed(request())

        XCTAssertEqual(result.status, 200)
        XCTAssertEqual(result.body, Data("ok".utf8))
    }

    func test_chain_ThreeModifiers_UnwindsOuterLast() async throws {
        let modifiers = [
            orderAppendingModifier(id: "a", priority: 0),
            orderAppendingModifier(id: "b", priority: 1),
            orderAppendingModifier(id: "c", priority: 2),
        ]

        let chain = ModifierChain(modifiers: modifiers) { _ in
            HTTPResult(status: 200, body: Data("{\"order\":[]}".utf8), headers: [:])
        }

        let result = try await chain.proceed(request())

        let json = try JSONSerialization.jsonObject(with: result.body) as! [String: Any]
        XCTAssertEqual(json["order"] as? [String], ["c", "b", "a"])
        XCTAssertEqual(result.status, 200)
    }

    func test_chain_InnerModifierThrows_OuterCannotHideFailure() async throws {
        let outerCode = """
        var id = "outer"; var path = "/x"; var method = "GET"; var scenario = null;
        var enabled = true; var priority = 0; var sampleMockRequestId = null;
        function transformer(req, chain) {
          var res = chain.proceed(req);
          res.status = 201;
          return res;
        }
        """
        let innerCode = """
        var id = "inner"; var path = "/x"; var method = "GET"; var scenario = null;
        var enabled = true; var priority = 1; var sampleMockRequestId = null;
        function transformer(req, chain) { throw new Error("boom"); }
        """
        let outer = try ModifierParser().parse(jsCode: outerCode)
        let inner = try ModifierParser().parse(jsCode: innerCode)

        let chain = ModifierChain(modifiers: [outer, inner]) { _ in
            HTTPResult(status: 200, body: Data(), headers: [:])
        }

        do {
            let result = try await chain.proceed(request())
            // The outer transformer must not be able to hide the inner failure behind a 201.
            XCTAssertNotEqual(result.status, 201)
            XCTAssertEqual(result.status, 500)
        } catch {
            // Throwing is also an acceptable fail-closed outcome.
        }
    }

    func test_chain_ModifierThrows_PropagatesError() async throws {
        let code = """
        var id = "m"; var path = "/x"; var method = "GET"; var scenario = null;
        var enabled = true; var priority = 0; var sampleMockRequestId = null;
        function transformer(req, chain) { throw new Error("boom"); }
        """
        let modifier = try ModifierParser().parse(jsCode: code)

        let chain = ModifierChain(modifiers: [modifier]) { _ in
            HTTPResult(status: 200, body: Data(), headers: [:])
        }

        do {
            _ = try await chain.proceed(request())
            XCTFail("expected chain.proceed to throw")
        } catch {
            // Fail-closed: Core is expected to map any thrown error to HTTP 500.
        }
    }
}
