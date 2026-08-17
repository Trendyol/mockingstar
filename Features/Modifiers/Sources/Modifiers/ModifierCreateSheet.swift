import CommonKit
import SwiftUI

public struct ModifierCreateSheet: View {
    @State private var viewModel: ModifierCreateViewModel
    private let domain: String
    private let onCreated: (String, ModifierCreationSeed) -> Void
    @Environment(\.dismiss) private var dismiss

    public init(
        seed: ModifierCreationSeed,
        domain: String,
        onCreated: @escaping (String, ModifierCreationSeed) -> Void
    ) {
        _viewModel = State(initialValue: ModifierCreateViewModel(seed: seed))
        self.domain = domain
        self.onCreated = onCreated
    }

    public var body: some View {
        @Bindable var viewModel = viewModel
        VStack(alignment: .leading, spacing: 12) {
            Text("New Modifier")
                .font(.title2.bold())

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
