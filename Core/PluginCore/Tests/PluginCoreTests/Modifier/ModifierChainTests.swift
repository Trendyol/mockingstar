import CommonKit
import Foundation
import XCTest
@testable import PluginCore

final class MockModifierChainTests: XCTestCase {
    private func request(url: String = "https://example.com/x", method: String = "GET") -> URLRequest {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = method
        return request
    }

    private func orderAppendingModifier(id: String, order: Int) -> MockModifierModel {
        let code = """
        function transformer(req, chain) {
          var res = chain.proceed(req);
          res.body.order = (res.body.order || []).concat(["\(id)"]);
          return res;
        }
        """
        return MockModifierModel(id: id, path: "/x", method: "GET", enabled: true, order: order, transformerCode: code)
    }

    func test_chain_ZeroModifiers_CallsTerminal() async throws {
        let chain = MockModifierChain(modifiers: []) { _ in
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

        let chain = MockModifierChain(modifiers: modifiers) { _ in
            HTTPResult(status: 200, body: Data("{\"order\":[]}".utf8), headers: [:])
        }

        let result = try await chain.proceed(request())

        let json = try JSONSerialization.jsonObject(with: result.body) as! [String: Any]
        XCTAssertEqual(json["order"] as? [String], ["c", "b", "a"])
        XCTAssertEqual(result.status, 200)
    }

    @MainActor
    func test_chain_DeepChainWithAsyncMainActorTerminalCompletesInOrder() async throws {
        let ids = (0..<16).map { "modifier-\($0)" }
        let chain = MockModifierChain(modifiers: ids.enumerated().map {
            orderAppendingModifier(id: $0.element, order: $0.offset + 1)
        }) { _ in
            await Task.yield()
            return await MainActor.run {
                HTTPResult(status: 200, body: Data(#"{"order":[]}"#.utf8), headers: [:])
            }
        }

        let result = try await chain.proceed(request())

        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: result.body) as? [String: Any])
        XCTAssertEqual(json["order"] as? [String], Array(ids.reversed()))
    }

    func test_chain_ConcurrentRequestsWithAsyncTerminalsCompleteIndependently() async throws {
        let input = request()
        let modifiers = (0..<4).map { orderAppendingModifier(id: "modifier-\($0)", order: $0 + 1) }
        let results = try await withThrowingTaskGroup(of: HTTPResult.self) { group in
            for _ in 0..<8 {
                group.addTask {
                    let chain = MockModifierChain(modifiers: modifiers) { _ in
                        await Task.yield()
                        return HTTPResult(status: 200, body: Data(#"{"order":[]}"#.utf8), headers: [:])
                    }
                    return try await chain.proceed(input)
                }
            }
            var results: [HTTPResult] = []
            for try await result in group { results.append(result) }
            return results
        }

        XCTAssertEqual(results.count, 8)
        for result in results {
            let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: result.body) as? [String: Any])
            XCTAssertEqual(json["order"] as? [String], ["modifier-3", "modifier-2", "modifier-1", "modifier-0"])
        }
    }

    func test_chain_InnerModifierThrows_OuterCannotHideFailure() async throws {
        let outer = MockModifierModel(
            id: "outer", path: "/x", method: "GET", order: 1,
            transformerCode: """
            function transformer(req, chain) {
              var res = chain.proceed(req);
              res.status = 201;
              return res;
            }
            """
        )
        let inner = MockModifierModel(
            id: "inner", path: "/x", method: "GET", order: 2,
            transformerCode: "function transformer(req, chain) { throw new Error(\"boom\"); }"
        )

        let chain = MockModifierChain(modifiers: [outer, inner]) { _ in
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
        let modifier = MockModifierModel(
            id: "m", path: "/x", method: "GET", order: 1,
            transformerCode: "function transformer(req, chain) { throw new Error(\"boom\"); }"
        )

        let chain = MockModifierChain(modifiers: [modifier]) { _ in
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
        let modifier = MockModifierModel(
            id: "mock", path: "/x", method: "GET", order: 1,
            transformerCode: """
            function transformer(req, chain) {
              return { status: 200, body: { mocked: true }, headers: {} };
            }
            """
        )

        var terminalCalled = false
        let chain = MockModifierChain(modifiers: [modifier]) { _ in
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
