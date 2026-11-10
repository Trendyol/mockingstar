//
//  URLRequest+Extension.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 26.09.2023.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension URLRequest {
    func cURL(pretty: Bool = false) -> String {
        func quoted(_ value: String) -> String {
            "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
        }
        var parts = [
            "curl",
            (pretty ? "--request " : "-X ") + quoted(httpMethod ?? "GET"),
            (pretty ? "--url " : "") + quoted(url?.absoluteString ?? "")
        ]
        for (key, value) in (allHTTPHeaderFields ?? [:]).sorted(by: { $0.key < $1.key }) {
            let header = value.isEmpty ? "\(key);" : "\(key): \(value)"
            parts.append((pretty ? "--header " : "-H ") + quoted(header))
        }
        if let bodyData = self.httpBody, let bodyString = String(data: bodyData, encoding: .utf8),  !bodyString.isEmpty {
            if value(forHTTPHeaderField: "Content-Type") == nil {
                parts.append((pretty ? "--header " : "-H ") + "'Content-Type:'")
            }
            parts.append("--data-raw " + quoted(bodyString))
        }
        return parts.joined(separator: pretty ? " \\\n  " : " ")
    }

    func recalculateContentLength() -> URLRequest {
        var request = self

        if !request.value(forHTTPHeaderField: "Content-Length").isNilOrEmpty {
            request.setValue(request.httpBody?.count.description, forHTTPHeaderField: "Content-Length")
        }

        return request
    }
}
