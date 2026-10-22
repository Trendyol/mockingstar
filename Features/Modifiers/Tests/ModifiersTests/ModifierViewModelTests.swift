import XCTest
@testable import Modifiers
import CommonKit
import CommonKitTestSupport
import CommonViewsKit
import CommonViewsKitTestSupport

@MainActor
final class MockModifierListViewModelTests: XCTestCase {
    private var api: FakeMockModifierAPIClient!
    private var notifications: MockNotificationManager!
    private var pasteBoard: MockNSPasteboard!
    private var sut: MockModifierListViewModel!

    override func setUp() {
        super.setUp()
        api = FakeMockModifierAPIClient()
        notifications = MockNotificationManager()
        pasteBoard = MockNSPasteboard()
        pasteBoard.stubbedClearContentsResult = 0
        pasteBoard.stubbedSetStringResult = true
        sut = MockModifierListViewModel(
            apiClient: api,
            notificationManager: notifications,
            navigationStore: .shared,
            pasteBoard: pasteBoard
        )
    }

    private func sampleModifier(
        id: String = "discount",
        order: Int = 1
    ) -> MockModifierModel {
        MockModifierModel(
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
            MockModifierModel(id: "a", path: "/a", method: "GET", enabled: true, order: 1, transformerCode: "function transformer(req, chain){return chain.proceed(req)}"),
            MockModifierModel(id: "b", path: "/b", method: "POST", enabled: false, order: 2, transformerCode: "function transformer(req, chain){return chain.proceed(req)}")
        ]

        await sut.load(domain: "Dev")

        XCTAssertEqual(sut.modifiers.map(\.id), ["a", "b"])
        XCTAssertFalse(sut.isLoading)
    }

    func test_setSource_SendsFullActivationSetPreservingExistingSources() async {
        api.stubbedList = [
            MockModifierModel(id: "a", path: "/a", method: "GET", enabled: true, source: .live, order: 1, transformerCode: "x"),
            MockModifierModel(id: "b", path: "/b", method: "GET", enabled: false, order: 2, transformerCode: "x")
        ]
        await sut.load(domain: "Dev")
        let inactive = try! XCTUnwrap(sut.modifiers.first(where: { $0.id == "b" }))
        api.stubbedList = [
            MockModifierModel(id: "a", path: "/a", method: "GET", enabled: true, source: .live, order: 1, transformerCode: "x"),
            MockModifierModel(id: "b", path: "/b", method: "GET", enabled: true, source: .mock, order: 2, transformerCode: "x")
        ]

        await sut.setSource(inactive, source: .mock, domain: "Dev")

        XCTAssertEqual(api.invokedSetActiveActivations, [
            MockModifierActivation(id: "a", source: .live),
            MockModifierActivation(id: "b", source: .mock)
        ])
    }

    func test_setSource_OffRemovesModifierFromActivationSet() async {
        api.stubbedList = [
            MockModifierModel(id: "a", path: "/a", method: "GET", enabled: true, source: .live, order: 1, transformerCode: "x"),
            MockModifierModel(id: "b", path: "/b", method: "GET", enabled: true, source: .mock, order: 2, transformerCode: "x")
        ]
        await sut.load(domain: "Dev")
        let active = try! XCTUnwrap(sut.modifiers.first(where: { $0.id == "b" }))

        await sut.setSource(active, source: nil, domain: "Dev")

        XCTAssertEqual(api.invokedSetActiveActivations, [
            MockModifierActivation(id: "a", source: .live)
        ])
    }

