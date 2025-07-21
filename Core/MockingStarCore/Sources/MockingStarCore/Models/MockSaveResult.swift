//
//  MockSaveResult.swift
//  MockingStarCore
//
//  Created by Yusuf Özgül on 7.03.2025.
//

import Foundation

public enum MockSaveResult: LocalizedError {
    case pathComponentLimitExceeded
    case preventedByFilters
    case noUrlFound

    public var errorDescription: String? {
        switch self {
        case .pathComponentLimitExceeded: "Request path components count more than limit."
        case .preventedByFilters: "Mock won't save due to filters."
        case .noUrlFound: "URL not found"
        }
    }
}
