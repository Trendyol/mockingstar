import AnyCodable
import CommonKit
import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class PluginsUtil {
    private let logger = Logger(category: "PluginsUtil")

    func urlRequest(_ url: String, _ headers: [String: String], _ method: String, _ body: String) -> PluginJavaScriptContext.URLRequestResponse {
        logger.info("Plugin sending request to: \(url)")
        let semaphore = DispatchSemaphore(value: 0)
        let emptyResponseBody = try! AnyCodableModel(jsonText: "{}")
        let responseLock = NSLock()

        guard let url = URL(string: url) else {
            return .init(body: emptyResponseBody, headers: [:], error: "Invalid URL")
        }

        var request = URLRequest(url: url)
        request.allHTTPHeaderFields = headers
        request.httpMethod = method
        request.timeoutInterval = 2
        if !body.isEmpty {
            request.httpBody = body.data(using: .utf8)
        }

        var responseResult: PluginJavaScriptContext.URLRequestResponse?
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            let result: PluginJavaScriptContext.URLRequestResponse = {
                var body = emptyResponseBody
                var headers: [String: String] = [:]
                let errorMessage = error?.localizedDescription ?? ""
                if let httpResponse = response as? HTTPURLResponse {
                    headers = httpResponse.allHeaderFields.reduce(into: [:]) { result, item in
                        result[String(describing: item.key)] = String(describing: item.value)
                    }
                }
                if let data,
                   let decoded = try? JSONDecoder().decode(AnyCodableModel.self, from: data) {
                    body = decoded
                }
                return .init(body: body, headers: headers, error: errorMessage)
            }()

            responseLock.lock()
            responseResult = result
            responseLock.unlock()
            semaphore.signal()
        }
        task.resume()

        guard semaphore.wait(timeout: .now() + request.timeoutInterval) == .success else {
            task.cancel()
            return .init(body: emptyResponseBody, headers: [:], error: "Request timed out")
        }

        responseLock.lock()
        defer { responseLock.unlock() }
        return responseResult ?? .init(body: emptyResponseBody, headers: [:], error: "Request failed")
    }

    func log(_ message: String, _ severity: String) {
        switch LogSeverity(rawValue: severity) ?? .info {
        case .debug: logger.debug(message)
        case .info: logger.info(message)
        case .notice: logger.notice(message)
        case .warning: logger.warning(message)
        case .error: logger.error(message)
        case .critical: logger.critical(message)
        case .fault: logger.fault(message)
        }
    }
}
