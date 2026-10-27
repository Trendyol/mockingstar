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
        let newLine = pretty ? "\\\n" : ""
        let method = (pretty ? "--request " : "-X ") + "\(quoted(self.httpMethod ?? "GET")) \(newLine)"
        let url: String = (pretty ? "--url " : "") + "\(quoted(self.url?.absoluteString ?? "")) \(newLine)"

        var cURL = "curl "
        var header = ""
        var data: String = ""

        if let httpHeaders = self.allHTTPHeaderFields, httpHeaders.keys.count > 0 {
            for (key,value) in httpHeaders {
                header += (pretty ? "--header " : "-H ") + "\(quoted("\(key): \(value)")) \(newLine)"
            }
        }

        if let bodyData = self.httpBody, let bodyString = String(data: bodyData, encoding: .utf8),  !bodyString.isEmpty {
            data = "--data \(quoted(bodyString))"
        }

        cURL += method + url + header + data

        return cURL
    }

    func recalculateContentLength() -> URLRequest {
        var request = self

        if !request.value(forHTTPHeaderField: "Content-Length").isNilOrEmpty {
            request.setValue(request.httpBody?.count.description, forHTTPHeaderField: "Content-Length")
        }

        return request
    }
}
