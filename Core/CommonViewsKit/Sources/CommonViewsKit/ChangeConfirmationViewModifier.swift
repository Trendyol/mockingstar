//
//  ChangeConfirmationViewModifier.swift
//
//
//  Created by Yusuf Özgül on 4.11.2023.
//

import SwiftUI
import TipKit

public struct ChangeConfirmationViewModifier: ViewModifier {
    @Environment(\.dismiss) var dismiss
    @State private var presentingConfirmationDialog: Bool = false
    @Binding private var hasChange: Bool
    @Binding private var backNavigationShortcutDisabled: Bool
    private var saveChanges: () -> Void

    public init(hasChange: Binding<Bool>, backNavigationShortcutDisabled: Binding<Bool> = .constant(false), saveChanges: @escaping () -> Void) {
        self._hasChange = hasChange
        self._backNavigationShortcutDisabled = backNavigationShortcutDisabled
        self.saveChanges = saveChanges
    }

    public func body(content: Content) -> some View {
        content
            .confirmationDialog("Unsaved Changes", isPresented: $presentingConfirmationDialog) {
                Button("Discard Changes", role: .destructive, action: { withAnimation { dismiss() } })
                Button("Save", action: { saveChanges() })
                Button("Cancel", role: .cancel, action: { })
            }
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    if backNavigationShortcutDisabled {
                        backButton
                    } else {
                        backButton
                        .keyboardShortcut(.leftArrow, modifiers: .command)
                    }

                    if hasChange {
                        Label("Unsaved", systemImage: "smallcircle.filled.circle.fill")
                            .help("Unsaved Changes")
                    }
                }
            }
    }
    
    @ViewBuilder
    private var backButton: some View {
        Button {
            if hasChange {
                presentingConfirmationDialog = true
            } else {
                withAnimation { dismiss() }
            }
        } label: {
            Label("Back", systemImage: "chevron.left")
                .padding(4)
        }
    }
}
