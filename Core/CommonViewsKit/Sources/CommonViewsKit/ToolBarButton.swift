//
//  ToolBarButton.swift
//  CommonViewsKit
//
//  Created by Yusuf Özgül on 26.09.2023.
//

import SwiftUI

public struct ToolBarButton: View {
    let title: LocalizedStringKey?
    let icon: String
    let backgroundColor: Color
    let action: () -> Void

    public init(title: LocalizedStringKey? = nil, icon: String, backgroundColor: Color, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.backgroundColor = backgroundColor
        self.action = action
    }

    public var body: some View {
        Button {
            action()
        } label: {
            HStack {
                Image(systemName: icon)

                if let title {
                    Text(title)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .foregroundStyle(.white)
            .background(backgroundColor)
            .clipShape(.rect(cornerRadius: 10))
        }
        .buttonBorderShape(.roundedRectangle)
        .buttonStyle(.plain)
    }
}

#Preview {
    ToolBarButton(title: "Save", icon: "tray.and.arrow.down", backgroundColor: .red) {

    }
}

