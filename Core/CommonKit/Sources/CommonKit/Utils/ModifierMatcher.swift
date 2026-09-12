import Foundation

public struct ModifierMatcher {
    public init() {}

    /// Filters already-loaded active modifiers by path/method/scenario and sorts by ascending
    /// `order`, then filename `id`. Callers must pass only modifiers that are active for the
    /// current device; this matcher does not consult activation state.
    public func match(modifiers: [ModifierModel],
                      path: String,
                      method: String,
                      scenario: String?) -> [ModifierModel] {
        modifiers
            .filter { $0.path == path }
            .filter { $0.method.uppercased() == method.uppercased() }
            .filter { modifier in
                guard let modifierScenario = modifier.scenario, !modifierScenario.isEmpty else { return true }
                return modifierScenario == (scenario ?? "")
            }
            .sorted { lhs, rhs in
                if lhs.order != rhs.order { return lhs.order < rhs.order }
                return lhs.id < rhs.id
            }
    }
}
