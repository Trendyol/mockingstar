//
//  MethodColor.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 22.09.2023.
//

import SwiftUI

enum MethodColor: String {
    case GET = "3f51b5"
    case POST = "49cc90"
    case PUT = "fca130"
    case DELETE = "f93e3e"
    case mone

    var color: Color { Color(hex: self.rawValue) }
    static func method(name: String) -> MethodColor {
        switch name {
        case "GET": return .GET
        case "POST": return .POST
        case "PUT": return .PUT
        case "DELETE": return .DELETE
        default: return .mone
        }
    }
}
