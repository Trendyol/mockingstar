//
//  PartialMockDeciderTests.swift
//
//
//  Created for Trendyol Marketing Object Testing
//

import XCTest
import CommonKit
import CommonKitTestSupport
@testable import MockingStarCore

final class PartialMockDeciderTests: XCTestCase {
    private var sut: PartialMockDecider!
    private var fileUrlBuilder: MockFileUrlBuilder!
    private var configs: MockConfigurations!

    override func setUpWithError() throws {
        try super.setUpWithError()

        fileUrlBuilder = .init()
        configs = .init()
        configs.stubbedConfigs = ConfigModel()
        fileUrlBuilder.stubbedIsPathMatchedResult = true

        sut = PartialMockDecider(fileURLBuilder: fileUrlBuilder, configs: configs)
    }

    // MARK: - Helpers

    private func makePartialMock(
        deviceId: String = "device1",
        url: String = "/api/test",
        method: String = "GET",
        mockDomain: String = "TestDomain",
        modifications: [PartialMockModification] = []
    ) -> PartialMockModel {
        return decodeJSON("""
        {
            "deviceId": "\(deviceId)",
            "url": "\(url)",
            "method": "\(method)",
            "mockDomain": "\(mockDomain)",
            "modifications": \(modificationsJSON(modifications))
        }
        """)
    }

    private func modificationsJSON(_ modifications: [PartialMockModification]) -> String {
        guard !modifications.isEmpty else { return "[]" }
        let data = try! JSONEncoder().encode(modifications)
        return String(data: data, encoding: .utf8)!
    }

    private func makeModification(
        path: String,
        operations: [PartialMockOperation]
    ) -> PartialMockModification {
        return decodeJSON("""
        {
            "path": \(jsonString(path)),
            "operations": \(operationsJSON(operations))
        }
        """)
    }

    private func operationsJSON(_ operations: [PartialMockOperation]) -> String {
        let data = try! JSONEncoder().encode(operations)
        return String(data: data, encoding: .utf8)!
    }

    private func makeOperation(
        type: PartialMockOperationType,
        key: String,
        value: Any? = nil,
        from: String? = nil
    ) -> PartialMockOperation {
        var json: [String: Any] = [
            "type": type.rawValue,
            "key": key
        ]
        if let value = value {
            json["value"] = value
        }
        if let from = from {
            json["from"] = from
        }
        let data = try! JSONSerialization.data(withJSONObject: json)
        return try! JSONDecoder().decode(PartialMockOperation.self, from: data)
    }

    private func decodeJSON<T: Decodable>(_ jsonString: String) -> T {
        let data = jsonString.data(using: .utf8)!
        return try! JSONDecoder().decode(T.self, from: data)
    }

    private func jsonString(_ s: String) -> String {
        // Wrap in array to make it valid JSON, then strip the brackets
        let data = try! JSONSerialization.data(withJSONObject: [s])
        let str = String(data: data, encoding: .utf8)!
        // str is like ["value"], extract the quoted string
        let start = str.index(after: str.startIndex)
        let end = str.index(before: str.endIndex)
        return String(str[start..<end])
    }

    private func makeRequest(url: String = "https://api.test.com/api/test", method: String = "GET") -> URLRequest {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = method
        return request
    }

    private func makeContext(
        domain: String = "test.com",
        method: String = "GET",
        requestPath: String = "/api/test"
    ) -> RequestContext {
        return RequestContext(domain: domain, method: method, requestPath: requestPath)
    }

    private func jsonData(_ object: Any) -> Data {
        return try! JSONSerialization.data(withJSONObject: object, options: .sortedKeys)
    }

    private func parseJSON(_ data: Data) -> Any {
        return try! JSONSerialization.jsonObject(with: data)
    }

    // MARK: - 1. addPartialMock / removePartialMocks

