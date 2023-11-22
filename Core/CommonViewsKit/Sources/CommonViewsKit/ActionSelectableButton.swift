//
//  ActionSelectableButton.swift
//  CommonViewsKit
//
//  Created by Yusuf Özgül on 26.09.2023.
//

import SwiftUI

public struct ActionSelectableButton<MenuContent: View>: View {
    let title: String
    let icon: String
    let backgroundColor: Color
    let action: () -> Void
    var menuContent: () -> MenuContent

    public init(title: String, icon: String, backgroundColor: Color, action: @escaping () -> Void, menuContent: @escaping () -> MenuContent) {
        self.title = title
        self.icon = icon
        self.backgroundColor = backgroundColor
        self.action = action
        self.menuContent = menuContent
    }

    public var body: some View {
        HStack(spacing: .zero) {
            Button {
                action()
            } label: {
                HStack {
                    Image(systemName: icon)
                    Text(title)
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .frame(maxHeight: .infinity)
                .background(backgroundColor)
            }

            Menu {
                menuContent()
            } label: {
                Image(systemName: "chevron.down")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 10)
                    .padding(.horizontal, 8)
                    .frame(maxHeight: .infinity)
                    .background(backgroundColor.opacity(0.8))

            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
        }
        .clipShape(.rect(cornerRadius: 10))
        .buttonBorderShape(.roundedRectangle)
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
    }
}

#Preview {
    ActionSelectableButton(title: "Save", icon: "tray.and.arrow.down", backgroundColor: .red) {
        print("Tapped")
    } menuContent: {
        Group {
            Button("Button 1") {}
            Button("Button 2") {}
            Button("Button 3") {}
        }
    }
}
