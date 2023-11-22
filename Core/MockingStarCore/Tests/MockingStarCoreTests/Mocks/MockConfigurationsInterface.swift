//
//  File.swift
//
//
//  Created by Yusuf Özgül on 4.09.2023.
//

import Foundation
import CommonKit
@testable import MockingStarCore

final class MockConfigurations: ConfigurationsInterface {
    var invokedConfigsSetter = false
    var invokedConfigsSetterCount = 0
    var invokedConfigs: ConfigModel?
    var invokedConfigsList: [ConfigModel] = []
    var invokedConfigsGetter = false
    var invokedConfigsGetterCount = 0
    var stubbedConfigs: ConfigModel!
    var configs: ConfigModel {
        set {
            invokedConfigsSetter = true
            invokedConfigsSetterCount += 1
            invokedConfigs = newValue
            invokedConfigsList.append(newValue)
        }
        get {
            invokedConfigsGetter = true
            invokedConfigsGetterCount += 1
            return stubbedConfigs
        }
    }
}

