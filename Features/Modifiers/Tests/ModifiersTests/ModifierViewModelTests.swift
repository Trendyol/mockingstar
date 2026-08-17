import XCTest
@testable import Modifiers
import CommonKit
import CommonKitTestSupport
import CommonViewsKit
import CommonViewsKitTestSupport

@MainActor
final class ModifierListViewModelTests: XCTestCase {
    private var api: MockModifierAPIClient!
    private var notifications: MockNotificationManager!
    private var sut: ModifierListViewModel!

    override func setUp() {
        super.setUp()
        api = MockModifierAPIClient()
        notifications = MockNotificationManager()
        sut = ModifierListViewModel(apiClient: api, notificationManager: notifications, navigationStore: .shared)
    }

    private func sampleModifier(
        id: String = "discount",
        order: Int = 1
    ) -> ModifierModel {
        ModifierModel(
            id: id,
            path: "/cart",
            method: "GET",
            enabled: false,
            order: order,
            transformerCode: "function transformer(req, chain) { return chain.proceed(req) }"
        )
    }

    func test_load_PopulatesModifiers() async {
        api.stubbedList = [
            ModifierModel(id: "a", path: "/a", method: "GET", enabled: true, order: 1, transformerCode: "function transformer(req, chain){return chain.proceed(req)}"),
            ModifierModel(id: "b", path: "/b", method: "POST", enabled: false, order: 2, transformerCode: "function transformer(req, chain){return chain.proceed(req)}")
        ]

        await sut.load(domain: "Dev")

        XCTAssertEqual(sut.modifiers.map(\.id), ["a", "b"])
        XCTAssertFalse(sut.isLoading)
    }

    func test_toggleEnabled_SendsFullActiveSet() async {
        api.stubbedList = [
            ModifierModel(id: "a", path: "/a", method: "GET", enabled: true, order: 1, transformerCode: "x"),
            ModifierModel(id: "b", path: "/b", method: "GET", enabled: false, order: 2, transformerCode: "x")
        ]
        await sut.load(domain: "Dev")
        let inactive = try! XCTUnwrap(sut.modifiers.first(where: { $0.id == "b" }))
        api.stubbedList = [
            ModifierModel(id: "a", path: "/a", method: "GET", enabled: true, order: 1, transformerCode: "x"),
            ModifierModel(id: "b", path: "/b", method: "GET", enabled: true, order: 2, transformerCode: "x")
        ]

        await sut.toggleEnabled(inactive, domain: "Dev")

        XCTAssertEqual(api.invokedSetActiveIds, ["a", "b"])
    }

    func test_load_ServerUnavailable_ShowsError() async {
        api.stubbedError = ModifierAPIError.serverUnavailable
        await sut.load(domain: "Dev")
        XCTAssertTrue(sut.shouldShowErrorMessage)
        XCTAssertEqual(sut.errorMessage, ModifierAPIError.serverUnavailable.localizedDescription)
    }

    func test_modifierLookupAndDefaultOrderSupportTableSelection() async {
        api.stubbedList = [
            sampleModifier(id: "b", order: 2),
            sampleModifier(id: "a", order: 1)
        ]
        await sut.load(domain: "Dev")

        XCTAssertEqual(sut.filteredModifiers.map(\.id), ["a", "b"])
        XCTAssertEqual(sut.modifier(id: "b")?.order, 2)
    }
}

@MainActor
final class ModifierDetailViewModelTests: XCTestCase {
    private var api: MockModifierAPIClient!
    private var sut: ModifierDetailViewModel!
    private var navigationStore: NavigationStore!

    override func setUp() {
        super.setUp()
        api = MockModifierAPIClient()
        navigationStore = NavigationStore()
        sut = ModifierDetailViewModel(
            modifierId: "discount",
            apiClient: api,
            notificationManager: MockNotificationManager(),
            navigationStore: navigationStore
        )
    }

    private func sampleModifier(
        id: String = "discount",
        order: Int = 1
    ) -> ModifierModel {
        ModifierModel(
            id: id,
            path: "/cart",
            method: "GET",
            enabled: false,
            order: order,
            transformerCode: "function transformer(req, chain) { return chain.proceed(req) }"
        )
    }

