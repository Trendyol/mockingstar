import CommonKit
import Foundation
import JavaScriptCore

enum MockModifierExecutionError: Error, Equatable {
    case invalidJSContext
    case syntaxError(String)
    case missingTransformer
    case jsException(String)
    case invalidResponse
}

/// Runs a single modifier's `transformer(req, chain)` function against a `JSContext`.
///
/// Fails closed: any JS syntax error, missing `transformer`, or runtime exception is
/// surfaced as a thrown `MockModifierExecutionError` rather than silently passing through
/// the pre-modifier response.
final class MockModifierExecutor {
    private let logger = Logger(category: "MockModifierExecutor")

    func execute(modifier: MockModifierModel,
                 request: URLRequest,
                 executionMode: MockModifierExecutionMode = .runtime,
                 chainProceed: @escaping (URLRequest) throws -> HTTPResult) throws -> HTTPResult {
        guard let context = JSContext() else { throw MockModifierExecutionError.invalidJSContext }

        var exceptionMessage: String?
        context.exceptionHandler = { _, exception in
            exceptionMessage = exception?.toString()
        }

        context.evaluateScript(modifier.transformerCode)
        if let exceptionMessage {
            logger.error("modifier '\(modifier.id)' failed to load: \(exceptionMessage)")
            throw MockModifierExecutionError.syntaxError(exceptionMessage)
        }

        guard let transformerFunction = context.objectForKeyedSubscript("transformer"),
              !transformerFunction.isUndefined else {
            logger.error("modifier '\(modifier.id)' is missing a transformer function")
            throw MockModifierExecutionError.missingTransformer
        }

        let jsRequest = JSMockModifierRequest(request: request)
        let chain = JSChain(context: context) { jsRequest in
            JSMockModifierResponse.from(result: try chainProceed(jsRequest.asURLRequest), context: context)
        }

        exceptionMessage = nil
        let result = transformerFunction.call(withArguments: [jsRequest, chain])

        if let exceptionMessage {
            logger.error("modifier '\(modifier.id)' threw during execution: \(exceptionMessage)")
            throw MockModifierExecutionError.jsException(exceptionMessage)
        }

        let httpResult: HTTPResult
        if let response = result?.toObjectOf(JSMockModifierResponse.self) as? JSMockModifierResponse {
            httpResult = response.toHTTPResult()
        } else if let coerced = Self.coercePlainObjectResponse(result) {
            httpResult = coerced
        } else {
            logger.error("modifier '\(modifier.id)' did not return a valid response")
            throw MockModifierExecutionError.invalidResponse
        }

        logger.info("modifier executed", metadata: [
            "modifierId": .string(modifier.id),
            "requestPath": .string(request.url?.path() ?? ""),
            "path": .string(modifier.path),
            "method": .string(modifier.method),
            "status": .string("\(httpResult.status)"),
            "executionMode": .string(executionMode.rawValue)
        ])

        return httpResult
    }

    /// Accepts plain JS objects like `{ status, body, headers }` so transformers can short-circuit
    /// without calling `chain.proceed`.
    private static func coercePlainObjectResponse(_ result: JSValue?) -> HTTPResult? {
        guard let object = result?.toObject() as? [String: Any] else { return nil }
        let status = (object["status"] as? Int)
            ?? (object["status"] as? NSNumber)?.intValue
            ?? 200
        let headers = object["headers"] as? [String: String] ?? [:]

        let bodyData: Data
        if let body = object["body"] {
            if JSONSerialization.isValidJSONObject(body),
               let data = try? JSONSerialization.data(withJSONObject: body, options: [.fragmentsAllowed]) {
                bodyData = data
            } else if let text = body as? String {
                bodyData = Data(text.utf8)
            } else if let number = body as? NSNumber {
                bodyData = Data(number.stringValue.utf8)
            } else {
                bodyData = Data()
            }
        } else {
            bodyData = Data()
        }

        return HTTPResult(status: status, body: bodyData, headers: headers)
    }
}
