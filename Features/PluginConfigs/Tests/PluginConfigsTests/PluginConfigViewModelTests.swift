//
//  PluginConfigViewModelTests.swift
//  
//
//  Created by Yusuf Özgül on 6.12.2023.
//

@testable import PluginConfigs
import XCTest
import CommonViewsKitTestSupport
import PluginCoreTestSupport

final class PluginConfigViewModelTests: XCTestCase {
    private var viewModel: PluginConfigViewModel!
    private var notificationManager: MockNotificationManager!
    private var pluginCoreActor: MockPluginCoreActor!
    private let defaults = UserDefaults.standard

    override func setUpWithError() throws {
        try super.setUpWithError()

        notificationManager = .init()
        pluginCoreActor = .init()

        viewModel = .init(plugin: "Plugin",
                          notificationManager: notificationManager,
                          pluginCoreActor: pluginCoreActor)
        defaults.dictionaryRepresentation().keys.forEach(defaults.removeObject(forKey:))
    }

    override func tearDown() {
        super.tearDown()

        defaults.dictionaryRepresentation().keys.forEach(defaults.removeObject(forKey:))
    }

    func test_loadPlugins_InvokesNecessaryMethods() async {
        let plugin = MockPlugin()
        pluginCoreActor.stubbedPluginCoreResult = plugin
        plugin.stubbedConfigAvailablePluginsResult = []

        XCTAssertFalse(pluginCoreActor.invokedPluginCore)
        XCTAssertFalse(plugin.invokedConfigAvailablePlugins)

        await viewModel.loadPlugins(for: "TestMockDomain")

        XCTAssertTrue(pluginCoreActor.invokedPluginCore)
        XCTAssertTrue(plugin.invokedConfigAvailablePlugins)
        XCTAssertEqual(pluginCoreActor.invokedPluginCoreParametersList.map(\.mockDomain), ["TestMockDomain"])
    }

    func test_saveChanges_InvokesNecessaryMethods() {
        XCTAssertEqual(viewModel.pluginConfigStorage.count, 0)
        XCTAssertFalse(notificationManager.invokedShow)

        viewModel.pluginConfigs = [
            .init(key: "Test",
                  valueType: .bool,
                  value: .bool(true))
        ]
        viewModel.saveChanges()

        XCTAssertEqual(viewModel.pluginConfigStorage.count, 1)
        XCTAssertTrue(notificationManager.invokedShow)
        XCTAssertEqual(viewModel.pluginConfigStorage, [
            .init(key: "Test",
                  valueType: .bool,
                  value: .init(true))
        ])
        XCTAssertEqual(notificationManager.invokedShowParametersList.map(\.title), ["All changes saved"])
        XCTAssertEqual(notificationManager.invokedShowParametersList.map(\.dismissTime), [6.0])
        XCTAssertEqual(notificationManager.invokedShowParametersList.map(\.color), [.green])
    }

    func test_checkChanges() {
        XCTAssertEqual(viewModel.shouldShowUnsavedIndicator, false)

        viewModel.pluginConfigs = [
            .init(key: "Test",
                  valueType: .bool,
                  value: .bool(true))
        ]

        viewModel.checkChanges()

        XCTAssertEqual(viewModel.shouldShowUnsavedIndicator, true)
    }
}