    func test_load_AppliesModel() async {
        api.stubbedGet = sampleModifier(id: "discount", order: 3).with(enabled: true)
        await sut.load(domain: "Dev")
        XCTAssertEqual(sut.draft.path, "/cart")
        XCTAssertEqual(sut.draft.order, 3)
        XCTAssertTrue(sut.enabled)
        XCTAssertTrue(sut.draft.transformerCode.contains("function transformer"))
    }

    func test_save_SendsWriteRequest() async {
        api.stubbedGet = sampleModifier()
        await sut.load(domain: "Dev")
        sut.draft.path = "/checkout"
        sut.draft.order = 2
        let ok = await sut.save(domain: "Dev")
        XCTAssertTrue(ok)
        XCTAssertEqual(api.invokedUpdate?.id, "discount")
        XCTAssertEqual(api.invokedUpdate?.request.path, "/checkout")
        XCTAssertEqual(api.invokedUpdate?.request.order, 2)
    }

    func test_metadataAndIdChangesMarkDocumentDirty() async {
        api.stubbedGet = sampleModifier(id: "discount")
        await sut.load(domain: "Dev")

        sut.draft.id = "discount-v2"
        sut.draft.order = 3

        XCTAssertTrue(sut.shouldShowUnsavedIndicator)
    }

    func test_askClaude_AppliesTransformerAndPersistsKey() async {
        let notifications = MockNotificationManager()
        let keyStore = InMemoryAPIKeyStore()
        let claude = MockClaudeMessagesClient()
        claude.stubbedText = """
        ```javascript
        function transformer(req, chain) {
          var res = chain.proceed(req);
          res.body.fromClaude = true;
          return res;
        }
        ```
        """

        sut = ModifierDetailViewModel(
            modifierId: "discount",
            apiClient: api,
            notificationManager: notifications,
            navigationStore: navigationStore,
            apiKeyStore: keyStore,
            claudeClient: claude
        )
        api.stubbedGet = sampleModifier()
        await sut.load(domain: "Dev")
        sut.claudeAPIKey = "sk-ant-test"
        sut.claudeUserIntent = "fromClaude alanını true yap"
        sut.shouldShowAskClaudeSheet = true
        sut.previewStatus = 200
        sut.responseEditorSession.setContent("{\"ok\":true}", type: .json)

        let ok = await sut.askClaude()

        XCTAssertTrue(ok)
        XCTAssertFalse(sut.shouldShowAskClaudeSheet)
        XCTAssertTrue(sut.claudeUserIntent.isEmpty)
        XCTAssertTrue(sut.claudeSheetError.isEmpty)
        XCTAssertTrue(sut.draft.transformerCode.contains("fromClaude"))
        XCTAssertEqual(sut.javaScriptEditorSession.content.content, sut.draft.transformerCode)
        XCTAssertTrue(sut.shouldShowUnsavedIndicator)
        XCTAssertEqual(keyStore.load(), "sk-ant-test")
        XCTAssertEqual(claude.invokedAPIKey, "sk-ant-test")
        XCTAssertTrue(claude.invokedUser?.contains("fromClaude alanını true yap") == true)
        XCTAssertTrue(claude.invokedUser?.contains("Current transformer (EDIT THIS") == true)
        XCTAssertTrue(claude.invokedUser?.contains("chain.proceed(req)") == true)
        XCTAssertTrue(claude.invokedUser?.contains("Sample response schema") == true)
        XCTAssertTrue(claude.invokedUser?.contains("\"ok\"") == true)
        XCTAssertFalse(claude.invokedUser?.contains("{\"ok\":true}") == true)
        XCTAssertEqual(claude.invokedSystem, ModifierClaudePromptBuilder.systemPrompt)
    }

    func test_askClaude_FailureKeepsSheetAndShowsError() async {
        let keyStore = InMemoryAPIKeyStore()
        let claude = MockClaudeMessagesClient()
        claude.stubbedError = ClaudeMessagesError.invalidResponse(status: 401, message: "invalid x-api-key")

        sut = ModifierDetailViewModel(
            modifierId: "discount",
            apiClient: api,
            notificationManager: MockNotificationManager(),
            navigationStore: navigationStore,
            apiKeyStore: keyStore,
            claudeClient: claude
        )
        api.stubbedGet = sampleModifier()
        await sut.load(domain: "Dev")
        sut.claudeAPIKey = "bad-key"
        sut.shouldShowAskClaudeSheet = true

        let ok = await sut.askClaude()

        XCTAssertFalse(ok)
        XCTAssertTrue(sut.shouldShowAskClaudeSheet)
        XCTAssertTrue(sut.claudeSheetError.contains("401"))
        XCTAssertFalse(sut.draft.transformerCode.contains("fromClaude"))
    }

