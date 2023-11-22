//
//  ConfigurationsError.swift
//
//
//  Created by Yusuf Özgül on 1.09.2023.
//

import Foundation

public enum ConfigurationsError: LocalizedError {
    case configUrlError

    public var errorDescription: String? {
        return switch self {
        case .configUrlError: "Config file url creation error"
        }
    }
}
