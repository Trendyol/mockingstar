//
//  PluginsUtil.swift
//
//
//  Created by Yusuf Özgül on 3.11.2023.
//

import AnyCodable
import CommonKit
import Foundation
import JavaScriptCore
import SwiftyJS

@objc
protocol PluginUtilJSExport: JSExport {
    func urlRequest(_ url: String, _ headers: String, _ method: String, _ body: String) -> JSURLRequestResponse
    func log(_ message: String, _ severity: String)
}

@objc
class PluginsUtil: NSObject, PluginUtilJSExport {
    private let logger = Logger(category: "PluginsUtil")
    private weak var context: JSContext?

    init(context: JSContext?) {
        self.context = context
    }
    
    /// A bridge between JavaScript plugins and app
    /// - Parameters:
    ///   - url: url for request, http and https supported
    ///   - headers: key value JSON presented headers
    ///   - method: HTTP method eg. GET, POST
    ///   - body: String presented http body
    /// - Returns: Response Model ``JSURLRequestResponse``
    func urlRequest(_ url: String, _ headers: String, _ method: String, _ body: String) -> JSURLRequestResponse {
        logger.info("Plugin sending request to: \(url)")
        let semaphore = DispatchSemaphore(value: 0)
        let jsResponse = JSURLRequestResponse(body: .init(), headers: [:], error: "")

        guard let url = URL(string: url) else { return jsResponse }

        var request = URLRequest(url: url)
        request.allHTTPHeaderFields = try? JSONDecoder().decode([String: String].self, from: headers.data(using: .utf8) ?? .init())
        request.httpMethod = method

        if !body.isEmpty {
            request.httpBody = body.data(using: .utf8)
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            jsResponse.error = error?.localizedDescription ?? ""

            (response as? HTTPURLResponse)?.allHeaderFields.forEach({ (key, value) in
                jsResponse.headers[key as? String ?? ""] = value as? String
            })

            if let data,
               let responseBody = try? JSONDecoder().decode(AnyCodableModel.self, from: data),
               let jsResponseBody = try? JSValueEncoder().encode(responseBody, in: .init()) {
                jsResponse.body = jsResponseBody
            }

            semaphore.signal()
        }.resume()

        semaphore.wait()

        return jsResponse
    }

    func log(_ message: String, _ severity: String) {
        switch LogSeverity(rawValue: severity) ?? .info {
        case .debug:
            logger.debug(message)
        case .info:
            logger.info(message)
        case .notice:
            logger.notice(message)
        case .warning:
            logger.warning(message)
        case .error:
            logger.error(message)
        case .critical:
            logger.critical(message)
        case .fault:
            logger.fault(message)
        }
    }
}

@objc
protocol JSURLRequestResponseJSExport: JSExport {
    var body: JSValue { get }
    var headers: [String: String] { get }
    var error: String { get }
}

@objc
/// HTTP Response presentation for Plugins.
class JSURLRequestResponse: NSObject, JSURLRequestResponseJSExport {
    /// JSON presented response body, accessible like JavaScript objects
    var body: JSValue
    /// response header presentation with key value
    var headers: [String : String]
    /// if http request failed, fail message accessible from error
    var error: String

    init(body: JSValue, headers: [String : String], error: String) {
        self.body = body
        self.headers = headers
        self.error = error
    }
}
