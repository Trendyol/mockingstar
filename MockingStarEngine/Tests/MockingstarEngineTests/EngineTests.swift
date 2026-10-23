import Foundation
import XCTest
import MockingstarEngine
import MockingStarCore

final class EngineTests: XCTestCase {
    func testHostCanUseWorkspaceCommandsAndStructuredErrors() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = MockWorkspace(root: root)
        try workspace.initialize()

        let created = try await MockingstarEngine.execute(["domain", "create", "--workspace", root.path, "--domain", "Dev"])
        XCTAssertNotNil(created)
        let result = try await MockingstarEngine.execute(["domain", "list", "--workspace", root.path])
        let json = try JSONSerialization.data(withJSONObject: result as Any)
        XCTAssertTrue(String(decoding: json, as: UTF8.self).contains("Dev"))

        do {
            _ = try await MockingstarEngine.execute(["mock", "show", "missing", "--workspace", root.path, "--domain", "Dev"])
            XCTFail("Missing mock must return a structured error")
        } catch let error as MockingstarEngineError {
            XCTAssertEqual(error.code, "not_found")
            XCTAssertFalse(error.message.isEmpty)
        }
    }

    func testInvalidCommandCannotCrashEmbeddedHost() async throws {
        do {
            _ = try await MockingstarEngine.execute([])
            XCTFail("Empty command must fail validation")
        } catch let error as MockingstarEngineError {
            XCTAssertEqual(error.code, "invalid_arguments")
        }
        XCTAssertEqual(MockingstarEngine.runtimeArgument, "--mockingstar-runtime")
    }
}
