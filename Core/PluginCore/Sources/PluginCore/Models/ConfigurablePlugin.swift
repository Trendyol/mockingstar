import Foundation

protocol ConfigurablePlugin {
    var config: [PluginConfiguration] { get throws }
}
