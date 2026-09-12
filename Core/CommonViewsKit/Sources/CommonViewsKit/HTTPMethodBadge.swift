//
//  HTTPMethodBadge.swift
//
//
//  Created by Yusuf Özgül on 3.08.2026.
//

import SwiftUI

public struct HTTPMethodBadge: View {
    private let method: String

    public init(method: String) {
        self.method = method.uppercased()
    }

    public var body: some View {
        HStack {
            Spacer()
            Text(method)
                .foregroundStyle(.white)
                .font(.callout.monospaced())
            Spacer()
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 2)
        .background(color)
        .clipShape(.rect(cornerRadius: 6))
    }

    private var color: Color {
        switch method {
        case "GET": Color(hex: "3f51b5")
        case "POST": Color(hex: "49cc90")
        case "PUT": Color(hex: "fca130")
        case "DELETE": Color(hex: "f93e3e")
        default: .gray
        }
    }
}
