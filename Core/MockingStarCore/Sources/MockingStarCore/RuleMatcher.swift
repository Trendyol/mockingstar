import Foundation
import CommonKit
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct MatchingRequest: Codable {
    public var url: URL
    public var method: String
    public var headers: [String: String]
    public var body: Data?
    public var scenario: String
    public var deviceId: String
    public init(url: URL, method: String, headers: [String: String] = [:], body: Data? = nil, scenario: String = "", deviceId: String = "") {
        self.url = url; self.method = method; self.headers = headers; self.body = body; self.scenario = scenario; self.deviceId = deviceId
    }
}

public struct MatchFailure: Codable {
    public var field: String
    public var reason: String
    public var expected: MatchValue?
    public var actual: MatchValue?
    public init(field: String, reason: String, expected: MatchValue? = nil, actual: MatchValue? = nil) {
        self.field = field; self.reason = reason; self.expected = expected; self.actual = actual
    }
    private enum CodingKeys: String, CodingKey { case field, reason, expected, actual }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        field = try container.decode(String.self, forKey: .field)
        reason = try container.decode(String.self, forKey: .reason)
        expected = container.contains(.expected) ? try container.decode(MatchValue.self, forKey: .expected) : nil
        actual = container.contains(.actual) ? try container.decode(MatchValue.self, forKey: .actual) : nil
    }
}

public struct MatchCandidate: Codable {
    public var mockId: String
    public var priority: Int
    public var matched: Bool
    public var failures: [MatchFailure]
}

public struct MatchDecision: Codable {
    public var mockId: String?
    public var reason: String
    public var candidates: [MatchCandidate]
    public init(mockId: String? = nil, reason: String = "no_candidate", candidates: [MatchCandidate] = []) {
        self.mockId = mockId; self.reason = reason; self.candidates = candidates
    }
}

/// Pure evaluator shared by serving, explain and offline request tests.
public enum RuleMatcher {
    public static func decide(request: MatchingRequest, mocks: [MockModel]) -> MatchDecision {
        var decision = MatchDecision()
        let rules = mocks.filter { $0.matching != nil }.sorted {
            let a = $0.matching!.priority, b = $1.matching!.priority
            return a == b ? $0.id < $1.id : a > b
        }
        for mock in rules {
            guard let rule = mock.matching else { continue }
            guard rule.enabled else {
                decision.candidates.append(.init(mockId: mock.id, priority: rule.priority, matched: false, failures: [.init(field: "enabled", reason: "rule_disabled", expected: .bool(true), actual: .bool(false))]))
                continue
            }
            var failures: [MatchFailure] = []
            if rule.endpoint.method.uppercased() != request.method.uppercased() {
                failures.append(.init(field: "method", reason: "method_mismatch", expected: .string(rule.endpoint.method), actual: .string(request.method)))
            }
            if rule.endpoint.host.lowercased() != request.url.host?.lowercased() {
                failures.append(.init(field: "host", reason: "host_mismatch", expected: .string(rule.endpoint.host), actual: request.url.host.map(MatchValue.string)))
            }
            if !pathMatches(request.url.path, rule.endpoint.path) {
                failures.append(.init(field: "path", reason: "path_mismatch", expected: .string(rule.endpoint.path.value), actual: .string(request.url.path)))
            }
            if failures.isEmpty, let expression = rule.conditions {
                failures = evaluate(expression, request: request).failures
            }
            let matched = failures.isEmpty
            decision.candidates.append(.init(mockId: mock.id, priority: rule.priority, matched: matched, failures: failures))
            if matched && decision.mockId == nil { decision.mockId = mock.id }
        }
        decision.reason = decision.mockId != nil ? "matched" : decision.candidates.isEmpty ? "no_candidate" : "conditions_not_matched"
        return decision
    }

    private static func pathMatches(_ path: String, _ match: MockPathMatch) -> Bool {
        switch match.style {
        case .exact: return path == match.value
        case .regex: return regex(match.value, in: path)
        case .glob:
            let pattern = "^" + NSRegularExpression.escapedPattern(for: match.value).replacingOccurrences(of: "\\*", with: ".*").replacingOccurrences(of: "\\?", with: ".") + "$"
            return regex(pattern, in: path)
        }
    }

