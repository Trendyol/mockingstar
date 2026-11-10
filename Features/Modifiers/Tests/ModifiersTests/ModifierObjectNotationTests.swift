import Foundation
import XCTest
@testable import Modifiers

final class MockModifierObjectNotationTests: XCTestCase {
    func test_make_ReplacesNestedValuesWithTypes() throws {
        let json = #"{"a":1,"b":"hello","c":[{"d":2},{"d":3}]}"#

        let notation = try MockModifierObjectNotation.make(from: Data(json.utf8))

        XCTAssertEqual(notation, #"{"a":"int","b":"string","c":[{"d":"int"}]}"#)
    }

    func test_make_DistinguishesBooleansIntegersAndFloatingPointNumbers() throws {
        let json = #"{"zero":0,"one":1,"negative":-2,"decimal":1.0,"fraction":1.5,"large":9223372036854775808,"yes":true,"no":false}"#

        let notation = try MockModifierObjectNotation.make(from: Data(json.utf8))

        XCTAssertEqual(notation, #"{"decimal":"double","fraction":"double","large":"int","negative":"int","no":"bool","one":"int","yes":"bool","zero":"int"}"#)
    }

    func test_make_MergesArrayFieldsRegardlessOfObjectKeyOrder() throws {
        let json = #"[{"a":1,"b":"x"},{"b":"y","a":2},{"a":"x"},{"b":false},{"nested":[1,2]},{"nested":[3]}]"#

        let notation = try MockModifierObjectNotation.make(from: Data(json.utf8))

        XCTAssertEqual(notation, #"[{"a":"int|string (optional)","b":"bool|string (optional)","nested":{"$optional":["int"]}}]"#)
    }

    func test_make_PreservesDistinctTypesInMixedArrays() throws {
        let json = #"[1,2,"a","b",true,false,1.5,2.5,null,null,{},[],[1],[2]]"#

        let notation = try MockModifierObjectNotation.make(from: Data(json.utf8))

        XCTAssertEqual(notation, #"[{},["int"],"bool|double|int|null|string"]"#)
    }

    func test_make_MergesNullableAndOptionalFields() throws {
        let json = #"[{"a":1},{"a":null,"b":"x"}]"#

        let notation = try MockModifierObjectNotation.make(from: Data(json.utf8))

        XCTAssertEqual(notation, #"[{"a":"int|null","b":"string (optional)"}]"#)
    }

    func test_make_MergesNestedObjectsAndEmptyArrays() throws {
        let json = #"[{"item":{"id":1},"children":[]},{"item":{"id":null,"name":"x"},"children":[{"id":2}]}]"#

        let notation = try MockModifierObjectNotation.make(from: Data(json.utf8))

        XCTAssertEqual(notation, #"[{"children":[{"id":"int"}],"item":{"id":"int|null","name":"string (optional)"}}]"#)
    }

    func test_make_PreservesContainerTypeUnionsAndOptionalContainers() throws {
        let json = #"[{"a":{"id":1},"b":[1]},{"a":null},{"a":"x","b":["x"]}]"#

        let notation = try MockModifierObjectNotation.make(from: Data(json.utf8))

        XCTAssertEqual(notation, #"[{"a":{"$types":[{"id":"int"},"null|string"]},"b":{"$optional":["int|string"]}}]"#)
    }

    func test_make_LargeArrayWithDifferentOptionalFieldsProducesOneSmallShape() throws {
        let objects = (0..<1_000).map { index in
            ["id": index, "field\(index % 10)": index]
        }
        let data = try JSONSerialization.data(withJSONObject: objects)

        let notation = try MockModifierObjectNotation.make(from: data)
        let shapes = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(notation.utf8)) as? [[String: String]])

        XCTAssertEqual(shapes.count, 1)
        XCTAssertEqual(shapes.first?.count, 11)
        XCTAssertEqual(shapes.first?["id"], "int")
        XCTAssertEqual(shapes.first?["field0"], "int (optional)")
        XCTAssertLessThan(notation.utf8.count, 400)
    }

    func test_make_PreservesEmptyContainersAndNullFields() throws {
        let json = #"{"object":{},"array":[],"missing":null}"#

        let notation = try MockModifierObjectNotation.make(from: Data(json.utf8))

        XCTAssertEqual(notation, #"{"array":[],"missing":"null","object":{}}"#)
    }

    func test_make_RejectsInvalidJSON() {
        for json in ["", "{invalid JSON}", "plain text"] {
            XCTAssertThrowsError(try MockModifierObjectNotation.make(from: Data(json.utf8)))
        }
    }
}
