import Foundation

public struct MockModifierMatcher {
    public init() {}

    /// Filters already-loaded active modifiers by path/method/scenario and sorts by ascending
    /// `order`, then filename `id`. Callers must pass only modifiers that are active for the
    /// current device; this matcher does not consult activation state.
    public func match(modifiers: [MockModifierModel],
                      path: String,
                      method: String,
                      scenario: String?) -> [MockModifierModel] {
        let requestMethod = method.uppercased()
        return modifiers
            .filter { modifier in
                guard modifier.path == path,
                      modifier.method.uppercased() == requestMethod else { return false }
                guard let modifierScenario = modifier.scenario, !modifierScenario.isEmpty else { return true }
                return modifierScenario == scenario
            }
            .sorted { lhs, rhs in
                if lhs.order != rhs.order { return lhs.order < rhs.order }
                return lhs.id < rhs.id
            }
    }
}
