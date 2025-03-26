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
    @SceneStorage("mockDomain") var mockDomain: String = ""
    @Environment(NavigationStore.self) private var navigationStore: NavigationStore

    public init(viewModel: MockDomainConfigsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            Form {
                LabeledContent("Mock Configurations") {
                    VStack(alignment: .leading) {
                        NavigationLink("Path Configurations") {
                            MockPathConfigurations(viewModel: viewModel)
                        }

                        NavigationLink("Query Configurations") {
                            MockQueryConfigurations(viewModel: viewModel)
                        }

                        NavigationLink("Header Configurations") {
                            MockHeaderConfigurations(viewModel: viewModel)
                        }
                    }
                }

                Picker(selection: $viewModel.appFilterConfigs.queryExecuteStyle) {
                    ForEach(QueryExecuteStyle.allCases, id: \.self) { Text($0.title).tag($0) }
                } label: {
                    Text("Query Execution")
                    HelpButton { QueryExecutionTip.isTipPresented.toggle() }
                }
                TipView(QueryExecutionTip())
                    .padding(.bottom)

                Picker(selection: $viewModel.appFilterConfigs.headerExecuteStyle) {
                    ForEach(HeaderExecuteStyle.allCases, id: \.self) { Text($0.title).tag($0) }
                } label: {
                    Text("Header Execution")
                    HelpButton { HeaderExecutionTip.isTipPresented.toggle() }
                }
                TipView(HeaderExecutionTip())
                    .padding(.bottom)

                LabeledContent("Domains") {
                    VStack {
                        ForEach(viewModel.appFilterConfigs.domains) { domain in
                            MockDomainConfigsDomainView(domain: domain) {
                                withAnimation {
                                    viewModel.withMutation(keyPath: \.appFilterConfigs) {
                                        viewModel.appFilterConfigs.domains.removeAll(where: { $0.domain == domain.domain })
                                    }
                                }
                            }
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

                LabeledContent("Path Matching Ratio") {
                    VStack {
                        TextField(value: $viewModel.appFilterConfigs.pathMatchingRatio, format: .number, label: EmptyView.init)
                        Slider(value: $viewModel.appFilterConfigs.pathMatchingRatio, in: 0...1)

                        TipView(PathMatchingRatioTip())
                    }
                }

                Divider()

                LabeledContent("Filters") {
                    HStack(alignment: .top) {
                        VStack {
                            ForEach(viewModel.mocksFilters) { filter in
                                MockDomainConfigsMockFilterView(filter: filter) {
                                    withAnimation {
                                        viewModel.withMutation(keyPath: \.mocksFilters) {
                                            viewModel.mocksFilters.removeAll(where: { $0.id == filter.id })
                                        }
                                    }
                                }
                            }
                        }

                        Button {
                            withAnimation {
                                viewModel.withMutation(keyPath: \.mocksFilters) {
                                    viewModel.mocksFilters.append(.init(inputText: .init()))
                                }
                            }
                        } label: {
                            Image(systemName: "plus.circle")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }

                TipView(MockFilterTip())

                Spacer()
            }
        }
        .contentMargins(.vertical, 20)
        .padding(.horizontal)
        .background(.background)
        .toolbar {
            ToolbarItemGroup {
                ToolBarButton(title: "Save", icon: "tray.and.arrow.down", backgroundColor: .blue) {
                    viewModel.saveChanges()
                }
                .keyboardShortcut("s")

                ToolBarButton(title: "Settings", icon: "gear", backgroundColor: .red) {
                    navigationStore.path.append(.appSettings)
                }
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

struct MockDomainConfigsMockFilterView: View {
    @Bindable private var filter: MockFilterConfigs
    private var onDelete: () -> Void

    init(filter: MockFilterConfigs, onDelete: @escaping () -> Void) {
        self.filter = filter
        self.onDelete = onDelete
    }

    var body: some View {
        GeometryReader { geometryProxy in
            HStack {
                Toggle(isOn: $filter.isActive, label: EmptyView.init)
                Picker(selection: $filter.selectedLocation, content: {
                    ForEach(FilterType.allCases, id: \.self) { Text($0.title).tag($0) }
                }, label: EmptyView.init).frame(width: geometryProxy.size.width * 0.15)
                Picker(selection: $filter.selectedFilter, content: {
                    ForEach(FilterStyle.allCases, id: \.self) { Text($0.title).tag($0) }
                }, label: EmptyView.init).frame(width: geometryProxy.size.width * 0.15)
                TextField(text: $filter.inputText, label: EmptyView.init)
                    .textFieldStyle(.roundedBorder)

                Button {
                    onDelete()
                } label: {
                    Image(systemName: "minus.circle")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .padding(.bottom, 8)
    }
}

struct MockFilterTip: Tip {
    var title: Text {
        Text("Mock Filter")
    }

    var message: Text? {
        Text("When saving a new mock, filter check is performed to determine whether mock should be saved. This filter check allows you to configure whether a mock should be saved or not. If there are multiple filters, having at least one filter that matches is sufficient for to be saved.")
    }

    var image: Image? {
        Image(systemName: "camera.filters")
    }
}

struct PathMatchingRatioTip: Tip {
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
