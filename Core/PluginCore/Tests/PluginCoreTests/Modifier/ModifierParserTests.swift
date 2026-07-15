import XCTest
@testable import PluginCore
import CommonKit

final class ModifierParserTests: XCTestCase {
    private let parser = ModifierParser()

    private let validJS = """
    var id = "test-modifier"
    var path = "/users/1"
    var method = "GET"
    var scenario = null
    var enabled = true
    var priority = 2
    var sampleMockRequestId = null

    function transformer(req, chain) {
      return chain.proceed(req)
    }
    """

    func test_parse_ValidJS_ReadsAllFields() throws {
        let model = try parser.parse(jsCode: validJS)
        XCTAssertEqual(model.id, "test-modifier")
        XCTAssertEqual(model.path, "/users/1")
        XCTAssertEqual(model.method, "GET")
        XCTAssertNil(model.scenario)
        XCTAssertTrue(model.enabled)
        XCTAssertEqual(model.priority, 2)
        XCTAssertNil(model.sampleMockRequestId)
        XCTAssertTrue(model.transformerCode.contains("function transformer"))
    }

    func test_parse_MissingId_Throws() {
        let js = "var path = \"/x\"\nvar method = \"GET\"\n"
        XCTAssertThrowsError(try parser.parse(jsCode: js)) { error in
            guard case ModifierParseError.missingRequiredField("id") = error else {
                return XCTFail("unexpected \(error)")
            }
        }
    }

    func test_parse_SyntaxError_Throws() {
        XCTAssertThrowsError(try parser.parse(jsCode: "var id = ")) { error in
            guard case ModifierParseError.syntaxError = error else {
                return XCTFail("unexpected \(error)")
            }
        }
    }
}
