import Foundation
import QuickJSC

final class QJSContext {
    let runtime: QJSRuntime
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(runtime: QJSRuntime) {
        self.runtime = runtime
    }

    func evaluate(_ code: String, filename: String = "<plugin>") throws {
        guard let handle = runtime.handle else { throw QuickJSError.runtimeUnavailable }
        var error: UnsafeMutablePointer<CChar>?
        let result = qjs_evaluate(handle, code, filename, &error)
        defer { qjs_free_string(error) }
        guard result == 0 else {
            throw QuickJSError.evaluation(Self.string(from: error))
        }
    }

    func call(function name: String, arguments: [Data]) throws -> Data {
        guard let handle = runtime.handle else { throw QuickJSError.runtimeUnavailable }
        let argumentsJSON = try Self.makeArrayJSON(arguments)
        var result: UnsafeMutablePointer<CChar>?
        var error: UnsafeMutablePointer<CChar>?
        let status = qjs_call_json(handle, name, argumentsJSON, &result, &error)
        defer {
            qjs_free_string(result)
            qjs_free_string(error)
        }
        guard status == 0 else {
            throw Self.error(from: error, function: name)
        }
        guard let result else { throw QuickJSError.invalidResponse }
        return Data(String(cString: result).utf8)
    }

    func callAsync(function name: String, arguments: [Data], timeout: Duration? = nil) throws -> Data {
        guard let handle = runtime.handle else { throw QuickJSError.runtimeUnavailable }
        let argumentsJSON = try Self.makeArrayJSON(arguments)
        let timeout = timeout ?? runtime.timeout
        let timeoutMilliseconds = UInt64(timeout.components.seconds) * 1_000
            + UInt64(timeout.components.attoseconds / 1_000_000_000_000_000)
        var result: UnsafeMutablePointer<CChar>?
        var error: UnsafeMutablePointer<CChar>?
        let status = qjs_call_async_json(handle, name, argumentsJSON,
                                         UInt32(min(timeoutMilliseconds, UInt64(UInt32.max))),
                                         100_000, &result, &error)
        defer {
            qjs_free_string(result)
            qjs_free_string(error)
        }
        guard status == 0 else {
            throw Self.error(from: error, function: name)
        }
        guard let result else { throw QuickJSError.invalidResponse }
        return Data(String(cString: result).utf8)
    }

    func getGlobalJSON(for key: String) throws -> Data {
        guard let handle = runtime.handle else { throw QuickJSError.runtimeUnavailable }
        var result: UnsafeMutablePointer<CChar>?
        var error: UnsafeMutablePointer<CChar>?
        let status = qjs_get_global_json(handle, key, &result, &error)
        defer {
            qjs_free_string(result)
            qjs_free_string(error)
        }
        guard status == 0 else {
            throw QuickJSError.serialization(Self.string(from: error))
        }
        guard let result else { throw QuickJSError.invalidResponse }
        return Data(String(cString: result).utf8)
    }

    func setGlobalJSON(_ data: Data, for key: String) throws {
        guard let handle = runtime.handle else { throw QuickJSError.runtimeUnavailable }
        _ = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        var error: UnsafeMutablePointer<CChar>?
        let value = String(decoding: data, as: UTF8.self)
        let status = qjs_set_global_json(handle, key, value, &error)
        defer { qjs_free_string(error) }
        guard status == 0 else {
            throw QuickJSError.serialization(Self.string(from: error))
        }
    }

    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw QuickJSError.serialization(error.localizedDescription)
        }
    }

    func encode<T: Encodable>(_ value: T) throws -> Data {
        do {
            return try encoder.encode(value)
        } catch {
            throw QuickJSError.serialization(error.localizedDescription)
        }
    }

    private static func makeArrayJSON(_ values: [Data]) throws -> String {
        do {
            let objects = try values.map {
                try JSONSerialization.jsonObject(with: $0, options: [.fragmentsAllowed])
            }
            let data = try JSONSerialization.data(withJSONObject: objects, options: [.sortedKeys])
            return String(decoding: data, as: UTF8.self)
        } catch {
            throw QuickJSError.serialization(error.localizedDescription)
        }
    }

    private static func string(from pointer: UnsafeMutablePointer<CChar>?) -> String {
        guard let pointer else { return "Unknown JavaScript error" }
        return String(cString: pointer)
    }

    private static func error(from pointer: UnsafeMutablePointer<CChar>?, function: String) -> Error {
        let message = string(from: pointer)
        if message.localizedCaseInsensitiveContains("not found") {
            return QuickJSError.functionNotFound(function)
        }
        if message.localizedCaseInsensitiveContains("timed out") {
            return QuickJSError.timeout
        }
        if message.localizedCaseInsensitiveContains("promise") {
            return QuickJSError.promise(message)
        }
        return QuickJSError.functionCall(message)
    }
}
