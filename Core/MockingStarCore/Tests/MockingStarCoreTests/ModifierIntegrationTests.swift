import CommonKit
import Foundation
import XCTest
@testable import MockingStarCore

/// End-to-end tests for `MockingStarCore.handle(request:flags:)` modifier wiring.
///
/// These exercise the real filesystem-backed stack (``ModifierStoreActor``, ``MockDeciderActor``,
/// `FileUrlBuilder`, `FileStructureHelper`) rather than mocks, since `ModifierStoreActor.shared`
/// always constructs `ModifierStore` with its default (real) dependencies. Each test points the
/// `workspaces` UserDefaults entry at a throwaway temp directory and uses a unique domain name so
/// tests don't collide with each other or with app state.
final class ModifierIntegrationTests: XCTestCase {
    private var tempWorkspaceURL: URL!
    private var previousWorkspacesData: Data?
    private var core: MockingStarCore!

    override func setUpWithError() throws {
        try super.setUpWithError()

        previousWorkspacesData = UserDefaults.standard.data(forKey: "workspaces")

        tempWorkspaceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ModifierIntegrationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempWorkspaceURL, withIntermediateDirectories: true)

        setWorkspace(path: tempWorkspaceURL.path())

        core = MockingStarCore()
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

    // MARK: - No modifiers on disk

    /// Empty/missing `Modifiers` folder must not change behaviour: `ModifierMatcher` returns no
    /// matches, so `handle` should fall straight through to `originalHandle`'s existing decision
    /// (mock not found + `.onlyMock` -> 404), rather than crashing or hanging.
    func test_handle_NoModifiers_FallsThroughToOriginalHandle_ReturnsNotFound() async throws {
        let domain = uniqueDomain("NoModifiers")

        var request = URLRequest(url: try XCTUnwrap(URL(string: "https://example.com/no-such-path")))
        request.httpMethod = "GET"

        let flags = MockServerFlags(mockSource: .onlyMock, scenario: nil, domain: domain, deviceId: "")

        let result = try await core.handle(request: request, flags: flags)

        XCTAssertEqual(result.status, 404)
    }

    // MARK: - Matched modifier

    /// Seeds a real mock file (so `originalHandle` resolves to a 200 JSON response) and a real
    /// enabled modifier `.js` file matching the request's path/method, then asserts the modifier
    /// chain patches the response body before it's returned from `handle`.
    func test_handle_MatchedModifier_PatchesMockResponseBody() async throws {
        let domain = uniqueDomain("Matched")
        let path = "/aboutus"
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
                             responseBody: "{\"value\":1}")
        try await FileSaverActor().saveFile(mock: mock, mockDomain: domain)

        let modifierCode = """
        var id = "patch-test";
        var path = "\(path)";
        var method = "GET";
        var scenario = null;
        var enabled = true;
        var priority = 0;
        var sampleMockRequestId = null;

        function transformer(req, chain) {
          var res = chain.proceed(req);
          res.body.injected = true;
          return res;
        }
        """
        let modifiersFolder = tempWorkspaceURL.appendingPathComponent("Domains/\(domain)/Modifiers", isDirectory: true)
        try FileManager.default.createDirectory(at: modifiersFolder, withIntermediateDirectories: true)
        try modifierCode.write(to: modifiersFolder.appendingPathComponent("patch-test.js"), atomically: true, encoding: .utf8)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let flags = MockServerFlags(mockSource: .onlyMock, scenario: nil, domain: domain, deviceId: "")

        let result = try await core.handle(request: request, flags: flags)

        XCTAssertEqual(result.status, 200)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: result.body) as? [String: Any])
        XCTAssertEqual(json["injected"] as? Bool, true)
        XCTAssertEqual(json["value"] as? Int, 1)
    }

    // MARK: - Disabled modifier

    /// A modifier present on disk but `enabled = false` must not be picked up by `ModifierMatcher`,
    /// so `handle` should behave exactly like the no-modifiers case for the same request.
    func test_handle_DisabledModifier_IsIgnored_ReturnsUnmodifiedMock() async throws {
        let domain = uniqueDomain("Disabled")
        let path = "/aboutus"
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
                             responseBody: "{\"value\":1}")
        try await FileSaverActor().saveFile(mock: mock, mockDomain: domain)

        let modifierCode = """
        var id = "patch-test";
        var path = "\(path)";
        var method = "GET";
        var scenario = null;
        var enabled = false;
        var priority = 0;
        var sampleMockRequestId = null;

        function transformer(req, chain) {
          var res = chain.proceed(req);
          res.body.injected = true;
          return res;
        }
        """
        let modifiersFolder = tempWorkspaceURL.appendingPathComponent("Domains/\(domain)/Modifiers", isDirectory: true)
        try FileManager.default.createDirectory(at: modifiersFolder, withIntermediateDirectories: true)
        try modifierCode.write(to: modifiersFolder.appendingPathComponent("patch-test.js"), atomically: true, encoding: .utf8)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let flags = MockServerFlags(mockSource: .onlyMock, scenario: nil, domain: domain, deviceId: "")

        let result = try await core.handle(request: request, flags: flags)

        XCTAssertEqual(result.status, 200)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: result.body) as? [String: Any])
        XCTAssertNil(json["injected"])
        XCTAssertEqual(json["value"] as? Int, 1)
    }
}
