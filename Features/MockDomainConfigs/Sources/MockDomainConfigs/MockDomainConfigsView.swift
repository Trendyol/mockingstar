//
//  MockDomainConfigsView.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 16.10.2023.
//

import CommonKit
import CommonViewsKit
import SwiftUI
import TipKit

public struct MockDomainConfigsView: View {
    @Bindable var viewModel: MockDomainConfigsViewModel
    @AppStorage("mockDomain") var mockDomain: String = ""
    @Environment(NavigationStore.self) private var navigationStore: NavigationStore

    public init(viewModel: MockDomainConfigsViewModel) {
        self.viewModel = viewModel
    }

    @ViewBuilder
    private func mockConfiguration() -> some View {
        VStack(alignment: .leading) {
            Text("Mock Configurations")
                .font(.title3)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack {
                ToolBarButton(title: "Path Configurations", icon: "document.badge.gearshape", backgroundColor: .gray) {
                    navigationStore.open(.configs_pathConfigs)
                }
                ToolBarButton(title: "Query Configurations", icon: "document.badge.gearshape", backgroundColor: .gray) {
                    navigationStore.open(.configs_queryConfigs)
                }
                ToolBarButton(title: "Header Configurations", icon: "document.badge.gearshape", backgroundColor: .gray) {
                    navigationStore.open(.configs_headerConfigs)
                }
            }
        }
    }

    @ViewBuilder
    private func executionSelection() -> some View {
        VStack(alignment: .leading) {
            Text("Mock Configurations")
                .font(.title3)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)

            Picker(selection: $viewModel.appFilterConfigs.queryExecuteStyle) {
                ForEach(QueryExecuteStyle.allCases, id: \.self) { Text($0.title).tag($0) }
            } label: {
                HStack {
                    Text("Query Execution")
                    HelpButton { QueryExecutionTip.isTipPresented.toggle() }
                }
            }
            .frame(width: 400)

            TipView(QueryExecutionTip())
                .padding(.bottom)

            Picker(selection: $viewModel.appFilterConfigs.headerExecuteStyle) {
                ForEach(HeaderExecuteStyle.allCases, id: \.self) { Text($0.title).tag($0) }
            } label: {
                HStack {
                    Text("Header Execution")
                    HelpButton { HeaderExecutionTip.isTipPresented.toggle() }
                }
            }
            .frame(width: 400)

            TipView(HeaderExecutionTip())
                .padding(.bottom)
        }
    }

    @ViewBuilder
    private func domains() -> some View {
        VStack(alignment: .leading) {
            Text("Enabled Domains")
                .font(.title3)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    ForEach(viewModel.appFilterConfigs.domains) { domain in
                        MockDomainConfigsDomainView(domain: domain) {
                            viewModel.withMutation(keyPath: \.appFilterConfigs) {
                                viewModel.appFilterConfigs.domains.removeAll(where: { $0.domain == domain.domain })
                            }
                        }
                        .frame(width: 400)
                    }
                }

                Button {
                    withAnimation {
                        viewModel.withMutation(keyPath: \.appFilterConfigs) {
                            viewModel.appFilterConfigs.domains.append(.init(domain: .init()))
                        }
                    }
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(Color.accentColor)
                }
                .padding(.leading, 4)
            }
        }
    }

    @ViewBuilder
    private func pathMatchingRatio() -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Path Matching Ratio")
                    .font(.title3)
                    .fontWeight(.semibold)

                HelpButton { PathMatchingRatioTip.isTipPresented.toggle() }

                Spacer()
            }

            HStack {
                TextField(value: $viewModel.appFilterConfigs.pathMatchingRatio, format: .number, label: EmptyView.init)
                    .frame(width: 150)
                    .textFieldStyle(.roundedBorder)
                Slider(value: $viewModel.appFilterConfigs.pathMatchingRatio, in: 0...1)
                    .frame(maxWidth: 150)
            }

            TipView(PathMatchingRatioTip())
        }
    }

    @ViewBuilder
    private func filters() -> some View {
        Section {
            HStack {
                Text("Mock Filters")
                    .font(.title3)
                    .fontWeight(.semibold)

                HelpButton { EnhancedMockFilterTip.isTipPresented.toggle() }

                Spacer()
            }

            ForEach(Array(viewModel.mocksFilters.enumerated()), id: \.element.id) { index, filter in
                EnhancedMockFilterView(
                    filter: filter,
                    isLast: index == viewModel.mocksFilters.count - 1,
                    onDelete: {
                        withAnimation {
                            viewModel.removeFilter(id: filter.id)
                        }
                    }
                )
            }
            .onMove { source, destination in
                withAnimation {
                    viewModel.moveFilter(from: source, to: destination)
                }
            }

            ToolBarButton(title: "Add New Filter", icon: "camera.filters", backgroundColor: .gray) {
                withAnimation { viewModel.addNewFilter() }
            }

            TipView(EnhancedMockFilterTip())
        }
    }

    public var body: some View {
        List {
            mockConfiguration()
                .listRowSeparator(.hidden)
            Spacer().frame(height: 40)
            executionSelection()
                .listRowSeparator(.hidden)
            Spacer().frame(height: 40)
            domains()
                .listRowSeparator(.hidden)
            Spacer().frame(height: 40)
            pathMatchingRatio()
                .listRowSeparator(.hidden)
            Spacer().frame(height: 40)
            filters()
                .listRowSeparator(.hidden)
        }
        .contentMargins(20, for: .scrollContent)
        .toolbar {
            ToolbarItemGroup {
                ToolBarButton(title: "Save", icon: "tray.and.arrow.down", backgroundColor: .blue) {
                    viewModel.saveChanges()
                }
                .keyboardShortcut("s")

                SettingsLink {
                    HStack {
                        Image(systemName: "gear")
                        Text("Settings")
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                    .foregroundStyle(.white)
                    .background(.red)
                    .clipShape(.rect(cornerRadius: 10))
                }
                .buttonBorderShape(.roundedRectangle)
                .buttonStyle(.plain)
            }
        }
        .task(id: mockDomain) { viewModel.mockDomainUpdated(mockDomain: mockDomain) }
    }
}

