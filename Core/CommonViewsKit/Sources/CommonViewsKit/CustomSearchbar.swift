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

    public init(text: Binding<String>, isSearchActive: Binding<Bool>) {
        self._text = text
        self._isSearchActive = isSearchActive
    }

    public func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.delegate = context.coordinator
        textField.placeholderString = "Search & Filters"
        textField.focusRingType = .none
        textField.drawsBackground = false
        textField.isBezeled = false
        return textField
    }

    public func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.stringValue = text

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
