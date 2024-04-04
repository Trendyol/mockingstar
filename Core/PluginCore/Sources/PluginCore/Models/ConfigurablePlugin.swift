//
//  File.swift
//  
//
//  Created by Yusuf Özgül on 2.11.2023.
//

import Foundation
import JavaScriptCore
import SwiftyJS

@SwiftyJS
protocol ConfigurablePlugin {
    var config: [PluginConfiguration] { get throws }
}
