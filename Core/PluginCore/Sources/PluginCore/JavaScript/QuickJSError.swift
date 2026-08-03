import Foundation

enum QuickJSError: LocalizedError {
    case runtimeUnavailable
    case evaluation(String)
    case functionNotFound(String)
    case functionCall(String)
    case promise(String)
    case timeout
    case serialization(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .runtimeUnavailable:
            "QuickJS runtime is unavailable"
        case let .evaluation(message):
            message
        case let .functionNotFound(name):
            "JavaScript function not found: \(name)"
        case let .functionCall(message):
            message
        case let .promise(message):
            message
        case .timeout:
            "JavaScript execution timed out"
        case let .serialization(message):
            "JavaScript serialization failed: \(message)"
        case .invalidResponse:
            "JavaScript response is invalid"
        }
    }
}
