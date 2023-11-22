//
//  File.swift
//  
//
//  Created by Yusuf Özgül on 9.09.2023.
//

import CommonKit
import Foundation

actor MockDeciderActor {
    private var deciderList: [String: MockDeciderInterface] = [:]
    private let fileStructureHelper: FileStructureHelperInterface

    init(fileStructureHelper: FileStructureHelperInterface = FileStructureHelper()) {
        self.fileStructureHelper = fileStructureHelper
    }

    /// Retrieves or creates a `MockDeciderInterface` for a specific mock domain.
    ///
    /// - Parameter mockDomain: The domain for which a ``MockDeciderInterface`` is retrieved or created.
    /// - Returns: A ``MockDeciderInterface`` for the specified mock domain.
    /// - Throws: If an error occurs during the file structure check or creation process, it is thrown.
    func decider(for mockDomain: String) async throws -> MockDeciderInterface {
        let decider = deciderList[mockDomain]

        if let decider = decider { return decider }

        if !fileStructureHelper.domainFileStructureCheck(mockDomain: mockDomain) {
            try fileStructureHelper.createDomainFileStructure(mockDomain: mockDomain)
        }

        let configs = Configurations(mockDomain: mockDomain)
        let newDecider = MockDecider(mockDomain: mockDomain,
                                     configs: configs)
        deciderList[mockDomain] = newDecider
        return newDecider
    }
}
