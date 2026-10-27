import CommonKit
import CommonViewsKit
import SwiftUI
import UniformTypeIdentifiers

public struct MockModifierListView: View {
    @Bindable private var viewModel: MockModifierListViewModel
    @AppStorage("mockDomain") private var mockDomain: String = "Dev"
    @State private var isSearchActive = false

    public init(viewModel: MockModifierListViewModel = .init()) {
        self.viewModel = viewModel
    }

    public var body: some View {
        content
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .navigationTitle("Modifiers")
        .toolbar {
            ToolbarItemGroup {
                Button(action: { isSearchActive = true }, label: EmptyView.init)
                    .keyboardShortcut("f")
                    .buttonStyle(.plain)
                    .hidden()

                Button(action: { Task { await viewModel.load(domain: mockDomain) } }, label: EmptyView.init)
                    .keyboardShortcut("r")
                    .buttonStyle(.plain)
                    .hidden()

                ToolBarButton(title: "Refresh", icon: "arrow.clockwise", backgroundColor: .gray) {
                    Task { await viewModel.load(domain: mockDomain) }
                }
                ToolBarButton(title: "New Modifier", icon: "plus", backgroundColor: .blue) {
                    viewModel.shouldShowCreateSheet = true
                }
                RichSearchBar(
                    filterType: $viewModel.filterType,
                    filterStyle: $viewModel.filterStyle,
                    searchTerm: $viewModel.searchTerm,
                    placeHolderCount: .constant(viewModel.filteredModifiers.count),
                    isSearchActive: $isSearchActive,
                    availableFilterTypes: [.all, .path, .scenario, .method]
                )
            }
            .disableSharedBackground()
        }
        .task(id: mockDomain) {
            await viewModel.load(domain: mockDomain)
        }
        .onAppear {
            // Reload after returning from detail; NavigationStack can recreate this
            // destination with a wiped in-memory list while .task is cancelled.
            Task { await viewModel.load(domain: mockDomain) }
        }
        .alert("Error", isPresented: $viewModel.shouldShowErrorMessage) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
        .confirmationDialog(viewModel.deleteConfirmationTitle, isPresented: $viewModel.shouldShowDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task { await viewModel.deletePending(domain: mockDomain) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $viewModel.shouldShowCreateSheet) {
            MockModifierCreateSheet(seed: .empty, domain: mockDomain) { id, previewSeed in
                viewModel.shouldShowCreateSheet = false
                Task { await viewModel.load(domain: mockDomain) }
                viewModel.openDetail(id: id, previewSeed: previewSeed)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.filteredModifiers.isEmpty {
            ContentUnavailableView(
                "No Modifiers",
                systemImage: "slider.horizontal.3",
                description: Text("Create a modifier to transform live or mock responses.")
            )
        } else {
            MockModifierListTable(
                viewModel: viewModel,
                mockDomain: mockDomain
            )
        }
    }
}

private struct MockModifierListTable: View {
    @Bindable var viewModel: MockModifierListViewModel
    let mockDomain: String

    var body: some View {
        GeometryReader { geometryProxy in
            let requestWidthMin = (geometryProxy.size.width - 300) / 3
            let requestWidthIdeal = (geometryProxy.size.width - 200) / 3

            table(requestWidthMin: requestWidthMin, requestWidthIdeal: requestWidthIdeal)
        }
    }

    @ViewBuilder
    private func table(requestWidthMin: CGFloat, requestWidthIdeal: CGFloat) -> some View {
        Table(viewModel.filteredModifiers, selection: $viewModel.selected) {
            TableColumn("Active") { (modifier: MockModifierModel) in
                MockModifierActivationPicker(selection: modifier.source) { newSource in
                    Task { await viewModel.setSource(modifier, source: newSource, domain: mockDomain) }
                }
            }
            .width(90)

            TableColumn("Method") { (modifier: MockModifierModel) in
                HTTPMethodBadge(method: modifier.method)
            }
            .width(min: 50, ideal: 60, max: 70)

            TableColumn("Request") { (modifier: MockModifierModel) in
                Text(modifier.path)
                    .help(modifier.path)
                    .padding(.vertical, 8)
            }
            .width(min: requestWidthMin, ideal: requestWidthIdeal)

            TableColumn("Scenario") { (modifier: MockModifierModel) in
                Text(modifier.scenario ?? "—")
                    .font(.callout)
                    .help(modifier.scenario ?? "")
            }
            .width(min: requestWidthMin, ideal: requestWidthIdeal)

            TableColumn("Order") { (modifier: MockModifierModel) in
                Text("\(modifier.order)")
                    .font(.callout)
            }
            .width(60)

            TableColumn("ID") { (modifier: MockModifierModel) in
                Text(modifier.id)
                    .font(.callout)
                    .help(modifier.id)
            }
        }
        .contextMenu(forSelectionType: MockModifierModel.ID.self) { selections in
            if selections.count == 1, let id = selections.first {
                Button("Open Modifier Detail") { viewModel.openDetail(id: id) }
                Button("Duplicate") {
                    Task { await viewModel.duplicate(id: id, domain: mockDomain) }
                }
                Divider()
            }
            Button("Delete", role: .destructive) {
                viewModel.confirmDelete(ids: Array(selections))
            }
        } primaryAction: { selections in
            guard let id = selections.first else { return }
            viewModel.openDetail(id: id)
        }
        .onCopyCommand {
            viewModel.copySelected()
        }
        .onPasteCommand(of: [.plainText], perform: { _ in
            Task { await viewModel.paste(domain: mockDomain) }
        })
    }
}
