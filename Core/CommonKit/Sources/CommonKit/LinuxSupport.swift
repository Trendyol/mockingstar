//
//  File.swift
//
//
//  Created by Yusuf Özgül on 1.04.2024.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

#if !canImport(os)
final class os {
    final class Logger {
        init(subsystem: String, category: String) {}
        func info(_ log: String) {}
        func debug(_ log: String) {}
        func fault(_ log: String) {}
        func critical(_ log: String) {}
        func notice(_ log: String) {}
        func warning(_ log: String) {}
        func error(_ log: String) {}
    }
}

#endif

#if os(Linux)
public extension Date {
    func formatted(_ format: FormatStyle) -> String {
        ""
    }
}

public final class FormatStyle {
    public static let iso8601 = FormatStyle()
}

public extension URLSession {
    enum URLSessionAsyncErrors: Error {
        case invalidUrlResponse, missingResponseData
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        return try await withCheckedThrowingContinuation { continuation in
            let task = self.dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let response = response as? HTTPURLResponse else {
                    continuation.resume(throwing: URLSessionAsyncErrors.invalidUrlResponse)
                    return
                }
                guard let data = data else {
                    continuation.resume(throwing: URLSessionAsyncErrors.missingResponseData)
                    return
                }
                continuation.resume(returning: (data, response))
            }
            task.resume()
        }
    }
}

public extension URL {
    func path(percentEncoded: Bool = true) -> String {
        path
    }

    func host(percentEncoded: Bool = true) -> String? {
        host
    }

    func appending<S>(path: S) -> URL where S : StringProtocol {
        appendingPathComponent(String(path))
    }

    func query(percentEncoded: Bool = true) -> String? {
        query
    }

    init(filePath path: String) {
        self.init(fileURLWithPath: path)
    }
}
#endif
