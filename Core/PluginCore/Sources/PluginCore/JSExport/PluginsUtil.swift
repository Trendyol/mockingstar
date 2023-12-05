//
//  PluginsUtil.swift
//
//
//  Created by Yusuf Özgül on 3.11.2023.
//

import AnyCodable
import Foundation
import JSValueCoder
import JavaScriptCore

@objc
protocol PluginUtilJSExport: JSExport {
    func urlRequest(_ url: String, _ headers: String, _ method: String, _ body: String) -> JSURLRequestResponse
}

@objc
class PluginsUtil: NSObject, PluginUtilJSExport {
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
