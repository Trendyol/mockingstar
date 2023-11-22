//
//  MockDomainConfigsView.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 16.10.2023.
//

import CommonKit
import CommonViewsKit
import SwiftUI

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

                LabeledContent("Query Filter Default Style Ignore") {
                    Toggle(isOn: $viewModel.appFilterConfigs.queryFilterDefaultStyleIgnore, label: EmptyView.init)
                        .toggleStyle(.switch)
                }

                LabeledContent("Header Filter Default Style Ignore") {
                    Toggle(isOn: $viewModel.appFilterConfigs.headerFilterDefaultStyleIgnore, label: EmptyView.init)
                        .toggleStyle(.switch)
                }

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
