import XCTest
@testable import Modifiers

final class ModifierJSONPathTests: XCTestCase {
    private func offset(of needle: String, in text: String) -> Int {
        let ns = text as NSString
        let range = ns.range(of: needle)
        XCTAssertNotEqual(range.location, NSNotFound, "needle not found: \(needle)")
        return range.location + range.length / 2
    }

    func test_resolve_NestedArrayAndObject_ReturnsPathAndLiteral() {
        let json = """
        {
          "widgets" : [
            {
              "type" : "banner"
            }
          ]
        }
        """
        let resolved = ModifierJSONPath.resolve(json: json, utf16Offset: offset(of: "banner", in: json))
        XCTAssertEqual(resolved?.path, [.key("widgets"), .index(0), .key("type")])
        XCTAssertEqual(resolved?.literal, "\"banner\"")
    }

    func test_resolve_ClickingKey_ResolvesToValue() {
        let json = """
        {
          "count" : 42
        }
        """
        let resolved = ModifierJSONPath.resolve(json: json, utf16Offset: offset(of: "count", in: json))
        XCTAssertEqual(resolved?.path, [.key("count")])
        XCTAssertEqual(resolved?.literal, "42")
    }

    func test_resolve_BooleanValue() {
        let json = """
        {
          "flag" : true
        }
        """
        let resolved = ModifierJSONPath.resolve(json: json, utf16Offset: offset(of: "true", in: json))
        XCTAssertEqual(resolved?.path, [.key("flag")])
        XCTAssertEqual(resolved?.literal, "true")
    }
}

final class ModifierTransformerEditorTests: XCTestCase {
    func test_lhs_UsesBracketsForNonIdentifierKeys() {
        let lhs = ModifierTransformerEditor.lhs(for: [.key("widgets"), .index(0), .key("foo-bar")])
        XCTAssertEqual(lhs, "res.body.widgets[0][\"foo-bar\"]")
    }

    func test_applyAssignment_InsertsProceedAndAssignmentBeforeReturn() {
        let code = """
        function transformer(req, chain) {
          return res;
        }
        """
        let result = ModifierTransformerEditor.applyAssignment(
            path: [.key("widgets"), .index(0), .key("type")],
            valueLiteral: "\"banner\"",
            to: code
        )
        XCTAssertTrue(result.code.contains("var res = chain.proceed(req);"))
        XCTAssertTrue(result.code.contains("res.body.widgets[0].type = \"banner\";"))
        let assignRange = result.code.range(of: "res.body.widgets[0].type =")
        let returnRange = result.code.range(of: "return res;")
        XCTAssertNotNil(assignRange)
        XCTAssertNotNil(returnRange)
        if let a = assignRange, let r = returnRange {
            XCTAssertTrue(a.lowerBound < r.lowerBound)
        }
    }

    func test_applyAssignment_UpdatesExistingAssignmentRHS() {
        let code = """
        function transformer(req, chain) {
          var res = chain.proceed(req);
          res.body.type = "old";
          return res;
        }
        """
        let result = ModifierTransformerEditor.applyAssignment(
            path: [.key("type")],
            valueLiteral: "\"new\"",
            to: code
        )
        XCTAssertTrue(result.code.contains("res.body.type = \"new\";"))
        XCTAssertFalse(result.code.contains("\"old\""))
        let occurrences = result.code.components(separatedBy: "chain.proceed(req)").count - 1
        XCTAssertEqual(occurrences, 1)
    }

    func test_ensureProceed_KeepsExistingProceed() {
        let code = """
        function transformer(req, chain) {
          var res = chain.proceed(req);
          return res;
        }
        """
        XCTAssertEqual(ModifierTransformerEditor.ensureProceed(in: code), code)
    }

    func test_applyAssignment_InsertsBeforeReturnChainProceed() {
        let code = """
        function transformer(req, chain) {
          return chain.proceed(req)
        }
        """
        let result = ModifierTransformerEditor.applyAssignment(
            path: [.key("type")],
            valueLiteral: "\"banner\"",
            to: code
        )
        let expected = """
        function transformer(req, chain) {
          var res = chain.proceed(req);
          res.body.type = "banner";
          return res;
        }
        """
        XCTAssertEqual(result.code, expected)
    }

    func test_applyAssignment_InsertsBeforeReturnOnSingleLineTransformer() throws {
        let code = "function transformer(req, chain) { return chain.proceed(req) }"
        let result = ModifierTransformerEditor.applyAssignment(
            path: [.key("flag")],
            valueLiteral: "true",
            to: code
        )
        XCTAssertTrue(result.code.contains("res.body.flag = true;"))
        let assignRange = try XCTUnwrap(result.code.range(of: "res.body.flag = true;"))
        let returnRange = try XCTUnwrap(result.code.range(of: "return res;"))
        XCTAssertTrue(assignRange.lowerBound < returnRange.lowerBound)
        XCTAssertFalse(result.code.contains("return chain.proceed"))
    }

    func test_applyAssignment_SecondEditStaysBeforeReturn() {
        let first = ModifierTransformerEditor.applyAssignment(
            path: [.key("a")],
            valueLiteral: "1",
            to: """
            function transformer(req, chain) {
              return chain.proceed(req)
            }
            """
        )
        let second = ModifierTransformerEditor.applyAssignment(
            path: [.key("b")],
            valueLiteral: "2",
            to: first.code
        )
        let expected = """
        function transformer(req, chain) {
          var res = chain.proceed(req);
          res.body.a = 1;
          res.body.b = 2;
          return res;
        }
        """
        XCTAssertEqual(second.code, expected)
    }
}
