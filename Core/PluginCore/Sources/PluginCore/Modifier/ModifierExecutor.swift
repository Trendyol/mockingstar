import CommonKit
import Foundation
import JavaScriptCore

enum ModifierExecutionError: Error, Equatable {
    case invalidJSContext
    case syntaxError(String)
    case missingTransformer
    case jsException(String)
    case invalidResponse
}

/// Runs a single modifier's `transformer(req, chain)` function against a `JSContext`.
///
/// Fails closed: any JS syntax error, missing `transformer`, or runtime exception is
/// surfaced as a thrown `ModifierExecutionError` rather than silently passing through
/// the pre-modifier response.
final class ModifierExecutor {
    private let logger = Logger(category: "ModifierExecutor")

    func execute(modifier: ModifierModel,
                 request: URLRequest,
                 chainProceed: @escaping (URLRequest) throws -> HTTPResult) throws -> HTTPResult {
        guard let context = JSContext() else { throw ModifierExecutionError.invalidJSContext }

        var exceptionMessage: String?
        context.exceptionHandler = { _, exception in
            exceptionMessage = exception?.toString()
        }

        context.evaluateScript(modifier.transformerCode)
        if let exceptionMessage {
            logger.error("Modifier '\(modifier.id)' failed to load: \(exceptionMessage)")
            throw ModifierExecutionError.syntaxError(exceptionMessage)
        }

        guard let transformerFunction = context.objectForKeyedSubscript("transformer"),
              !transformerFunction.isUndefined else {
            logger.error("Modifier '\(modifier.id)' is missing a transformer function")
            throw ModifierExecutionError.missingTransformer
        }

        let jsRequest = JSModifierRequest(request: request)
        let chain = JSChain(context: context) { jsRequest in
            JSModifierResponse.from(result: try chainProceed(jsRequest.asURLRequest), context: context)
        }

        exceptionMessage = nil
        let result = transformerFunction.call(withArguments: [jsRequest, chain])

        if let exceptionMessage {
            logger.error("Modifier '\(modifier.id)' threw during execution: \(exceptionMessage)")
            throw ModifierExecutionError.jsException(exceptionMessage)
        }

        guard let response = result?.toObjectOf(JSModifierResponse.self) as? JSModifierResponse else {
            logger.error("Modifier '\(modifier.id)' did not return a valid response")
            throw ModifierExecutionError.invalidResponse
        }

        let httpResult = response.toHTTPResult()
        logger.info("Modifier executed", metadata: [
            "id": .string(modifier.id),
            "path": .string(modifier.path),
            "method": .string(modifier.method),
            "status": .string("\(httpResult.status)")
        ])

        return httpResult
    }
}
