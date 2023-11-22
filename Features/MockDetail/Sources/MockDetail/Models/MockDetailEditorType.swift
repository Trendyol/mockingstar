//
//  MockDetailEditorType.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 16.10.2023.
//

import Foundation

enum MockDetailEditorType {
    case responseBody
    case responseHeader
    case requestBody
    case requestHeader

    var buttonTitle: String {
        return switch self {
        case .responseBody: "Response Body"
        case .responseHeader: "Response Header"
        case .requestBody: "Request Body"
        case .requestHeader: "Request Header"
        }
    }

    var buttonIcon: String {
        return switch self {
        case .responseBody: "arrow.turn.down.left"
        case .responseHeader: "arrow.turn.down.left"
        case .requestBody: "arrow.turn.down.right"
        case .requestHeader: "arrow.turn.down.right"
        }
    }
}
