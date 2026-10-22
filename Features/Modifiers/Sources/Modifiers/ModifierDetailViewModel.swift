import AppKit
import CommonKit
import CommonViewsKit
import Editor
import Foundation
import SwiftUI

enum MockModifierDetailField: Hashable {
    case id
    case path
    case method
    case order
    case url
    case headers
    case sampleMockId
}

@Observable
public final class MockModifierDetailViewModel {
    private let apiClient: MockModifierAPIClientInterface
    private let notificationManager: NotificationManagerInterface
    private let navigationStore: NavigationStore
    private let pasteBoard: NSPasteboardInterface
    private let defaults: UserDefaults
    private let initialPreviewSeed: MockModifierCreationSeed?

    private(set) var currentId: String
    var draft: MockModifierDetailDraft {
        didSet {
            refreshDirtyState()
            syncJavaScriptEditorFromDraft()
        }
    }
    private var savedSnapshot: MockModifierDetailDraft
    var previewInput: MockModifierPreviewInput
    let javaScriptEditorSession: EditorSession
    let responseEditorSession: EditorSession
    let diffEditorSession: MonacoDiffSession
    private var latestPreviewToken = UUID()
    private(set) var fieldErrors: [MockModifierDetailField: String] = [:]
    private(set) var previewBodyBase64 = ""
    private(set) var previewModifiedText = ""
    private(set) var previewModifiedType: MockModelBodyType = .text
    private(set) var hasPreviewOriginal = false

    var enabled: Bool = false
    var activeSource: MockModifierPreviewSource?
    var isLoading = false
    var shouldShowErrorMessage = false
    var errorMessage = ""
    var shouldShowUnsavedIndicator = false
    var shouldShowDeleteConfirmation = false
    var shouldDismissView = false
    var previewStatus: Int?
    var previewResponseHeaders: String = ""
    var previewIsStale = false
    var isPreviewLoading = false

    /// Compatibility alias used by navigation title / existing call sites.
    var modifierId: String { currentId }

    var hasUnsavedChanges: Bool {
        shouldShowUnsavedIndicator
    }

    /// Compatibility surface for the Task 7 inspector until Task 8 redesign.
    var previewResponseBody: String {
        responseEditorSession.content.content
    }

    var canCopyObjectNotation: Bool {
        previewStatus != nil && previewModifiedType == .json && !isPreviewLoading
    }

    public init(modifierId: String,
                previewSeed: MockModifierCreationSeed? = nil,
                apiClient: MockModifierAPIClientInterface = MockModifierAPIClient(),
                notificationManager: NotificationManagerInterface = NotificationManager.shared,
                navigationStore: NavigationStore = .shared,
                pasteBoard: NSPasteboardInterface = NSPasteboard.general,
                defaults: UserDefaults = .standard) {
        let placeholder = MockModifierModel(
            id: modifierId,
            path: "/",
            method: "GET",
            transformerCode: ""
        )
        let initialDraft = MockModifierDetailDraft(model: placeholder)
        self.apiClient = apiClient
        self.notificationManager = notificationManager
        self.navigationStore = navigationStore
        self.pasteBoard = pasteBoard
        self.defaults = defaults
        self.initialPreviewSeed = previewSeed
        self.currentId = modifierId
        self.savedSnapshot = initialDraft
        self.previewInput = .initial(model: placeholder, seed: previewSeed)
        self.javaScriptEditorSession = EditorSession(
            content: .init(content: "", type: .javascript),
            isReadOnly: false
        )
        self.responseEditorSession = EditorSession(
            content: .init(content: "", type: .text),
            isReadOnly: true
        )
        self.diffEditorSession = MonacoDiffSession()
        // Assign last so didSet can safely compare against savedSnapshot.
        self.draft = initialDraft
        self.diffEditorSession.onEditPath = { [weak self] offset in
            Task { @MainActor in self?.editPreviewPath(offset: offset) }
        }
        self.diffEditorSession.onCopyObjectNotation = { [weak self] offset in
            Task { @MainActor in self?.copyObjectNotation(offset: offset) }
        }
    }

