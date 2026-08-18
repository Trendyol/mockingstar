import Foundation

enum ModifierClaudePromptBuilder {
    static let systemPrompt = """
    You are editing an existing MockingStar JavaScript response modifier.
    Start from the Current transformer code below. Apply ONLY the user's requested change.
    Preserve all existing working behavior that the user did not ask to change.
    Prefer small, incremental edits over rewriting from scratch.
    Write clear, functional ES5-style code: extract reusable helpers, guard with null/
    typeof/Array.isArray checks, mutate objects in place, keep `transformer` readable.
    Reply with ONLY one fenced JavaScript code block that contains the complete updated
    file: `function transformer(req, chain) { ... }` plus any helper `function`s it needs.
    No TypeScript, no imports, no async/await, no arrow functions required.
    Do not include explanations outside the code fence.
    The sample below is a SCHEMA only (types/structure, no real values). Infer field paths from it.
    """

    static func buildUserPrompt(
        userIntent: String,
        modifierId: String,
        path: String,
        method: String,
        scenario: String,
        currentJavaScript: String,
        sampleResponse: String?
    ) -> String {
        let intent = userIntent.trimmingCharacters(in: .whitespacesAndNewlines)
        let scenarioLine = scenario.isEmpty ? "(none)" : scenario
        let js = currentJavaScript.trimmingCharacters(in: .whitespacesAndNewlines)
        let sample = schemaSample(sampleResponse)
        let currentBlock = js.isEmpty
            ? "function transformer(req, chain) {\n  var res = chain.proceed(req);\n\n  return res;\n}"
            : js

        return """
        ## What I want (incremental change)
        \(intent.isEmpty ? "(No special instruction. Keep the current transformer and only make a tiny safe improvement if needed.)" : intent)

        Important:
        - The Current transformer below is the source of truth.
        - Update it to satisfy the request above; do NOT discard unrelated existing logic.
        - Keep the same overall structure when possible so the user can iterate step by step.

        ## Modifier metadata
        - id: \(modifierId)
        - path: \(path)
        - method: \(method)
        - scenario: \(scenarioLine)

        ## Coding style (required)
        Prefer a functional, defensive style like this pattern:

        ```javascript
        function transformer(req, chain) {
          var res = chain.proceed(req);

          if (res && res.body) {
            if (res.body.widgets && Array.isArray(res.body.widgets)) {
              for (var i = 0; i < res.body.widgets.length; i++) {
                var widget = res.body.widgets[i];
                if (widget && widget.widgetProducts && Array.isArray(widget.widgetProducts)) {
                  for (var j = 0; j < widget.widgetProducts.length; j++) {
                    changeProductName(widget.widgetProducts[j]);
                  }
                }
              }
            }

            if (res.body.storeAds && Array.isArray(res.body.storeAds)) {
              for (var k = 0; k < res.body.storeAds.length; k++) {
                var ad = res.body.storeAds[k];
                if (ad && ad.contents && Array.isArray(ad.contents)) {
                  for (var m = 0; m < ad.contents.length; m++) {
                    changeProductName(ad.contents[m]);
                  }
                }
              }
            }
          }

          return res;
        }

        function changeProductName(obj) {
          if (!obj || typeof obj !== "object") return;

          if (typeof obj.name === "string") {
            obj.name = "B";
          }
          if (obj.content && typeof obj.content === "object") {
            if (typeof obj.content.name === "string") {
              obj.content.name = "B";
            }
            if (typeof obj.content.productName === "string") {
              obj.content.productName = "B";
            }
            if (typeof obj.content.title === "string") {
              obj.content.title = "B";
            }
          }
          if (typeof obj.productName === "string") {
            obj.productName = "B";
          }
          if (typeof obj.title === "string") {
            obj.title = "B";
          }

          if (obj.variants && Array.isArray(obj.variants)) {
            for (var i = 0; i < obj.variants.length; i++) {
              changeProductName(obj.variants[i]);
            }
          }
        }
        ```

        Style rules:
        - Keep `transformer(req, chain)` as the entry: `var res = chain.proceed(req);` then mutate `res`, then `return res;`.
        - Extract repeated mutations into named helper `function`s (function declarations are fine after `transformer`).
        - Guard every nested access with `if (x && ...)` / `typeof x === "string"` / `Array.isArray(x)`.
        - Prefer in-place mutation of objects/arrays from `res.body` over rebuilding huge payloads.
        - Reuse helpers across similar collections (e.g. widgets + storeAds) instead of duplicating loops.
        - Do not invent fields that are not in the schema or the current code unless the user asks.

        ## Current transformer (EDIT THIS — preserve working parts)
        ```javascript
        \(currentBlock)
        ```

        ## Sample response schema (values stripped)
        \(sample)

        Reply with ONLY one ```javascript fenced block containing the complete updated `transformer` plus helpers.
        """
    }

    private static func schemaSample(_ sampleResponse: String?) -> String {
        guard let sampleResponse else {
            return "(No preview response yet. Write a generic transformer or ask for clarification.)"
        }
        let trimmed = sampleResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "(Preview response is empty.)"
        }
        let schema = ModifierResponseSchemaSummarizer.summarize(trimmed)
        return """
        ```json
        \(schema)
        ```
        """
    }
}
