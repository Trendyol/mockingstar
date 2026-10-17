import CommonKit
import Foundation

enum MockModifierAPIError: LocalizedError, Equatable {
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

public protocol MockModifierAPIClientInterface {
    func listModifiers(domain: String) async throws -> [MockModifierModel]
    func getModifier(domain: String, id: String) async throws -> MockModifierModel
    func createModifier(domain: String, request: MockModifierWriteRequest) async throws
    func updateModifier(domain: String, id: String, request: MockModifierWriteRequest) async throws
    func deleteModifier(domain: String, id: String) async throws
    func setActiveModifiers(domain: String, activations: [MockModifierActivation]) async throws
    func previewModifier(domain: String, request: MockModifierPreviewRequest) async throws -> MockModifierPreviewResponse
}

public final class MockModifierAPIClient: MockModifierAPIClientInterface {
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

    public func listModifiers(domain: String) async throws -> [MockModifierModel] {
        let request = try makeRequest(path: "/modifiers", method: "GET", domain: domain)
        return try await decode([MockModifierModel].self, from: request, expected: [200])
    }

    public func getModifier(domain: String, id: String) async throws -> MockModifierModel {
        let request = try makeRequest(path: "/modifiers/\(id)", method: "GET", domain: domain)
        return try await decode(MockModifierModel.self, from: request, expected: [200])
    }

    public func createModifier(domain: String, request writeRequest: MockModifierWriteRequest) async throws {
        var request = try makeRequest(path: "/modifiers", method: "POST", domain: domain)
        request.httpBody = try jsonEncoder.encode(writeRequest)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        _ = try await perform(request, expected: [201])
    }

    public func updateModifier(domain: String, id: String, request writeRequest: MockModifierWriteRequest) async throws {
        var request = try makeRequest(path: "/modifiers/\(id)", method: "PUT", domain: domain)
        request.httpBody = try jsonEncoder.encode(writeRequest)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        _ = try await perform(request, expected: [202])
    }

    public func deleteModifier(domain: String, id: String) async throws {
        let request = try makeRequest(path: "/modifiers/\(id)", method: "DELETE", domain: domain)
        _ = try await perform(request, expected: [202])
    }

    public func setActiveModifiers(domain: String, activations: [MockModifierActivation]) async throws {
        var request = try makeRequest(path: "/modifiers", method: "PUT", domain: domain)
        request.httpBody = try jsonEncoder.encode(activations)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        _ = try await perform(request, expected: [202])
    }

    public func previewModifier(
        domain: String,
        request previewRequest: MockModifierPreviewRequest
    ) async throws -> MockModifierPreviewResponse {
        var request = try makeRequest(
            path: "/modifiers/preview",
            method: "POST",
            domain: domain
        )
        request.httpBody = try jsonEncoder.encode(previewRequest)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await decode(
            MockModifierPreviewResponse.self,
            from: request,
            expected: [200]
        )
    }

    private func makeRequest(path: String, method: String, domain: String, includeDeviceHeader: Bool = true) throws -> URLRequest {
        let port = portProvider()
        guard let url = URL(string: "http://localhost:\(port)\(path)?domain=\(domain.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? domain)") else {
            throw MockModifierAPIError.serverUnavailable
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
            throw MockModifierAPIError.decodingFailed
        }
    }

    private func perform(_ request: URLRequest, expected: [Int]) async throws -> Data {
        let (data, response) = try await data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw MockModifierAPIError.invalidResponse(status: 0)
        }
        let envelope = try? jsonDecoder.decode(MockModifierAPIErrorResponse.self, from: data)
        switch http.statusCode {
        case let status where expected.contains(status):
            return data
        case 400:
            throw MockModifierAPIError.badRequest
        case 404:
            throw MockModifierAPIError.notFound
        case 409:
            throw MockModifierAPIError.conflict
        case 422:
            throw MockModifierAPIError.executionFailed(
                envelope?.message ?? "Modifier preview execution failed"
            )
        case 502:
            throw MockModifierAPIError.liveRequestFailed(
                envelope?.message ?? "Live preview request failed"
            )
        default:
            throw MockModifierAPIError.invalidResponse(status: http.statusCode)
        }
    }

    private func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await urlSession.data(for: request)
        } catch {
            throw MockModifierAPIError.serverUnavailable
        }
    }
}
