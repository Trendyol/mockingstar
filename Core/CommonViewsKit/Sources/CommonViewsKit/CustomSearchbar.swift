//
//  MockListSearchBar.swift
//
//
//  Created by Yusuf Özgül on 25.10.2023.
//

import SwiftUI

public struct CustomSearchbar: NSViewRepresentable {
    @Binding public var text: String
    @Binding public var isSearchActive: Bool
    @Binding public var placeholderCount: Int

    public init(text: Binding<String>, isSearchActive: Binding<Bool>, placeholderCount: Binding<Int> = .constant(0)) {
        self._text = text
        self._isSearchActive = isSearchActive
        self._placeholderCount = placeholderCount
    }

    public func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.delegate = context.coordinator
        textField.focusRingType = .none
        textField.drawsBackground = false
        textField.isBezeled = false
        return textField
    }

    @MainActor
    public func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.stringValue = text

        if placeholderCount != 0 {
            nsView.placeholderString = "Search & Filters (\(placeholderCount))"
        } else {
            nsView.placeholderString = "Search & Filters"
        }

        if isSearchActive && !context.coordinator.previousSearchActive {
            nsView.becomeFirstResponder()
            context.coordinator.previousSearchActive = true
        }
    }

    public func makeCoordinator() -> Coordinator { Coordinator(self) }

    public class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: CustomSearchbar
        var previousSearchActive = false

        init(_ parent: CustomSearchbar) {
            self.parent = parent
        }
        
        public func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField, textField.stringValue != parent.text else { return }
            parent.text = textField.stringValue
        }

        public func controlTextDidEndEditing(_ obj: Notification) {
            previousSearchActive = false
            parent.isSearchActive = false
        }
    }
}
