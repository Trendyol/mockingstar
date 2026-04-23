//
//  PartialMockModel.swift
//
//
//  Created for Trendyol Marketing Object Testing
//

import Foundation
import AnyCodable

public struct PartialMockModel: Codable {
    public let deviceId: String
    public let url: String
    public let method: String
    public let mockDomain: String
    public let modifications: [PartialMockModification]
}

public struct PartialMockModification: Codable {
    public let path: String
    public let operations: [PartialMockOperation]
}

/// A single operation to apply to a matched JSON node's child member.
/// Operation types and semantics follow RFC 6902 (JSON Patch).
///
/// - `key`: The target child member name (corresponds to the last segment of the RFC 6902 `path`).
/// - `value`: Required for `add`, `replace`, `test`. Ignored for `remove`, `move`, `copy`.
/// - `from`: Required for `move`, `copy`. The source child member name (corresponds to RFC 6902 `from`).
public struct PartialMockOperation: Codable {
    public let type: PartialMockOperationType
    public let key: String
    public let value: AnyCodableModel?
    public let from: String?
}

/// RFC 6902 JSON Patch operation types.
/// https://datatracker.ietf.org/doc/html/rfc6902#section-4
public enum PartialMockOperationType: String, Codable {
    /// Adds a member to the target object. If the member already exists, its value is replaced.
    case add
    /// Removes the member from the target object. The member MUST exist.
    case remove
    /// Replaces the value of the target member. The member MUST exist.
    case replace
    /// Removes the value at `from` and adds it to the target location.
    case move
    /// Copies the value at `from` to the target location.
    case copy
    /// Tests that the value at the target location equals the specified value.
    case test
}
