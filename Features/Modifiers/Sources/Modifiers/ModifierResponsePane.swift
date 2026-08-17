import Editor
import SwiftUI

struct ModifierResponsePane: View {
    @Bindable var viewModel: ModifierDetailViewModel

    var body: some View {
        VStack(spacing: 0) {
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
                Spacer()
                Button("Copy") { viewModel.copyPreviewResponse() }
                    .disabled(viewModel.previewStatus == nil)
                Menu("Headers") {
                    Text(viewModel.previewResponseHeaders.isEmpty
                         ? "No response headers"
                         : viewModel.previewResponseHeaders)
                }
                .disabled(viewModel.previewStatus == nil)
            }
            .padding(10)

            Group {
                if viewModel.previewStatus == nil && !viewModel.isPreviewLoading {
                    ContentUnavailableView(
                        "No Preview Response",
                        systemImage: "curlybraces",
                        description: Text("Edit the request and JavaScript, then choose Run.")
                    )
                } else {
                    EditorView(session: viewModel.responseEditorSession)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}
