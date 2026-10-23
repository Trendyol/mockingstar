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
    private let fileUrlBuilder: FileUrlBuilderInterface

    init(fileStructureHelper: FileStructureHelperInterface = FileStructureHelper(), fileUrlBuilder: FileUrlBuilderInterface = FileUrlBuilder()) {
        self.fileUrlBuilder = fileUrlBuilder
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

        let configs = Configurations(mockDomain: mockDomain, fileUrlBuilder: fileUrlBuilder)
        let newDecider = MockDecider(mockDomain: mockDomain,
                                     fileUrlBuilder: fileUrlBuilder, configs: configs)
        deciderList[mockDomain] = newDecider
        return newDecider
    }
}
