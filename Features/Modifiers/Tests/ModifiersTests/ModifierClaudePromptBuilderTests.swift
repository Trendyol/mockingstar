import XCTest
@testable import Modifiers

final class ModifierResponseSchemaSummarizerTests: XCTestCase {
    func test_summarize_ReplacesValuesWithTypes() {
        let sample = """
        {
          "count": 571100,
          "ok": true,
          "name": "Elbise",
          "widgets": [
            {
              "id": 1,
              "content": { "brandName": "X", "ratingInfo": { "ratingCount": 10 } }
            },
            {
              "id": 2,
              "content": { "brandName": "Y", "extra": null }
            }
          ]
        }
        """
        let schema = ModifierResponseSchemaSummarizer.summarize(sample)

        XCTAssertTrue(schema.contains("\"count\" : \"number\"") || schema.contains("\"count\": \"number\""))
        XCTAssertTrue(schema.contains("\"ok\" : \"boolean\"") || schema.contains("\"ok\": \"boolean\""))
        XCTAssertTrue(schema.contains("\"name\" : \"string\"") || schema.contains("\"name\": \"string\""))
        XCTAssertTrue(schema.contains("brandName"))
        XCTAssertTrue(schema.contains("ratingCount") || schema.contains("extra"))
        XCTAssertFalse(schema.contains("571100"))
        XCTAssertFalse(schema.contains("Elbise"))
        XCTAssertFalse(schema.contains("\"X\""))
    }

    func test_summarize_NonJSON() {
        let schema = ModifierResponseSchemaSummarizer.summarize("not-json-at-all")
        XCTAssertTrue(schema.contains("non-JSON"))
        XCTAssertFalse(schema.contains("not-json-at-all"))
    }
}

final class ModifierClaudePromptBuilderTests: XCTestCase {
    func test_buildUserPrompt_IncludesIntentMetadataJsAndSchemaNotValues() {
        let prompt = ModifierClaudePromptBuilder.buildUserPrompt(
            userIntent: "brandName alanını MockingStar yap",
            modifierId: "sampleMock",
            path: "/search/widgets",
            method: "GET",
            scenario: "cosmetics",
            currentJavaScript: "function transformer(req, chain) { return chain.proceed(req) }",
            sampleResponse: "{\"widgets\":[{\"brandName\":\"Nike\",\"count\":3}],\"title\":\"sale\"}"
        )

        XCTAssertTrue(prompt.contains("brandName alanını MockingStar yap"))
        XCTAssertTrue(prompt.contains("sampleMock"))
        XCTAssertTrue(prompt.contains("/search/widgets"))
        XCTAssertTrue(prompt.contains("GET"))
        XCTAssertTrue(prompt.contains("cosmetics"))
        XCTAssertTrue(prompt.contains("function transformer(req, chain)"))
        XCTAssertTrue(prompt.contains("Current transformer (EDIT THIS"))
        XCTAssertTrue(prompt.contains("return chain.proceed(req)"))
        XCTAssertTrue(prompt.contains("incremental"))
        XCTAssertTrue(prompt.contains("Coding style (required)"))
        XCTAssertTrue(prompt.contains("changeProductName"))
        XCTAssertTrue(prompt.contains("Array.isArray"))
        XCTAssertTrue(prompt.contains("Sample response schema"))
        XCTAssertTrue(prompt.contains("brandName"))
        XCTAssertTrue(prompt.contains("\"string\"") || prompt.contains("string"))
        XCTAssertFalse(prompt.contains("Nike"))
        XCTAssertFalse(prompt.contains("\"sale\""))
        XCTAssertTrue(prompt.contains("Reply with ONLY one"))
        XCTAssertTrue(ModifierClaudePromptBuilder.systemPrompt.contains("Preserve all existing working behavior"))
        XCTAssertTrue(ModifierClaudePromptBuilder.systemPrompt.contains("extract reusable helpers"))
    }

    func test_buildUserPrompt_HandlesMissingSample() {
        let prompt = ModifierClaudePromptBuilder.buildUserPrompt(
            userIntent: "",
            modifierId: "id",
            path: "/",
            method: "GET",
            scenario: "",
            currentJavaScript: "",
            sampleResponse: nil
        )

        XCTAssertTrue(prompt.contains("No preview response yet"))
    }
}

final class ModifierClaudeResponseParserTests: XCTestCase {
    func test_extract_FromJavaScriptFence() throws {
        let text = """
        Sure, here you go:
        ```javascript
        function transformer(req, chain) {
          var res = chain.proceed(req);
          res.body.ok = true;
          return res;
        }
        ```
        """
        let js = try ModifierClaudeResponseParser.extractTransformerJavaScript(from: text)
        XCTAssertTrue(js.contains("function transformer(req, chain)"))
        XCTAssertTrue(js.contains("res.body.ok = true"))
        XCTAssertFalse(js.contains("```"))
    }

    func test_extract_BareFunction() throws {
        let text = """
        function transformer(req, chain) {
          return chain.proceed(req);
        }
        """
        let js = try ModifierClaudeResponseParser.extractTransformerJavaScript(from: text)
        XCTAssertEqual(
            js,
            """
            function transformer(req, chain) {
              return chain.proceed(req);
            }
            """
        )
    }

    func test_extract_GarbageThrows() {
        XCTAssertThrowsError(
            try ModifierClaudeResponseParser.extractTransformerJavaScript(from: "no code here")
        ) { error in
            XCTAssertEqual(
                error as? ModifierClaudeResponseParserError,
                .noTransformerFound
            )
        }
    }
}
