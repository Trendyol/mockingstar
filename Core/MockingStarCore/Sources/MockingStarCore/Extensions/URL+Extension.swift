//
//  URL+Extension.swift
//  MockingStarCore
//
//  Created by Yusuf Özgül on 29.07.2025.
//

import Foundation

extension URL {
    var scenario: String? {
        // MocksFolder/Dev/Mocks/about-us/GET/about-us_scenario_id.json
        // MocksFolder/Dev/Mocks/about-us/GET/about-us_id.json
        // MocksFolder/Dev/Mocks/about-us.../GET/scenario_id.json  ## if path longer than 256 character
        // MocksFolder/Dev/Mocks/about-us.../GET/id.json           ## if path longer than 256 character

        let urlPrefix = path()
            .components(separatedBy: "/")
            .prefix(while: { $0 != "Mocks" })
            .joined(separator: "/") + "/Mocks"

        let requestPath = path()
            .replacingOccurrences(of: urlPrefix + "/", with: "")
            .replacingOccurrences(of: "/" + pathComponents[safe: pathComponents.count - 2].orEmpty, with: "") // method
            .replacingOccurrences(of: "/" + lastPathComponent, with: "") // file name
            .replacingOccurrences(of: "/", with: "+")

        var scenario = lastPathComponent
            .replacingOccurrences(of: lastPathComponent.components(separatedBy: "_").last.orEmpty, with: "") // uuid.json

        if lastPathComponent.hasPrefix(requestPath) {
            scenario = scenario.replacingOccurrences(of: requestPath, with: "")
        }

        if scenario.hasPrefix("_") {
            scenario.removeFirst()
        }

        if scenario.hasSuffix("_") {
            scenario.removeLast()
        }

        return scenario.isEmpty ? nil : scenario
    }
    
    var hasScenario: Bool { scenario != nil }
}
