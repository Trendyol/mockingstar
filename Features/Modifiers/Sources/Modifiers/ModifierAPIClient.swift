import CommonKit
import Foundation

enum ModifierAPIError: LocalizedError, Equatable {
    case serverUnavailable
    case invalidResponse(status: Int)
    case decodingFailed
    case conflict
    case badRequest
    case notFound
    case executionFailed(String)
    case liveRequestFailed(String)

    var errorDescription: String? {
        switch self {
        case .serverUnavailable: return "MockingStar server is not running"
        case .invalidResponse(let status): return "Unexpected server response (\(status))"
        case .decodingFailed: return "Failed to decode server response"
        case .conflict: return "A modifier with this id already exists"
        case .badRequest: return "Invalid modifier request"
        case .notFound: return "Modifier not found"
        case .executionFailed(let message): return message
        case .liveRequestFailed(let message): return message
        }
    }
}

public protocol ModifierAPIClientInterface {
    func listModifiers(domain: String) async throws -> [ModifierModel]
    func getModifier(domain: String, id: String) async throws -> ModifierModel
    func createModifier(domain: String, request: ModifierWriteRequest) async throws
    func updateModifier(domain: String, id: String, request: ModifierWriteRequest) async throws
    func deleteModifier(domain: String, id: String) async throws
    func setActiveModifiers(domain: String, ids: [String]) async throws
    func previewModifier(domain: String, request: ModifierPreviewRequest) async throws -> ModifierPreviewResponse
}

public final class ModifierAPIClient: ModifierAPIClientInterface {
    private let urlSession: URLSessionInterface
    private let portProvider: () -> UInt16
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()

    public init(urlSession: URLSessionInterface = URLSession.shared,
                portProvider: @escaping () -> UInt16 = {
                    @UserDefaultStorage("httpServerPort") var port: UInt16 = 8008
                    return port
                }) {
        self.urlSession = urlSession
        self.portProvider = portProvider
    }

    public func listModifiers(domain: String) async throws -> [ModifierModel] {
        let request = try makeRequest(path: "/modifiers", method: "GET", domain: domain)
        return try await decode([ModifierModel].self, from: request, expected: [200])
    }

    public func getModifier(domain: String, id: String) async throws -> ModifierModel {
        let request = try makeRequest(path: "/modifiers/\(id)", method: "GET", domain: domain)
        return try await decode(ModifierModel.self, from: request, expected: [200])
    }

    public func createModifier(domain: String, request writeRequest: ModifierWriteRequest) async throws {
        var request = try makeRequest(path: "/modifiers", method: "POST", domain: domain)
        request.httpBody = try jsonEncoder.encode(writeRequest)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        _ = try await perform(request, expected: [201])
    }

    public func updateModifier(domain: String, id: String, request writeRequest: ModifierWriteRequest) async throws {
        var request = try makeRequest(path: "/modifiers/\(id)", method: "PUT", domain: domain)
        request.httpBody = try jsonEncoder.encode(writeRequest)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        _ = try await perform(request, expected: [202])
    }

    public func deleteModifier(domain: String, id: String) async throws {
        let request = try makeRequest(path: "/modifiers/\(id)", method: "DELETE", domain: domain)
        _ = try await perform(request, expected: [202])
    }

    public func setActiveModifiers(domain: String, ids: [String]) async throws {
        var request = try makeRequest(path: "/modifiers", method: "PUT", domain: domain)
        request.httpBody = try jsonEncoder.encode(ids)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        _ = try await perform(request, expected: [202])
    }

    public func previewModifier(
        domain: String,
        request previewRequest: ModifierPreviewRequest
    ) async throws -> ModifierPreviewResponse {
        var request = try makeRequest(
            path: "/modifiers/preview",
            method: "POST",
            domain: domain
        )
        request.httpBody = try jsonEncoder.encode(previewRequest)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await decode(
            ModifierPreviewResponse.self,
            from: request,
            expected: [200]
        )
    }

    private func makeRequest(path: String, method: String, domain: String, includeDeviceHeader: Bool = true) throws -> URLRequest {
        let port = portProvider()
        guard let url = URL(string: "http://localhost:\(port)\(path)?domain=\(domain.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? domain)") else {
            throw ModifierAPIError.serverUnavailable
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        if includeDeviceHeader {
            request.setValue("", forHTTPHeaderField: "deviceId")
        }
        return request
    }

    private func decode<T: Decodable>(_ type: T.Type, from request: URLRequest, expected: [Int]) async throws -> T {
        let data = try await perform(request, expected: expected)
        do {
            return try jsonDecoder.decode(T.self, from: data)
        } catch {
            throw ModifierAPIError.decodingFailed
        }
    }

    private func perform(_ request: URLRequest, expected: [Int]) async throws -> Data {
        let (data, response) = try await data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ModifierAPIError.invalidResponse(status: 0)
        }
        let envelope = try? jsonDecoder.decode(ModifierAPIErrorResponse.self, from: data)
        switch http.statusCode {
        case let status where expected.contains(status):
            return data
        case 400:
            throw ModifierAPIError.badRequest
        case 404:
            throw ModifierAPIError.notFound
        case 409:
            throw ModifierAPIError.conflict
        case 422:
            throw ModifierAPIError.executionFailed(
                envelope?.message ?? "Modifier preview execution failed"
            )
        case 502:
            throw ModifierAPIError.liveRequestFailed(
                envelope?.message ?? "Live preview request failed"
            )
        default:
            throw ModifierAPIError.invalidResponse(status: http.statusCode)
        }
    }

    private func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await urlSession.data(for: request)
        } catch {
            throw ModifierAPIError.serverUnavailable
        }
    }
}