    func test_load_ServerUnavailable_ShowsError() async {
        api.stubbedError = MockModifierAPIError.serverUnavailable
        await sut.load(domain: "Dev")
        XCTAssertTrue(sut.shouldShowErrorMessage)
        XCTAssertEqual(sut.errorMessage, MockModifierAPIError.serverUnavailable.localizedDescription)
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

    func test_search_FiltersEachFieldCaseInsensitively() async {
        api.stubbedList = [
            MockModifierModel(id: "one", path: "/Cart", method: "GET", scenario: "sale", order: 2, transformerCode: "x"),
            MockModifierModel(id: "two", path: "/checkout", method: "POST", scenario: "cart", order: 1, transformerCode: "x")
        ]
        await sut.load(domain: "Dev")
        sut.searchTerm = " CART "
        XCTAssertEqual(sut.filteredModifiers.map(\.id), ["two", "one"])
        sut.filterType = .path
        XCTAssertEqual(sut.filteredModifiers.map(\.id), ["one"])
        sut.filterType = .scenario
        XCTAssertEqual(sut.filteredModifiers.map(\.id), ["two"])
        sut.filterType = .method
        sut.searchTerm = "get"
        XCTAssertEqual(sut.filteredModifiers.map(\.id), ["one"])
        sut.filterType = .all
        sut.searchTerm = "two"
        XCTAssertEqual(sut.filteredModifiers.map(\.id), ["two"])
    }

    func test_search_SupportsEveryStyleAndKeepsOrderForEmptyTerm() async {
        api.stubbedList = [sampleModifier(id: "one", order: 2), sampleModifier(id: "two", order: 1)]
        await sut.load(domain: "Dev")
        sut.filterType = .path
        let cases: [(FilterStyle, String, [String])] = [
            (.contains, "ar", ["two", "one"]),
            (.notContains, "cart", []),
            (.startWith, "/ca", ["two", "one"]),
            (.endWith, "art", ["two", "one"]),
            (.equal, "/cart", ["two", "one"]),
            (.notEqual, "/cart", [])
        ]
        for (style, term, expected) in cases {
            sut.filterStyle = style
            sut.searchTerm = term
            XCTAssertEqual(sut.filteredModifiers.map(\.id), expected, "Style: \(style)")
        }
        sut.searchTerm = "  "
        XCTAssertEqual(sut.filteredModifiers.map(\.id), ["two", "one"])
    }

    func test_duplicate_CreatesCopyIdAndNextOrderWithoutActivation() async {
        api.stubbedList = [sampleModifier(id: "discount", order: 1)]
        await sut.load(domain: "Dev")

        await sut.duplicate(id: "discount", domain: "Dev")

        XCTAssertEqual(api.invokedCreate?.id, "discount-copy")
        XCTAssertEqual(api.invokedCreate?.order, 2)
        XCTAssertEqual(api.invokedCreate?.path, "/cart")
        XCTAssertEqual(api.invokedCreate?.method, "GET")
        XCTAssertEqual(
            api.invokedCreate?.transformerCode,
            "function transformer(req, chain) { return chain.proceed(req) }"
        )
        XCTAssertNil(api.invokedSetActiveActivations)
        XCTAssertEqual(sut.selected, ["discount-copy"])
    }

    func test_duplicate_SecondCopyUsesIncrementedSuffix() async {
        api.stubbedList = [
            sampleModifier(id: "discount", order: 1),
            sampleModifier(id: "discount-copy", order: 2)
        ]
        await sut.load(domain: "Dev")

        await sut.duplicate(id: "discount", domain: "Dev")

        XCTAssertEqual(api.invokedCreate?.id, "discount-copy-2")
        XCTAssertEqual(api.invokedCreate?.order, 3)
    }

    func test_deletePending_DeletesEveryConfirmedSelection() async {
        api.stubbedList = [
            sampleModifier(id: "a", order: 1),
            sampleModifier(id: "b", order: 2),
            sampleModifier(id: "c", order: 3)
        ]
        await sut.load(domain: "Dev")
        sut.selected = ["a", "c"]

        sut.confirmDelete(ids: ["a", "c"])
        await sut.deletePending(domain: "Dev")

        XCTAssertEqual(api.invokedDeletedIds, ["a", "c"])
        XCTAssertEqual(sut.modifiers.map(\.id), ["b"])
        XCTAssertTrue(sut.selected.isEmpty)
        XCTAssertNil(api.invokedSetActiveActivations)
    }

    func test_paste_IgnoresPlainTextWithoutClipboardPrefix() async {
        api.stubbedList = [sampleModifier()]
        await sut.load(domain: "Dev")
        pasteBoard.stubbedString = "{\"id\":\"discount\",\"path\":\"/cart\"}"

        await sut.paste(domain: "Dev")

        XCTAssertNil(api.invokedCreate)
    }

    func test_copyThenPaste_CreatesDuplicateFromClipboard() async {
        api.stubbedList = [sampleModifier(id: "discount", order: 1)]
        await sut.load(domain: "Dev")
        sut.selected = ["discount"]

        sut.copySelected()
        await sut.paste(domain: "Dev")

        XCTAssertTrue(pasteBoard.invokedSetString)
        XCTAssertEqual(api.invokedCreate?.id, "discount-copy")
        XCTAssertEqual(api.invokedCreate?.order, 2)
        XCTAssertEqual(
            api.invokedCreate?.transformerCode,
            "function transformer(req, chain) { return chain.proceed(req) }"
        )
    }
}

@MainActor
final class MockModifierDetailViewModelTests: XCTestCase {
    private var api: FakeMockModifierAPIClient!
    private var sut: MockModifierDetailViewModel!
    private var navigationStore: NavigationStore!

