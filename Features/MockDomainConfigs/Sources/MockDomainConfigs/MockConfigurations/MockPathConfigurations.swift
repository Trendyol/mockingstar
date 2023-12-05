//
//  MockPathConfigurations.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 20.10.2023.
//

import CommonKit
import CommonViewsKit
import SwiftUI

public struct MockPathConfigurations: View {
    @Bindable var viewModel: MockDomainConfigsViewModel
    @State private var selected: UUID? = nil
    @State private var path: String = ""
    @State private var executeAllQueries: Bool = false
    @State private var executeAllHeaders: Bool = false
    @State private var shouldShowInspectorView: Bool = true
    @SceneStorage("mockDomain") var mockDomain: String = ""

    public init(viewModel: MockDomainConfigsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Table(viewModel.pathConfigs, selection: $selected) {
            TableColumn("Path", value: \.path)
            TableColumn("Execute All Queries", value: \.executeAllQueries.description)
            TableColumn("Execute All Headers", value: \.executeAllHeaders.description)
        }
        .onChange(of: selected) { (_, selectedId) in
            guard let config = viewModel.pathConfigs.first(where: { $0.id == selectedId }) else { return }
            path = config.path
            executeAllQueries = config.executeAllQueries
            executeAllHeaders = config.executeAllHeaders
        }
        .inspector(isPresented: $shouldShowInspectorView) {
            Form {
                TextField("Path", text: $path, prompt: Text("/about-us"), axis: .vertical)
                    .lineLimit(1...10)

                LabeledContent("Execute All Queries") { Toggle(isOn: $executeAllQueries, label: EmptyView.init).toggleStyle(.switch) }
                LabeledContent("Execute All Headers") { Toggle(isOn: $executeAllHeaders, label: EmptyView.init).toggleStyle(.switch) }

                VStack {
                    Button {
                        if let selected, let index = viewModel.pathConfigs.firstIndex(where: { $0.id == selected }) {
                            viewModel.withMutation(keyPath: \.pathConfigs) {
                                viewModel.pathConfigs[index].path = path
                                viewModel.pathConfigs[index].executeAllQueries = executeAllQueries
                                viewModel.pathConfigs[index].executeAllHeaders = executeAllHeaders
                                self.selected = viewModel.pathConfigs[index].id
                            }
                        } else {
                            viewModel.withMutation(keyPath: \.pathConfigs) {
                                let config = MockPathConfigModel(path: path,
                                                                 executeAllQueries: executeAllQueries,
                                                                 executeAllHeaders: executeAllHeaders)
                                viewModel.pathConfigs.append(config)
                                selected = config.id
                            }
                        }

                    } label: {
                        Text("Save")
                            .frame(maxWidth: .infinity)
                            .padding(8)
                            .background(Color.accentColor)
                            .clipShape(.rect(cornerRadius: 10))
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.plain)
                    .padding([.horizontal, .top])

                    if let selected {
                        Button {
                            viewModel.withMutation(keyPath: \.pathConfigs) {
                                viewModel.pathConfigs.removeAll(where: { $0.id == selected })
                                self.selected = nil
                            }
                        } label: {
                            Text("Delete")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem {
                ToolBarButton(title: "Save", icon: "tray.and.arrow.down", backgroundColor: .blue) {
                    viewModel.saveChanges()
                }
                .keyboardShortcut("s")
            }
            
            ToolbarItem {
                ToolBarButton(title: "New", icon: "plus.circle", backgroundColor: .accentColor) {
                    selected = nil
                    path = .init()
                    executeAllQueries = false
                    executeAllHeaders = false
                    shouldShowInspectorView = true
                }
            }

            ToolbarItem {
                Button {
                    shouldShowInspectorView = !shouldShowInspectorView
                } label: {
                    Label("Hide Inspector", systemImage: "sidebar.trailing")
                }
            }
        }
        .navigationBarBackButtonHidden(false)
        .navigationTitle("Path Configs")
        .task(id: mockDomain) { viewModel.mockDomainUpdated(mockDomain: mockDomain) }
    }
}

#Preview {
    MockPathConfigurations(viewModel: .init())
}
