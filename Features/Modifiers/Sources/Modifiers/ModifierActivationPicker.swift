import CommonKit
import SwiftUI

struct MockModifierActivationPicker: View {
    let selection: MockModifierPreviewSource?
    let onChange: (MockModifierPreviewSource?) -> Void

    var body: some View {
        Picker("", selection: binding) {
            Text("Off").tag(MockModifierPreviewSource?.none)
            Text("Mock").tag(MockModifierPreviewSource?.some(.mock))
            Text("Live").tag(MockModifierPreviewSource?.some(.live))
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .fixedSize()
    }

    private var binding: Binding<MockModifierPreviewSource?> {
        Binding(
            get: { selection },
            set: { onChange($0) }
        )
    }
}
