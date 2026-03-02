//
//  MockDetailEditorTypeButton.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 20.09.2023.
//

import SwiftUI

struct MockDetailEditorTypeButton: View {
    @Binding var selectedEditorType: MockDetailEditorType
    @State private var __selectedEditorType: MockDetailEditorType
    @State private var opacity: [MockDetailEditorType: Double] = [:]
    
    init(selectedEditorType: Binding<MockDetailEditorType>) {
        self._selectedEditorType = selectedEditorType
        self.__selectedEditorType = selectedEditorType.wrappedValue
    }

    var body: some View {
        HStack {
            button(type: .responseBody)
            button(type: .responseHeader)
            button(type: .requestBody)
            button(type: .requestHeader)
        }
        .padding(8)
    }

    @ViewBuilder
    private func button(type: MockDetailEditorType) -> some View {
        Button {
            withAnimation {
                selectedEditorType = type
                __selectedEditorType = type
            }
        } label: {
            Label(type.buttonTitle, systemImage: type.buttonIcon)
                .frame(maxWidth: .infinity)
                .frame(height: 20.0)
                .foregroundStyle(.white)
        }
        .buttonStyle(.borderedProminent)
        .tint(__selectedEditorType == type ? Color.accentColor : .secondary.opacity(opacity[type, default: 0.4]))
        .onHover { hovering in
            opacity[type] = hovering ? 0.6 : 0.4
        }
    }
}

#Preview {
    MockDetailEditorTypeButton(selectedEditorType: .constant(.requestBody))
}