    @MainActor
    func load(domain: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let model = try await apiClient.getModifier(domain: domain, id: currentId)
            draft = MockModifierDetailDraft(model: model)
            savedSnapshot = draft
            previewInput = resolvePreviewInput(model: model, domain: domain)
            activeSource = model.source
            enabled = model.enabled
            if let source = model.source {
                previewInput.source = source
            }
            javaScriptEditorSession.setContent(model.transformerCode, type: .javascript)
            javaScriptEditorSession.content.onContentDidChange = { [weak self] in
                guard let self else { return }
                let code = self.javaScriptEditorSession.content.content
                if self.draft.transformerCode != code {
                    self.draft.transformerCode = code
                }
            }
            shouldShowUnsavedIndicator = false
        } catch {
            present(error)
        }
    }

    @MainActor
    func save(domain: String) async -> Bool {
        guard validateDocument() else { return false }
        let oldId = currentId
        do {
            try await apiClient.updateModifier(
                domain: domain,
                id: oldId,
                request: draft.writeRequest
            )
            currentId = draft.id
            savedSnapshot = draft
            shouldShowUnsavedIndicator = false
            persistPreviewInput(domain: domain)
            if oldId != currentId {
                MockModifierPreviewInputStore.remove(domain: domain, id: oldId, defaults: defaults)
                navigationStore.replaceLast(
                    with: .modifier(id: currentId, previewSeed: initialPreviewSeed)
                )
            }
            notificationManager.show(title: "Modifier saved", color: .green)
            return true
        } catch {
            present(error)
            return false
        }
    }

    private func resolvePreviewInput(model: MockModifierModel, domain: String) -> MockModifierPreviewInput {
        if let initialPreviewSeed {
            let seeded = MockModifierPreviewInput.initial(model: model, seed: initialPreviewSeed)
            MockModifierPreviewInputStore.save(seeded, domain: domain, id: currentId, defaults: defaults)
            return seeded
        }
        if let stored = MockModifierPreviewInputStore.load(
            domain: domain,
            id: currentId,
            defaults: defaults
        ) {
            return stored
        }
        return .initial(model: model, seed: nil)
    }

    private func persistPreviewInput(domain: String) {
        MockModifierPreviewInputStore.save(
            previewInput,
            domain: domain,
            id: currentId,
            defaults: defaults
        )
    }

    @MainActor
    func runPreview(domain: String) async {
        let token = UUID()
        latestPreviewToken = token
        guard let validated = validatePreview() else { return }
        let url = validated.url
        let headers = validated.headers

        isPreviewLoading = true
        defer {
            if latestPreviewToken == token { isPreviewLoading = false }
        }
        do {
            let result = try await apiClient.previewModifier(
                domain: domain,
                request: .init(
                    currentModifierId: currentId,
                    modifier: draft.writeRequest,
                    request: .init(
                        url: url,
                        method: previewInput.method.uppercased(),
                        scenario: previewInput.scenario.isEmpty ? nil : previewInput.scenario,
                        headers: headers,
                        bodyBase64: Data(previewInput.body.utf8).base64EncodedString()
                    ),
                    source: previewInput.source
                )
            )
            guard latestPreviewToken == token else { return }
            applyPreview(result)
        } catch {
            guard latestPreviewToken == token else { return }
            previewIsStale = previewStatus != nil
            present(error)
        }
    }

    @MainActor
    func setSource(_ source: MockModifierPreviewSource?, domain: String) async {
        do {
            let all = try await apiClient.listModifiers(domain: domain)
            var sources = Dictionary(
                all.compactMap { model in model.source.map { (model.id, $0) } },
                uniquingKeysWith: { first, _ in first }
            )
            if let source {
                sources[currentId] = source
                previewInput.source = source
            } else {
                sources.removeValue(forKey: currentId)
            }
            let activations = sources
                .map { MockModifierActivation(id: $0.key, source: $0.value) }
                .sorted { $0.id < $1.id }
            try await apiClient.setActiveModifiers(domain: domain, activations: activations)
            activeSource = source
            enabled = source != nil
            persistPreviewInput(domain: domain)
        } catch {
            present(error)
        }
    }

    @MainActor
    func delete(domain: String) async {
        do {
            try await apiClient.deleteModifier(domain: domain, id: currentId)
            notificationManager.show(title: "Modifier deleted", color: .green)
            shouldDismissView = true
            navigationStore.pop()
        } catch {
            present(error)
        }
    }

    func copyPreviewResponse() {
        guard !previewBodyBase64.isEmpty else { return }
        let data = Data(base64Encoded: previewBodyBase64) ?? Data()
        let value = String(data: data, encoding: .utf8) ?? previewBodyBase64
        pasteBoard.clearContents()
        pasteBoard.setString(value, forType: .string)
    }

    @MainActor
    func copyObjectNotation() {
        guard canCopyObjectNotation else { return }
        do {
            let data = Data(base64Encoded: previewBodyBase64) ?? Data()
            let notation = try MockModifierObjectNotation.make(from: data)
            pasteBoard.clearContents()
            pasteBoard.setString(notation, forType: .string)
            notificationManager.show(title: "Object notation copied to clipboard", color: .green)
        } catch {
            present(error)
        }
    }

    @MainActor
    func copyObjectNotation(offset: Int) {
        guard canCopyObjectNotation else { return }
        guard let object = MockModifierJSONPath.resolveObject(json: previewModifiedText, utf16Offset: offset) else {
            notificationManager.show(title: "Right-click an object or one of its fields", color: .red)
            return
        }
        do {
            // Resolve against the displayed text, but infer from the original JSON to preserve number types.
            var value = try JSONSerialization.jsonObject(with: Data(base64Encoded: previewBodyBase64) ?? Data())
            for component in object.path {
                switch component {
                case .key(let key):
                    guard let child = (value as? [String: Any])?[key] else { return }
                    value = child
                case .index(let index):
                    guard let array = value as? [Any], array.indices.contains(index) else { return }
                    value = array[index]
                }
            }
            let notation = try MockModifierObjectNotation.make(from: value)
            let path = MockModifierTransformerEditor.lhs(for: object.path)
            pasteBoard.clearContents()
            pasteBoard.setString("Path: \(path)\n\(notation)", forType: .string)
            notificationManager.show(title: "Object notation copied to clipboard", color: .green)
        } catch {
            present(error)
        }
    }

    @MainActor
    func copyPreviewCURL() {
        fieldErrors.removeValue(forKey: .url)
        fieldErrors.removeValue(forKey: .headers)
        guard let input = validatePreviewRequest() else {
            notificationManager.show(
                title: fieldErrors[.url] ?? fieldErrors[.headers] ?? "Invalid preview request",
                color: .red
            )
            return
        }
        var request = URLRequest(url: input.url)
        request.httpMethod = previewInput.method.uppercased()
        request.allHTTPHeaderFields = input.headers
        request.httpBody = Data(previewInput.body.utf8)
        pasteBoard.clearContents()
        pasteBoard.setString(request.cURL(pretty: true), forType: .string)
        notificationManager.show(title: "Request copied to clipboard", color: .green)
    }

    private func refreshDirtyState() {
        shouldShowUnsavedIndicator = draft != savedSnapshot
    }

    private func syncJavaScriptEditorFromDraft() {
        guard javaScriptEditorSession.content.content != draft.transformerCode else { return }
        javaScriptEditorSession.content.content = draft.transformerCode
    }

    private func isValidModifierId(_ id: String) -> Bool {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty
            && trimmed == id
            && !id.contains("/")
            && !id.contains("\\")
            && !id.contains("..")
            && !id.contains("\0")
            && id != "."
            && id != ".."
    }

    @discardableResult
    private func validateDocument() -> Bool {
        fieldErrors.removeAll()
        if !isValidModifierId(draft.id) {
            fieldErrors[.id] = "Enter a valid filename ID"
        }
        if draft.path.isEmpty {
            fieldErrors[.path] = "Path is required"
        }
        if draft.method.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fieldErrors[.method] = "Method is required"
        }
        if draft.order < 1 {
            fieldErrors[.order] = "Order must be at least 1"
        }
        return fieldErrors.isEmpty
    }

    private func validatePreview() -> (
        url: URL,
        headers: [String: String]
    )? {
        _ = validateDocument()
        guard let input = validatePreviewRequest() else { return nil }
        if previewInput.source == .mock && draft.sampleMockRequestId.isEmpty {
            fieldErrors[.sampleMockId] = "Select a sample mock"
        }
        return fieldErrors.isEmpty ? input : nil
    }

    private func validatePreviewRequest() -> (url: URL, headers: [String: String])? {
        guard let url = URL(string: previewInput.url),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              url.host() != nil else {
            fieldErrors[.url] = "Enter an absolute HTTP or HTTPS URL"
            return nil
        }
        guard let data = previewInput.headersJSON.data(using: .utf8),
              let headers = try? JSONDecoder().decode([String: String].self, from: data) else {
            fieldErrors[.headers] = "Headers must be a JSON string dictionary"
            return nil
        }
        return (url, headers)
    }

    private func applyPreview(_ result: MockModifierPreviewResponse) {
        previewStatus = result.status
        previewBodyBase64 = result.bodyBase64
        previewResponseHeaders = result.headers
            .map { "\($0.key): \($0.value)" }
            .sorted()
            .joined(separator: "\n")
        previewIsStale = false

        let modified = Self.formatBody(base64: result.bodyBase64)
        responseEditorSession.setContent(modified.text, type: modified.type)
        previewModifiedText = modified.text
        previewModifiedType = modified.type

        if let originalBase64 = result.originalBodyBase64 {
            let original = Self.formatBody(base64: originalBase64)
            hasPreviewOriginal = true
            diffEditorSession.setDiff(original: original.text, modified: modified.text, type: modified.type)
        } else {
            hasPreviewOriginal = false
            diffEditorSession.setDiff(original: nil, modified: modified.text, type: modified.type)
        }
    }

    static func formatBody(base64: String) -> (text: String, type: MockModelBodyType) {
        guard let data = Data(base64Encoded: base64) else {
            return ("Invalid Base64 response body", .text)
        }
        if let json = try? JSONSerialization.jsonObject(with: data),
           let formatted = try? JSONSerialization.data(
               withJSONObject: json,
               options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
           ),
           let text = String(data: formatted, encoding: .utf8) {
            return (text, .json)
        } else if let text = String(data: data, encoding: .utf8) {
            return (text, .text)
        } else {
            return ("Binary response (\(data.count) bytes). Use Copy to copy Base64.", .text)
        }
    }

    @MainActor
    func editPreviewPath(offset: Int) {
        guard previewModifiedType == .json else { return }
        guard let resolved = MockModifierJSONPath.resolve(json: previewModifiedText, utf16Offset: offset) else { return }
        let result = MockModifierTransformerEditor.applyAssignment(
            path: resolved.path,
            valueLiteral: resolved.literal,
            to: draft.transformerCode
        )
        guard result.code != draft.transformerCode else {
            if let line = result.focusLine { javaScriptEditorSession.revealLine(line) }
            return
        }
        draft.transformerCode = result.code
        if let line = result.focusLine { javaScriptEditorSession.revealLine(line) }
    }

    @MainActor
    private func present(_ error: Error) {
        errorMessage = error.localizedDescription
        shouldShowErrorMessage = true
        notificationManager.show(title: errorMessage, color: .red)
    }
}
