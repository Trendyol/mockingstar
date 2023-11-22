//
//  MockQueryConfigurations.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 20.10.2023.
//

import CommonViewsKit
import SwiftUI

public struct MockQueryConfigurations: View {
    @Bindable var viewModel: MockDomainConfigsViewModel
    @State private var selected: UUID? = nil
    @State private var paths: [MockDomainConfigPathModel] = []
    @State private var key: String = ""
    @State private var value: String = ""
    @State private var shouldShowInspectorView: Bool = true
    @SceneStorage("mockDomain") var mockDomain: String = ""

    public init(viewModel: MockDomainConfigsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Table(viewModel.queryConfigs, selection: $selected) {
            TableColumn("Key", value: \.key)
            TableColumn("Value", value: \.value)
            TableColumn("Path", value: \.path.description)
        }
        .onChange(of: selected) { (_, selectedId) in
            guard let config = viewModel.queryConfigs.first(where: { $0.id == selectedId }) else { return }
            paths = config.path.map { .init(path: $0) }
            key = config.key
            value = config.value
        }
        .inspector(isPresented: $shouldShowInspectorView) {
            Form {
                LabeledContent("Paths") {
                    VStack(alignment: .trailing) {
                        ForEach($paths) { $path in
                            HStack {
                                TextField(text: $path.path, prompt: Text("/about-us"), axis: .vertical, label: EmptyView.init)
                                    .lineLimit(1...10)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(maxWidth: .infinity)
                                Button {
                                    withAnimation { paths.removeAll(where: { $0 == $path.wrappedValue }) }
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                        Button {
                            withAnimation {
                                paths.append(.init(path: .init()))
                            }
                        } label: {
                            Image(systemName: "plus.circle")
                                .foregroundStyle(Color.accentColor)
                        }
                        .padding(.leading, 4)
                    }
                }

                TextField("Key", text: $key, prompt: Text("id"), axis: .vertical)
                    .lineLimit(1...10)

                TextField("Value", text: $value, prompt: Text("123"), axis: .vertical)
                    .lineLimit(1...10)
                
                VStack {
                    Button {
                        if let selected, let index = viewModel.queryConfigs.firstIndex(where: { $0.id == selected }) {
                            viewModel.withMutation(keyPath: \.queryConfigs) {
                                viewModel.queryConfigs[index].path = paths.map(\.path)
                                viewModel.queryConfigs[index].key = key
                                viewModel.queryConfigs[index].value = value
                                self.selected = viewModel.queryConfigs[index].id
                            }
                        } else {
                            viewModel.withMutation(keyPath: \.queryConfigs) {
                                let config = MockQueryConfigModel(path: paths.map(\.path),
                                                                  key: key,
                                                                  value: value)
                                viewModel.queryConfigs.append(config)
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
                    .padding()

                    if let selected {
                        Button {
                            viewModel.withMutation(keyPath: \.queryConfigs) {
                                viewModel.queryConfigs.removeAll(where: { $0.id == selected })
                                self.selected = nil
                            }
                        } label: {
                            Text("Delete")
                                .frame(maxWidth: .infinity)
                                .padding(4)
                                .background(Color.secondary)
                                .clipShape(.rect(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .padding()
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
                    paths.removeAll()
                    key = ""
                    value = ""
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
        .navigationTitle("Query Configs")
        .task(id: mockDomain) { viewModel.mockDomainUpdated(mockDomain: mockDomain) }
    }
}

#Preview {
    MockQueryConfigurations(viewModel: .init())
}
