import AnyCodable
import CommonKit
import Foundation
import QuickJSC

private final class NativePluginCallbacks {
    let logHandler: PluginJavaScriptContext.LogHandler
    let urlRequestHandler: PluginJavaScriptContext.URLRequestHandler

    init(logHandler: @escaping PluginJavaScriptContext.LogHandler,
         urlRequestHandler: @escaping PluginJavaScriptContext.URLRequestHandler) {
        self.logHandler = logHandler
        self.urlRequestHandler = urlRequestHandler
    }
}

private func qjsNativeLog(_ opaque: UnsafeMutableRawPointer?,
                          _ message: UnsafePointer<CChar>?,
                          _ severity: UnsafePointer<CChar>?) {
    guard let opaque, let message, let severity else { return }
    let callbacks = Unmanaged<NativePluginCallbacks>.fromOpaque(opaque).takeUnretainedValue()
    callbacks.logHandler(String(cString: message), String(cString: severity))
}

private func qjsNativeURLRequest(_ opaque: UnsafeMutableRawPointer?,
                                 _ url: UnsafePointer<CChar>?,
                                 _ headers: UnsafePointer<CChar>?,
                                 _ method: UnsafePointer<CChar>?,
                                 _ body: UnsafePointer<CChar>?,
                                 _ bodyJSON: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?,
                                 _ headersJSON: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?,
                                 _ errorMessage: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32 {
    guard let opaque, let url, let headers, let method, let body else { return -1 }
    let callbacks = Unmanaged<NativePluginCallbacks>.fromOpaque(opaque).takeUnretainedValue()
    let response = callbacks.urlRequestHandler(String(cString: url),
                                                 decodeHeaders(String(cString: headers)),
                                                 String(cString: method),
                                                 String(cString: body))
    let bodyString = encodeJSON(response.body) ?? "{}"
    let headersString = encodeJSON(response.headers) ?? "{}"
    let bodyPointer = qjs_copy_string(bodyString)
    let headersPointer = qjs_copy_string(headersString)
    let errorPointer = qjs_copy_string(response.error)
    guard let bodyPointer, let headersPointer, let errorPointer else {
        qjs_free_string(bodyPointer)
        qjs_free_string(headersPointer)
        qjs_free_string(errorPointer)
        errorMessage?.pointee = qjs_copy_string("Unable to allocate urlRequest response")
        return -1
    }
    bodyJSON?.pointee = bodyPointer
    headersJSON?.pointee = headersPointer
    errorMessage?.pointee = errorPointer
    return 0
}

private func decodeHeaders(_ value: String) -> [String: String] {
    guard let data = value.data(using: .utf8),
          let headers = try? JSONDecoder().decode([String: String].self, from: data) else {
        return [:]
    }
    return headers
}

private func encodeJSON<T: Encodable>(_ value: T) -> String? {
    guard let data = try? JSONEncoder().encode(value) else { return nil }
    return String(decoding: data, as: UTF8.self)
}

final class PluginJavaScriptContext {
    typealias URLRequestHandler = (String, [String: String], String, String) -> URLRequestResponse
    typealias LogHandler = (String, String) -> Void

    struct URLRequestResponse {
        let body: AnyCodableModel
        let headers: [String: String]
        let error: String
    }

    private let runtime: QJSRuntime
    private let context: QJSContext
    private let callbacks: NativePluginCallbacks

    init(memoryLimit: Int = 32 * 1024 * 1024,
         stackLimit: Int = 1024 * 1024,
         timeout: Duration = .seconds(2),
         logHandler: @escaping LogHandler = { _, _ in },
         urlRequestHandler: @escaping URLRequestHandler = { _, _, _, _ in .init(body: try! AnyCodableModel(jsonText: "{}"), headers: [:], error: "") }) throws {
        runtime = try QJSRuntime(memoryLimit: memoryLimit, stackLimit: stackLimit, timeout: timeout)
        context = QJSContext(runtime: runtime)

        guard let handle = runtime.handle else { throw QuickJSError.runtimeUnavailable }
        let callbacks = NativePluginCallbacks(logHandler: logHandler, urlRequestHandler: urlRequestHandler)
        self.callbacks = callbacks
        let opaque = Unmanaged.passRetained(callbacks).toOpaque()
        let result = qjs_register_util(handle, opaque, qjsNativeLog, qjsNativeURLRequest)
        guard result == 0 else {
            Unmanaged<NativePluginCallbacks>.fromOpaque(opaque).release()
            throw QuickJSError.runtimeUnavailable
        }
    }

    deinit {
        guard let handle = runtime.handle else { return }
        let opaque = qjs_get_user_opaque(handle)
        runtime.shutdown()
        if let opaque {
            Unmanaged<NativePluginCallbacks>.fromOpaque(opaque).release()
        }
    }

    func evaluate(_ code: String) throws {
        try context.evaluate(code)
    }

    func call(function name: String, arguments: [Data]) throws -> Data {
        try context.call(function: name, arguments: arguments)
    }

    func callVoid(function name: String, arguments: [Data]) throws {
        _ = try call(function: name, arguments: arguments)
    }

    func callAsync(function name: String, arguments: [Data]) async throws -> Data {
        try context.callAsync(function: name, arguments: arguments)
    }

    func setGlobalJSON(_ value: Data, for key: String) throws {
        try context.setGlobalJSON(value, for: key)
    }

    func getGlobalJSON(for key: String) throws -> Data {
        try context.getGlobalJSON(for: key)
    }

    func encode<T: Encodable>(_ value: T) throws -> Data {
        try context.encode(value)
    }

    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try context.decode(type, from: data)
    }

    func reset() throws {
        try runtime.reset()
        guard let handle = runtime.handle else { throw QuickJSError.runtimeUnavailable }
        let opaque = Unmanaged.passUnretained(callbacks).toOpaque()
        guard qjs_register_util(handle, opaque, qjsNativeLog, qjsNativeURLRequest) == 0 else {
            throw QuickJSError.runtimeUnavailable
        }
    }

}
