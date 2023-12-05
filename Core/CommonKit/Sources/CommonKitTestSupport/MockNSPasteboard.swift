//
//  MockNSPasteboard.swift
//
//
//  Created by Yusuf Özgül on 4.12.2023.
//

import Foundation
import CommonKit
import AppKit

public final class MockNSPasteboard: NSPasteboardInterface {
    public init() { }
    
    public var invokedClearContents = false
    public var invokedClearContentsCount = 0
    public var stubbedClearContentsResult: Int!
    public func clearContents() -> Int {
        invokedClearContents = true
        invokedClearContentsCount += 1
        return stubbedClearContentsResult
    }

    public  var invokedSetString = false
    public  var invokedSetStringCount = 0
    public  var invokedSetStringParameters: (string: String, dataType: NSPasteboard.PasteboardType, Void)?
    public  var invokedSetStringParametersList: [(string: String, dataType: NSPasteboard.PasteboardType, Void)] = []
    public  var stubbedSetStringResult: Bool!
    public  func setString(_ string: String, forType dataType: NSPasteboard.PasteboardType) -> Bool {
        invokedSetString = true
        invokedSetStringCount += 1
        invokedSetStringParameters = (string, dataType, ())
        invokedSetStringParametersList.append((string, dataType, ()))
        return stubbedSetStringResult
    }
}
