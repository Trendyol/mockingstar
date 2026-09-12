import CommonKit
import Foundation
import XCTest
@testable import MockingStarCore
import CommonKitTestSupport
import Server

/// End-to-end tests for `MockingStarCore.handle(request:flags:)` modifier wiring.
final class ModifierIntegrationTests: XCTestCase {
    private var tempWorkspaceURL: URL!
    private var previousWorkspacesData: Data?
    private var activationStore: ModifierActivationStore!
    private var mockURLSession: MockURLSession!
    private var core: MockingStarCore!

    override func setUpWithError() throws {
        try super.setUpWithError()

        previousWorkspacesData = UserDefaults.standard.data(forKey: "workspaces")

        tempWorkspaceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ModifierIntegrationTests-\(UUID().uuidString)", isDirectory: true)
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
        let workspace = Workspace(name: "ModifierIntegrationTests", path: path, bookmark: Data())
        workspace.isSelected = true
        let data = try? JSONEncoder().encode([workspace])
        UserDefaults.standard.setValue(data, forKey: "workspaces")
    }

    private func uniqueDomain(_ name: String) -> String {
        "\(name)-\(UUID().uuidString.prefix(8))"
    }

    private func writeModifier(domain: String, id: String, path: String, order: Int = 1, bodyMutation: String = "res.body.injected = true;") throws {
        let modifierCode = """
        var path = "\(path)";
        var method = "GET";
        var scenario = null;
        var order = \(order);
        var sampleMockRequestId = null;

        function transformer(req, chain) {
          var res = chain.proceed(req);
          \(bodyMutation)
          return res;
        }
        """
        let modifiersFolder = tempWorkspaceURL.appendingPathComponent("Domains/\(domain)/Modifiers", isDirectory: true)
        try FileManager.default.createDirectory(at: modifiersFolder, withIntermediateDirectories: true)
        try modifierCode.write(to: modifiersFolder.appendingPathComponent("\(id).js"), atomically: true, encoding: .utf8)
    }

    private func saveMock(domain: String, path: String, body: String = "{\"value\":1}") async throws -> URL {
        let url = try XCTUnwrap(URL(string: "https://example.com\(path)"))
        let mock = MockModel(metaData: .init(url: url,
                                             method: "GET",
                                             appendTime: .init(),
                                             updateTime: .init(),
                                             httpStatus: 200,
                                             responseTime: 0,
                                             scenario: "",
                                             id: UUID().uuidString),
                             requestHeader: "{}",
                             responseHeader: "{}",
                             requestBody: "",
                             responseBody: body)
        try await FileSaverActor().saveFile(mock: mock, mockDomain: domain)
        return url
    }

    func test_handle_NoModifiers_FallsThroughToOriginalHandle_ReturnsNotFound() async throws {
        let domain = uniqueDomain("NoModifiers")

        var request = URLRequest(url: try XCTUnwrap(URL(string: "https://example.com/no-such-path")))
        request.httpMethod = "GET"

        let flags = MockServerFlags(mockSource: .onlyMock, scenario: nil, domain: domain, deviceId: "")

        let result = try await core.handle(request: request, flags: flags)

        XCTAssertEqual(result.status, 404)
    }

