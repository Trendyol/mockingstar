import CommonKit
import CommonViewsKit
import SwiftUI

public struct ModifierListView: View {
    @Bindable private var viewModel: ModifierListViewModel
    @AppStorage("mockDomain") private var mockDomain: String = "Dev"

    public init(viewModel: ModifierListViewModel = .init()) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Search modifiers", text: $viewModel.searchTerm)
                    .textFieldStyle(.roundedBorder)
                Spacer()
            }
            .padding()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .navigationTitle("Modifiers")
        .toolbar {
            ToolbarItemGroup {
                ToolBarButton(title: "Refresh", icon: "arrow.clockwise", backgroundColor: .gray) {
                    Task { await viewModel.load(domain: mockDomain) }
                }
                ToolBarButton(title: "New Modifier", icon: "plus", backgroundColor: .blue) {
                    viewModel.shouldShowCreateSheet = true
                }
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
        .confirmationDialog("Delete modifier?", isPresented: $viewModel.shouldShowDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task { await viewModel.deletePending(domain: mockDomain) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $viewModel.shouldShowCreateSheet) {
            ModifierCreateSheet(seed: .empty, domain: mockDomain) { id, previewSeed in
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
            ModifierListTable(
                viewModel: viewModel,
                mockDomain: mockDomain
            )
        }
    }
}

private struct ModifierListTable: View {
    @Bindable var viewModel: ModifierListViewModel
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
            TableColumn("Active") { (modifier: ModifierModel) in
                Toggle(
                    "",
                    isOn: Binding(
                        get: { modifier.enabled },
                        set: { _ in
                            Task { await viewModel.toggleEnabled(modifier, domain: mockDomain) }
                        }
                    )
                )
                .labelsHidden()
            }
            .width(70)

            TableColumn("Method") { (modifier: ModifierModel) in
                HTTPMethodBadge(method: modifier.method)
            }
            .width(min: 50, ideal: 60, max: 70)

            TableColumn("Request") { (modifier: ModifierModel) in
                Text(modifier.path)
                    .help(modifier.path)
                    .padding(.vertical, 8)
            }
            .width(min: requestWidthMin, ideal: requestWidthIdeal)

            TableColumn("Scenario") { (modifier: ModifierModel) in
                Text(modifier.scenario ?? "—")
                    .font(.callout)
                    .help(modifier.scenario ?? "")
            }
            .width(min: requestWidthMin, ideal: requestWidthIdeal)

            TableColumn("Order") { (modifier: ModifierModel) in
                Text("\(modifier.order)")
                    .font(.callout)
            }
            .width(60)

            TableColumn("ID") { (modifier: ModifierModel) in
                Text(modifier.id)
                    .font(.callout)
                    .help(modifier.id)
            }
        }
        .contextMenu(forSelectionType: ModifierModel.ID.self) { selections in
            if selections.count == 1, let id = selections.first {
                Button("Open Modifier Detail") { viewModel.openDetail(id: id) }
                Divider()
            }
            Button("Delete", role: .destructive) {
                guard let id = selections.first else { return }
                viewModel.confirmDelete(id: id)
            }
        } primaryAction: { selections in
            guard let id = selections.first else { return }
            viewModel.openDetail(id: id)
        }
    }
}
