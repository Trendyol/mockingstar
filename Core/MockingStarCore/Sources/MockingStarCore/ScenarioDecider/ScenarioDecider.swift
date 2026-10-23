//
//  ScenarioDecider.swift
//
//
//  Created by Yusuf Özgül on 8.11.2023.
//

import CommonKit
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

actor ScenarioDecidersActor {
    private var deciderList: [String: ScenarioDecider] = [:]
    private let fileUrlBuilder: FileUrlBuilderInterface
    private let root: URL?
    init(fileUrlBuilder: FileUrlBuilderInterface = FileUrlBuilder(), root: URL? = nil) { self.fileUrlBuilder = fileUrlBuilder; self.root = root }

    func decider(for mockDomain: String) async -> ScenarioDecider {
        if let decider = deciderList[mockDomain] {
            return decider
        }

        let configs = Configurations(mockDomain: mockDomain, fileUrlBuilder: fileUrlBuilder)
        let newDecider = ScenarioDecider(fileURLBuilder: fileUrlBuilder, configs: configs, root: root, domain: mockDomain)

        deciderList[mockDomain] = newDecider
        return newDecider
    }
}

actor ScenarioDecider {
    private let fileURLBuilder: FileUrlBuilderInterface
    private var scenarios: [ScenarioModel] = []
    private var configs: ConfigurationsInterface
    private let root: URL?
    private let domain: String
    private let logger = Logger(category: "ScenarioDecider")

    init(fileURLBuilder: FileUrlBuilderInterface = FileUrlBuilder(), configs: ConfigurationsInterface, root: URL? = nil, domain: String = "") {
        self.fileURLBuilder = fileURLBuilder
        self.configs = configs
        self.root = root; self.domain = domain
    }

    /// Adds a new scenario to the list of configured scenarios.
    ///
    /// - Parameter scenario: The ``ScenarioModel` to be added.
    func addNewScenario(_ scenario: ScenarioModel) throws {
        try mutate { values in
            values.removeAll(where: { $0.deviceId == scenario.deviceId && $0.mockDomain == scenario.mockDomain && $0.path == scenario.path && $0.method == scenario.method })
            values.append(scenario)
        }
    }

    /// Removes a scenario from the list of configured scenarios.
    ///
    /// - Parameter scenario: The ``ScenarioModel`` to be removed.
    func removeScenarios(deviceId: String) throws {
        try mutate { $0.removeAll(where: { $0.deviceId == deviceId }) }
    }

    func listScenarios() throws -> [ScenarioModel] {
        scenarios = try load()
        return scenarios
    }

    private func reload() {
        do { scenarios = try load() }
        catch { logger.error("Scenario reload rejected", metadata: ["domain": .string(domain), "reason": .string(error.localizedDescription)]) }
    }
    private func load() throws -> [ScenarioModel] {
        guard let root else { return scenarios }
        let workspace = MockWorkspace(root: root)
        try workspace.checkDomain(domain)
        let url = root.appendingPathComponent("Domains/\(domain)/Configs/scenarios.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try JSONDecoder.shared.decode([ScenarioModel].self, from: Data(contentsOf: url))
    }
    private func mutate(_ update: (inout [ScenarioModel]) -> Void) throws {
        guard let root else { update(&scenarios); return }
        let workspace = MockWorkspace(root: root)
        try workspace.checkDomain(domain)
        try workspace.withLock {
            var values = try load()
            update(&values)
            try workspace.write(values, to: root.appendingPathComponent("Domains/\(domain)/Configs/scenarios.json"))
            scenarios = values
        }
    }

    /// Decides the scenario for a given URLRequest and device ID.
    ///
    /// This function iterates through the list of scenarios and determines the matching scenario based on the provided URLRequest and device ID.
    ///
    /// - Parameters:
    ///   - request: The URLRequest for which a scenario decision is made.
    ///   - deviceId: The device ID for which the scenario is decided.
    /// - Returns: The scenario associated with the matching configuration, if found; otherwise, returns `nil`.
    func decideScenario(request: URLRequest, deviceId: String) -> String? {
        reload()
        return scenarios.first(where: {
            let isPathMatching = fileURLBuilder.isPathMatched(requestPath: request.url?.path() ?? "",
                                                              configPath: $0.path,
                                                              pathMatchingRatio: configs.configs.appFilterConfigs.pathMatchingRatio)

            return $0.deviceId == deviceId &&
            ($0.method == nil || $0.method == request.httpMethod) &&
            isPathMatching
        })?.scenario
    }
}
