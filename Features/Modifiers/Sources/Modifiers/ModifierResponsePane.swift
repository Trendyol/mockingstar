import Editor
import SwiftUI
import TipKit

struct MockModifierResponsePane: View {
    @Bindable var viewModel: MockModifierDetailViewModel

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Response").font(.headline)
                    if let status = viewModel.previewStatus {
                        Text("\(status)")
                            .font(.caption.monospacedDigit())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.quaternary, in: Capsule())
                    }
                    if viewModel.previewIsStale {
                        Text("Stale").foregroundStyle(.orange)
                    }
                    if viewModel.previewStatus != nil && !viewModel.hasPreviewOriginal {
                        Text("No original")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .help("The transformer did not call chain.proceed, so there is no original response to diff against.")
                    }
                    Spacer()
                }
                HStack {
                    Spacer()
                    Button("Copy") { viewModel.copyPreviewResponse() }
                        .disabled(viewModel.previewStatus == nil)
                    if viewModel.previewStatus != nil {
                        Button("Copy Object Notation") { viewModel.copyObjectNotation() }
                            .disabled(!viewModel.canCopyObjectNotation)
                            .help("Copy the merged response structure. Right-click a response field to copy only its object and path.")
                    }
                    Button("Copy cURL") { viewModel.copyPreviewCURL() }
                }
            }
            .padding(10)

            TipView(ModifierResponseTip())
                .padding(.horizontal, 10)

            Group {
                if viewModel.previewStatus == nil && !viewModel.isPreviewLoading {
                    ContentUnavailableView(
                        "No Preview Response",
                        systemImage: "curlybraces",
                        description: Text("Edit the request and JavaScript, then choose Run.")
                    )
                } else {
                    MonacoDiffView(session: viewModel.diffEditorSession)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}