    override func setUp() {
        super.setUp()
        api = FakeMockModifierAPIClient()
        navigationStore = NavigationStore()
        sut = MockModifierDetailViewModel(
            modifierId: "discount",
            apiClient: api,
            notificationManager: MockNotificationManager(),
            navigationStore: navigationStore
        )
    }

    private func sampleModifier(
        id: String = "discount",
        order: Int = 1
    ) -> MockModifierModel {
        MockModifierModel(
            id: id,
            path: "/cart",
            method: "GET",
            enabled: false,
            order: order,
            transformerCode: "function transformer(req, chain) { return chain.proceed(req) }"
        )
    }

    func test_copyPreviewCURL_UsesUnsavedRequestWithoutRunningOrSaving() throws {
        let pasteBoard = MockNSPasteboard()
        pasteBoard.stubbedClearContentsResult = 0
        pasteBoard.stubbedSetStringResult = true
        let notifications = MockNotificationManager()
        sut = MockModifierDetailViewModel(
            modifierId: "discount", apiClient: api,
            notificationManager: notifications, pasteBoard: pasteBoard
        )
        sut.previewInput = .init(
            source: .mock, url: "https://example.com/cart?q=1", method: "post",
            scenario: "sale", headersJSON: "{\"X-Test\":\"one\"}", body: "{\"name\":\"O'Reilly\"}"
        )
        sut.copyPreviewCURL()
        let curl = try XCTUnwrap(pasteBoard.stubbedString)
        XCTAssertTrue(curl.contains("--request 'POST'"))
        XCTAssertTrue(curl.contains("--url 'https://example.com/cart?q=1'"))
        XCTAssertTrue(curl.contains("--header 'X-Test: one'"))
        XCTAssertTrue(curl.contains("O'\\''Reilly"))
        XCTAssertNil(api.invokedPreview)
        XCTAssertNil(api.invokedUpdate)
        XCTAssertEqual(notifications.invokedShowParameters?.color, .green)
    }

    func test_copyPreviewCURL_InvalidInputPreservesClipboardAndShowsRedError() {
        let pasteBoard = MockNSPasteboard()
        pasteBoard.stubbedString = "existing clipboard"
        let notifications = MockNotificationManager()
        sut = MockModifierDetailViewModel(
            modifierId: "discount", apiClient: api,
            notificationManager: notifications, pasteBoard: pasteBoard
        )
        sut.previewInput.url = "/relative"
        sut.copyPreviewCURL()
        XCTAssertEqual(pasteBoard.stubbedString, "existing clipboard")
        XCTAssertNotNil(sut.fieldErrors[.url])
        XCTAssertEqual(notifications.invokedShowParameters?.color, .red)
        sut.previewInput.url = "https://example.com"
        sut.previewInput.headersJSON = "{\"X-Test\":1}"
        sut.copyPreviewCURL()
        XCTAssertNil(sut.fieldErrors[.url])
        XCTAssertNotNil(sut.fieldErrors[.headers])
        XCTAssertEqual(pasteBoard.stubbedString, "existing clipboard")
        XCTAssertEqual(notifications.invokedShowParameters?.color, .red)
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
        api.stubbedError = MockModifierAPIError.conflict

        let saved = await sut.save(domain: "Dev")
        XCTAssertFalse(saved)

        XCTAssertEqual(sut.currentId, "discount")
        XCTAssertEqual(sut.draft.id, "discount-v2")
    }

    func test_load_AppliesActivationSourceToPreview() async {
        let suiteName = "modifier.preview.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        MockModifierPreviewInputStore.save(
            .init(
                source: .mock,
                url: "https://stored.example/cart",
                method: "GET",
                scenario: "",
                headersJSON: "{}",
                body: ""
            ),
            domain: "Dev",
            id: "discount",
            defaults: defaults
        )
        sut = MockModifierDetailViewModel(
            modifierId: "discount",
            apiClient: api,
            notificationManager: MockNotificationManager(),
            navigationStore: navigationStore,
            defaults: defaults
        )
        api.stubbedGet = MockModifierModel(
            id: "discount",
            path: "/cart",
            method: "GET",
            enabled: true,
            source: .live,
            transformerCode: "function transformer(req, chain) { return chain.proceed(req) }"
        )

        await sut.load(domain: "Dev")

        XCTAssertEqual(sut.previewInput.source, .live)
        XCTAssertEqual(sut.activeSource, .live)
        XCTAssertEqual(sut.previewInput.url, "https://stored.example/cart")
    }

