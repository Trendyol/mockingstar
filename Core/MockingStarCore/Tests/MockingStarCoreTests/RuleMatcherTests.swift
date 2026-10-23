import XCTest
import Foundation
import CommonKit
@testable import MockingStarCore

final class RuleMatcherTests: XCTestCase {
    func mock(_ id: String = "rule", priority: Int = 0, path: MockPathMatch = .init(value: "/items"), expression: MockMatchExpression? = nil) -> MockModel {
        MockModel(metaData: .init(url: URL(string: "https://api.example.com/items")!, method: "GET", appendTime: Date(), updateTime: Date(), httpStatus: 200, responseTime: 0, scenario: "bundle-name-does-not-matter", id: id), requestHeader: "{}", responseHeader: "{}", requestBody: "", responseBody: "mock", matching: .init(priority: priority, endpoint: .init(method: "GET", host: "API.EXAMPLE.COM", path: path), conditions: expression))
    }
    func predicate(_ source: MockPredicate.Source, _ key: String? = nil, _ op: MockPredicate.Operator = .equals, _ value: MatchValue? = nil) -> MockMatchExpression { .init(predicate: .init(source: source, key: key, op: op, value: value)) }
    func request(_ query: String = "", body: String? = nil, headers: [String: String] = [:]) -> MatchingRequest {
        .init(url: URL(string: "https://api.example.com/items" + (query.isEmpty ? "" : "?" + query))!, method: "get", headers: headers, body: body.map { Data($0.utf8) })
    }
    func testPageOneOnlyAndActionableFailure() {
        let m = mock(expression: predicate(.query, "page", .equals, .string("1")))
        XCTAssertEqual(RuleMatcher.decide(request: request("size=10&page=1"), mocks: [m]).mockId, m.id)
        let missed = RuleMatcher.decide(request: request("page=2&size=10"), mocks: [m])
        XCTAssertNil(missed.mockId); XCTAssertEqual(missed.candidates.first?.failures.first?.field, "query:page")
        XCTAssertEqual(missed.candidates.first?.failures.first?.actual, .array([.string("2")]))
    }
    func testQueryMultisetPreservesDuplicatesAndIgnoresOrder() {
        let m = mock(expression: predicate(.query, "tag", .equals, .array([.string("a"), .string("a"), .string("b")])))
        XCTAssertNotNil(RuleMatcher.decide(request: request("tag=b&other=x&tag=a&tag=a"), mocks: [m]).mockId)
        XCTAssertNil(RuleMatcher.decide(request: request("tag=b&tag=a"), mocks: [m]).mockId)
        m.matching?.conditions = predicate(.query, "tag", .oneOf, .array([.string("b"), .string("c")]))
        XCTAssertNotNil(RuleMatcher.decide(request: request("tag=a&tag=b"), mocks: [m]).mockId)
    }
    func testNestedJSONNullMissingObjectEqualityAndArrayOrder() throws {
        let nullPredicate = try JSONDecoder().decode(MockMatchExpression.self, from: Data(#"{"predicate":{"source":"jsonBody","key":"/user/name","op":"equals","value":null}}"#.utf8))
        try nullPredicate.validate()
        let m = mock(expression: .init(all: [nullPredicate, predicate(.jsonBody, "/missing", .absent), predicate(.jsonBody, "/object", .equals, .object(["a": .number(1), "b": .number(2)])), predicate(.jsonBody, "/array", .equals, .array([.number(1), .number(2)]))]))
        let json = #"{"user":{"name":null},"object":{"b":2,"a":1},"array":[1,2]}"#
        XCTAssertNotNil(RuleMatcher.decide(request: request(body: json), mocks: [m]).mockId)
        XCTAssertNil(RuleMatcher.decide(request: request(body: json.replacingOccurrences(of: "[1,2]", with: "[2,1]")), mocks: [m]).mockId)
        XCTAssertNil(RuleMatcher.decide(request: request(body: #"{"user":{}}"#), mocks: [m]).mockId)
        XCTAssertEqual(MatchValue.object(["a/b": .object(["~key": .string("ok")])]).at(pointer: "/a~1b/~0key"), .string("ok"))
    }
    func testAllAnyNotRegexHeadersNumbersAndIdentity() throws {
        let expr = MockMatchExpression(all: [predicate(.header, "x-token", .startsWith, .string("Bearer")), .init(any: [predicate(.query, "page", .gte, .number(3)), predicate(.body, nil, .contains, .string("needle"))]), .init(not: [predicate(.query, "disabled", .exists)]), predicate(.scenario, nil, .endsWith, .string("test")), predicate(.deviceId, nil, .regex, .string("^sim-[0-9]+$"))])
        try expr.validate()
        let m = mock(expression: expr)
        var r = request("page=4", headers: ["X-Token": "Bearer abc"]); r.scenario = "ui-test"; r.deviceId = "sim-42"
        XCTAssertNotNil(RuleMatcher.decide(request: r, mocks: [m]).mockId)
        r.url = URL(string: "https://api.example.com/items?page=4&disabled")!
        XCTAssertNil(RuleMatcher.decide(request: r, mocks: [m]).mockId)
    }
    func testBroadPathRulesPriorityAndStableID() {
        let a = mock("a", priority: 2, path: .init(style: .glob, value: "/it*"))
        let b = mock("b", priority: 2, path: .init(style: .regex, value: "^/items$"))
        let c = mock("c", priority: 3)
        XCTAssertEqual(RuleMatcher.decide(request: request(), mocks: [b, a]).mockId, "a")
        XCTAssertEqual(RuleMatcher.decide(request: request(), mocks: [a, b, c]).mockId, "c")
        c.matching?.enabled = false
        XCTAssertEqual(RuleMatcher.decide(request: request(), mocks: [c, b, a]).mockId, "a")
    }
    func testValidationRejectsAmbiguousOrMalformedExpressions() {
        XCTAssertThrowsError(try MockMatchExpression(all: [], any: []).validate())
        XCTAssertThrowsError(try predicate(.query, nil, .equals, .string("x")).validate())
        XCTAssertThrowsError(try predicate(.jsonBody, "bad", .equals, .null).validate())
        XCTAssertThrowsError(try predicate(.jsonBody, "/bad~2", .equals, .null).validate())
        XCTAssertThrowsError(try predicate(.jsonBody, "/bad~", .exists).validate())
        XCTAssertThrowsError(try predicate(.jsonBody, "/bad~\u{0301}", .exists).validate())
        XCTAssertNil(MatchValue.object(["bad~2": .null]).at(pointer: "/bad~2"))
        XCTAssertNoThrow(try predicate(.jsonBody, "/~01", .exists).validate())
        XCTAssertThrowsError(try predicate(.body, nil, .regex, .string("[")).validate())
        XCTAssertThrowsError(try predicate(.query, "n", .gt, .string("2")).validate())
    }
    func testEmptyDisjunctionDoesNotMatchAndDisabledRuleIsExplained() {
        let m = mock(expression: .init(any: []))
        let missed = RuleMatcher.decide(request: request(), mocks: [m])
        XCTAssertNil(missed.mockId)
        XCTAssertEqual(missed.candidates.first?.failures.first?.reason, "no_condition_matched")
        m.matching?.enabled = false
        XCTAssertEqual(RuleMatcher.decide(request: request(), mocks: [m]).candidates.first?.failures.first?.reason, "rule_disabled")
    }
    func testBatchRejectsEscapingMetadataHeadersAndFilenameCollisionsWithoutChangingMocks() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = MockWorkspace(root: root); try workspace.initialize()
        let existing = mock("existing")
        try workspace.apply([existing], domain: "Dev")
        let invalid = mock("invalid")
        invalid.metaData.method = "../../Configs"
        XCTAssertThrowsError(try workspace.apply([invalid], domain: "Dev"))
        invalid.metaData.method = "GET"
        invalid.responseHeader = .init(["X-Test": "value\r\nInjected: yes"])
        XCTAssertThrowsError(try workspace.apply([invalid], domain: "Dev"))
        invalid.responseHeader = "{}"
        invalid.metaData.scenario = "../../../../../../Plugins/overwrite"
        XCTAssertThrowsError(try workspace.apply([invalid], domain: "Dev"))
        let a = mock("a"), b = mock("s_a")
        a.metaData.scenario = "s"; b.metaData.scenario = ""
        XCTAssertThrowsError(try workspace.apply([a, b], domain: "Dev"))
        XCTAssertEqual(try workspace.mocks(domain: "Dev").map(\.id), [existing.id])
        XCTAssertEqual(try workspace.mock(id: existing.id, domain: "Dev").matching, existing.matching)
    }
    func testMatchingSurvivesNativeRoundTripCopyAndLazyDecode() throws {
        let m = mock(expression: predicate(.jsonBody, "/name", .equals, .null)); m.responseBody = #"{"result":true}"#
        let data = try JSONEncoder.shared.encode(m)
        let decoded = try JSONDecoder.shared.decode(MockModel.self, from: data)
        let copy = decoded.copy() as! MockModel
        let lazy = try JSONDecoder.custom([.lazyDecoding: true]).decode(MockModel.self, from: data)
        try lazy.decode(from: data)
        XCTAssertEqual(copy.matching, m.matching); XCTAssertEqual(lazy.matching, m.matching)
        XCTAssertEqual(try JSONDecoder().decode(MatchValue.self, from: Data(lazy.responseBody.utf8)), try JSONDecoder().decode(MatchValue.self, from: Data(m.responseBody.utf8)))
        m.matching = nil
        XCTAssertNil(try JSONDecoder.shared.decode(MockModel.self, from: JSONEncoder.shared.encode(m)).matching)
    }
    func testBundleValidationMakesNoPartialChangesAndIndexReloadKeepsLastValidRule() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = MockWorkspace(root: root); try workspace.initialize(); try workspace.createDomain("Dev")
        let valid = mock("valid"), invalid = mock("invalid"); invalid.metaData.httpStatus = 900
        XCTAssertThrowsError(try workspace.apply([valid, invalid], domain: "Dev"))
        XCTAssertTrue(try workspace.mocks(domain: "Dev").isEmpty)
        try workspace.apply([valid], domain: "Dev")
        try workspace.validate(workspace.mock(id: valid.id, domain: "Dev"))
        let index = RuleIndex(root: root)
        let initial = try await index.mocks(domain: "Dev"); XCTAssertEqual(initial.count, 1)
        let file = try workspace.mock(id: valid.id, domain: "Dev").fileURL!
        try Data("invalid json".utf8).write(to: file, options: .atomic)
        let after = try await index.mocks(domain: "Dev"); XCTAssertEqual(after.count, 1)
        XCTAssertEqual(after.first?.matching, valid.matching)
    }
    func testExplicitMismatchCannotBypassThroughLegacyMatcherAndBroadRuleLoads() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = MockWorkspace(root: root); try workspace.initialize()
        let m = mock(expression: predicate(.query, "page", .equals, .string("1")))
        try workspace.apply([m], domain: "Dev")
        let core = MockingStarCore(root: root, recordLive: false)
        let missed = try await core.explain(request: request("page=2"), domain: "Dev"); XCTAssertNil(missed.mockId)
        m.matching?.endpoint.path = .init(style: .glob, value: "/other/*")
        try workspace.apply([m], domain: "Dev")
        let broad = try await core.explain(request: .init(url: URL(string: "https://api.example.com/other/42?page=1")!, method: "GET"), domain: "Dev")
        let explanation = String(decoding: try JSONEncoder().encode(broad), as: UTF8.self)
        XCTAssertEqual(broad.mockId, m.id, explanation)
    }
    func testCurlIsDataAndRoundTripsQuotedPayload() throws {
        let command = #"curl 'https://api.example.com/items' -H 'X-Token: hello: world' --data-raw '{"name":"$(touch /tmp/never)","quote":"it is fine"}'"#
        let request = try CurlRequestParser.parse(command)
        XCTAssertEqual(request.method, "POST"); XCTAssertEqual(request.headers["X-Token"], "hello: world")
        let again = try CurlRequestParser.parse(CurlRequestParser.export(request))
        XCTAssertEqual(again.body, request.body)
        XCTAssertThrowsError(try CurlRequestParser.parse("curl https://example.com; touch /tmp/never"))
        XCTAssertThrowsError(try CurlRequestParser.parse("curl https://example.com --data @secret"))
    }
}