#Preview {
    MockDomainConfigsView(viewModel: .init())
}

struct MockDomainConfigsDomainView: View {
    @Bindable private var domain: AppFilterConfigDomain
    private var onDelete: () -> Void

    init(domain: AppFilterConfigDomain, onDelete: @escaping () -> Void) {
        self.domain = domain
        self.onDelete = onDelete
    }

    var body: some View {
        HStack {
            TextField(text: $domain.domain, prompt: Text("trendyol.com"), label: EmptyView.init)
                .textFieldStyle(.roundedBorder)
            Button {
                onDelete()
            } label: {
                Image(systemName: "minus.circle")
                    .foregroundStyle(Color.accentColor)
            }
        }
    }
}

struct EnhancedMockFilterView: View {
    @Bindable private var filter: MockFilterConfigs
    private var isLast: Bool
    private var onDelete: () -> Void

    init(filter: MockFilterConfigs, isLast: Bool, onDelete: @escaping () -> Void) {
        self.filter = filter
        self.isLast = isLast
        self.onDelete = onDelete
    }

    var body: some View {
        VStack(spacing: .zero) {
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal")
                    .foregroundColor(.secondary)
                    .font(.caption)

                Group {
                    Picker(selection: $filter.selectedLocation, content: {
                        ForEach(FilterType.allCases, id: \.self) { Text($0.title).tag($0) }
                    }, label: EmptyView.init)
                    .frame(width: 100)

                    Picker(selection: $filter.selectedFilter, content: {
                        ForEach(FilterStyle.allCases, id: \.self) { Text($0.title).tag($0) }
                    }, label: EmptyView.init)
                    .frame(width: 120)

                    TextField("Filter value", text: $filter.inputText, prompt: Text("filter by value"), axis: .vertical)
                        .lineLimit(5)
                        .textFieldStyle(.roundedBorder)

                    Button("Remove", systemImage: "minus.circle", role: .destructive, action: onDelete)
                }
            }
            .padding(10)
            .background(.quinary)
            .clipShape(.rect(cornerRadius: 8))
            .padding(.horizontal)


            VStack(spacing: 1) {
                if filter.logicType == .and { Image(systemName: "chevron.up.2") }
                if filter.logicType == .or { Image(systemName: "chevron.up.dotted.2") }
                if filter.logicType.isAction { Text("Then").foregroundColor(.secondary) }

                Picker(selection: $filter.logicType, content: {
                    ForEach(FilterLogicType.allCases.filter { isLast ? $0.isAction : $0.isOperator }, id: \.self) { type in
                        Text(type.title).tag(type)
                    }
                }, label: EmptyView.init)
                .pickerStyle(.segmented)
                .frame(width: 100)

                if filter.logicType == .and { Image(systemName: "chevron.down.2") }
                if filter.logicType == .or { Image(systemName: "chevron.down.dotted.2") }
            }
            .padding(.vertical, 3)
        }
    }
}

