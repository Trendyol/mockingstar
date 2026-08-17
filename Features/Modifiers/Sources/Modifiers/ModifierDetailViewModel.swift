import AppKit
import CommonKit
import CommonViewsKit
import Editor
import Foundation
import SwiftUI

enum ModifierDetailField: Hashable {
    case id
    case path
    case method
    case order
    case url
    case headers
    case sampleMockId
}

@Observable
public final class ModifierDetailViewModel {
    private let apiClient: ModifierAPIClientInterface
    private let notificationManager: NotificationManagerInterface
    private let navigationStore: NavigationStore
    private let pasteBoard: NSPasteboardInterface
    private let defaults: UserDefaults
    private let apiKeyStore: APIKeyStoreInterface
    private let claudeClient: ClaudeMessagesClientInterface
    private let initialPreviewSeed: ModifierCreationSeed?

    private(set) var currentId: String
    var draft: ModifierDetailDraft {
        didSet {
            refreshDirtyState()
            syncJavaScriptEditorFromDraft()
        }
    }
    private var savedSnapshot: ModifierDetailDraft
    var previewInput: ModifierPreviewInput
    let javaScriptEditorSession: EditorSession
    let responseEditorSession: EditorSession
    private var latestPreviewToken = UUID()
    private(set) var fieldErrors: [ModifierDetailField: String] = [:]
    private(set) var previewBodyBase64 = ""

    var enabled: Bool = false
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
    var shouldShowAskClaudeSheet = false
    var claudeAPIKey = ""
    var claudeUserIntent = ""
    var claudeSheetError = ""
    var isClaudeLoading = false

    /// Compatibility alias used by navigation title / existing call sites.
    var modifierId: String { currentId }

    var hasUnsavedChanges: Bool {
        shouldShowUnsavedIndicator
    }

    /// Compatibility surface for the Task 7 inspector until Task 8 redesign.
    var previewResponseBody: String {
        responseEditorSession.content.content
    }

    var canGenerateWithClaude: Bool {
        !claudeAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isClaudeLoading
    }

    public init(modifierId: String,
                previewSeed: ModifierCreationSeed? = nil,
                apiClient: ModifierAPIClientInterface = ModifierAPIClient(),
                notificationManager: NotificationManagerInterface = NotificationManager.shared,
                navigationStore: NavigationStore = .shared,
                pasteBoard: NSPasteboardInterface = NSPasteboard.general,
                defaults: UserDefaults = .standard,
                apiKeyStore: APIKeyStoreInterface? = nil,
                claudeClient: ClaudeMessagesClientInterface = ClaudeMessagesClient()) {
        let placeholder = ModifierModel(
            id: modifierId,
            path: "/",
            method: "GET",
            transformerCode: ""
        )
        let initialDraft = ModifierDetailDraft(model: placeholder)
        let resolvedKeyStore = apiKeyStore ?? UserDefaultsAPIKeyStore(defaults: defaults)
        self.apiClient = apiClient
        self.notificationManager = notificationManager
        self.navigationStore = navigationStore
        self.pasteBoard = pasteBoard
        self.defaults = defaults
        self.apiKeyStore = resolvedKeyStore
        self.claudeClient = claudeClient
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
        // Assign last so didSet can safely compare against savedSnapshot.
        self.draft = initialDraft
        self.claudeAPIKey = resolvedKeyStore.load() ?? ""
    }

