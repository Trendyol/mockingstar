import CommonKit
import Foundation
import XCTest
@testable import MockingStarCore
import CommonKitTestSupport
import Server

/// End-to-end tests for side-effect-free draft-chain preview.
final class ModifierPreviewTests: XCTestCase {
    private var tempWorkspaceURL: URL!
    private var previousWorkspacesData: Data?
    private var activationStore: ModifierActivationStore!
    private var mockURLSession: MockURLSession!
    private var core: MockingStarCore!

    override func setUpWithError() throws {
        try super.setUpWithError()

        previousWorkspacesData = UserDefaults.standard.data(forKey: "workspaces")

        tempWorkspaceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ModifierPreviewTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempWorkspaceURL, withIntermediateDirectories: true)

        setWorkspace(path: tempWorkspaceURL.path())

        activationStore = ModifierActivationStore()
        mockURLSession = MockURLSession()
        core = MockingStarCore(urlSession: mockURLSession, activationStore: activationStore)
    }

    override func tearDownWithError() throws {
        core = nil
        try? FileManager.default.removeItem(at: tempWorkspaceURL)

        if let previousWorkspacesData {
            UserDefaults.standard.setValue(previousWorkspacesData, forKey: "workspaces")
        } else {
            UserDefaults.standard.removeObject(forKey: "workspaces")
        }

        try super.tearDownWithError()
    }

    private func setWorkspace(path: String) {
        let workspace = Workspace(name: "ModifierPreviewTests", path: path, bookmark: Data())
        workspace.isSelected = true
        let data = try? JSONEncoder().encode([workspace])
        UserDefaults.standard.setValue(data, forKey: "workspaces")
    }

    private func uniqueDomain(_ name: String) -> String {
        "\(name)-\(UUID().uuidString.prefix(8))"
    }

    private func modifiersFolder(domain: String) -> URL {
        tempWorkspaceURL.appendingPathComponent("Domains/\(domain)/Modifiers", isDirectory: true)
    }

    private func mocksFolder(domain: String) -> URL {
        tempWorkspaceURL.appendingPathComponent("Domains/\(domain)/Mocks", isDirectory: true)
    }

    private func writeModifier(
        domain: String,
        id: String,
        path: String,
        order: Int = 1,
        sampleMockRequestId: String? = nil,
        bodyMutation: String = "res.body.injected = true;"
    ) throws {
        let sampleLiteral = sampleMockRequestId.map { "\"\($0)\"" } ?? "null"
        let modifierCode = """
        var path = "\(path)";
        var method = "GET";
        var scenario = null;
        var order = \(order);
        var sampleMockRequestId = \(sampleLiteral);

        function transformer(req, chain) {
          var res = chain.proceed(req);
          \(bodyMutation)
          return res;
        }
        """
        let folder = modifiersFolder(domain: domain)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try modifierCode.write(to: folder.appendingPathComponent("\(id).js"), atomically: true, encoding: .utf8)
    }

    private func saveMock(
        domain: String,
        path: String,
        body: String = "{\"value\":1}",
        id: String = UUID().uuidString
    ) async throws -> (mock: MockModel, url: URL) {
        let url = try XCTUnwrap(URL(string: "https://example.com\(path)"))
        let mock = MockModel(
            metaData: .init(
                url: url,
                method: "GET",
                appendTime: .init(),
                updateTime: .init(),
                httpStatus: 200,
                responseTime: 0,
                scenario: "",
                id: id
            ),
            requestHeader: "{}",
            responseHeader: "{}",
            requestBody: "",
            responseBody: body
        )
        try await FileSaverActor().saveFile(mock: mock, mockDomain: domain)
        return (mock, url)
    }

    private func previewRequest(
        currentModifierId: String,
        modifierId: String,
        path: String,
        url: URL,
        order: Int = 1,
        sampleMockRequestId: String? = nil,
        transformerCode: String,
        source: ModifierPreviewSource,
        method: String = "GET"
    ) -> ModifierPreviewRequest {
        ModifierPreviewRequest(
            currentModifierId: currentModifierId,
            modifier: .init(
                id: modifierId,
                path: path,
                method: method,
                order: order,
                sampleMockRequestId: sampleMockRequestId,
                transformerCode: transformerCode
            ),
            request: .init(url: url, method: method),
            source: source
        )
    }

    private func passthroughTransformer(bodyMutation: String) -> String {
        """
        function transformer(req, chain) {
          var res = chain.proceed(req);
          \(bodyMutation)
          return res;
        }
        """
    }

    func test_preview_InactiveDraftRunsInsideOtherActiveMatchingModifiers() async throws {
        let domain = uniqueDomain("InactiveDraft")
        let path = "/cart"
        let (mock, url) = try await saveMock(domain: domain, path: path, body: "{\"order\":[]}")
        try writeModifier(
            domain: domain,
            id: "a",
            path: path,
            order: 1,
            bodyMutation: "res.body.order = (res.body.order || []).concat([\"a\"]);"
        )
        try writeModifier(
            domain: domain,
            id: "draft",
            path: path,
            order: 2,
            bodyMutation: "res.body.order = (res.body.order || []).concat([\"saved-draft\"]);"
        )
        try writeModifier(
            domain: domain,
            id: "c",
            path: path,
            order: 3,
            bodyMutation: "res.body.order = (res.body.order || []).concat([\"c\"]);"
        )
        await activationStore.replaceActiveIds(domain: domain, deviceId: "", ids: ["a", "c"])

        let request = previewRequest(
            currentModifierId: "draft",
            modifierId: "draft",
            path: path,
            url: url,
            order: 2,
            sampleMockRequestId: mock.id,
            transformerCode: passthroughTransformer(
                bodyMutation: "res.body.order = (res.body.order || []).concat([\"draft\"]);"
            ),
            source: .mock
        )

        let response = try await core.previewModifier(domain: domain, deviceId: "", request: request)

        let json = try XCTUnwrap(
            try JSONSerialization.jsonObject(
                with: try XCTUnwrap(Data(base64Encoded: response.bodyBase64))
            ) as? [String: Any]
        )
        XCTAssertEqual(json["order"] as? [String], ["c", "draft", "a"])
        let activeIds = await activationStore.activeModifierIds(domain: domain, deviceId: "")
        XCTAssertEqual(activeIds, Set(["a", "c"]))
    }

    func test_preview_ActiveSavedVersionIsReplacedNotDuplicated() async throws {
        let domain = uniqueDomain("Replace")
        let path = "/cart"
        let (mock, url) = try await saveMock(domain: domain, path: path, body: "{\"count\":0}")
        try writeModifier(
            domain: domain,
            id: "patch",
            path: path,
            bodyMutation: """
            res.body.count = (res.body.count || 0) + 1;
            res.body.from = "saved";
            """
        )
        await activationStore.replaceActiveIds(domain: domain, deviceId: "", ids: ["patch"])

        let request = previewRequest(
            currentModifierId: "patch",
            modifierId: "patch",
            path: path,
            url: url,
            sampleMockRequestId: mock.id,
            transformerCode: passthroughTransformer(
                bodyMutation: """
                res.body.count = (res.body.count || 0) + 1;
                res.body.from = "draft";
                """
            ),
            source: .mock
        )

        let response = try await core.previewModifier(domain: domain, deviceId: "", request: request)
        let json = try XCTUnwrap(
            try JSONSerialization.jsonObject(
                with: try XCTUnwrap(Data(base64Encoded: response.bodyBase64))
            ) as? [String: Any]
        )
        XCTAssertEqual(json["count"] as? Int, 1)
        XCTAssertEqual(json["from"] as? String, "draft")
    }

    func test_preview_MockSourceLoadsExactSampleWithoutLiveCall() async throws {
        let domain = uniqueDomain("MockSource")
        let path = "/cart"
        let (mock, url) = try await saveMock(domain: domain, path: path, body: "{}")
        try writeModifier(domain: domain, id: "draft", path: path, sampleMockRequestId: mock.id)

        let request = previewRequest(
            currentModifierId: "draft",
            modifierId: "draft",
            path: path,
            url: url,
            sampleMockRequestId: mock.id,
            transformerCode: passthroughTransformer(bodyMutation: "res.body.draftApplied = true;"),
            source: .mock
        )

        let response = try await core.previewModifier(domain: domain, deviceId: "", request: request)

        XCTAssertEqual(mockURLSession.invokedDataCount, 0)
        XCTAssertEqual(response.status, 200)
        XCTAssertEqual(
            try JSONSerialization.jsonObject(with: Data(base64Encoded: response.bodyBase64)! ) as? [String: Bool],
            ["draftApplied": true]
        )
    }

    func test_preview_LiveSourceCallsURLSessionAndDoesNotSaveMock() async throws {
        let domain = uniqueDomain("LiveSource")
        let path = "/live-path"
        let url = try XCTUnwrap(URL(string: "https://example.com\(path)"))
        try writeModifier(domain: domain, id: "live-draft", path: path)

        let mocksPath = mocksFolder(domain: domain)
        let beforeMocks = (try? FileManager.default.contentsOfDirectory(atPath: mocksPath.path())) ?? []

        let liveBody = Data("{\"from\":\"live\"}".utf8)
        let liveResponse = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        mockURLSession.stubbedDataResult = (liveBody, liveResponse)

        let request = previewRequest(
            currentModifierId: "live-draft",
            modifierId: "live-draft",
            path: path,
            url: url,
            transformerCode: passthroughTransformer(bodyMutation: "res.body.from = \"modifier\";"),
            source: .live
        )

        let response = try await core.previewModifier(domain: domain, deviceId: "", request: request)

        XCTAssertEqual(mockURLSession.invokedDataCount, 1)
        XCTAssertEqual(response.status, 200)
        let json = try XCTUnwrap(
            try JSONSerialization.jsonObject(
                with: try XCTUnwrap(Data(base64Encoded: response.bodyBase64))
            ) as? [String: Any]
        )
        XCTAssertEqual(json["from"] as? String, "modifier")

        let afterMocks = (try? FileManager.default.contentsOfDirectory(atPath: mocksPath.path())) ?? []
        XCTAssertEqual(afterMocks, beforeMocks)
    }

    func test_preview_DraftIdConflictThrowsConflict() async throws {
        let domain = uniqueDomain("Conflict")
        let path = "/cart"
        let (_, url) = try await saveMock(domain: domain, path: path)
        try writeModifier(domain: domain, id: "current", path: path)
        try writeModifier(domain: domain, id: "existing", path: path)

        let request = previewRequest(
            currentModifierId: "current",
            modifierId: "existing",
            path: path,
            url: url,
            transformerCode: passthroughTransformer(bodyMutation: ""),
            source: .mock
        )

        do {
            _ = try await core.previewModifier(domain: domain, deviceId: "", request: request)
            XCTFail("expected previewConflict")
        } catch ServerModifierError.previewConflict(let id) {
            XCTAssertEqual(id, "existing")
        }
    }

    func test_preview_DraftMismatchThrowsInvalidRequest() async throws {
        let domain = uniqueDomain("Mismatch")
        let path = "/cart"
        let (_, _) = try await saveMock(domain: domain, path: path)
        try writeModifier(domain: domain, id: "draft", path: path)
        let otherURL = try XCTUnwrap(URL(string: "https://example.com/other"))

        let request = previewRequest(
            currentModifierId: "draft",
            modifierId: "draft",
            path: path,
            url: otherURL,
            sampleMockRequestId: "unused",
            transformerCode: passthroughTransformer(bodyMutation: ""),
            source: .mock
        )

        do {
            _ = try await core.previewModifier(domain: domain, deviceId: "", request: request)
            XCTFail("expected previewInvalidRequest")
        } catch ServerModifierError.previewInvalidRequest(let message) {
            XCTAssertTrue(message.contains("does not match"))
        }
    }

    func test_preview_SyntaxErrorThrowsExecutionFailure() async throws {
        let domain = uniqueDomain("Syntax")
        let path = "/cart"
        let (mock, url) = try await saveMock(domain: domain, path: path)
        try writeModifier(domain: domain, id: "draft", path: path)

        let request = previewRequest(
            currentModifierId: "draft",
            modifierId: "draft",
            path: path,
            url: url,
            sampleMockRequestId: mock.id,
            transformerCode: "function transformer(req, chain) { !!! }",
            source: .mock
        )

        do {
            _ = try await core.previewModifier(domain: domain, deviceId: "", request: request)
            XCTFail("expected previewExecutionFailed")
        } catch ServerModifierError.previewExecutionFailed {
            // expected
        }
    }

    func test_preview_SuccessAndFailureDoNotChangeFilesOrActivation() async throws {
        let domain = uniqueDomain("Isolation")
        let path = "/cart"
        let (mock, url) = try await saveMock(domain: domain, path: path)
        try writeModifier(domain: domain, id: "draft", path: path)
        try writeModifier(domain: domain, id: "other", path: path, order: 2)
        await activationStore.replaceActiveIds(domain: domain, deviceId: "", ids: ["other"])

        let folder = modifiersFolder(domain: domain)
        let beforeIds = await activationStore.activeModifierIds(domain: domain, deviceId: "")
        let beforeFiles = try FileManager.default.contentsOfDirectory(atPath: folder.path()).sorted()

        let successRequest = previewRequest(
            currentModifierId: "draft",
            modifierId: "draft",
            path: path,
            url: url,
            sampleMockRequestId: mock.id,
            transformerCode: passthroughTransformer(bodyMutation: "res.body.ok = true;"),
            source: .mock
        )
        _ = try await core.previewModifier(domain: domain, deviceId: "", request: successRequest)

        let failureRequest = previewRequest(
            currentModifierId: "draft",
            modifierId: "draft",
            path: path,
            url: url,
            sampleMockRequestId: mock.id,
            transformerCode: "function transformer(req, chain) { !!! }",
            source: .mock
        )
        do {
            _ = try await core.previewModifier(domain: domain, deviceId: "", request: failureRequest)
            XCTFail("expected failure")
        } catch ServerModifierError.previewExecutionFailed {
            // expected
        }

        let afterIds = await activationStore.activeModifierIds(domain: domain, deviceId: "")
        XCTAssertEqual(afterIds, beforeIds)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path()).sorted(), beforeFiles)
    }
}
