//
//  MockDetailHelperPlugin.swift
//
//
//  Created by Yusuf Özgül on 3.11.2023.
//

import CommonKit
import Foundation
import JavaScriptCore
import SwiftyJS

@SwiftyJS
/// Plugin definiton protocol
///
/// Implementation automatically generates with @SwiftyJS macro
/// ```swift
/// class MockDetailHelperPluginJSBridge: MockDetailHelperPlugin {
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
///     func mockDetailMessages(path: String, scenario: String, mock: MockModel) throws -> String ...
///     func asyncMockDetailMessages(mock: MockModel) async throws -> String ...
///}
/// ```
///
protocol MockDetailHelperPlugin {
    var config: [PluginConfiguration] { get throws }

    func mockDetailMessages(path: String, scenario: String, mock: MockModel) throws -> String
    func asyncMockDetailMessages(mock: MockModel) async throws -> String
}
