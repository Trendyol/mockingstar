import CommonKit
import CommonViewsKit
import Foundation
import SwiftUI

@Observable
public final class ModifierListViewModel {
    private let apiClient: ModifierAPIClientInterface
    private let notificationManager: NotificationManagerInterface
    private let navigationStore: NavigationStore

    var modifiers: [ModifierModel] = []
    var searchTerm: String = ""
    var selected = Set<ModifierModel.ID>()
    var isLoading = false
    var shouldShowErrorMessage = false
    var errorMessage = ""
    var shouldShowDeleteConfirmation = false
    var pendingDeleteId: String?
    var shouldShowCreateSheet = false

    var filteredModifiers: [ModifierModel] {
        let term = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let sorted = modifiers.sorted {
            if $0.order != $1.order { return $0.order < $1.order }
            return $0.id < $1.id
        }
        guard !term.isEmpty else { return sorted }
        return sorted.filter {
            [$0.id, $0.path, $0.method, $0.scenario ?? ""].joined(separator: " ").lowercased().contains(term)
        }
    }

    public init(apiClient: ModifierAPIClientInterface = ModifierAPIClient(),
                notificationManager: NotificationManagerInterface = NotificationManager.shared,
                navigationStore: NavigationStore = .shared) {
        self.apiClient = apiClient
        self.notificationManager = notificationManager
        self.navigationStore = navigationStore
    }

    @MainActor
    func load(domain: String) async {
        // Keep the existing table visible during refresh so returning from detail
        // does not flash the empty state while the request is in flight.
        let showFullLoading = modifiers.isEmpty
        if showFullLoading { isLoading = true }
        defer { isLoading = false }
        do {
            modifiers = try await apiClient.listModifiers(domain: domain)
        } catch {
            present(error)
        }
    }

    @MainActor
    func toggleEnabled(_ modifier: ModifierModel, domain: String) async {
        var ids = Set(modifiers.filter(\.enabled).map(\.id))
        if modifier.enabled {
            ids.remove(modifier.id)
        } else {
            ids.insert(modifier.id)
        }
        do {
            try await apiClient.setActiveModifiers(domain: domain, ids: Array(ids).sorted())
            await load(domain: domain)
        } catch {
            present(error)
        }
    }

    @MainActor
    func confirmDelete(id: String) {
        pendingDeleteId = id
        shouldShowDeleteConfirmation = true
    }

    @MainActor
    func deletePending(domain: String) async {
        guard let id = pendingDeleteId else { return }
        do {
            try await apiClient.deleteModifier(domain: domain, id: id)
            notificationManager.show(title: "Modifier deleted", color: .green)
            await load(domain: domain)
        } catch {
            present(error)
        }
        pendingDeleteId = nil
    }

    func openDetail(id: String, previewSeed: ModifierCreationSeed? = nil) {
        navigationStore.open(.modifier(id: id, previewSeed: previewSeed))
    }

    func modifier(id: ModifierModel.ID) -> ModifierModel? {
        modifiers.first { $0.id == id }
    }

    @MainActor
    private func present(_ error: Error) {
        errorMessage = error.localizedDescription
        shouldShowErrorMessage = true
        notificationManager.show(title: errorMessage, color: .red)
    }
}
