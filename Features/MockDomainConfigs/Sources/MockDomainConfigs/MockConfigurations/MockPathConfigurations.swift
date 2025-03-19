//
//  MockPathConfigurations.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 20.10.2023.
//

import CommonKit
import CommonViewsKit
import SwiftUI
import TipKit

public struct MockPathConfigurations: View {
    @Bindable var viewModel: MockDomainConfigsViewModel
    @State private var selected: UUID? = nil
    @State private var path: String = ""
    @State private var queryExecuteStyle: QueryExecuteStyle = .ignoreAll
    @State private var headerExecuteStyle: HeaderExecuteStyle = .ignoreAll
    @State private var shouldShowInspectorView: Bool = true
    @SceneStorage("mockDomain") var mockDomain: String = ""

    public init(viewModel: MockDomainConfigsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Table(viewModel.pathConfigs, selection: $selected) {
            TableColumn("Path", value: \.path)
            TableColumn("Execute All Queries", value: \.queryExecuteStyle.title)
                .width(max: 200)
            TableColumn("Execute All Headers", value: \.headerExecuteStyle.title)
                .width(max: 200)
        }
        .contextMenu(forSelectionType: MockHeaderConfigModel.ID.self, menu: { selections in
            Button("Remove") {
                viewModel.withMutation(keyPath: \.pathConfigs) {
                    viewModel.pathConfigs.removeAll(where: { $0.id == selected })
                    self.selected = nil
                }
            }
        }, primaryAction: { selections in
            guard let config = viewModel.pathConfigs.first(where: { $0.id == selections.first }) else { return }
            path = config.path
            queryExecuteStyle = config.queryExecuteStyle
            headerExecuteStyle = config.headerExecuteStyle
        })
        .onChange(of: selected) { (_, selectedId) in
            guard let config = viewModel.pathConfigs.first(where: { $0.id == selectedId }) else { return }
            path = config.path
            queryExecuteStyle = config.queryExecuteStyle
            headerExecuteStyle = config.headerExecuteStyle
        }
        .onChange(of: path) { save() }
        .onChange(of: queryExecuteStyle) { save() }
        .onChange(of: headerExecuteStyle) { save() }
        .inspector(isPresented: $shouldShowInspectorView) {
            Form {
                if #available(macOS 15.0, *) {
                    TextField("Path", text: $path, prompt: Text("/about-us"), axis: .vertical)
                        .lineLimit(1...10)
                        .textInputSuggestions {
                            ForEach(recommendedPaths(), id: \.self) { suggestedPath in
                                Text(suggestedPath)
                                    .textInputCompletion(suggestedPath)
                            }
                        }
                } else {
                    TextField("Path", text: $path, prompt: Text("/about-us"), axis: .vertical)
                        .lineLimit(1...10)
                }

                Section {
                    Picker("Query Execution", selection: $queryExecuteStyle) {
                        ForEach(QueryExecuteStyle.allCases, id: \.self) { Text($0.title).tag($0) }
                    }

                    VStack(alignment: .leading) {
                        Text("You can use mocks by ignoring all query parameters in a request. Conversely, you can use your mocks by matching all query parameters.\n\nFor example, if you want to mock all queries for /api/v1/users, you can set this option to `Match All Query Items`. With this setting `/api/v1/users?id=1` and `/api/v1/users?id=2` are different mock. If you set this option to `Ignore All Query Items`, both of them are same mock.")
                        Text("Default behavior for all paths is `\(viewModel.appFilterConfigs.queryExecuteStyle.title)`.")
                            .padding(.top)
                    }
                    .font(.footnote)
                }

                Section {
                    Picker("Header Execution", selection: $headerExecuteStyle) {
                        ForEach(HeaderExecuteStyle.allCases, id: \.self) { Text($0.title).tag($0) }
                    }

                    VStack(alignment: .leading) {
                        Text("You can use mocks by ignoring all header parameters in a request. Conversely, you can use your mocks by matching all header parameters.\n\nFor example, if you want to mock all headers for /api/v1/users, you can set this option to `Match All Header Items`. With this setting `Authorization: Bearer 123` and `Authorization: Bearer 456` are different mock. If you set this option to `Ignore All Header Items`, both of them are same mock.")
                        Text("Default behavior for all paths is `\(viewModel.appFilterConfigs.headerExecuteStyle.title)`.").padding(.top)
                    }
                    .font(.footnote)
                }

                TipView(PathConfigsTip())
            }
            .inspectorColumnWidth(min: 400, ideal: 400, max: 1000)
        }
        .toolbar {
            ToolbarItem {
                if let selected {
                    ToolBarButton(title: "Remove", icon: "trash", backgroundColor: .red) {
                        viewModel.withMutation(keyPath: \.pathConfigs) {
                            viewModel.pathConfigs.removeAll(where: { $0.id == selected })
                            self.selected = nil
                        }
                    }
                }
            }

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
                    queryExecuteStyle = .ignoreAll
                    headerExecuteStyle = .ignoreAll
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
        .onAppear {
            queryExecuteStyle = viewModel.appFilterConfigs.queryExecuteStyle
            headerExecuteStyle = viewModel.appFilterConfigs.headerExecuteStyle
        }
    }

