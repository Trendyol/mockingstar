import CommonKit
import SwiftUI

public struct MockModifierCreateSheet: View {
    @State private var viewModel: MockModifierCreateViewModel
    private let domain: String
    private let onCreated: (String, MockModifierCreationSeed) -> Void
    @Environment(\.dismiss) private var dismiss

    public init(
        seed: MockModifierCreationSeed,
        domain: String,
        onCreated: @escaping (String, MockModifierCreationSeed) -> Void
    ) {
        _viewModel = State(initialValue: MockModifierCreateViewModel(seed: seed))
        self.domain = domain
        self.onCreated = onCreated
    }

    public var body: some View {
        @Bindable var viewModel = viewModel
        VStack(alignment: .leading, spacing: 12) {
            Text("New Modifier")
                .font(.title2.bold())

            Text("ID becomes the .js filename. Path and method must match the request to transform. Scenario is optional. Order starts at 1; a lower order runs first.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Form {
                TextField("ID (filename)", text: $viewModel.modifierId)
                TextField("Path", text: $viewModel.path)
                TextField("Method", text: $viewModel.method)
                TextField("Scenario", text: $viewModel.scenario)
                TextField("Order", value: $viewModel.order, format: .number)

                if !viewModel.sampleMockRequestId.isEmpty {
                    LabeledContent("Selected Mock ID") {
                        Text(viewModel.sampleMockRequestId)
                            .textSelection(.enabled)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)

            if let fieldError = viewModel.fieldError {
                Text(fieldError)
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Create") {
                    Task {
                        if let result = await viewModel.create(domain: domain) {
                            onCreated(result.id, result.seed)
                            dismiss()
                        }
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.isCreating)
            }
        }
        .padding()
        .frame(width: 420)
        .disabled(viewModel.isCreating)
    }
}
