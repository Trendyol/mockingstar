import Foundation

public struct ModifierMatcher {
    public init() {}

    public func match(modifiers: [ModifierModel],
                      path: String,
                      method: String,
                      scenario: String?) -> [ModifierModel] {
        modifiers
            .filter { $0.enabled }
            .filter { $0.path == path }
            .filter { $0.method.uppercased() == method.uppercased() }
            .filter { modifier in
                guard let modifierScenario = modifier.scenario, !modifierScenario.isEmpty else { return true }
                return modifierScenario == (scenario ?? "")
            }
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
                return lhs.id < rhs.id
            }
    }
}
