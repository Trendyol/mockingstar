import CommonKit
import CommonViewsKit
import Editor
import SwiftUI

/// Owns a stable ViewModel so NavigationStack parent re-renders do not wipe preview seed/state.
public struct ModifierDetailRouteView: View {
    @State private var viewModel: ModifierDetailViewModel

    public init(modifierId: String, previewSeed: ModifierCreationSeed? = nil) {
        _viewModel = State(
            initialValue: ModifierDetailViewModel(
                modifierId: modifierId,
                previewSeed: previewSeed
            )
        )
    }

    public var body: some View {
        ModifierDetailView(viewModel: viewModel)
    }
}

public struct ModifierDetailView: View {
    @Bindable private var viewModel: ModifierDetailViewModel
    @AppStorage("mockDomain") private var mockDomain: String = "Dev"
    @FocusState private var isEditorFocused: Bool

    public init(viewModel: ModifierDetailViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HSplitView {
                    ModifierResponsePane(viewModel: viewModel)
                        .frame(minWidth: 420)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    VStack(spacing: 0) {
                        HStack {
                            Text("JavaScript").font(.headline)
                            Spacer()
                            if viewModel.isPreviewLoading {
                                ProgressView().controlSize(.small)
                            }
                            Button {
                                viewModel.openAskClaudeSheet()
                            } label: {
                                Label("Ask Claude", systemImage: "sparkles")
                            }
                            .help("Ask Claude to rewrite the transformer from your intent + preview sample")
                            .disabled(viewModel.isClaudeLoading)
                            Button {
                                Task { await viewModel.runPreview(domain: mockDomain) }
                            } label: {
                                Label("Run", systemImage: "play.fill")
                            }
                            .keyboardShortcut(.return, modifiers: [.command])
                            .disabled(viewModel.isPreviewLoading)
                        }
                        .padding(10)

                        EditorView(session: viewModel.javaScriptEditorSession)
                            .focused($isEditorFocused)
                            .frame(minHeight: 220)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        ModifierDetailInspectorPane(viewModel: viewModel)
                            .frame(minHeight: 280)
                    }
                    .frame(minWidth: 340, idealWidth: 420)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.background)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .navigationTitle(viewModel.currentId)
        .toolbar {
            ToolbarItemGroup {
                Toggle("Active", isOn: Binding(
                    get: { viewModel.enabled },
                    set: { _ in Task { await viewModel.toggleEnabled(domain: mockDomain) } }
                ))

                ToolBarButton(
                    title: "Save",
                    icon: "tray.and.arrow.down",
                    backgroundColor: .blue
                ) {
                    Task { _ = await viewModel.save(domain: mockDomain) }
                }
                .keyboardShortcut("s")
            }
            .disableSharedBackground()

            ToolbarItem {
                Menu {
                    Button("Delete", role: .destructive) {
                        viewModel.shouldShowDeleteConfirmation = true
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
            .disableSharedBackground()
        }
        .task {
            await viewModel.load(domain: mockDomain)
        }
        .alert("Error", isPresented: $viewModel.shouldShowErrorMessage) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
        .confirmationDialog("Delete modifier?", isPresented: $viewModel.shouldShowDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task { await viewModel.delete(domain: mockDomain) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $viewModel.shouldShowAskClaudeSheet) {
            ModifierAskClaudeSheet(viewModel: viewModel)
        }
        .modifier(ChangeConfirmationViewModifier(hasChange: $viewModel.shouldShowUnsavedIndicator,
                                                 backNavigationShortcutDisabled: .init(get: { isEditorFocused }, set: { _ in })) {
            Task { _ = await viewModel.save(domain: mockDomain) }
        })
    }
}

private struct ModifierAskClaudeSheet: View {
    @Bindable var viewModel: ModifierDetailViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Ask Claude for transformer JS")
                .font(.title2.bold())

            Text("Describe the next incremental change. Claude receives your current JS plus a response schema, updates the existing transformer, and tries not to break working logic.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("GenAI Gateway API key")
                .font(.headline)
            HStack(spacing: 8) {
                SecureField("MLP UI generated key", text: $viewModel.claudeAPIKey)
                    .textFieldStyle(.roundedBorder)
                    .disabled(viewModel.isClaudeLoading)
                Button("Clear") {
                    viewModel.clearClaudeAPIKey()
                }
                .disabled(viewModel.claudeAPIKey.isEmpty || viewModel.isClaudeLoading)
            }

            Text("What should this modifier do?")
                .font(.headline)
            TextEditor(text: $viewModel.claudeUserIntent)
                .font(.body)
                .frame(minHeight: 120)
                .disabled(viewModel.isClaudeLoading)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.35))
                )

            if viewModel.previewStatus == nil {
                Label(
                    "Tip: Run a preview first so Claude gets the sample response JSON.",
                    systemImage: "info.circle"
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            }

            if !viewModel.claudeSheetError.isEmpty {
                Text(viewModel.claudeSheetError)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    viewModel.shouldShowAskClaudeSheet = false
                    dismiss()
                }
                .disabled(viewModel.isClaudeLoading)
                Button {
                    Task {
                        if await viewModel.askClaude() {
                            dismiss()
                        }
                    }
                } label: {
                    if viewModel.isClaudeLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Generate")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!viewModel.canGenerateWithClaude)
            }
        }
        .padding(20)
        .frame(width: 520)
        .onChange(of: viewModel.shouldShowAskClaudeSheet) { _, isPresented in
            if !isPresented {
                dismiss()
            }
        }
    }
}

/// Matches Mock Detail inspector: always-open GroupBox sections instead of DisclosureGroups.
private struct ModifierDetailInspectorPane: View {
    @Bindable var viewModel: ModifierDetailViewModel

