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

    private func orderAppendingModifier(id: String, order: Int) -> ModifierModel {
        let code = """
        function transformer(req, chain) {
          var res = chain.proceed(req);
          res.body.order = (res.body.order || []).concat(["\(id)"]);
          return res;
        }
        """
        return ModifierModel(id: id, path: "/x", method: "GET", enabled: true, order: order, transformerCode: code)
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
        // Lower order is outermost: a(1) enters first, c(3) is closest to terminal.
        // Post-proceed response transforms unwind c -> b -> a.
        let modifiers = [
            orderAppendingModifier(id: "a", order: 1),
            orderAppendingModifier(id: "b", order: 2),
            orderAppendingModifier(id: "c", order: 3),
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
        let outer = ModifierModel(
            id: "outer", path: "/x", method: "GET", order: 1,
            transformerCode: """
            function transformer(req, chain) {
              var res = chain.proceed(req);
              res.status = 201;
              return res;
            }
            """
        )
        let inner = ModifierModel(
            id: "inner", path: "/x", method: "GET", order: 2,
            transformerCode: "function transformer(req, chain) { throw new Error(\"boom\"); }"
        )

        let chain = ModifierChain(modifiers: [outer, inner]) { _ in
            HTTPResult(status: 200, body: Data(), headers: [:])
        }

        do {
            let result = try await chain.proceed(request())
            XCTAssertNotEqual(result.status, 201)
            XCTAssertEqual(result.status, 500)
        } catch {
            // Throwing is also an acceptable fail-closed outcome.
        }
    }

    func test_chain_ModifierThrows_PropagatesError() async throws {
        let modifier = ModifierModel(
            id: "m", path: "/x", method: "GET", order: 1,
            transformerCode: "function transformer(req, chain) { throw new Error(\"boom\"); }"
        )

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

    func test_chain_SingleModifier_CanReturnWithoutProceed() async throws {
        let modifier = ModifierModel(
            id: "mock", path: "/x", method: "GET", order: 1,
            transformerCode: """
            function transformer(req, chain) {
              return { status: 200, body: { mocked: true }, headers: {} };
            }
            """
        )

        var terminalCalled = false
        let chain = ModifierChain(modifiers: [modifier]) { _ in
            terminalCalled = true
            return HTTPResult(status: 500, body: Data(), headers: [:])
        }

        let result = try await chain.proceed(request())
        XCTAssertFalse(terminalCalled)
        XCTAssertEqual(result.status, 200)
        let json = try JSONSerialization.jsonObject(with: result.body) as! [String: Any]
        XCTAssertEqual(json["mocked"] as? Bool, true)
    }
}
