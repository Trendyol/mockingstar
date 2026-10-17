import AppKit
import CommonKit
import CommonViewsKit
import Foundation
import SwiftUI

@Observable
public final class MockModifierListViewModel {
    static let clipboardPrefix = "mockingstar-modifier-v1\n"

    private let apiClient: MockModifierAPIClientInterface
    private let notificationManager: NotificationManagerInterface
    private let navigationStore: NavigationStore
    private let pasteBoard: NSPasteboardInterface

    var modifiers: [MockModifierModel] = []
    var searchTerm: String = ""
    var selected = Set<MockModifierModel.ID>()
    var isLoading = false
    var shouldShowErrorMessage = false
    var errorMessage = ""
    var shouldShowDeleteConfirmation = false
    var pendingDeleteIds: [String] = []

    var deleteConfirmationTitle: String {
        pendingDeleteIds.count > 1
            ? "Delete \(pendingDeleteIds.count) modifiers?"
            : "Delete modifier?"
    }
    var shouldShowCreateSheet = false

    var filteredModifiers: [MockModifierModel] {
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

    public init(apiClient: MockModifierAPIClientInterface = MockModifierAPIClient(),
                notificationManager: NotificationManagerInterface = NotificationManager.shared,
                navigationStore: NavigationStore = .shared,
                pasteBoard: NSPasteboardInterface = NSPasteboard.general) {
        self.apiClient = apiClient
        self.notificationManager = notificationManager
        self.navigationStore = navigationStore
        self.pasteBoard = pasteBoard
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
    func setSource(_ modifier: MockModifierModel, source: MockModifierPreviewSource?, domain: String) async {
        var sources = Dictionary(
            modifiers.compactMap { model in model.source.map { (model.id, $0) } },
            uniquingKeysWith: { first, _ in first }
        )
        if let source {
            sources[modifier.id] = source
        } else {
            sources.removeValue(forKey: modifier.id)
        }
        let activations = sources
            .map { MockModifierActivation(id: $0.key, source: $0.value) }
            .sorted { $0.id < $1.id }
        do {
            try await apiClient.setActiveModifiers(domain: domain, activations: activations)
            await load(domain: domain)
        } catch {
            present(error)
        }
    }

    @MainActor
    func confirmDelete(ids: [String]) {
        pendingDeleteIds = ids
        shouldShowDeleteConfirmation = !ids.isEmpty
    }

    @MainActor
    func deletePending(domain: String) async {
        let ids = pendingDeleteIds
        pendingDeleteIds = []
        guard !ids.isEmpty else { return }
        var failure: Error?
        for id in ids {
            do {
                try await apiClient.deleteModifier(domain: domain, id: id)
            } catch {
                failure = error
            }
        }
        selected.subtract(ids)
        await load(domain: domain)
        if let failure {
            present(failure)
        } else {
            let title = ids.count == 1 ? "Modifier deleted" : "\(ids.count) modifiers deleted"
            notificationManager.show(title: title, color: .green)
        }
    }

    func openDetail(id: String, previewSeed: MockModifierCreationSeed? = nil) {
        navigationStore.open(.modifier(id: id, previewSeed: previewSeed))
    }

    func modifier(id: MockModifierModel.ID) -> MockModifierModel? {
        modifiers.first { $0.id == id }
    }

    @MainActor
    func duplicate(id: String, domain: String) async {
        guard let modifier = modifier(id: id) else { return }
        await createCopy(from: writeRequest(from: modifier), domain: domain)
    }

    @MainActor
    @discardableResult
    func copySelected() -> [NSItemProvider] {
        guard let id = selected.first, let modifier = modifier(id: id) else { return [] }
        guard let data = try? JSONEncoder().encode(writeRequest(from: modifier)),
              let json = String(data: data, encoding: .utf8) else { return [] }
        let payload = Self.clipboardPrefix + json
        pasteBoard.clearContents()
        pasteBoard.setString(payload, forType: .string)
        return [NSItemProvider(object: payload as NSString)]
    }

    @MainActor
    func paste(domain: String) async {
        guard let payload = pasteBoard.string(forType: .string),
              payload.hasPrefix(Self.clipboardPrefix) else { return }
        let json = String(payload.dropFirst(Self.clipboardPrefix.count))
        guard let data = json.data(using: .utf8),
              let request = try? JSONDecoder().decode(MockModifierWriteRequest.self, from: data) else {
            return
        }
        await createCopy(from: request, domain: domain)
    }

    @MainActor
    private func createCopy(from request: MockModifierWriteRequest, domain: String) async {
        let trimmedId = request.id?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let newId = uniqueCopyId(from: trimmedId.isEmpty ? "modifier" : trimmedId)
        let copy = MockModifierWriteRequest(
            id: newId,
            path: request.path,
            method: request.method,
            scenario: request.scenario,
            order: nextOrder(),
            sampleMockRequestId: request.sampleMockRequestId,
            transformerCode: request.transformerCode
        )
        do {
            try await apiClient.createModifier(domain: domain, request: copy)
            notificationManager.show(title: "Modifier duplicated", color: .green)
            await load(domain: domain)
            selected = [newId]
        } catch {
            present(error)
        }
    }

    private func writeRequest(from modifier: MockModifierModel) -> MockModifierWriteRequest {
        MockModifierWriteRequest(
            id: modifier.id,
            path: modifier.path,
            method: modifier.method,
            scenario: modifier.scenario,
            order: modifier.order,
            sampleMockRequestId: modifier.sampleMockRequestId,
            transformerCode: modifier.transformerCode
        )
    }

    private func uniqueCopyId(from sourceId: String) -> String {
        let ids = Set(modifiers.map(\.id))
        let base = "\(sourceId)-copy"
        guard ids.contains(base) else { return base }
        var index = 2
        while ids.contains("\(sourceId)-copy-\(index)") {
            index += 1
        }
        return "\(sourceId)-copy-\(index)"
    }

    private func nextOrder() -> Int {
        (modifiers.map(\.order).max() ?? 0) + 1
    }

    @MainActor
    private func present(_ error: Error) {
        errorMessage = error.localizedDescription
        shouldShowErrorMessage = true
        notificationManager.show(title: errorMessage, color: .red)
    }
}
