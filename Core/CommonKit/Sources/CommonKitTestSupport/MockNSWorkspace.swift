//
//  File.swift
//
//
//  Created by Yusuf Özgül on 4.12.2023.
//

import CommonKit
import Foundation

public final class MockNSWorkspace: NSWorkspaceInterface {
    public init() { }

    public var invokedSelectFile = false
    public var invokedSelectFileCount = 0
    public var invokedSelectFileParameters: (fullPath: String?, rootFullPath: String, Void)?
    public var invokedSelectFileParametersList: [(fullPath: String?, rootFullPath: String, Void)] = []
    public var stubbedSelectFileResult: Bool!
    public func selectFile(_ fullPath: String?, inFileViewerRootedAtPath rootFullPath: String) -> Bool {
        invokedSelectFile = true
        invokedSelectFileCount += 1
        invokedSelectFileParameters = (fullPath, rootFullPath, ())
        invokedSelectFileParametersList.append((fullPath, rootFullPath, ()))
        return stubbedSelectFileResult
    }
}
