//
//  ConfigsBuilder.swift
//
//
//  Created by Yusuf Özgül on 2.09.2023.
//

import Foundation
import Combine

public protocol ConfigsBuilderInterface {
    /// Find all suitable path configs for given mock url
    /// - Parameters:
    ///   - mockUrl: Current request url
    ///   - pathConfigs: Loaded configs from file
    ///   - pathMatchingRatio: A 0 to 1 value, it determents suitable ratio eg: 1 is all path component must equal config and mock, 0.5 is only half of suffix components must equal
    /// - Returns: Usable Path components for this mock
    ///
    func findProperPathConfigs(mockUrl: URL, pathConfigs: [PathConfigModel], pathMatchingRatio: Double) -> [PathConfigModel]

    /// Find all suitable query configs for given mock url
    /// - Parameters:
    ///   - mockUrl: Current request url
    ///   - queryConfigs: Loaded configs from file
    ///   - pathMatchingRatio: A 0 to 1 value, it determents suitable ratio eg: 1 is all path component must equal config and mock, 0.5 is only half of suffix components must equal
    /// - Returns: Usable Query components for this mock

    func findProperQueryConfigs(mockUrl: URL, queryConfigs: [QueryConfigModel], pathMatchingRatio: Double) -> [QueryConfigModel]

    /// Find all suitable header configs for given mock url
    /// - Parameters:
    ///   - mockUrl: Loaded from file mock
    ///   - headers: Current request headers
    ///   - headerConfigs: Loaded configs from file
    ///   - pathMatchingRatio: A 0 to 1 value, it determents suitable ratio eg: 1 is all path component must equal config and mock, 0.5 is only half of suffix components must equal
    /// - Returns: Usable Header components for this mock
    func findProperHeaderConfigs(mockUrl: URL, headers: [String: String], headerConfigs: [HeaderConfigModel], pathMatchingRatio: Double) -> [HeaderConfigModel]
}

public final class ConfigsBuilder: ConfigsBuilderInterface {
    private let fileUrlBuilder: FileUrlBuilderInterface

    public init(fileUrlBuilder: FileUrlBuilderInterface = FileUrlBuilder()) {
        self.fileUrlBuilder = fileUrlBuilder
    }

    public func findProperPathConfigs(mockUrl: URL, pathConfigs: [PathConfigModel], pathMatchingRatio: Double) -> [PathConfigModel] {
        pathConfigs.filter {
            fileUrlBuilder.isPathMatched(requestPath: mockUrl.path(), configPath: $0.path, pathMatchingRatio: pathMatchingRatio)
        }
    }

    public func findProperQueryConfigs(mockUrl: URL, queryConfigs: [QueryConfigModel], pathMatchingRatio: Double) -> [QueryConfigModel] {
        guard let queryItems = URLComponents(url: mockUrl, resolvingAgainstBaseURL: true)?.queryItems, !queryItems.isEmpty else { return [] }

        return queryConfigs.filter { queryConfig in
            let matchedQueries = queryItems.filter { $0.name == queryConfig.key }
            guard !matchedQueries.isEmpty else { return false }

            if let value = queryConfig.value,
               !matchedQueries.contains(where: { $0.value == value }) {
                return false
            }

            if !queryConfig.path.isEmpty {
                let pathConfigs: [PathConfigModel] = queryConfig.path.map { .init(path: $0, executeAllQueries: false, executeAllHeaders: false) }
                let suitablePathConfigs = findProperPathConfigs(mockUrl: mockUrl, pathConfigs: pathConfigs, pathMatchingRatio: pathMatchingRatio)
                return !suitablePathConfigs.isEmpty
            }

            return true
        }
    }

    public func findProperHeaderConfigs(mockUrl: URL, headers: [String: String], headerConfigs: [HeaderConfigModel], pathMatchingRatio: Double) -> [HeaderConfigModel] {
        headerConfigs.filter { headerConfig in
            let matchedHeaders = headers.filter { $0.key == headerConfig.key }
            guard !matchedHeaders.isEmpty else { return false }

            if let value = headerConfig.value,
               !matchedHeaders.contains(where: { $0.value == value }) {
                return false
            }

            if !headerConfig.path.isEmpty {
                let pathConfigs: [PathConfigModel] = headerConfig.path.map { .init(path: $0, executeAllQueries: false, executeAllHeaders: false) }
                let suitablePathConfigs = findProperPathConfigs(mockUrl: mockUrl, pathConfigs: pathConfigs, pathMatchingRatio: pathMatchingRatio)
                return !suitablePathConfigs.isEmpty
            }

            return true
        }
    }
}