    private static func regex(_ pattern: String, in text: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    private static func evaluate(_ expression: MockMatchExpression, request: MatchingRequest) -> (matched: Bool, failures: [MatchFailure]) {
        if let all = expression.all {
            let results = all.map { evaluate($0, request: request) }
            return (results.allSatisfy(\.matched), results.flatMap(\.failures))
        }
        if let any = expression.any {
            if any.isEmpty { return (false, [.init(field: "any", reason: "no_condition_matched")]) }
            let results = any.map { evaluate($0, request: request) }
            return results.contains(where: \.matched) ? (true, []) : (false, results.flatMap(\.failures))
        }
        if let child = expression.not?.first {
            let result = evaluate(child, request: request)
            return result.matched ? (false, [.init(field: "not", reason: "negated_condition_matched")]) : (true, [])
        }
        guard let p = expression.predicate else { return (false, [.init(field: "conditions", reason: "invalid_expression")]) }
        let actual = value(for: p, request: request)
        let matched: Bool
        if p.op == .exists { matched = actual != nil }
        else if p.op == .absent { matched = actual == nil }
        else if let actual, let expected = p.value {
            if p.source == .query, case .array(let values) = actual, !isArray(expected) || p.op == .oneOf {
                matched = values.contains { compare($0, expected, op: p.op) }
            } else if p.source == .query, p.op == .equals, case .array(let a) = actual, case .array(let b) = expected {
                var remaining = b
                matched = a.count == b.count && a.allSatisfy { v in
                    guard let i = remaining.firstIndex(of: v) else { return false }
                    remaining.remove(at: i); return true
                }
            } else { matched = compare(actual, expected, op: p.op) }
        } else { matched = false }
        return matched ? (true, []) : (false, [.init(field: p.source.rawValue + (p.key.map { ":" + $0 } ?? ""), reason: actual == nil ? "field_missing" : p.source.rawValue + "_mismatch", expected: p.value, actual: actual)])
    }

    private static func isArray(_ value: MatchValue) -> Bool { if case .array = value { return true }; return false }

    private static func value(for predicate: MockPredicate, request: MatchingRequest) -> MatchValue? {
        switch predicate.source {
        case .query:
            let items = URLComponents(url: request.url, resolvingAgainstBaseURL: false)?.queryItems?.filter { $0.name == predicate.key } ?? []
            return items.isEmpty ? nil : .array(items.map { $0.value.map(MatchValue.string) ?? .null })
        case .header: return request.headers.first(where: { $0.key.lowercased() == predicate.key?.lowercased() }).map { .string($0.value) }
        case .jsonBody:
            guard let body = request.body, let json = try? JSONDecoder().decode(MatchValue.self, from: body) else { return nil }
            return json.at(pointer: predicate.key ?? "")
        case .body: return request.body.flatMap { String(data: $0, encoding: .utf8) }.map(MatchValue.string)
        case .scenario: return .string(request.scenario)
        case .deviceId: return .string(request.deviceId)
        }
    }

    private static func compare(_ actual: MatchValue, _ expected: MatchValue, op: MockPredicate.Operator) -> Bool {
        switch op {
        case .equals: return actual == expected
        case .contains:
            if case .array(let values) = actual { return values.contains(expected) }
            return actual.text.flatMap { a in expected.text.map { a.contains($0) } } ?? false
        case .startsWith: return actual.text.flatMap { a in expected.text.map { a.hasPrefix($0) } } ?? false
        case .endsWith: return actual.text.flatMap { a in expected.text.map { a.hasSuffix($0) } } ?? false
        case .regex: return actual.text.flatMap { a in expected.text.map { regex($0, in: a) } } ?? false
        case .oneOf: if case .array(let values) = expected { return values.contains(actual) }; return false
        case .gt, .gte, .lt, .lte:
            guard let a = actual.number ?? actual.text.flatMap(Double.init), let b = expected.number else { return false }
            switch op { case .gt: return a > b; case .gte: return a >= b; case .lt: return a < b; default: return a <= b }
        case .exists, .absent: return false
        }
    }
}
