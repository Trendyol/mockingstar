//
//  MockFileSaverActor.swift
//
//
//  Created by Yusuf Özgül on 4.12.2023.
//

import CommonKit
import Foundation
import MockingStarCore

public final class MockFileSaverActor: FileSaverActorInterface {
    public init() { }
    
    public var invokedSaveFile = false
    public var invokedSaveFileCount = 0
    public var invokedSaveFileParameters: (mock: MockModel, mockDomain: String, Void)?
    public var invokedSaveFileParametersList: [(mock: MockModel, mockDomain: String, Void)] = []
    public var stubbedSaveFileError: Error? = nil
    public func saveFile(mock: MockModel, mockDomain: String) throws {
        invokedSaveFile = true
        invokedSaveFileCount += 1
        invokedSaveFileParameters = (mock, mockDomain, ())
        invokedSaveFileParametersList.append((mock, mockDomain, ()))

        if let stubbedSaveFileError {
            throw stubbedSaveFileError
        }
    }
}
