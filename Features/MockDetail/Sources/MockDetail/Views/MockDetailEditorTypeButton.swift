//
//  MockDetailEditorTypeButton.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 20.09.2023.
//

import SwiftUI

struct MockDetailEditorTypeButton: View {
    @Binding var selectedEditorType: MockDetailEditorType
    @State private var opacity: [MockDetailEditorType: Double] = [:]

    var body: some View {
        HStack {
            button(type: .responseBody)
            button(type: .responseHeader)
            button(type: .requestBody)
            button(type: .requestHeader)
        }
        .padding()
    }

    @ViewBuilder
    private func button(type: MockDetailEditorType) -> some View {
        Button {
            withAnimation {
                selectedEditorType = type
            }
        } label: {
            Label(type.buttonTitle, systemImage: type.buttonIcon)
                .frame(maxWidth: .infinity)
                .frame(height: 25.0)
                .border(Color.gray.opacity(0.2))
                .foregroundColor(.white)
                .buttonStyle(.plain)
                .background(selectedEditorType == type ? Color.accentColor : .secondary.opacity(opacity[type, default: 0.4]))
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            opacity[type] = hovering ? 0.6 : 0.4
        }
    }
}

#Preview {
    MockDetailEditorTypeButton(selectedEditorType: .constant(.requestBody))
}
