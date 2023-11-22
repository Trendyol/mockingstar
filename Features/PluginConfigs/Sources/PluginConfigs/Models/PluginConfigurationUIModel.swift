//
//  PluginConfigurationUIModel.swift
//
//
//  Created by Yusuf Özgül on 3.11.2023.
//

import Foundation
import SwiftUI
import PluginCore

struct PluginConfigurationUIModel: Hashable, Identifiable, Codable {
    let id: UUID
    let key: String
    var value: PluginConfigurationTypeViewModel
    let valueType: PluginConfigurationValueType

    init(key: String, valueType: PluginConfigurationValueType, value: PluginConfigurationTypeViewModel? = nil) {
        self.id = .init()
        self.key = key
        self.valueType = valueType

        if let value {
            self.value = value
        } else {
            self.value = switch valueType {
            case .text: .text("")
            case .number: .number(0)
            case .bool: .bool(false)
            case .textArray: .textArray([])
            case .numberArray: .numberArray([])
            }
        }
    }

    static func == (lhs: PluginConfigurationUIModel, rhs: PluginConfigurationUIModel) -> Bool {
        lhs.id == rhs.id &&
        lhs.key == rhs.key &&
        lhs.value == rhs.value &&
        lhs.valueType == rhs.valueType
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(key)
        hasher.combine(value)
        hasher.combine(valueType)
    }
}

enum PluginConfigurationTypeViewModel: Hashable, Codable {
    case text(String)
    case number(Double)
    case bool(Bool)
    case textArray([String])
    case numberArray([Double])

    var rawValue: Any {
        switch self {
        case .text(let string): string
        case .number(let double): double
        case .bool(let bool): bool
        case .textArray(let array): array
        case .numberArray(let array): array
        }
    }
}

struct PluginConfigArrayItemModel<T: Hashable>: Identifiable, Hashable {
    let id: UUID
    var value: T

    init(value: T) {
        self.id = .init()
        self.value = value
    }
}
