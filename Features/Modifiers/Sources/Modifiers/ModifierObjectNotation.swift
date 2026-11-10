import CoreFoundation
import Foundation

/// Summarizes all observed array elements into one shape per JSON container type.
/// Optional containers use {"$optional": ...}; mixed container/scalar fields use {"$types": [...]}.
enum MockModifierObjectNotation {
    static func make(from data: Data) throws -> String {
        let json = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
        return try make(from: json)
    }

    static func make(from json: Any) throws -> String {
        let notation = try summarize([json])
        return String(decoding: try JSONSerialization.data(
            withJSONObject: notation,
            options: [.fragmentsAllowed, .sortedKeys, .withoutEscapingSlashes]
        ), as: UTF8.self)
    }

    private static func summarize(_ values: [Any]) throws -> Any {
        let shapes = try variants(values)
        if shapes.count == 1, let shape = shapes.first { return shape }
        return ["$types": shapes]
    }

    private static func variants(_ values: [Any]) throws -> [Any] {
        var objects: [[String: Any]] = []
        var arrays: [[Any]] = []
        var types = Set<String>()
        for value in values {
            switch value {
            case let object as [String: Any]: objects.append(object)
            case let array as [Any]: arrays.append(array)
            case is String: types.insert("string")
            case let number as NSNumber:
                if CFGetTypeID(number) == CFBooleanGetTypeID() {
                    types.insert("bool")
                } else {
                    let type = String(cString: number.objCType)
                    types.insert(type == "f" || type == "d" ? "double" : "int")
                }
            case is NSNull: types.insert("null")
            default:
                throw EncodingError.invalidValue(value, .init(
                    codingPath: [], debugDescription: "Unsupported JSON value"
                ))
            }
        }

        var shapes: [Any] = []
        if !objects.isEmpty {
            var fields: [String: [Any]] = [:]
            for object in objects {
                for (key, value) in object { fields[key, default: []].append(value) }
            }
            var shape: [String: Any] = [:]
            for (key, observations) in fields {
                let field = try summarize(observations)
                if observations.count < objects.count {
                    if let type = field as? String {
                        shape[key] = type + " (optional)"
                    } else {
                        shape[key] = ["$optional": field]
                    }
                } else {
                    shape[key] = field
                }
            }
            shapes.append(shape)
        }
        if !arrays.isEmpty {
            shapes.append(try variants(arrays.flatMap { $0 }))
        }
        if !types.isEmpty { shapes.append(types.sorted().joined(separator: "|")) }
        return shapes
    }
}