    @MainActor
    func load(domain: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let model = try await apiClient.getModifier(domain: domain, id: currentId)
            draft = ModifierDetailDraft(model: model)
            savedSnapshot = draft
            previewInput = resolvePreviewInput(model: model, domain: domain)
            enabled = model.enabled
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
                ModifierPreviewInputStore.remove(domain: domain, id: oldId, defaults: defaults)
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

    private func resolvePreviewInput(model: ModifierModel, domain: String) -> ModifierPreviewInput {
        if let initialPreviewSeed {
            let seeded = ModifierPreviewInput.initial(model: model, seed: initialPreviewSeed)
            ModifierPreviewInputStore.save(seeded, domain: domain, id: currentId, defaults: defaults)
            return seeded
        }
        if let stored = ModifierPreviewInputStore.load(
            domain: domain,
            id: currentId,
            defaults: defaults
        ) {
            return stored
        }
        return .initial(model: model, seed: nil)
    }

    private func persistPreviewInput(domain: String) {
        ModifierPreviewInputStore.save(
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
    func toggleEnabled(domain: String) async {
        do {
            let all = try await apiClient.listModifiers(domain: domain)
            var ids = Set(all.filter(\.enabled).map(\.id))
            if enabled {
                ids.remove(currentId)
            } else {
                ids.insert(currentId)
            }
            try await apiClient.setActiveModifiers(domain: domain, ids: Array(ids).sorted())
            enabled.toggle()
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

    func openAskClaudeSheet() {
        claudeSheetError = ""
        if claudeAPIKey.isEmpty {
            claudeAPIKey = apiKeyStore.load() ?? ""
        }
        shouldShowAskClaudeSheet = true
    }

    @MainActor
    func clearClaudeAPIKey() {
        do {
            try apiKeyStore.clear()
            claudeAPIKey = ""
            claudeSheetError = ""
        } catch {
            claudeSheetError = error.localizedDescription
        }
    }

    /// Calls Claude and replaces the JS editor draft with the returned transformer.
    /// - Returns: `true` when the transformer was applied and the sheet should dismiss.
    @MainActor
    @discardableResult
    func askClaude() async -> Bool {
        guard canGenerateWithClaude else { return false }
        claudeSheetError = ""
        isClaudeLoading = true
        defer { isClaudeLoading = false }

        do {
            try apiKeyStore.save(claudeAPIKey)
            let sample: String?
            if previewStatus != nil {
                let body = responseEditorSession.content.content
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                sample = body.isEmpty ? nil : body
            } else {
                sample = nil
            }
            // Prefer Monaco editor content so unsynced keystrokes are included.
            let currentJavaScript = javaScriptEditorSession.content.content
            if draft.transformerCode != currentJavaScript {
                draft.transformerCode = currentJavaScript
            }
            let userPrompt = ModifierClaudePromptBuilder.buildUserPrompt(
                userIntent: claudeUserIntent,
                modifierId: draft.id,
                path: draft.path,
                method: draft.method,
                scenario: draft.scenario,
                currentJavaScript: currentJavaScript,
                sampleResponse: sample
            )
            let assistant = try await claudeClient.complete(
                apiKey: claudeAPIKey,
                system: ModifierClaudePromptBuilder.systemPrompt,
                user: userPrompt
            )
            let js = try ModifierClaudeResponseParser.extractTransformerJavaScript(from: assistant)
            applyGeneratedTransformer(js)
            claudeUserIntent = ""
            claudeSheetError = ""
            shouldShowAskClaudeSheet = false
            notificationManager.show(title: "Claude updated transformer", color: .green)
            return true
        } catch {
            claudeSheetError = error.localizedDescription
            notificationManager.show(title: error.localizedDescription, color: .red)
            return false
        }
    }

    private func applyGeneratedTransformer(_ javaScript: String) {
        draft.transformerCode = javaScript
        javaScriptEditorSession.setContent(javaScript, type: .javascript)
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
        if previewInput.source == .mock && draft.sampleMockRequestId.isEmpty {
            fieldErrors[.sampleMockId] = "Select a sample mock"
        }
        return fieldErrors.isEmpty ? (url, headers) : nil
    }

    private func applyPreview(_ result: ModifierPreviewResponse) {
        previewStatus = result.status
        previewBodyBase64 = result.bodyBase64
        previewResponseHeaders = result.headers
            .map { "\($0.key): \($0.value)" }
            .sorted()
            .joined(separator: "\n")
        previewIsStale = false

        guard let data = Data(base64Encoded: result.bodyBase64) else {
            responseEditorSession.setContent(
                "Invalid Base64 response body",
                type: .text
            )
            return
        }
        if let json = try? JSONSerialization.jsonObject(with: data),
           let formatted = try? JSONSerialization.data(
               withJSONObject: json,
               options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
           ),
           let text = String(data: formatted, encoding: .utf8) {
            responseEditorSession.setContent(text, type: .json)
        } else if let text = String(data: data, encoding: .utf8) {
            responseEditorSession.setContent(text, type: .text)
        } else {
            responseEditorSession.setContent(
                "Binary response (\(data.count) bytes). Use Copy to copy Base64.",
                type: .text
            )
        }
    }

    @MainActor
    private func present(_ error: Error) {
        errorMessage = error.localizedDescription
        shouldShowErrorMessage = true
        notificationManager.show(title: errorMessage, color: .red)
    }
}