    var body: some View {
        List {
            GroupBox {
                VStack(alignment: .leading, spacing: 0) {
                    LabeledContent("ID") {
                        TextField("ID", text: $viewModel.draft.id)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.plain)
                    }
                    fieldErrorText(for: .id)
                    Divider().padding(.vertical, 6)

                    LabeledContent("Path") {
                        TextField("Path", text: $viewModel.draft.path)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.plain)
                    }
                    fieldErrorText(for: .path)
                    Divider().padding(.vertical, 6)

                    LabeledContent("Method") {
                        TextField("Method", text: $viewModel.draft.method)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.plain)
                    }
                    fieldErrorText(for: .method)
                    Divider().padding(.vertical, 6)

                    LabeledContent("Scenario") {
                        TextField("Scenario", text: $viewModel.draft.scenario)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.plain)
                    }
                    Divider().padding(.vertical, 6)

                    LabeledContent("Order") {
                        TextField(
                            "Order",
                            value: $viewModel.draft.order,
                            format: .number
                        )
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.plain)
                    }
                    fieldErrorText(for: .order)
                    Divider().padding(.vertical, 6)

                    LabeledContent("Sample Mock ID") {
                        TextField(
                            "Sample Mock ID",
                            text: $viewModel.draft.sampleMockRequestId
                        )
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.plain)
                    }
                    fieldErrorText(for: .sampleMockId)
                    Divider().padding(.vertical, 6)

                    LabeledContent("Current ID") {
                        Text(viewModel.currentId)
                            .textSelection(.enabled)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(6)
            } label: {
                Label("Metadata", systemImage: "book.pages")
                    .labelStyle(.titleOnly)
                    .font(.title3)
            }
            .listRowSeparator(.hidden)

            GroupBox {
                VStack(alignment: .leading, spacing: 0) {
                    LabeledContent("Source") {
                        ModifierSourcePicker(source: $viewModel.previewInput.source)
                            .frame(maxWidth: 180)
                    }
                    Divider().padding(.vertical, 6)

                    LabeledContent("URL") {
                        TextField("URL", text: $viewModel.previewInput.url, axis: .vertical)
                            .lineLimit(1...4)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.plain)
                    }
                    fieldErrorText(for: .url)
                    Divider().padding(.vertical, 6)

                    LabeledContent("Method") {
                        TextField("Method", text: $viewModel.previewInput.method)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.plain)
                    }
                    Divider().padding(.vertical, 6)

                    LabeledContent("Scenario") {
                        TextField("Scenario", text: $viewModel.previewInput.scenario)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.plain)
                    }
                    Divider().padding(.vertical, 6)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Headers JSON")
                        TextField(
                            "Headers JSON",
                            text: $viewModel.previewInput.headersJSON,
                            axis: .vertical
                        )
                        .lineLimit(2...6)
                        .textFieldStyle(.plain)
                        fieldErrorText(for: .headers)
                    }
                    Divider().padding(.vertical, 6)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Body")
                        TextField(
                            "Body",
                            text: $viewModel.previewInput.body,
                            axis: .vertical
                        )
                        .lineLimit(2...8)
                        .textFieldStyle(.plain)
                    }
                }
                .padding(6)
            } label: {
                Label("Preview Request", systemImage: "book.pages")
                    .labelStyle(.titleOnly)
                    .font(.title3)
            }
            .listRowSeparator(.hidden)
        }
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func fieldErrorText(for field: ModifierDetailField) -> some View {
        if let message = viewModel.fieldErrors[field] {
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 4)
        }
    }
}

/// Form-safe Mock/Live control. System `.segmented` picks get clipped inside
/// grouped form rows and look crooked on macOS.
private struct ModifierSourcePicker: View {
    @Binding var source: ModifierPreviewSource

    var body: some View {
        HStack(spacing: 2) {
            chip(title: "Mock", value: .mock)
            chip(title: "Live", value: .live)
        }
        .padding(2)
        .background(Color.secondary.opacity(0.2), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func chip(title: String, value: ModifierPreviewSource) -> some View {
        let selected = source == value
        return Button {
            source = value
        } label: {
            Text(title)
                .font(.callout.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .foregroundStyle(selected ? Color.black : Color.primary)
                .background(
                    selected ? Color.accentColor : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
        }
        .buttonStyle(.plain)
    }
}