    func test_setSource_ActivatesModifierAndPreviewTogether() async {
        api.stubbedGet = sampleModifier()
        api.stubbedList = [
            MockModifierModel(id: "latency", path: "/x", method: "GET", enabled: true, source: .mock, transformerCode: "x"),
            sampleModifier()
        ]
        await sut.load(domain: "Dev")

        await sut.setSource(.live, domain: "Dev")

        XCTAssertEqual(sut.previewInput.source, .live)
        XCTAssertEqual(sut.activeSource, .live)
        XCTAssertEqual(api.invokedSetActiveActivations, [
            MockModifierActivation(id: "discount", source: .live),
            MockModifierActivation(id: "latency", source: .mock)
        ])
    }

    func test_setSource_OffClearsActivationWithoutChangingPreviewTerminal() async {
        api.stubbedGet = sampleModifier().with(enabled: true, source: .live)
        api.stubbedList = [
            sampleModifier().with(enabled: true, source: .live)
        ]
        await sut.load(domain: "Dev")
        XCTAssertEqual(sut.previewInput.source, .live)

        await sut.setSource(nil, domain: "Dev")

        XCTAssertNil(sut.activeSource)
        XCTAssertEqual(sut.previewInput.source, .live)
        XCTAssertEqual(api.invokedSetActiveActivations, [])
    }

    func test_load_WithCreationSeed_KeepsMockURLAndHeaders() async {
        let seed = MockModifierCreationSeed(
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
        sut = MockModifierDetailViewModel(
            modifierId: "discount",
            previewSeed: seed,
            apiClient: api,
            notificationManager: MockNotificationManager(),
            navigationStore: navigationStore,
            defaults: defaults
        )
        api.stubbedGet = MockModifierModel(
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
        sut = MockModifierDetailViewModel(
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

        let reloaded = MockModifierDetailViewModel(
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
            var values: [CheckedContinuation<MockModifierPreviewResponse, Error>] = []
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

private extension MockModifierModel {
    func with(enabled: Bool, source: MockModifierPreviewSource? = nil) -> MockModifierModel {
        MockModifierModel(
            id: id,
            path: path,
            method: method,
            scenario: scenario,
            enabled: enabled,
            source: source,
            order: order,
            sampleMockRequestId: sampleMockRequestId,
            transformerCode: transformerCode
        )
    }
}

final class FakeMockModifierAPIClient: MockModifierAPIClientInterface {
    var stubbedList: [MockModifierModel] = []
    var stubbedGet: MockModifierModel?
    var stubbedError: Error?
    var stubbedPreview = MockModifierPreviewResponse(
        status: 200,
        headers: [:],
        bodyBase64: ""
    )
    var invokedPreview: MockModifierPreviewRequest?
    var previewHandler: ((MockModifierPreviewRequest) async throws -> MockModifierPreviewResponse)?
    var invokedCreate: MockModifierWriteRequest?
    var invokedDeletedIds: [String] = []
    var invokedSetActiveActivations: [MockModifierActivation]?
    var invokedUpdate: (id: String, request: MockModifierWriteRequest)?

    func listModifiers(domain: String) async throws -> [MockModifierModel] {
        if let stubbedError { throw stubbedError }
        return stubbedList
    }

    func getModifier(domain: String, id: String) async throws -> MockModifierModel {
        if let stubbedError { throw stubbedError }
        return stubbedGet!
    }

    func createModifier(domain: String, request: MockModifierWriteRequest) async throws {
        if let stubbedError { throw stubbedError }
        invokedCreate = request
        if let id = request.id {
            stubbedList.append(request.asModel(id: id))
        }
    }

    func updateModifier(domain: String, id: String, request: MockModifierWriteRequest) async throws {
        if let stubbedError { throw stubbedError }
        invokedUpdate = (id, request)
    }

    func deleteModifier(domain: String, id: String) async throws {
        invokedDeletedIds.append(id)
        if let stubbedError { throw stubbedError }
        stubbedList.removeAll { $0.id == id }
    }

    func setActiveModifiers(domain: String, activations: [MockModifierActivation]) async throws {
        if let stubbedError { throw stubbedError }
        invokedSetActiveActivations = activations
    }

    func previewModifier(
        domain: String,
        request: MockModifierPreviewRequest
    ) async throws -> MockModifierPreviewResponse {
        invokedPreview = request
        if let stubbedError { throw stubbedError }
        if let previewHandler { return try await previewHandler(request) }
        return stubbedPreview
    }
}
