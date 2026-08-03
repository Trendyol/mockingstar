import AnyCodable
import XCTest
@testable import PluginCore

final class QuickJSTests: XCTestCase {
    func testEvaluateAndCallJSON() throws {
        let context = try PluginJavaScriptContext()
        try context.evaluate("function greet(value) { return { message: 'Hello ' + value, count: 2 }; }")

        let argument = try context.encode("QuickJS")
        let result = try context.call(function: "greet", arguments: [argument])
        let decoded = try context.decode([String: AnyCodableModel].self, from: result)

        XCTAssertEqual(decoded["message"], try AnyCodableModel(jsonText: "\"Hello QuickJS\""))
        XCTAssertEqual(decoded["count"], try AnyCodableModel(jsonText: "2"))
    }

    func testGlobalJSONAndContextReset() throws {
        let context = try PluginJavaScriptContext()
        try context.setGlobalJSON(Data(#"{"value":"before-reset"}"#.utf8), for: "config")
        XCTAssertEqual(
            try context.getGlobalJSON(for: "config"),
            Data(#"{"value":"before-reset"}"#.utf8)
        )

        try context.reset()
        XCTAssertThrowsError(try context.getGlobalJSON(for: "config"))
    }

    func testPromiseResolveAndReject() async throws {
        let context = try PluginJavaScriptContext()
        try context.evaluate("async function resolveValue() { return { value: 42 }; } async function rejectValue() { throw new Error('rejected'); }")

        let resolved = try await context.callAsync(function: "resolveValue", arguments: [])
        XCTAssertEqual(resolved, Data(#"{"value":42}"#.utf8))
        await XCTAssertThrowsErrorAsync(try await context.callAsync(function: "rejectValue", arguments: []))
    }

    func testSyntaxErrorAndMissingFunction() throws {
        let context = try PluginJavaScriptContext()
        XCTAssertThrowsError(try context.evaluate("function invalid("))
        XCTAssertThrowsError(try context.call(function: "missing", arguments: []))
    }

    func testInfiniteLoopIsInterrupted() throws {
        let context = try PluginJavaScriptContext(timeout: .milliseconds(50))
        try context.evaluate("function loop() { while (true) {} }")
        XCTAssertThrowsError(try context.call(function: "loop", arguments: []))
    }

    func testInfinitePromiseJobIsInterrupted() async throws {
        let context = try PluginJavaScriptContext(timeout: .milliseconds(50))
        try context.evaluate("function promiseLoop() { return Promise.resolve().then(() => { while (true) {} }); }")
        await XCTAssertThrowsErrorAsync(try await context.callAsync(function: "promiseLoop", arguments: []))
    }
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected an error", file: file, line: line)
    } catch {
        XCTAssertTrue(true)
    }
}
