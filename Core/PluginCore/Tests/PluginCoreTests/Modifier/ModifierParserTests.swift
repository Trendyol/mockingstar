import XCTest
@testable import PluginCore
import CommonKit

final class ModifierParserTests: XCTestCase {
    private let parser = ModifierParser()

    private let legacyJS = """
    var id = "embedded-id"
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

    private let canonicalJS = """
    // metadata
    var path = "/users/1"
    var method = "GET"
    var scenario = null
    var order = 3
    var sampleMockRequestId = null

    function transformer(req, chain) {
      return chain.proceed(req)
    }
    """

    func test_parse_UsesFilenameId_IgnoresEmbeddedId() throws {
        let model = try parser.parse(jsCode: legacyJS, filenameId: "file-name")
        XCTAssertEqual(model.id, "file-name")
        XCTAssertEqual(model.path, "/users/1")
        XCTAssertEqual(model.method, "GET")
        XCTAssertNil(model.scenario)
        XCTAssertFalse(model.enabled)
        XCTAssertEqual(model.order, 2)
        XCTAssertNil(model.sampleMockRequestId)
        XCTAssertTrue(model.transformerCode.hasPrefix("function transformer"))
        XCTAssertFalse(model.transformerCode.contains("var id"))
    }

    func test_parse_CanonicalOrder_ReadsOrder() throws {
        let model = try parser.parse(jsCode: canonicalJS, filenameId: "canonical")
        XCTAssertEqual(model.id, "canonical")
        XCTAssertEqual(model.order, 3)
    }

    func test_parse_MissingPath_Throws() {
        let js = "var method = \"GET\"\nfunction transformer(req, chain) { return chain.proceed(req) }\n"
        XCTAssertThrowsError(try parser.parse(jsCode: js, filenameId: "x")) { error in
            guard case ModifierParseError.missingRequiredField("path") = error else {
                return XCTFail("unexpected \(error)")
            }
        }
    }

    func test_parse_MissingMethod_Throws() {
        let js = "var path = \"/x\"\nfunction transformer(req, chain) { return chain.proceed(req) }\n"
        XCTAssertThrowsError(try parser.parse(jsCode: js, filenameId: "x")) { error in
            guard case ModifierParseError.missingRequiredField("method") = error else {
                return XCTFail("unexpected \(error)")
            }
        }
    }

    func test_parse_SyntaxError_Throws() {
        XCTAssertThrowsError(try parser.parse(jsCode: "var path = ", filenameId: "x")) { error in
            guard case ModifierParseError.syntaxError = error else {
                return XCTFail("unexpected \(error)")
            }
        }
    }

    func test_parse_InvalidFilenameId_Throws() {
        XCTAssertThrowsError(try parser.parse(jsCode: canonicalJS, filenameId: "../evil")) { error in
            guard case ModifierParseError.invalidModifierId = error else {
                return XCTFail("unexpected \(error)")
            }
        }
    }

    func test_serialize_OmitsIdEnabledPriority() {
        let model = ModifierModel(id: "discount",
                                  path: "/cart",
                                  method: "GET",
                                  scenario: "promo",
                                  enabled: true,
                                  order: 2,
                                  sampleMockRequestId: "mock-1",
                                  transformerCode: "function transformer(req, chain) { return chain.proceed(req) }")
        let serialized = parser.serialize(model)
        XCTAssertFalse(serialized.contains("var id"))
        XCTAssertFalse(serialized.contains("enabled"))
        XCTAssertFalse(serialized.contains("priority"))
        XCTAssertTrue(serialized.contains("var order = 2"))
        XCTAssertTrue(serialized.contains("var path = \"/cart\""))
        XCTAssertTrue(serialized.contains("function transformer"))
    }

    func test_serialize_RoundTrip_PreservesFields() throws {
        let original = ModifierModel(id: "latency",
                                     path: "/users",
                                     method: "POST",
                                     scenario: nil,
                                     enabled: false,
                                     order: 4,
                                     sampleMockRequestId: nil,
                                     transformerCode: "function transformer(req, chain) {\n  return chain.proceed(req)\n}")
        let parsed = try parser.parse(jsCode: parser.serialize(original), filenameId: "latency")
        XCTAssertEqual(parsed.id, "latency")
        XCTAssertEqual(parsed.path, "/users")
        XCTAssertEqual(parsed.method, "POST")
        XCTAssertNil(parsed.scenario)
        XCTAssertEqual(parsed.order, 4)
        XCTAssertTrue(parsed.transformerCode.contains("function transformer"))
    }

    func test_parse_DefaultOrderIsOne() throws {
        let js = """
        var path = "/x"
        var method = "GET"
        function transformer(req, chain) { return chain.proceed(req) }
        """
        let model = try parser.parse(jsCode: js, filenameId: "default-order")
        XCTAssertEqual(model.order, 1)
    }
}