    func test_runPreview_SendsUnsavedDraftWithoutUpdate() async {
        api.stubbedGet = sampleModifier(id: "discount")
        api.stubbedPreview = .init(
            status: 200,
            headers: ["Content-Type": "application/json"],
            bodyBase64: Data("{\"ok\":true}".utf8).base64EncodedString()
        )
        await sut.load(domain: "Dev")
        sut.draft.transformerCode = "function transformer(req, chain) { return { body: { draft: true } } }"

        await sut.runPreview(domain: "Dev")

        XCTAssertNil(api.invokedUpdate)
        XCTAssertEqual(api.invokedPreview?.modifier.transformerCode, sut.draft.transformerCode)
        XCTAssertEqual(sut.previewStatus, 200)
        guard case .json = sut.responseEditorSession.content.type else {
            return XCTFail("expected JSON response editor")
        }
    }

    func test_save_RenameUpdatesCurrentIdAndRouteOnlyAfterSuccess() async {
        api.stubbedGet = sampleModifier(id: "discount")
        navigationStore.path = [.modifiers, .modifier(id: "discount")]
        await sut.load(domain: "Dev")
        sut.draft.id = "discount-v2"

        let saved = await sut.save(domain: "Dev")
        XCTAssertTrue(saved)

        XCTAssertEqual(api.invokedUpdate?.id, "discount")
        XCTAssertEqual(api.invokedUpdate?.request.id, "discount-v2")
        XCTAssertEqual(sut.currentId, "discount-v2")
        XCTAssertFalse(sut.shouldShowUnsavedIndicator)
        XCTAssertEqual(navigationStore.path, [.modifiers, .modifier(id: "discount-v2")])
    }

    func test_failedRenamePreservesCurrentIdAndDraft() async {
        api.stubbedGet = sampleModifier(id: "discount")
        await sut.load(domain: "Dev")
        sut.draft.id = "discount-v2"
        api.stubbedError = ModifierAPIError.conflict

        let saved = await sut.save(domain: "Dev")
        XCTAssertFalse(saved)

        XCTAssertEqual(sut.currentId, "discount")
        XCTAssertEqual(sut.draft.id, "discount-v2")
    }

    func test_load_WithCreationSeed_KeepsMockURLAndHeaders() async {
        let seed = ModifierCreationSeed(
            mockId: "mock-1",
            url: "https://real.example/search?q=1",
            path: "/search",
            method: "GET",
            scenario: "cosmetics",
            requestHeadersJSON: "{\n  \"Accept\" : \"application/json\"\n}",
            requestBody: "{\"q\":1}"
        )
        let suiteName = "modifier.preview.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        sut = ModifierDetailViewModel(
            modifierId: "discount",
            previewSeed: seed,
            apiClient: api,
            notificationManager: MockNotificationManager(),
            navigationStore: navigationStore,
            defaults: defaults
        )
        api.stubbedGet = ModifierModel(
            id: "discount",
            path: "/search",
            method: "GET",
            scenario: "cosmetics",
            sampleMockRequestId: "mock-1",
            transformerCode: "function transformer(req, chain) { return chain.proceed(req) }"
        )

        await sut.load(domain: "Dev")