    func test_addPartialMock_addsToList() async {
        let mock = makePartialMock()
        await sut.addPartialMock(mock)

        let result = await sut.findMatchingPartialMocks(request: makeRequest(), deviceId: "device1")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.url, "/api/test")
    }

    func test_addPartialMock_replacesDuplicate() async {
        let mock1 = makePartialMock(deviceId: "device1", url: "/api/test", method: "GET")
        let mock2 = makePartialMock(deviceId: "device1", url: "/api/test", method: "GET")
        await sut.addPartialMock(mock1)
        await sut.addPartialMock(mock2)

        let result = await sut.findMatchingPartialMocks(request: makeRequest(), deviceId: "device1")
        XCTAssertEqual(result.count, 1, "Duplicate should replace, not accumulate")
    }

    func test_removePartialMocks_removesForDevice() async {
        let mock = makePartialMock(deviceId: "device1")
        await sut.addPartialMock(mock)
        await sut.removePartialMocks(deviceId: "device1")

        let result = await sut.findMatchingPartialMocks(request: makeRequest(), deviceId: "device1")
        XCTAssertTrue(result.isEmpty)
    }

    func test_removePartialMocks_doesNotAffectOtherDevices() async {
        let mock1 = makePartialMock(deviceId: "device1")
        let mock2 = makePartialMock(deviceId: "device2")
        await sut.addPartialMock(mock1)
        await sut.addPartialMock(mock2)
        await sut.removePartialMocks(deviceId: "device1")

        let result1 = await sut.findMatchingPartialMocks(request: makeRequest(), deviceId: "device1")
        let result2 = await sut.findMatchingPartialMocks(request: makeRequest(), deviceId: "device2")
        XCTAssertTrue(result1.isEmpty)
        XCTAssertEqual(result2.count, 1)
    }

    // MARK: - 2. findMatchingPartialMocks — wildcard & path matching

    func test_findMatching_exactUrlAndMethod() async {
        let mock = makePartialMock(url: "/api/test", method: "GET")
        await sut.addPartialMock(mock)

        let result = await sut.findMatchingPartialMocks(request: makeRequest(), deviceId: "device1")
        XCTAssertEqual(result.count, 1)
    }

    func test_findMatching_wildcardMethod() async {
        let mock = makePartialMock(method: "*")
        await sut.addPartialMock(mock)

        let resultGET = await sut.findMatchingPartialMocks(request: makeRequest(method: "GET"), deviceId: "device1")
        let resultPOST = await sut.findMatchingPartialMocks(request: makeRequest(method: "POST"), deviceId: "device1")
        XCTAssertEqual(resultGET.count, 1)
        XCTAssertEqual(resultPOST.count, 1)
    }

    func test_findMatching_wildcardUrl() async {
        let mock = makePartialMock(url: "*", method: "GET")
        await sut.addPartialMock(mock)

        let result = await sut.findMatchingPartialMocks(
            request: makeRequest(url: "https://api.test.com/some/other/path"),
            deviceId: "device1"
        )
        XCTAssertEqual(result.count, 1)
    }

    func test_findMatching_wildcardBoth() async {
        let mock = makePartialMock(url: "*", method: "*")
        await sut.addPartialMock(mock)

        let result = await sut.findMatchingPartialMocks(
            request: makeRequest(url: "https://other.com/anything", method: "DELETE"),
            deviceId: "device1"
        )
        XCTAssertEqual(result.count, 1)
    }

    func test_findMatching_deviceMismatch_returnsEmpty() async {
        let mock = makePartialMock(deviceId: "device1")
        await sut.addPartialMock(mock)

        let result = await sut.findMatchingPartialMocks(request: makeRequest(), deviceId: "device999")
        XCTAssertTrue(result.isEmpty)
    }

    func test_findMatching_methodMismatch_returnsEmpty() async {
        let mock = makePartialMock(method: "POST")
        await sut.addPartialMock(mock)

        let result = await sut.findMatchingPartialMocks(request: makeRequest(method: "GET"), deviceId: "device1")
        XCTAssertTrue(result.isEmpty)
    }

    func test_findMatching_pathMismatch_returnsEmpty() async {
        fileUrlBuilder.stubbedIsPathMatchedResult = false
        let mock = makePartialMock(url: "/api/other", method: "GET")
        await sut.addPartialMock(mock)

        let result = await sut.findMatchingPartialMocks(request: makeRequest(), deviceId: "device1")
        XCTAssertTrue(result.isEmpty)
    }

    func test_findMatching_emptyList_returnsEmpty() async {
        let result = await sut.findMatchingPartialMocks(request: makeRequest(), deviceId: "device1")
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - 3. applyModifications — RFC 6902 operations

    func test_add_insertsNewField() async {
        let data = jsonData(["name": "Alice"])
        let op = makeOperation(type: .add, key: "age", value: 30)
        let mod = makeModification(path: "$", operations: [op])
        let context = makeContext()

        let result = await sut.applyModifications(to: data, modifications: [mod], context: context)
        let parsed = parseJSON(result) as! [String: Any]
        XCTAssertEqual(parsed["age"] as? Int, 30)
        XCTAssertEqual(parsed["name"] as? String, "Alice")
    }

    func test_add_replacesExistingField() async {
        let data = jsonData(["name": "Alice"])
        let op = makeOperation(type: .add, key: "name", value: "Bob")
        let mod = makeModification(path: "$", operations: [op])
        let context = makeContext()

        let result = await sut.applyModifications(to: data, modifications: [mod], context: context)
        let parsed = parseJSON(result) as! [String: Any]
        XCTAssertEqual(parsed["name"] as? String, "Bob")
    }

    func test_remove_deletesField() async {
        let data = jsonData(["name": "Alice", "age": 30])
        let op = makeOperation(type: .remove, key: "age")
        let mod = makeModification(path: "$", operations: [op])
        let context = makeContext()

        let result = await sut.applyModifications(to: data, modifications: [mod], context: context)
        let parsed = parseJSON(result) as! [String: Any]
        XCTAssertNil(parsed["age"])
        XCTAssertEqual(parsed["name"] as? String, "Alice")
    }

    func test_remove_nonexistent_graceful() async {
        let original = jsonData(["name": "Alice"])
        let op = makeOperation(type: .remove, key: "nonexistent")
        let mod = makeModification(path: "$", operations: [op])
        let context = makeContext()

        let result = await sut.applyModifications(to: original, modifications: [mod], context: context)
        let parsed = parseJSON(result) as! [String: Any]
        XCTAssertEqual(parsed["name"] as? String, "Alice")
    }

    func test_replace_updatesExisting() async {
        let data = jsonData(["name": "Alice", "age": 30])
        let op = makeOperation(type: .replace, key: "age", value: 31)
        let mod = makeModification(path: "$", operations: [op])
        let context = makeContext()

        let result = await sut.applyModifications(to: data, modifications: [mod], context: context)
        let parsed = parseJSON(result) as! [String: Any]
        XCTAssertEqual(parsed["age"] as? Int, 31)
    }

    func test_replace_nonexistent_graceful() async {
        let original = jsonData(["name": "Alice"])
        let op = makeOperation(type: .replace, key: "missing", value: "value")
        let mod = makeModification(path: "$", operations: [op])
        let context = makeContext()

        let result = await sut.applyModifications(to: original, modifications: [mod], context: context)
        let parsed = parseJSON(result) as! [String: Any]
        XCTAssertEqual(parsed["name"] as? String, "Alice")
    }

    func test_move_movesField() async {
        // Implementation note: PartialMockDecider passes .move(fromPointer, childPointer)
        // to DynamicJSON, which treats args as .move(destination, source).
        // So `from` is the destination and `key` is the source.
        let data = jsonData(["container": ["sourceKey": "value", "other": 1]])
        let op = makeOperation(type: .move, key: "sourceKey", from: "destKey")
        let mod = makeModification(path: "$.container", operations: [op])
        let context = makeContext()

        let result = await sut.applyModifications(to: data, modifications: [mod], context: context)
        let parsed = parseJSON(result) as! [String: Any]
        let container = parsed["container"] as! [String: Any]
        XCTAssertEqual(container["destKey"] as? String, "value")
        XCTAssertNil(container["sourceKey"])
    }

    func test_copy_copiesField() async {
        // Implementation note: PartialMockDecider passes .copy(fromPointer, childPointer)
        // to DynamicJSON, which treats args as .copy(destination, source).
        // So `from` is the destination and `key` is the source.
        let data = jsonData(["container": ["source": "value", "other": 1]])
        let op = makeOperation(type: .copy, key: "source", from: "target")
        let mod = makeModification(path: "$.container", operations: [op])
        let context = makeContext()

        let result = await sut.applyModifications(to: data, modifications: [mod], context: context)
        let parsed = parseJSON(result) as! [String: Any]
        let container = parsed["container"] as! [String: Any]
        XCTAssertEqual(container["source"] as? String, "value")
        XCTAssertEqual(container["target"] as? String, "value")
    }

    func test_test_matchingValue_succeeds() async {
        let data = jsonData(["name": "Alice"])
        let op = makeOperation(type: .test, key: "name", value: "Alice")
        let mod = makeModification(path: "$", operations: [op])
        let context = makeContext()

        let result = await sut.applyModifications(to: data, modifications: [mod], context: context)
        let parsed = parseJSON(result) as! [String: Any]
        XCTAssertEqual(parsed["name"] as? String, "Alice")
    }

    func test_test_mismatchingValue_graceful() async {
        let original = jsonData(["name": "Alice"])
        let op = makeOperation(type: .test, key: "name", value: "Bob")
        let mod = makeModification(path: "$", operations: [op])
        let context = makeContext()

        let result = await sut.applyModifications(to: original, modifications: [mod], context: context)
        let parsed = parseJSON(result) as! [String: Any]
        XCTAssertEqual(parsed["name"] as? String, "Alice")
    }

    // MARK: - 4. applyModifications — RFC 9535 JSONPath queries

    func test_simpleJsonPath() async {
        let data = jsonData(["store": ["price": 10]])
        let op = makeOperation(type: .add, key: "currency", value: "USD")
        let mod = makeModification(path: "$.store", operations: [op])
        let context = makeContext()

        let result = await sut.applyModifications(to: data, modifications: [mod], context: context)
        let parsed = parseJSON(result) as! [String: Any]
        let store = parsed["store"] as! [String: Any]
        XCTAssertEqual(store["currency"] as? String, "USD")
        XCTAssertEqual(store["price"] as? Int, 10)
    }

    func test_recursiveDescent() async {
        let data = jsonData([
            "widgets": [
                ["marketing": ["delphoi": ["id": 1]]],
                ["marketing": ["atlas": ["id": 2]]]
            ]
        ])
        let op = makeOperation(type: .add, key: "tracked", value: true)
        let mod = makeModification(path: "$..marketing.*", operations: [op])
        let context = makeContext()

        let result = await sut.applyModifications(to: data, modifications: [mod], context: context)
        let parsed = parseJSON(result) as! [String: Any]
        let widgets = parsed["widgets"] as! [[String: Any]]
        let delphoi = (widgets[0]["marketing"] as! [String: Any])["delphoi"] as! [String: Any]
        let atlas = (widgets[1]["marketing"] as! [String: Any])["atlas"] as! [String: Any]
        XCTAssertEqual(delphoi["tracked"] as? Bool, true)
        XCTAssertEqual(atlas["tracked"] as? Bool, true)
    }

    func test_wildcardIndex() async {
        let data = jsonData(["items": [["name": "A"], ["name": "B"]]])
        let op = makeOperation(type: .add, key: "selected", value: false)
        let mod = makeModification(path: "$.items[*]", operations: [op])
        let context = makeContext()

        let result = await sut.applyModifications(to: data, modifications: [mod], context: context)
        let parsed = parseJSON(result) as! [String: Any]
        let items = parsed["items"] as! [[String: Any]]
        XCTAssertEqual(items[0]["selected"] as? Bool, false)
        XCTAssertEqual(items[1]["selected"] as? Bool, false)
    }

    func test_noMatches_returnsOriginal() async {
        let original = jsonData(["name": "Alice"])
        let op = makeOperation(type: .add, key: "x", value: 1)
        let mod = makeModification(path: "$.nonexistent.deep.path", operations: [op])
        let context = makeContext()

        let result = await sut.applyModifications(to: original, modifications: [mod], context: context)
        let parsed = parseJSON(result) as! [String: Any]
        XCTAssertEqual(parsed["name"] as? String, "Alice")
        XCTAssertNil(parsed["x"])
    }

    // MARK: - 5. Template variable resolution

    func test_templateDomain() async {
        let data = jsonData(["info": [:] as [String: Any]])
        let op = makeOperation(type: .add, key: "{domain}", value: "injected")
        let mod = makeModification(path: "$.info", operations: [op])
        let context = makeContext(domain: "example.com")

        let result = await sut.applyModifications(to: data, modifications: [mod], context: context)
        let parsed = parseJSON(result) as! [String: Any]
        let info = parsed["info"] as! [String: Any]
        XCTAssertEqual(info["example.com"] as? String, "injected")
    }

    func test_templateMethod() async {
        let data = jsonData(["info": [:] as [String: Any]])
        let op = makeOperation(type: .add, key: "{method}", value: "injected")
        let mod = makeModification(path: "$.info", operations: [op])
        let context = makeContext(method: "POST")

        let result = await sut.applyModifications(to: data, modifications: [mod], context: context)
        let parsed = parseJSON(result) as! [String: Any]
        let info = parsed["info"] as! [String: Any]
        XCTAssertEqual(info["POST"] as? String, "injected")
    }

    func test_templateRequestPath() async {
        let data = jsonData(["info": [:] as [String: Any]])
        let op = makeOperation(type: .add, key: "{requestPath}", value: "injected")
        let mod = makeModification(path: "$.info", operations: [op])
        let context = makeContext(requestPath: "/api/v2/data")

        let result = await sut.applyModifications(to: data, modifications: [mod], context: context)
        let parsed = parseJSON(result) as! [String: Any]
        let info = parsed["info"] as! [String: Any]
        XCTAssertEqual(info["/api/v2/data"] as? String, "injected")
    }

    func test_templateJsonPath() async {
        let data = jsonData(["marketing": ["delphoi": ["id": 1]]])
        let op = makeOperation(type: .add, key: "{jsonPath}", value: "path_value")
        let mod = makeModification(path: "$.marketing.delphoi", operations: [op])
        let context = makeContext()

        let result = await sut.applyModifications(to: data, modifications: [mod], context: context)
        let parsed = parseJSON(result) as! [String: Any]
        let delphoi = (parsed["marketing"] as! [String: Any])["delphoi"] as! [String: Any]
        XCTAssertEqual(delphoi["$.marketing.delphoi"] as? String, "path_value")
    }

    func test_templateCombined() async {
        let data = jsonData(["info": [:] as [String: Any]])
        let op = makeOperation(type: .add, key: "{domain};{method};{requestPath}", value: "combined")
        let mod = makeModification(path: "$.info", operations: [op])
        let context = makeContext(domain: "d", method: "M", requestPath: "/p")

        let result = await sut.applyModifications(to: data, modifications: [mod], context: context)
        let parsed = parseJSON(result) as! [String: Any]
        let info = parsed["info"] as! [String: Any]
        XCTAssertEqual(info["d;M;/p"] as? String, "combined")
    }

    // MARK: - 6. End-to-end discovery scenario

    func test_discoveryInjection() async {
        let data = jsonData([
            "widgets": [
                ["marketing": ["delphoi": ["id": 1, "type": "banner"]]]
            ]
        ])
        // Use template resolution for the key — {jsonPath} resolves to the matched node's dot-notation path
        let opWithTemplate = makeOperation(type: .add, key: "{jsonPath}", value: "tracked")
        let mod = makeModification(path: "$..marketing.*", operations: [opWithTemplate])
        let context = makeContext(domain: "trendyol.com", method: "GET", requestPath: "/api/widgets")

        let result = await sut.applyModifications(to: data, modifications: [mod], context: context)
        let parsed = parseJSON(result) as! [String: Any]
        let widgets = parsed["widgets"] as! [[String: Any]]
        let delphoi = (widgets[0]["marketing"] as! [String: Any])["delphoi"] as! [String: Any]
        XCTAssertEqual(delphoi["$.widgets[0].marketing.delphoi"] as? String, "tracked")
    }

    func test_multipleMarketingObjects() async {
        let data = jsonData([
            "widgets": [
                ["marketing": ["delphoi": ["id": 1]]],
                ["marketing": ["atlas": ["id": 2]]]
            ]
        ])
        let op = makeOperation(type: .add, key: "{jsonPath}", value: "path_marker")
        let mod = makeModification(path: "$..marketing.*", operations: [op])
        let context = makeContext()

        let result = await sut.applyModifications(to: data, modifications: [mod], context: context)
        let parsed = parseJSON(result) as! [String: Any]
        let widgets = parsed["widgets"] as! [[String: Any]]
        let delphoi = (widgets[0]["marketing"] as! [String: Any])["delphoi"] as! [String: Any]
        let atlas = (widgets[1]["marketing"] as! [String: Any])["atlas"] as! [String: Any]
        // Each should have its own unique jsonPath key
        XCTAssertNotNil(delphoi["$.widgets[0].marketing.delphoi"])
        XCTAssertNotNil(atlas["$.widgets[1].marketing.atlas"])
        // And they should be different
        XCTAssertNotEqual(
            delphoi.keys.first(where: { $0.contains("widgets") }),
            atlas.keys.first(where: { $0.contains("widgets") })
        )
    }

    func test_nestedMarketingObjects() async {
        let data = jsonData([
            "page": [
                "sections": [
                    ["marketing": ["tracker": ["id": 1]]],
                    ["content": [
                        "marketing": ["inner": ["id": 2]]
                    ]]
                ]
            ]
        ])
        let op = makeOperation(type: .add, key: "instrumented", value: true)
        let mod = makeModification(path: "$..marketing.*", operations: [op])
        let context = makeContext()

        let result = await sut.applyModifications(to: data, modifications: [mod], context: context)
        let parsed = parseJSON(result) as! [String: Any]
        let page = parsed["page"] as! [String: Any]
        let sections = page["sections"] as! [[String: Any]]
        let tracker = (sections[0]["marketing"] as! [String: Any])["tracker"] as! [String: Any]
        let content = sections[1]["content"] as! [String: Any]
        let inner = (content["marketing"] as! [String: Any])["inner"] as! [String: Any]
        XCTAssertEqual(tracker["instrumented"] as? Bool, true)
        XCTAssertEqual(inner["instrumented"] as? Bool, true)
    }

    // MARK: - 7. Edge cases

    func test_invalidJson_returnsOriginal() async {
        let invalidData = "not json at all".data(using: .utf8)!
        let op = makeOperation(type: .add, key: "x", value: 1)
        let mod = makeModification(path: "$", operations: [op])
        let context = makeContext()

        let result = await sut.applyModifications(to: invalidData, modifications: [mod], context: context)
        XCTAssertEqual(result, invalidData)
    }

    func test_invalidJsonPath_returnsOriginal() async {
        let data = jsonData(["name": "Alice"])
        let op = makeOperation(type: .add, key: "x", value: 1)
        let mod = makeModification(path: "$[invalid[[[", operations: [op])
        let context = makeContext()

        let result = await sut.applyModifications(to: data, modifications: [mod], context: context)
        // Should still return valid JSON (the original, re-encoded with sortedKeys)
        let parsed = parseJSON(result) as! [String: Any]
        XCTAssertEqual(parsed["name"] as? String, "Alice")
        XCTAssertNil(parsed["x"])
    }

    func test_emptyModifications_returnsOriginal() async {
        let data = jsonData(["name": "Alice"])
        let context = makeContext()

        let result = await sut.applyModifications(to: data, modifications: [], context: context)
        let parsed = parseJSON(result) as! [String: Any]
        XCTAssertEqual(parsed["name"] as? String, "Alice")
    }

    func test_multipleModifications_appliedSequentially() async {
        let data = jsonData(["count": 0])
        let op1 = makeOperation(type: .replace, key: "count", value: 1)
        let mod1 = makeModification(path: "$", operations: [op1])
        let op2 = makeOperation(type: .add, key: "extra", value: "added")
        let mod2 = makeModification(path: "$", operations: [op2])
        let context = makeContext()

        let result = await sut.applyModifications(to: data, modifications: [mod1, mod2], context: context)
        let parsed = parseJSON(result) as! [String: Any]
        XCTAssertEqual(parsed["count"] as? Int, 1)
        XCTAssertEqual(parsed["extra"] as? String, "added")
    }
}
