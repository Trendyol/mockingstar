import Foundation

/// JSON values retain the distinction between a missing field and a present null.
public indirect enum MatchValue: Codable, Equatable, Sendable {
    case null, bool(Bool), number(Double), string(String)
    case array([MatchValue]), object([String: MatchValue])

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([MatchValue].self) { self = .array(v) }
        else { self = .object(try c.decode([String: MatchValue].self)) }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        }
    }

    public var text: String? { if case .string(let v) = self { return v }; return nil }
    public var number: Double? { if case .number(let v) = self { return v }; return nil }

    public static func isValidJSONPointer(_ pointer: String) -> Bool {
        guard pointer.isEmpty || pointer.hasPrefix("/") else { return false }
        var characters = pointer.unicodeScalars.makeIterator()
        while let character = characters.next() {
            if character == "~" {
                guard let escaped = characters.next(), escaped == "0" || escaped == "1" else { return false }
            }
        }
        return true
    }

    public func at(pointer: String) -> MatchValue? {
        guard Self.isValidJSONPointer(pointer) else { return nil }
        if pointer.isEmpty { return self }
        var current = self
        for token in pointer.dropFirst().split(separator: "/", omittingEmptySubsequences: false) {
            let key = String(token).replacingOccurrences(of: "~1", with: "/").replacingOccurrences(of: "~0", with: "~")
            switch current {
            case .object(let values): guard let v = values[key] else { return nil }; current = v
            case .array(let values):
                guard key == "0" || (!key.hasPrefix("0") && key.allSatisfy(\.isNumber)), let i = Int(key), i >= 0, i < values.count else { return nil }; current = values[i]
            default: return nil
            }
        }
        return current
    }
}

public struct MockPathMatch: Codable, Equatable, Sendable {
    public enum Style: String, Codable, Sendable { case exact, glob, regex }
    public var style: Style
    public var value: String
    public init(style: Style = .exact, value: String) { self.style = style; self.value = value }
}

public struct MockEndpointMatch: Codable, Equatable, Sendable {
    public var method: String
    public var host: String
    public var path: MockPathMatch
    public init(method: String, host: String, path: MockPathMatch) {
        self.method = method; self.host = host; self.path = path
    }
}

public struct MockPredicate: Codable, Equatable, Sendable {
    public enum Source: String, Codable, Sendable { case query, header, jsonBody, body, scenario, deviceId }
    public enum Operator: String, Codable, Sendable {
        case equals, contains, startsWith, endsWith, regex, exists, absent, oneOf, gt, gte, lt, lte
    }
    public var source: Source
    public var key: String?
    public var op: Operator
    public var value: MatchValue?
    public init(source: Source, key: String? = nil, op: Operator, value: MatchValue? = nil) {
        self.source = source; self.key = key; self.op = op; self.value = value
    }
    private enum CodingKeys: String, CodingKey { case source, key, op, value }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        source = try c.decode(Source.self, forKey: .source); key = try c.decodeIfPresent(String.self, forKey: .key)
        op = try c.decode(Operator.self, forKey: .op)
        value = c.contains(.value) ? try c.decode(MatchValue.self, forKey: .value) : nil
    }
}

/// Exactly one expression member must be present.
public struct MockMatchExpression: Codable, Equatable, Sendable {
    public var all: [MockMatchExpression]?
    public var any: [MockMatchExpression]?
    public var not: [MockMatchExpression]?
    public var predicate: MockPredicate?
    public init(all: [MockMatchExpression]? = nil, any: [MockMatchExpression]? = nil,
                not: [MockMatchExpression]? = nil, predicate: MockPredicate? = nil) {
        self.all = all; self.any = any; self.not = not; self.predicate = predicate
    }
    private enum CodingKeys: String, CodingKey { case all, any, not, predicate }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        all = try c.decodeIfPresent([Self].self, forKey: .all)
        any = try c.decodeIfPresent([Self].self, forKey: .any)
        predicate = try c.decodeIfPresent(MockPredicate.self, forKey: .predicate)
        if c.contains(.not) {
            if let child: MockMatchExpression = try? c.decode(MockMatchExpression.self, forKey: .not) { not = [child] }
            else { not = try c.decode([MockMatchExpression].self, forKey: .not) }
        }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(all, forKey: .all); try c.encodeIfPresent(any, forKey: .any)
        try c.encodeIfPresent(predicate, forKey: .predicate)
        if let not { if not.count == 1 { try c.encode(not[0], forKey: .not) } else { try c.encode(not, forKey: .not) } }
    }
    public func validate(depth: Int = 0) throws {
        guard depth < 32, [all != nil, any != nil, not != nil, predicate != nil].filter({ $0 }).count == 1 else {
            throw MockMatchingError.invalidExpression
        }
        if let not, not.count != 1 { throw MockMatchingError.invalidExpression }
        for child in (all ?? []) + (any ?? []) + (not ?? []) { try child.validate(depth: depth + 1) }
        if let p = predicate {
            if [.query, .header].contains(p.source), p.key?.isEmpty != false { throw MockMatchingError.invalidExpression }
            if p.source == .jsonBody, let key = p.key, !MatchValue.isValidJSONPointer(key) { throw MockMatchingError.invalidExpression }
            if p.op != .exists && p.op != .absent && p.value == nil { throw MockMatchingError.invalidExpression }
            if p.op == .regex {
                guard let pattern = p.value?.text else { throw MockMatchingError.invalidExpression }
                _ = try NSRegularExpression(pattern: pattern)
            }
            if [.gt, .gte, .lt, .lte].contains(p.op), p.value?.number == nil { throw MockMatchingError.invalidExpression }
            if p.op == .oneOf { guard case .array = p.value else { throw MockMatchingError.invalidExpression } }
        }
    }
}

public struct MockMatching: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var priority: Int
    public var endpoint: MockEndpointMatch
    public var conditions: MockMatchExpression?
    public init(enabled: Bool = true, priority: Int = 0, endpoint: MockEndpointMatch, conditions: MockMatchExpression? = nil) {
        self.enabled = enabled; self.priority = priority; self.endpoint = endpoint; self.conditions = conditions
    }
    private enum CodingKeys: String, CodingKey { case enabled, priority, endpoint, conditions }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        priority = try c.decodeIfPresent(Int.self, forKey: .priority) ?? 0
        endpoint = try c.decode(MockEndpointMatch.self, forKey: .endpoint)
        conditions = try c.decodeIfPresent(MockMatchExpression.self, forKey: .conditions)
    }
    public func validate() throws {
        guard Self.isHTTPToken(endpoint.method), !endpoint.host.isEmpty, !endpoint.path.value.isEmpty else { throw MockMatchingError.invalidEndpoint }
        if endpoint.path.style == .regex { _ = try NSRegularExpression(pattern: endpoint.path.value) }
        try conditions?.validate()
    }
    public static func isHTTPToken(_ value: String) -> Bool {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!#$%&'*+-.^_`|~")
        return !value.isEmpty && value.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}

public enum MockMatchingError: Error, LocalizedError {
    case invalidExpression, invalidEndpoint
    public var errorDescription: String? {
        switch self {
        case .invalidExpression: "Invalid matching expression, operand or JSON Pointer"
        case .invalidEndpoint: "Matching requires method, host and path"
        }
    }
}