        XCTAssertEqual(sut.previewInput.url, "https://real.example/search?q=1")
        XCTAssertEqual(sut.previewInput.headersJSON, "{\"Accept\":\"application/json\"}")
        XCTAssertEqual(sut.previewInput.body, "{\"q\":1}")
        XCTAssertEqual(sut.previewInput.source, .mock)
    }

    func test_save_PersistsPreviewInputForLaterReload() async {
        let suiteName = "modifier.preview.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        sut = ModifierDetailViewModel(
            modifierId: "discount",
            apiClient: api,
            notificationManager: MockNotificationManager(),
            navigationStore: navigationStore,
            defaults: defaults
        )
        api.stubbedGet = sampleModifier()
        await sut.load(domain: "Dev")
        sut.previewInput.url = "https://saved.example/cart"
        sut.previewInput.headersJSON = "{\"X-Test\":\"1\"}"

        let saved = await sut.save(domain: "Dev")
        XCTAssertTrue(saved)

        let reloaded = ModifierDetailViewModel(
            modifierId: "discount",
            apiClient: api,
            notificationManager: MockNotificationManager(),
            navigationStore: navigationStore,
            defaults: defaults
        )
        await reloaded.load(domain: "Dev")

        XCTAssertEqual(reloaded.previewInput.url, "https://saved.example/cart")
        XCTAssertEqual(reloaded.previewInput.headersJSON, "{\"X-Test\":\"1\"}")
    }

    func test_runPreview_LateOldResponseCannotOverwriteNewResponse() async {
        api.stubbedGet = sampleModifier()
        await sut.load(domain: "Dev")
        final class ContinuationsBox: @unchecked Sendable {
            var values: [CheckedContinuation<ModifierPreviewResponse, Error>] = []
        }
        let box = ContinuationsBox()
        api.previewHandler = { _ in
            try await withCheckedThrowingContinuation { continuation in
                box.values.append(continuation)
            }
        }

        let first = Task { await sut.runPreview(domain: "Dev") }
        while box.values.count < 1 { await Task.yield() }
        let second = Task { await sut.runPreview(domain: "Dev") }
        while box.values.count < 2 { await Task.yield() }

        box.values[1].resume(returning: .init(
            status: 201,
            headers: [:],
            bodyBase64: Data("new".utf8).base64EncodedString()
        ))
        await second.value
        box.values[0].resume(returning: .init(
            status: 200,
            headers: [:],
            bodyBase64: Data("old".utf8).base64EncodedString()
        ))
        await first.value

        XCTAssertEqual(sut.previewStatus, 201)
        XCTAssertEqual(sut.responseEditorSession.content.content, "new")
    }
}

private extension ModifierModel {
    func with(enabled: Bool) -> ModifierModel {
        ModifierModel(
            id: id,
            path: path,
            method: method,
            scenario: scenario,
            enabled: enabled,
            order: order,
            sampleMockRequestId: sampleMockRequestId,
            transformerCode: transformerCode
        )
    }
}

final class MockModifierAPIClient: ModifierAPIClientInterface {
    var stubbedList: [ModifierModel] = []
    var stubbedGet: ModifierModel?
    var stubbedError: Error?
    var stubbedPreview = ModifierPreviewResponse(
        status: 200,
        headers: [:],
        bodyBase64: ""
    )
    var invokedPreview: ModifierPreviewRequest?
    var previewHandler: ((ModifierPreviewRequest) async throws -> ModifierPreviewResponse)?
    var invokedCreate: ModifierWriteRequest?
    var invokedSetActiveIds: [String]?
    var invokedUpdate: (id: String, request: ModifierWriteRequest)?

    func listModifiers(domain: String) async throws -> [ModifierModel] {
        if let stubbedError { throw stubbedError }
        return stubbedList
    }

    func getModifier(domain: String, id: String) async throws -> ModifierModel {
        if let stubbedError { throw stubbedError }
        return stubbedGet!
    }

    func createModifier(domain: String, request: ModifierWriteRequest) async throws {
        if let stubbedError { throw stubbedError }
        invokedCreate = request
    }

    func updateModifier(domain: String, id: String, request: ModifierWriteRequest) async throws {
        if let stubbedError { throw stubbedError }
        invokedUpdate = (id, request)
    }

    func deleteModifier(domain: String, id: String) async throws {
        if let stubbedError { throw stubbedError }
    }

    func setActiveModifiers(domain: String, ids: [String]) async throws {
        if let stubbedError { throw stubbedError }
        invokedSetActiveIds = ids
    }

    func previewModifier(
        domain: String,
        request: ModifierPreviewRequest
    ) async throws -> ModifierPreviewResponse {
        invokedPreview = request
        if let stubbedError { throw stubbedError }
        if let previewHandler { return try await previewHandler(request) }
        return stubbedPreview
    }
}

final class MockClaudeMessagesClient: ClaudeMessagesClientInterface {
    var stubbedText = ""
    var stubbedError: Error?
    var invokedAPIKey: String?
    var invokedSystem: String?
    var invokedUser: String?

    func complete(apiKey: String, system: String, user: String) async throws -> String {
        invokedAPIKey = apiKey
        invokedSystem = system
        invokedUser = user
        if let stubbedError { throw stubbedError }
        return stubbedText
    }
}
