//
//  MockListView.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 15.09.2023.
//

import CommonKit
import CommonViewsKit
import MockingStarCore
import SwiftUI

public struct MockListView: View {
    @Bindable var viewModel: MockListViewModel
    @Environment(NavigationStore.self) private var navigationStore: NavigationStore
    @SceneStorage("mockDomain") var mockDomain: String = ""
    @AppStorage("MockListColumnCustomization") private var columnCustomization: TableColumnCustomization<MockModel>
    @AppStorage("isFirstOpen") private var isFirstOpen: Bool = true
    @State private var isSearchActive: Bool = false

    public init(viewModel: MockListViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        GeometryReader { geometryProxy in
            Table(viewModel.mockListUIModel, selection: $viewModel.selected, sortOrder: $viewModel.sortOrder, columnCustomization: $columnCustomization) {
                TableColumn("Method", value: \.metaData.method) { mock in
                    HStack {
                        Spacer()
                        Text(mock.metaData.method)
                            .foregroundStyle(.white)
                            .font(.callout.monospaced())
                        Spacer()
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 2)
                    .background(MethodColor.method(name: mock.metaData.method).color)
                    .clipShape(.rect(cornerRadius: 6))
                }
                .width(min: 50, ideal: 60, max: 70)
                .customizationID("Method")

                TableColumn("Request", value: \.metaData.url.absoluteString) { mock in
                    VStack(alignment: .leading) {
                        Text(mock.metaData.url.path())
                            .help(mock.metaData.url.path())

                        if let query = mock.metaData.url.query() {
                            Text(query)
                                .font(.footnote)
                                .help(query)
                        }
                    }
                    .padding(.vertical, 8)
                }

                TableColumn("HTTP Status", value: \.metaData.httpStatus) { mock in
                    Text(mock.metaData.httpStatus, format: .number)
                        .font(.callout)
                }
                .width(80)
                .customizationID("HTTPStatus")

                TableColumn("Scenario", value: \.metaData.scenario) { mock in
                    Text(mock.metaData.scenario)
                        .font(.callout)
                        .help(mock.metaData.scenario)
                }
                .width(min: (geometryProxy.size.width - 300)/3, ideal: (geometryProxy.size.width - 200)/3, max: (geometryProxy.size.width - 100)/3)
                .customizationID("Scenario")

                TableColumn("Response Time", value: \.metaData.responseTime) { mock in
                    Text(mock.metaData.responseTime, format: .number)
                        .font(.callout)
                }
                .width(90)
                .customizationID("ResponseTime")

                TableColumn("Last Updated", value: \.metaData.updateTime) { mock in
                    Text(mock.metaData.updateTime, style: .relative)
                        .font(.callout)
                }
                .width(90)
                .customizationID("LastUpdated")

                TableColumn("Created", value: \.metaData.appendTime) { mock in
                    Text(mock.metaData.appendTime, style: .relative)
                        .font(.callout)
                }
                .width(90)
                .customizationID("Created")
            }
            .contextMenu(forSelectionType: MockModel.ID.self, menu: { selections in
                if selections.count == 1 {
                    Button("Open Mock Detail") {
                        if let id = selections.first,
                           let mock = viewModel.mock(id: id) {
                            withAnimation {
                                navigationStore.path.append(.mock(mock))
                            }
                        }
                    }
                    Divider()
                }

                Button("Remove Selected", role: .destructive) {
                    viewModel.shouldShowDeleteConfirmation = true
                }

                Menu("Share", systemImage: "square.and.arrow.up") {
                    ForEach(ShareStyle.allCases, id: \.self) { shareStyle in
                        Button(shareStyle.rawValue) { viewModel.shareButtonTapped(shareStyle: shareStyle)}
                    }
                }
            }) { selections in
                if let id = selections.first,
                   let mock = viewModel.mock(id: id) {
                    withAnimation {
                        navigationStore.path.append(.mock(mock))
                    }
                }
            }
        }
        .overlay {
            if viewModel.isLoading { ProgressView() }
        }
        .toolbar {
            ToolbarItemGroup {
                Button(action: { isSearchActive = true }, label: EmptyView.init)
                    .keyboardShortcut("f")
                    .hidden()

                Button(action: { viewModel.reloadMocks() }, label: EmptyView.init)
                    .keyboardShortcut("r")
                    .hidden()

                ActionSelectableButton(title: "Delete", icon: "trash", backgroundColor: .red) {
                    viewModel.shouldShowDeleteConfirmation = true
                } menuContent: {
                    Group {
                        Button("Select All") {
                            withAnimation { viewModel.selected = .init(viewModel.mockListUIModel.map(\.id)) }
                        }

                        Button("Unselect All") {
                            withAnimation { viewModel.selected.removeAll() }
                        }
                    }
                }
                .disabled(viewModel.selected.isEmpty)

                HStack(spacing: .zero) {
                    VStack(spacing: .zero) {
                        Menu {
                            ForEach(FilterType.allCases, id: \.self) { type in
                                Button {
                                    viewModel.filterType = type
                                } label: {
                                    Text(type.title)
                                }
                            }
                        } label: {
                            Text(viewModel.filterType.title)
                                .font(.caption2)
                        }

                        Menu {
                            ForEach(FilterStyle.allCases, id: \.self) { type in
                                Button {
                                    viewModel.filterStyle = type
                                } label: {
                                    Text(type.title)
                                }
                            }
                        } label: {
                            Text(viewModel.filterStyle.title)
                                .font(.caption2)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 6)
                    .padding(.vertical, 2)

                    Divider()
                        .padding(.trailing, 6)

                    CustomSearchbar(text: $viewModel.searchTerm, isSearchActive: $isSearchActive, placeholderCount: $viewModel.mockListCount)
                        .frame(width: 200)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(viewModel.searchTerm.isEmpty ? Color.secondary : Color.accentColor, lineWidth: 1)
                )
            }
        }
        .onAppear {
            if isFirstOpen {
                isFirstOpen = false
                columnCustomization[visibility: "Created"] = .hidden
                columnCustomization[visibility: "ResponseTime"] = .hidden
                columnCustomization[visibility: "HTTPStatus"] = .hidden
            }
        }
        .confirmationDialog("Are you sure?", isPresented: $viewModel.shouldShowDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                viewModel.deleteSelectedMocks()
            }
        } message: {
            Text("Deleting selected mocks will also delete all associated mock responses. Are you sure you want to do this?") +
            Text("\n\n") +
            Text("You will delete ^[\(viewModel.selected.count) \("mock")](inflect: true).")
        }
        .alert("Error", isPresented: $viewModel.shouldShowErrorMessage, actions: {
            Button("Ok", role: .cancel, action: { })
        }, message: {
            Text(viewModel.errorMessage)
        })
        .task(id: viewModel.sortOrder) { await viewModel.searchData() }
        .task(id: viewModel.mockModelList) { await viewModel.searchData() }
        .task(id: viewModel.searchTerm) { await viewModel.searchData() }
        .task(id: viewModel.filterType) { await viewModel.searchData() }
        .task(id: viewModel.filterStyle) { await viewModel.searchData() }
        .task(id: mockDomain) { await viewModel.mockDomainChanged(mockDomain) }
        .onReceive(NotificationCenter.default.publisher(for: .reloadMocks)) { _ in
            viewModel.reloadMocks()
        }
        .onReceive(NotificationCenter.default.publisher(for: .selectAllMocks)) { _ in
            withAnimation { viewModel.selected = .init(viewModel.mockListUIModel.map(\.id)) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .deselectAllMocks)) { _ in
            withAnimation { viewModel.selected.removeAll() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .removeMock)) { _ in
            viewModel.shouldShowDeleteConfirmation = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .fileIntegrityCheck)) { _ in
            navigationStore.path.append(.fileIntegrityCheck)
        }
    }
}

#Preview {
    MockListView(viewModel: .init())
}
