//
//  FormatStyle+Extension.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 16.10.2023.
//

import Foundation

public struct PortFormat: ParseableFormatStyle {
    public var parseStrategy: PortParseStrategy = PortParseStrategy()

    public func format(_ value: UInt16) -> String {
        String(value)
    }

    public struct PortParseStrategy: ParseStrategy {
        public func parse(_ value: String) throws -> UInt16 {
            let intValue = Int(value) ?? 8008

            guard intValue <= UInt16.max else { return 8008 }
            let value = UInt16(intValue)

            if value < 1024 {
                return 1024
            }

            if value > 65_535 {
                return 65_535
            }

            return value
        }
    }
}

public extension FormatStyle where Self == PortFormat {
    static func port() -> PortFormat {
        .init()
    }
}


public struct HTTPStatusFormat: ParseableFormatStyle {
    public var parseStrategy: HTTPStatusParseStrategy = HTTPStatusParseStrategy()

    public func format(_ value: Int) -> String {
        String(value)
    }

    public struct HTTPStatusParseStrategy: ParseStrategy {
        public func parse(_ value: String) throws -> Int {
            let intValue = Int(value) ?? 200

            guard intValue >= 100 && intValue < 600 else { return 200 }
            return intValue
        }
    }
}

public extension FormatStyle where Self == HTTPStatusFormat {
    static func httpStatus() -> HTTPStatusFormat {
        .init()
    }
}
