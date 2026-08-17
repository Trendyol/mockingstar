import CommonKit
import Foundation

public enum ClaudeMessagesError: LocalizedError, Equatable {
    case missingAPIKey
    case invalidResponse(status: Int, message: String?)
    case emptyAssistantText
    case decodingFailed
    case network(String)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Enter a GenAI Gateway API key"
        case .invalidResponse(let status, let message):
            if let message, !message.isEmpty {
                return "GenAI Gateway error (\(status)): \(message)"
            }
            return "GenAI Gateway error (\(status))"
        case .emptyAssistantText:
            return "Claude returned an empty reply"
        case .decodingFailed:
            return "Failed to decode Claude response"
        case .network(let message):
            return message
        }
    }
}

public protocol ClaudeMessagesClientInterface {
    func complete(apiKey: String, system: String, user: String) async throws -> String
}

/// OpenAI-compatible Chat Completions client for Trendyol GenAI Gateway.
public struct ClaudeMessagesClient: ClaudeMessagesClientInterface {
    public static let defaultModel = "gemini-3.5-flash"
    public static let defaultEndpoint = URL(
        string: "https://mlplatform.gcp.trendyol.com/piper/genai/chat/completions"
    )!

    private let urlSession: URLSessionInterface
    private let model: String
    private let maxTokens: Int
    private let endpoint: URL

    public init(
        urlSession: URLSessionInterface = URLSession.shared,
        model: String = ClaudeMessagesClient.defaultModel,
        maxTokens: Int = 4096,
        endpoint: URL = ClaudeMessagesClient.defaultEndpoint
    ) {
        self.urlSession = urlSession
        self.model = model
        self.maxTokens = maxTokens
        self.endpoint = endpoint
    }

    public func complete(apiKey: String, system: String, user: String) async throws -> String {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw ClaudeMessagesError.missingAPIKey }

        let body = ChatCompletionsRequest(
            model: model,
            maxTokens: maxTokens,
            messages: [
                .init(role: "system", content: system),
                .init(role: "user", content: user)
            ]
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw ClaudeMessagesError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw ClaudeMessagesError.invalidResponse(status: 0, message: nil)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ClaudeMessagesError.invalidResponse(
                status: http.statusCode,
                message: Self.errorMessage(from: data)
            )
        }

        do {
            let decoded = try JSONDecoder().decode(ChatCompletionsResponse.self, from: data)
            let text = decoded.choices
                .compactMap(\.message?.content)
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { throw ClaudeMessagesError.emptyAssistantText }
            return text
        } catch let error as ClaudeMessagesError {
            throw error
        } catch {
            throw ClaudeMessagesError.decodingFailed
        }
    }

    private static func errorMessage(from data: Data) -> String? {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let message = object["error"] as? String {
                return message
            }
            if let error = object["error"] as? [String: Any] {
                if let message = error["message"] as? String { return message }
                if let message = error["error"] as? String { return message }
            }
            if let message = object["message"] as? String {
                return message
            }
        }
        return String(data: data, encoding: .utf8)
    }
}

private struct ChatCompletionsRequest: Encodable {
    let model: String
    let maxTokens: Int
    let messages: [Message]

    struct Message: Encodable {
        let role: String
        let content: String
    }

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case messages
    }
}

private struct ChatCompletionsResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }

        let message: Message?
    }

    let choices: [Choice]
}
