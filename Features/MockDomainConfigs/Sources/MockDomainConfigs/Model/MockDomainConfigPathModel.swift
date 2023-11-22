//
//  MockDomainConfigPathModel.swift
//
//
//  Created by Yusuf Özgül on 26.10.2023.
//

import Foundation

struct MockDomainConfigPathModel: Hashable, Identifiable {
    let id: UUID
    var path: String

    init(path: String) {
        self.id = .init()
        self.path = path
    }
}
