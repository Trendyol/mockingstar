//
//  PartialMockDecider.swift
//
//
//  Created for Trendyol Marketing Object Testing
//

import CommonKit
import DynamicJSON
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

actor PartialMockDecidersActor {
    private var deciderList: [String: PartialMockDecider] = [:]

    func decider(for mockDomain: String) async -> PartialMockDecider {
        if let decider = deciderList[mockDomain] {
            return decider
        }

        let configs = Configurations(mockDomain: mockDomain)
        let newDecider = PartialMockDecider(configs: configs)

        deciderList[mockDomain] = newDecider
        return newDecider
    }
}

/// Context about the original HTTP request, passed through for template variable resolution.
struct RequestContext {
    let domain: String
    let method: String
    let requestPath: String
}

actor PartialMockDecider {
    private let fileURLBuilder: FileUrlBuilderInterface
    private var partialMocks: [PartialMockModel] = []
    private var configs: ConfigurationsInterface
    private let logger = Logger(category: "PartialMockDecider")

    init(fileURLBuilder: FileUrlBuilderInterface = FileUrlBuilder(), configs: ConfigurationsInterface) {
        self.fileURLBuilder = fileURLBuilder
        self.configs = configs
    }

    func addPartialMock(_ partialMock: PartialMockModel) {
        let replaced = partialMocks.contains(where: {
            $0.deviceId == partialMock.deviceId &&
            $0.url == partialMock.url &&
            $0.method == partialMock.method
        })
        partialMocks.removeAll(where: {
            $0.deviceId == partialMock.deviceId &&
            $0.url == partialMock.url &&
            $0.method == partialMock.method
        })
        partialMocks.append(partialMock)
        let action = replaced ? "Replaced" : "Added"
        logger.info("\(action) partial mock: \(partialMock.method) \(partialMock.url) (device: \(partialMock.deviceId), \(partialMock.modifications.count) modification(s))")
    }

    func removePartialMocks(deviceId: String) {
        let count = partialMocks.filter({ $0.deviceId == deviceId }).count
        partialMocks.removeAll(where: { $0.deviceId == deviceId })
        logger.info("Removed \(count) partial mock(s) for device: \(deviceId)")
    }

    func findMatchingPartialMocks(request: URLRequest, deviceId: String) -> [PartialMockModel] {
        let requestPath = request.url?.path() ?? ""
        let requestMethod = request.httpMethod ?? "?"

        guard !partialMocks.isEmpty else { return [] }

        let matched = partialMocks.filter {
            let isDeviceMatch = $0.deviceId == deviceId
            let isMethodMatch = $0.method == "*" || $0.method == request.httpMethod
            let isPathMatching = $0.url == "*" || fileURLBuilder.isPathMatched(
                requestPath: requestPath,
                configPath: $0.url,
                pathMatchingRatio: configs.configs.appFilterConfigs.pathMatchingRatio
            )

            if !isDeviceMatch {
                logger.debug("Partial mock \($0.method) \($0.url) skipped: device mismatch (rule: \($0.deviceId), request: \(deviceId))")
            } else if !isMethodMatch {
                logger.debug("Partial mock \($0.method) \($0.url) skipped: method mismatch (rule: \($0.method), request: \(requestMethod))")
            } else if !isPathMatching {
                logger.debug("Partial mock \($0.method) \($0.url) skipped: path not matched (request: \(requestPath))")
            }

            return isDeviceMatch && isMethodMatch && isPathMatching
        }

        if matched.isEmpty {
            logger.debug("No partial mocks matched for \(requestMethod) \(requestPath) (device: \(deviceId), \(partialMocks.count) rule(s) checked)")
        } else {
            logger.info("Matched \(matched.count) partial mock(s) for \(requestMethod) \(requestPath) (device: \(deviceId))")
        }

        return matched
    }

    /// Applies partial mock modifications to response JSON data using RFC 9535 JSONPath queries
    /// and RFC 6902 JSON Patch operations.
    ///
    /// - Parameters:
    ///   - data: The original response body as JSON-encoded Data.
    ///   - modifications: The list of path + operations modifications to apply.
    ///   - context: Request context for template variable resolution. Required.
    /// - Returns: The modified response body, or the original data if parsing/modification fails.
    func applyModifications(to data: Data, modifications: [PartialMockModification], context: RequestContext) -> Data {
        guard var json = try? JSONDecoder().decode(JSON.self, from: data) else {
            logger.error("Failed to parse response body as JSON for partial mock modification")
            return data
        }

        for modification in modifications {
            // RFC 9535: Query the JSON document with the JSONPath expression
            guard let matches = try? json.query(modification.path) else {
                logger.error("Failed to query JSONPath: \(modification.path)")
                continue
            }

            logger.info("Applying \(modification.operations.count) operation(s) at path: \(modification.path) (\(matches.count) match(es))")

            for match in matches {
                guard let pointer = match.location.pointer else {
                    logger.error("Cannot convert location to JSON pointer: \(match.location)")
                    continue
                }

                let jsonPathStr = dotNotationPath(from: match.location)

                for operation in modification.operations {
                    let resolvedKey = resolveTemplate(
                        operation.key,
                        context: context,
                        jsonPath: jsonPathStr
                    )
                    // RFC 6901: Build a JSON Pointer to the child member
                    let childPointer = pointer.select(member: resolvedKey)

                    do {
                        // RFC 6902 §4: Apply operation with standard semantics
                        switch operation.type {
                        case .add:
                            // §4.1: Add — creates member if absent, replaces if present
                            let jsonValue = jsonFromAny(operation.value?.value)
                            try json.apply(operation: .add(childPointer, jsonValue))

                        case .remove:
                            // §4.2: Remove — target MUST exist
                            try json.apply(operation: .remove(childPointer))

                        case .replace:
                            // §4.3: Replace — target MUST exist
                            let jsonValue = jsonFromAny(operation.value?.value)
                            try json.apply(operation: .replace(childPointer, jsonValue))

                        case .move:
                            // §4.4: Move — remove from source, add at target
                            guard let fromKey = operation.from else {
                                logger.error("'move' operation requires 'from' field")
                                continue
                            }
                            let fromPointer = pointer.select(member: fromKey)
                            try json.apply(operation: .move(fromPointer, childPointer))

                        case .copy:
                            // §4.5: Copy — copy value at source to target
                            guard let fromKey = operation.from else {
                                logger.error("'copy' operation requires 'from' field")
                                continue
                            }
                            let fromPointer = pointer.select(member: fromKey)
                            try json.apply(operation: .copy(fromPointer, childPointer))

                        case .test:
                            // §4.6: Test — verify value at target equals expected
                            let jsonValue = jsonFromAny(operation.value?.value)
                            try json.apply(operation: .test(childPointer, jsonValue))
                        }
                    } catch {
                        logger.error("Failed to apply RFC 6902 '\(operation.type)' for key '\(resolvedKey)': \(error)")
                    }
                }
            }
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let modifiedData = try? encoder.encode(json) else {
            logger.error("Failed to serialize modified JSON")
            return data
        }

        logger.info("Response body modified successfully (\(data.count) -> \(modifiedData.count) bytes)")
        return modifiedData
    }

    // MARK: - Private Helpers

    /// Resolves template variables in operation keys.
    ///
    /// Supported variables:
    /// - `{domain}` → request context domain
    /// - `{method}` → HTTP method (e.g. GET, POST)
    /// - `{requestPath}` → URL path of the request
    /// - `{jsonPath}` → dot-notation JSONPath of the matched node
    private func resolveTemplate(_ template: String, context: RequestContext, jsonPath: String) -> String {
        return template
            .replacingOccurrences(of: "{domain}", with: context.domain)
            .replacingOccurrences(of: "{method}", with: context.method)
            .replacingOccurrences(of: "{requestPath}", with: context.requestPath)
            .replacingOccurrences(of: "{jsonPath}", with: jsonPath)
    }

    /// Converts a JSONLocation (RFC 9535 normalized path) to dot-notation JSONPath string.
    ///
    /// Example: `$['widgets'][0]['marketing']['delphoi']` → `$.widgets[0].marketing.delphoi`
    private func dotNotationPath(from location: JSONLocation) -> String {
        var result = "$"
        for segment in location.segments {
            switch segment {
            case .member(let name):
                result += ".\(name)"
            case .index(let idx):
                result += "[\(idx)]"
            }
        }
        return result
    }

    /// Converts a Foundation `Any` value (from `AnyCodableModel`) to DynamicJSON's `JSON` type.
    private func jsonFromAny(_ value: Any?) -> JSON {
        guard let value = value else { return .null }
        let wrapper: [Any] = [value]
        guard JSONSerialization.isValidJSONObject(wrapper),
              let data = try? JSONSerialization.data(withJSONObject: wrapper),
              let decoded = try? JSONDecoder().decode([JSON].self, from: data),
              let result = decoded.first else {
            return .string(String(describing: value))
        }
        return result
    }
}