    func test_handle_InactiveModifier_IsIgnored_ReturnsUnmodifiedMock() async throws {
        let domain = uniqueDomain("Inactive")
        let path = "/aboutus"
        let url = try await saveMock(domain: domain, path: path)
        try writeModifier(domain: domain, id: "patch-test", path: path)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let flags = MockServerFlags(mockSource: .onlyMock, scenario: nil, domain: domain, deviceId: "")

        let result = try await core.handle(request: request, flags: flags)

        XCTAssertEqual(result.status, 200)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: result.body) as? [String: Any])
        XCTAssertNil(json["injected"])
        XCTAssertEqual(json["value"] as? Int, 1)
    }

    func test_handle_ActiveModifier_WithOnlyMock_PatchesMockResponseBody() async throws {
        let domain = uniqueDomain("Matched")
        let path = "/aboutus"
        let url = try await saveMock(domain: domain, path: path)
        try writeModifier(domain: domain, id: "patch-test", path: path)
        await activationStore.replaceActiveIds(domain: domain, deviceId: "", ids: ["patch-test"])

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let flags = MockServerFlags(mockSource: .onlyMock, scenario: nil, domain: domain, deviceId: "")

        let result = try await core.handle(request: request, flags: flags)

        XCTAssertEqual(result.status, 200)
        XCTAssertEqual(mockURLSession.invokedDataCount, 0)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: result.body) as? [String: Any])
        XCTAssertEqual(json["injected"] as? Bool, true)
        XCTAssertEqual(json["value"] as? Int, 1)
    }

    func test_handle_ActiveModifier_DefaultSource_UsesLiveTerminal() async throws {
        let domain = uniqueDomain("LiveTerminal")
        let path = "/live-path"
        let url = try await saveMock(domain: domain, path: path, body: "{\"from\":\"mock\"}")
        try writeModifier(domain: domain, id: "live-patch", path: path, bodyMutation: "res.body.from = \"modifier\";")
        await activationStore.replaceActiveIds(domain: domain, deviceId: "", ids: ["live-patch"])

        let liveBody = Data("{\"from\":\"live\"}".utf8)
        let liveResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        mockURLSession.stubbedDataResult = (liveBody, liveResponse)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let flags = MockServerFlags(mockSource: .default, scenario: nil, domain: domain, deviceId: "")

        let result = try await core.handle(request: request, flags: flags)

        XCTAssertEqual(result.status, 200)
        XCTAssertEqual(mockURLSession.invokedDataCount, 1)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: result.body) as? [String: Any])
        XCTAssertEqual(json["from"] as? String, "modifier")
    }

    func test_handle_DeviceIsolation_DoesNotCrossContaminate() async throws {
        let domain = uniqueDomain("Devices")
        let path = "/cart"
        let url = try await saveMock(domain: domain, path: path)
        try writeModifier(domain: domain, id: "device-a-mod", path: path, bodyMutation: "res.body.device = \"a\";")
        try writeModifier(domain: domain, id: "device-b-mod", path: path, bodyMutation: "res.body.device = \"b\";")
        await activationStore.replaceActiveIds(domain: domain, deviceId: "A", ids: ["device-a-mod"])
        await activationStore.replaceActiveIds(domain: domain, deviceId: "B", ids: ["device-b-mod"])

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let resultA = try await core.handle(request: request, flags: .init(mockSource: .onlyMock, scenario: nil, domain: domain, deviceId: "A"))
        let resultB = try await core.handle(request: request, flags: .init(mockSource: .onlyMock, scenario: nil, domain: domain, deviceId: "B"))
        let resultDefault = try await core.handle(request: request, flags: .init(mockSource: .onlyMock, scenario: nil, domain: domain, deviceId: ""))

        let jsonA = try XCTUnwrap(try JSONSerialization.jsonObject(with: resultA.body) as? [String: Any])
        let jsonB = try XCTUnwrap(try JSONSerialization.jsonObject(with: resultB.body) as? [String: Any])
        let jsonDefault = try XCTUnwrap(try JSONSerialization.jsonObject(with: resultDefault.body) as? [String: Any])
        XCTAssertEqual(jsonA["device"] as? String, "a")
        XCTAssertEqual(jsonB["device"] as? String, "b")
        XCTAssertNil(jsonDefault["device"])
    }

    func test_handle_ChainedModifiers_ExecuteInAscendingOrder() async throws {
        let domain = uniqueDomain("Chain")
        let path = "/chain"
        let url = try await saveMock(domain: domain, path: path, body: "{\"order\":[]}")
        try writeModifier(domain: domain, id: "a", path: path, order: 1, bodyMutation: "res.body.order = (res.body.order || []).concat([\"a\"]);")
        try writeModifier(domain: domain, id: "b", path: path, order: 2, bodyMutation: "res.body.order = (res.body.order || []).concat([\"b\"]);")
        try writeModifier(domain: domain, id: "c", path: path, order: 3, bodyMutation: "res.body.order = (res.body.order || []).concat([\"c\"]);")
        await activationStore.replaceActiveIds(domain: domain, deviceId: "", ids: ["a", "b", "c"])

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let result = try await core.handle(request: request, flags: .init(mockSource: .onlyMock, scenario: nil, domain: domain, deviceId: ""))

        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: result.body) as? [String: Any])
        XCTAssertEqual(json["order"] as? [String], ["c", "b", "a"])
    }

    func test_setActiveModifiers_UnknownId_Throws() async throws {
        let domain = uniqueDomain("Unknown")
        try writeModifier(domain: domain, id: "exists", path: "/x")

        do {
            try await core.setActiveModifiers(domain: domain, deviceId: "A", activations: [
                .init(id: "exists", source: .live),
                .init(id: "missing", source: .live)
            ])
            XCTFail("expected unknownIds")
        } catch ServerModifierError.unknownIds(let ids) {
            XCTAssertEqual(ids, ["missing"])
        }
    }

    func test_handle_MockSourceModifier_PatchesMockAndSkipsLive() async throws {
        let domain = uniqueDomain("MockSource")
        let path = "/mock-source"
        let url = try await saveMock(domain: domain, path: path, body: "{\"from\":\"mock\"}")
        try writeModifier(domain: domain, id: "mock-mod", path: path, bodyMutation: "res.body.from = \"modifier\";")
        try await core.setActiveModifiers(domain: domain, deviceId: "", activations: [
            .init(id: "mock-mod", source: .mock)
        ])

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let flags = MockServerFlags(mockSource: .default, scenario: nil, domain: domain, deviceId: "")

        let result = try await core.handle(request: request, flags: flags)

        XCTAssertEqual(result.status, 200)
        XCTAssertEqual(mockURLSession.invokedDataCount, 0)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: result.body) as? [String: Any])
        XCTAssertEqual(json["from"] as? String, "modifier")
    }

    func test_handle_LiveSourceModifier_UsesLiveTerminal() async throws {
        let domain = uniqueDomain("LiveSource")
        let path = "/live-source"
        let url = try await saveMock(domain: domain, path: path, body: "{\"from\":\"mock\"}")
        try writeModifier(domain: domain, id: "live-mod", path: path, bodyMutation: "res.body.from = res.body.from + \"+modifier\";")
        try await core.setActiveModifiers(domain: domain, deviceId: "", activations: [
            .init(id: "live-mod", source: .live)
        ])

        let liveBody = Data("{\"from\":\"live\"}".utf8)
        let liveResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        mockURLSession.stubbedDataResult = (liveBody, liveResponse)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let flags = MockServerFlags(mockSource: .default, scenario: nil, domain: domain, deviceId: "")

        let result = try await core.handle(request: request, flags: flags)

        XCTAssertEqual(result.status, 200)
        XCTAssertEqual(mockURLSession.invokedDataCount, 1)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: result.body) as? [String: Any])
        XCTAssertEqual(json["from"] as? String, "live+modifier")
    }

    func test_handle_MixedSources_LiveWins() async throws {
        let domain = uniqueDomain("Mixed")
        let path = "/mixed"
        let url = try await saveMock(domain: domain, path: path, body: "{\"from\":\"mock\"}")
        try writeModifier(domain: domain, id: "a-mock", path: path, order: 1, bodyMutation: "res.body.a = true;")
        try writeModifier(domain: domain, id: "b-live", path: path, order: 2, bodyMutation: "res.body.b = true;")
        try await core.setActiveModifiers(domain: domain, deviceId: "", activations: [
            .init(id: "a-mock", source: .mock),
            .init(id: "b-live", source: .live)
        ])

        let liveBody = Data("{\"from\":\"live\"}".utf8)
        let liveResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        mockURLSession.stubbedDataResult = (liveBody, liveResponse)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let flags = MockServerFlags(mockSource: .default, scenario: nil, domain: domain, deviceId: "")

        let result = try await core.handle(request: request, flags: flags)

        XCTAssertEqual(mockURLSession.invokedDataCount, 1)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: result.body) as? [String: Any])
        XCTAssertEqual(json["from"] as? String, "live")
    }

    func test_handle_DisableLiveEnvironment_OverridesLiveSource() async throws {
        let domain = uniqueDomain("DisableLive")
        let path = "/safety"
        let url = try await saveMock(domain: domain, path: path, body: "{\"from\":\"mock\"}")
        try writeModifier(domain: domain, id: "live-mod", path: path, bodyMutation: "res.body.patched = true;")
        try await core.setActiveModifiers(domain: domain, deviceId: "", activations: [
            .init(id: "live-mod", source: .live)
        ])

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let flags = MockServerFlags(mockSource: .onlyMock, scenario: nil, domain: domain, deviceId: "")

        let result = try await core.handle(request: request, flags: flags)

        XCTAssertEqual(mockURLSession.invokedDataCount, 0)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: result.body) as? [String: Any])
        XCTAssertEqual(json["from"] as? String, "mock")
        XCTAssertEqual(json["patched"] as? Bool, true)
    }

    func test_updateModifier_RenamePreservesAllDeviceActivation() async throws {
        let domain = uniqueDomain("Rename")
        try writeModifier(domain: domain, id: "old", path: "/cart")
        await activationStore.replaceActiveIds(domain: domain, deviceId: "A", ids: ["old"])
        await activationStore.replaceActiveIds(domain: domain, deviceId: "B", ids: ["old"])

        let model = ModifierModel(
            id: "new",
            path: "/cart",
            method: "GET",
            order: 1,
            transformerCode: "function transformer(req, chain) { return chain.proceed(req) }"
        )
        try await core.updateModifier(domain: domain, currentId: "old", model: model)

        let aIds = await activationStore.activeModifierIds(domain: domain, deviceId: "A")
        let bIds = await activationStore.activeModifierIds(domain: domain, deviceId: "B")
        XCTAssertEqual(aIds, Set(["new"]))
        XCTAssertEqual(bIds, Set(["new"]))
        let folder = tempWorkspaceURL.appendingPathComponent("Domains/\(domain)/Modifiers")
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("old.js").path()))
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("new.js").path()))
    }
}
