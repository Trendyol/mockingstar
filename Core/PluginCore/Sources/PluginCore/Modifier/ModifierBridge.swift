import Foundation
import JavaScriptCore

@objc
protocol JSModifierRequestExport: JSExport {
    var url: String { get set }
    var method: String { get set }
    var headers: [String: String] { get set }
    var body: String { get set }
}

/// Mutable request presentation exposed to JS `transformer(req, chain)` functions.
@objc
final class JSModifierRequest: NSObject, JSModifierRequestExport {
    var url: String
    var method: String
    var headers: [String: String]
    var body: String

    init(url: String, method: String, headers: [String: String], body: String) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
    }

    convenience init(request: URLRequest) {
        var headerFields: [String: String] = [:]
        request.allHTTPHeaderFields?.forEach { headerFields[$0.key] = $0.value }
        let bodyString = request.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? ""

        self.init(
            url: request.url?.absoluteString ?? "",
            method: request.httpMethod ?? "GET",
            headers: headerFields,
            body: bodyString
        )
    }

    /// Rebuilds a `URLRequest` from the (possibly JS-mutated) request fields.
    var asURLRequest: URLRequest {
        guard let requestUrl = URL(string: url) else {
            return URLRequest(url: URL(string: "about:blank")!)
        }

        var request = URLRequest(url: requestUrl)
        request.httpMethod = method
        request.allHTTPHeaderFields = headers

        if !body.isEmpty {
            request.httpBody = body.data(using: .utf8)
        }

        return request
    }
}

@objc
protocol JSModifierResponseExport: JSExport {
    var status: Int { get set }
    var headers: [String: String] { get set }
    var body: JSValue { get set }
    var contentType: String { get }
}

/// Mutable response presentation exposed to JS `transformer(req, chain)` functions.
///
/// `body` is a live `JSValue`: when the underlying HTTP body is valid JSON it is exposed
/// as a JS object/array so scripts can mutate fields directly (eg. `res.body.injected = true`).
/// Non-JSON bodies fall back to a plain string, signalled via `contentType == "text"`.
@objc
final class JSModifierResponse: NSObject, JSModifierResponseExport {
    var status: Int
    var headers: [String: String]
    var body: JSValue
    let contentType: String

    init(status: Int, headers: [String: String], body: JSValue, contentType: String) {
        self.status = status
        self.headers = headers
        self.body = body
        self.contentType = contentType
    }

    static func from(result: HTTPResult, context: JSContext) -> JSModifierResponse {
        if !result.body.isEmpty,
           let json = try? JSONSerialization.jsonObject(with: result.body, options: [.fragmentsAllowed]),
           let jsBody = JSValue(object: json, in: context) {
            return JSModifierResponse(status: result.status, headers: result.headers, body: jsBody, contentType: "json")
        }

        let text = String(data: result.body, encoding: .utf8) ?? ""
        let jsBody: JSValue = JSValue(object: text, in: context)
        return JSModifierResponse(status: result.status, headers: result.headers, body: jsBody, contentType: "text")
    }

    func toHTTPResult() -> HTTPResult {
        guard contentType == "json" else {
            let text = body.toString() ?? ""
            return HTTPResult(status: status, body: text.data(using: .utf8) ?? Data(), headers: headers)
        }

        guard let object = body.toObject(),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.fragmentsAllowed]) else {
            return HTTPResult(status: status, body: Data(), headers: headers)
        }

        return HTTPResult(status: status, body: data, headers: headers)
    }
}

@objc
protocol JSChainExport: JSExport {
    func proceed(_ request: JSModifierRequest) -> JSModifierResponse
}

/// Bridges the synchronous JS `chain.proceed(req)` call to the (async) next link of the chain.
///
/// Fails closed: `JSExport` methods cannot throw a Swift error, so when `onProceed` throws
/// (eg. a nested modifier hop failed), the failure is surfaced by setting `context.exception`
/// before returning a dummy response. JavaScriptCore raises this as a JS exception as soon as
/// control returns to the calling script, which aborts the *outer* transformer before it can
/// read/mutate the dummy response and hide the failure behind a seemingly successful result.
@objc
final class JSChain: NSObject, JSChainExport {
    private let context: JSContext
    private let onProceed: (JSModifierRequest) throws -> JSModifierResponse

    init(context: JSContext, onProceed: @escaping (JSModifierRequest) throws -> JSModifierResponse) {
        self.context = context
        self.onProceed = onProceed
    }

    func proceed(_ request: JSModifierRequest) -> JSModifierResponse {
        do {
            return try onProceed(request)
        } catch {
            context.exception = JSValue(newErrorFromMessage: "chain.proceed failed: \(error)", in: context)
            return JSModifierResponse(status: 500, headers: [:], body: JSValue(nullIn: context), contentType: "text")
        }
    }
}
