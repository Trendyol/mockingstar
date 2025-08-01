//
//  LazyDecodingModel.swift
//  CommonKit
//
//  Created by Yusuf Özgül on 1.08.2025.
//

import Foundation

public protocol LazyDecodingModel {
    func decode(from data: Data) throws
}
