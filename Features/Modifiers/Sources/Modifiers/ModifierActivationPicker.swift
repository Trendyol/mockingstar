import CommonKit
import SwiftUI

struct ModifierActivationPicker: View {
    let selection: ModifierPreviewSource?
    let onChange: (ModifierPreviewSource?) -> Void

    var body: some View {
        Picker("", selection: binding) {
            Text("Off").tag(ModifierPreviewSource?.none)
            Text("Mock").tag(ModifierPreviewSource?.some(.mock))
            Text("Live").tag(ModifierPreviewSource?.some(.live))
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .fixedSize()
    }

    private var binding: Binding<ModifierPreviewSource?> {
        Binding(
            get: { selection },
            set: { onChange($0) }
        )
    }
}
