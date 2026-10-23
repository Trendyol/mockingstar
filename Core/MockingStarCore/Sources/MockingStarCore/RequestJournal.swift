import Foundation
import CommonKit

public struct RecordedRequest: Codable {
    public var id: String
    public var date: Date
    public var domain: String
    public var request: MatchingRequest
    public var decision: MatchDecision
    public var outcome: String
    public var status: Int?
    public var error: String?
    public var errorCode: String?
    public var completedAt: Date?
}

public actor RequestJournal {
    private let root: URL
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            var c = encoder.singleValueContainer(); try c.encode(formatter.string(from: date))
        }; return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer(), text = try c.decode(String.self)
            let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: text) { return date }
            let legacy = DateFormatter(); legacy.dateFormat = "dd.MM.yyyy HH:mm:ss"; legacy.locale = Locale(identifier: "en_US_POSIX")
            guard let date = legacy.date(from: text) else { throw DecodingError.dataCorruptedError(in: c, debugDescription: "Invalid request timestamp") }; return date
        }; return decoder
    }()
    public init(root: URL) { self.root = root.appendingPathComponent(".mockingstar/requests") }
    public func begin(domain: String, request: MatchingRequest, id: String = UUID().uuidString) throws -> String {
        guard UUID(uuidString: id) != nil else { throw WorkspaceFailure("invalid_request_id", "Request ID must be a UUID") }
        try write(.init(id: id, date: Date(), domain: domain, request: request, decision: .init(), outcome: "pending"))
        return id
    }
    public func decision(_ id: String, _ decision: MatchDecision, outcome: String) throws {
        var record = try read(id); record.decision = decision; record.outcome = outcome; try write(record)
    }
    public func finish(_ id: String, status: Int?, error: String? = nil, errorCode: String? = nil) throws {
        var record = try read(id); record.status = status; record.error = error
        record.errorCode = errorCode; record.completedAt = Date()
        if error != nil { record.outcome = "error" }
        try write(record)
    }
    public func read(_ id: String) throws -> RecordedRequest {
        guard UUID(uuidString: id) != nil else { throw FileManagerError.fileNotFound }
        return try decoder.decode(RecordedRequest.self, from: Data(contentsOf: root.appendingPathComponent(id + ".json")))
    }
    public func list() throws -> [RecordedRequest] {
        guard FileManager.default.fileExists(atPath: root.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }.compactMap { try? decoder.decode(RecordedRequest.self, from: Data(contentsOf: $0)) }
            .sorted { $0.date < $1.date }
    }
    private func write(_ record: RecordedRequest) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try encoder.encode(record).write(to: root.appendingPathComponent(record.id + ".json"), options: .atomic)
    }
}
