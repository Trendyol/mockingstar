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
    private var saveChanges: () -> Void
//    private let unsavedTip = UnsavedChangesTip()

    public init(hasChange: Binding<Bool>, saveChanges: @escaping () -> Void) {
        self._hasChange = hasChange
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
                    .keyboardShortcut(.leftArrow, modifiers: .command)

                    if hasChange {
                        Label("Unsaved", systemImage: "smallcircle.filled.circle.fill")
                            .help("Unsaved Changes")
//                            .popoverTip(unsavedTip)
                    }
                }
            }
    }
}
/// removed due to crash, can investigate later.
//struct UnsavedChangesTip: Tip {
//    var title: Text {
//        Text("Unsaved Changes")
//    }
//
//    var message: Text? {
//        Text("You can save or discard them")
//    }
//
//    var image: Image? {
//        Image(systemName: "pencil.and.outline")
//    }
//}
