//
//  MockErrorPlugin.swift
//
//
//  Created by Yusuf Özgül on 1.11.2023.
//

import Foundation
import JavaScriptCore
import SwiftyJS

@SwiftyJS
/// Plugin definiton protocol
///
/// Implementation automatically generates with @SwiftyJS macro
/// ```swift
/// class MockErrorPluginJSBridge: MockErrorPlugin {
///     private (set) var jsContext = JSContext()!
///     private let encoder = JSValueEncoder()
///     private let decoder = JSValueDecoder()
///
///     func loadFrom(jsCode: String, resetContext: Bool = false) ...
///     func loadFrom(url: URL, resetContext: Bool = false) throws ...
///
///     private func callJS<T: Decodable>(functionName: String = #function, params: [Encodable] = []) throws -> T ...
///     private func callJS(functionName: String = #function, params: [Encodable] = []) throws ...
///
///     var config: [PluginConfiguration] ...
///
///     func setConfig(_ value: [PluginConfiguration]) throws ...
///     func defaultResponseModel(message: String) throws -> String ...
///}
/// ```
///
protocol MockErrorPlugin {
    var config: [PluginConfiguration] { get throws }
    
    func defaultResponseModel(message: String) throws -> String
}