// MARK: - Tip Views
struct PathMatchingRatioTip: Tip {
    @Parameter
    static var isTipPresented: Bool = false
    var rules: [Rule] {
        [
            #Rule(Self.$isTipPresented) {
                $0 == true
            }
        ]
    }

    var title: Text {
        Text("Path Matching Ratio")
    }

    var message: Text? {
        Text("In the app-wide configurations, instead of writing the entire path, you can enable the usage of configurations based on a minimum path matching ratio starting from the end. This means that if there is a minimum match ratio of paths from the end, the configuration will be used.")
    }

    var image: Image? {
        Image(systemName: "slider.horizontal.below.square.filled.and.square")
    }
}

struct QueryExecutionTip: Tip {
    @Parameter
    static var isTipPresented: Bool = false
    var rules: [Rule] {
        [
            #Rule(Self.$isTipPresented) {
                $0 == true
            }
        ]
    }

    var title: Text {
        Text("Is Query Matters to Mock?")
    }

    var message: Text? {
        Text("You can use mocks by ignoring all query parameters in a request. Conversely, you can use your mocks by matching all query parameters. This setting is default behavior for all paths, you can change this behavior for particular path using `Path Configs`.\n\nFor example, if you want to mock all queries for /api/v1/users, you can set this option to `Match All Query Items`. With this setting `/api/v1/users?id=1` and `/api/v1/users?id=2` are different mock. If you set this option to `Ignore All Query Items`, both of them are same mock.")
    }

    var image: Image? {
        Image(systemName: "questionmark")
    }
}

struct HeaderExecutionTip: Tip {
    @Parameter
    static var isTipPresented: Bool = false
    var rules: [Rule] {
        [
            #Rule(Self.$isTipPresented) {
                $0 == true
            }
        ]
    }

    var title: Text {
        Text("Is Header Matters to Mock?")
    }

    var message: Text? {
        Text("You can use mocks by ignoring all header parameters in a request. Conversely, you can use your mocks by matching all header parameters. This setting is default behavior for all paths, you can change this behavior for particular path using `Path Configs`.\n\nFor example, if you want to mock all headers for /api/v1/users, you can set this option to `Match All Header Items`. With this setting `Authorization: Bearer 123` and `Authorization: Bearer 456` are different mock. If you set this option to `Ignore All Header Items`, both of them are same mock.")
    }

    var image: Image? {
        Image(systemName: "questionmark")
    }
}

struct EnhancedMockFilterTip: Tip {
    @Parameter
    static var isTipPresented: Bool = false
    var rules: [Rule] {
        [
            #Rule(Self.$isTipPresented) {
                $0 == true
            }
        ]
    }

    var title: Text {
        Text("Enhanced Mock Filter")
    }

    var message: Text? {
        Text("Create filter rules with AND/OR logic and specify the action (Mock/Do Not Mock). Each filter can be chained with others using AND/OR operators. Use 'Mock' or 'Do Not Mock' to determine the final action for matching requests.\n\nExample: 'Path contains api AND Method equals GET' -> Mock")
    }

    var image: Image? {
        Image(systemName: "camera.filters")
    }
}
