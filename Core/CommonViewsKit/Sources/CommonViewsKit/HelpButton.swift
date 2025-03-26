//
//  HelpButton.swift
//  CommonViewsKit
//
//  Created by Yusuf Özgül on 18.03.2025.
//

import SwiftUI

public struct HelpButton: View {
    var action : () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button {
            action()
        } label: {
            Text("?").font(.system(size: 15, weight: .medium ))
                .padding(.horizontal)
                .background {
                    Circle()
                        .strokeBorder(Color(NSColor.shadowColor), lineWidth: 0.5)
                        .background(Circle().foregroundColor(Color(NSColor.controlColor)))
                        .shadow(color: Color(NSColor.shadowColor).opacity(0.3), radius: 1)
                        .frame(width: 20, height: 20)
                }
        }
        .buttonStyle(.plain)
    }
}
