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

    func decider(for mockDomain: String) async -> ScenarioDecider {
        if let decider = deciderList[mockDomain] {
            return decider
        }

        let configs = Configurations(mockDomain: mockDomain)
        let newDecider = ScenarioDecider(configs: configs)

        deciderList[mockDomain] = newDecider
        return newDecider
    }
}

actor ScenarioDecider {
    private let fileURLBuilder: FileUrlBuilderInterface
    private var scenarios: [ScenarioModel] = []
    private var configs: ConfigurationsInterface

    init(fileURLBuilder: FileUrlBuilderInterface = FileUrlBuilder(), configs: ConfigurationsInterface) {
        self.fileURLBuilder = fileURLBuilder
        self.configs = configs
    }

    /// Adds a new scenario to the list of configured scenarios.
    ///
    /// - Parameter scenario: The ``ScenarioModel` to be added.
    func addNewScenario(_ scenario: ScenarioModel) {
        scenarios.removeAll(where: { $0.deviceId == scenario.deviceId && $0.mockDomain == scenario.mockDomain && $0.path == scenario.path && $0.method == scenario.method })
        scenarios.append(scenario)
    }

    /// Removes a scenario from the list of configured scenarios.
    ///
    /// - Parameter scenario: The ``ScenarioModel`` to be removed.
    func removeScenarios(deviceId: String) {
        scenarios.removeAll(where: { $0.deviceId == deviceId })
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
        return scenarios.first(where: {
            let isPathMatching = fileURLBuilder.isPathMatched(requestPath: request.url?.path() ?? "",
                                                              configPath: $0.path,
                                                              pathMatchingRatio: configs.configs.appFilterConfigs.pathMatchingRatio)

            return $0.deviceId == deviceId &&
            $0.method == request.httpMethod &&
            isPathMatching
        })?.scenario
    }
}
