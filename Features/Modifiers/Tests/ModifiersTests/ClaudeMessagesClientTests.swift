import CommonKit
import CommonKitTestSupport
import Foundation
import XCTest
@testable import Modifiers

final class ClaudeMessagesClientTests: XCTestCase {
    func test_complete_SendsBearerChatCompletionsAndReturnsText() async throws {
        let session = MockURLSession()
        let responseBody = """
        {"choices":[{"message":{"role":"assistant","content":"function transformer(req, chain) { return chain.proceed(req); }"}}]}
        """
        session.stubbedDataResult = (
            Data(responseBody.utf8),
            HTTPURLResponse(
                url: ClaudeMessagesClient.defaultEndpoint,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
        )

        let client = ClaudeMessagesClient(urlSession: session)
        let text = try await client.complete(
            apiKey: "sk-company-test",
            system: "sys",
            user: "user prompt"
        )

        XCTAssertTrue(text.contains("function transformer"))
        let request = try XCTUnwrap(session.invokedDataParameters?.request)
        XCTAssertEqual(request.url, ClaudeMessagesClient.defaultEndpoint)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer sk-company-test")
        XCTAssertNil(request.value(forHTTPHeaderField: "x-api-key"))
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, ClaudeMessagesClient.defaultModel)
        let messages = try XCTUnwrap(json["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0]["role"] as? String, "system")
        XCTAssertEqual(messages[0]["content"] as? String, "sys")
        XCTAssertEqual(messages[1]["role"] as? String, "user")
        XCTAssertEqual(messages[1]["content"] as? String, "user prompt")
    }

    func test_complete_MapsStringErrorBody() async {
        let session = MockURLSession()
        session.stubbedDataResult = (
            Data("{\"error\":\"Invalid model name\"}".utf8),
            HTTPURLResponse(
                url: ClaudeMessagesClient.defaultEndpoint,
                statusCode: 400,
                httpVersion: nil,
                headerFields: nil
            )!
        )

        let client = ClaudeMessagesClient(urlSession: session)
        do {
            _ = try await client.complete(apiKey: "bad", system: "s", user: "u")
            XCTFail("expected error")
        } catch let error as ClaudeMessagesError {
            XCTAssertEqual(
                error,
                .invalidResponse(status: 400, message: "Invalid model name")
            )
        } catch {
            XCTFail("unexpected \(error)")
        }
    }
}