    private func recommendedPaths() -> [String] {
        let pathComponents = path.split(separator: "/")

        return viewModel.allPaths.filter { mockPath in
            let mockPathComponents = mockPath.split(separator: "/")

            guard !mockPath.isEmpty else { return true }
            guard pathComponents.count < mockPathComponents.count else { return false }

            for startIndex in 0...(mockPathComponents.count - pathComponents.count) {
                var matches = true

                for (index, component) in pathComponents.enumerated() {
                    let mockComponent = mockPathComponents[startIndex + index]

                    if component == "*" || mockComponent.hasPrefix(component) {
                        continue
                    }

                    if component.contains("*") {
                        let pattern = component.replacingOccurrences(of: "*", with: ".*")
                        let regex = try? NSRegularExpression(pattern: pattern)
                        let range = NSRange(mockComponent.startIndex..., in: mockComponent)
                        matches = regex?.firstMatch(in: String(mockComponent), range: range) != nil
                    } else {
                        matches = false
                    }

                    if !matches {
                        break
                    }
                }

                if matches {
                    return true
                }
            }

            return false
        }
    }

    private func save() {
        guard !path.isEmpty else { return }

        if let selected, let index = viewModel.pathConfigs.firstIndex(where: { $0.id == selected }) {
            viewModel.withMutation(keyPath: \.pathConfigs) {
                viewModel.pathConfigs[index].path = path
                viewModel.pathConfigs[index].queryExecuteStyle = queryExecuteStyle
                viewModel.pathConfigs[index].headerExecuteStyle = headerExecuteStyle
                self.selected = viewModel.pathConfigs[index].id
            }
        } else {
            viewModel.withMutation(keyPath: \.pathConfigs) {
                let config = MockPathConfigModel(path: path,
                                                 queryExecuteStyle: queryExecuteStyle,
                                                 headerExecuteStyle: headerExecuteStyle)
                viewModel.pathConfigs.append(config)
                selected = config.id
            }
        }
    }
}

#Preview {
    MockPathConfigurations(viewModel: .init())
}

struct PathConfigsTip: Tip {
    var title: Text {
        Text("Path Configurations")
    }

    var message: Text? {
        Text("Mocking Star uses exact matching of request paths to determine mocks. \nHowever, there are cases where path components can be ignored. Path Configurations allow you to modify the path matching style.")
    }

    var actions: [Action] {
        Action(title: "Open Documentations") {
            NSWorkspace.shared.open(URL(string: "https://trendyol.github.io/mockingstar/documentation/mockingstar/configurations")!)
        }
    }
}
