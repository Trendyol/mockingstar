//
//  MockHeaderConfigurations.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 20.10.2023.
//

import CommonViewsKit
import SwiftUI
import TipKit

public struct MockHeaderConfigurations: View {
    @Bindable var viewModel: MockDomainConfigsViewModel
    @State private var selected: UUID? = nil
    @State private var paths: [MockDomainConfigPathModel] = []
    @State private var key: String = ""
    @State private var value: String = ""
    @State private var shouldShowInspectorView: Bool = true
    @AppStorage("mockDomain") var mockDomain: String = ""

    public init(viewModel: MockDomainConfigsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Table(viewModel.headerConfigs, selection: $selected) {
            TableColumn("Key", value: \.key)
            TableColumn("Value", value: \.value)
            TableColumn("Path", value: \.path.description)
        }
        .contextMenu(forSelectionType: MockHeaderConfigModel.ID.self, menu: { selections in
            Button("Remove") {
                viewModel.withMutation(keyPath: \.headerConfigs) {
                    viewModel.headerConfigs.removeAll(where: { selections.contains($0.id) })
                    self.selected = nil
                }
            }
        }, primaryAction: { selections in
            guard let config = viewModel.headerConfigs.first(where: { $0.id == selections.first }) else { return }
            paths = config.path.map { .init(path: $0) }
            key = config.key
            value = config.value
        })
        .onChange(of: selected) { (_, selectedId) in
            guard let config = viewModel.headerConfigs.first(where: { $0.id == selectedId }) else { return }
            paths = config.path.map { .init(path: $0) }
            key = config.key
            value = config.value
        }
        .onChange(of: paths) { save() }
        .onChange(of: key) { save() }
        .onChange(of: value) { save() }
        .inspector(isPresented: $shouldShowInspectorView) {
            Form {
                LabeledContent("Paths") {
                    VStack(alignment: .trailing) {
                        ForEach($paths) { $path in
                            VStack {
                                HStack {
                                    if #available(macOS 15.0, *) {
                                        TextField(text: $path.path, prompt: Text("/about-us"), axis: .vertical, label: EmptyView.init)
                                            .lineLimit(1...10)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(maxWidth: .infinity)
                                            .textInputSuggestions {
                                                ForEach(recommendedPaths(for: path.path), id: \.self) { suggestedPath in
                                                    Text(suggestedPath)
                                                        .textInputCompletion(suggestedPath)
                                                }
                                            }
                                    } else {
                                        TextField(text: $path.path, prompt: Text("/about-us"), axis: .vertical, label: EmptyView.init)
                                            .lineLimit(1...10)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(maxWidth: .infinity)
                                    }
                                    Button {
                                        withAnimation { paths.removeAll(where: { $0 == $path.wrappedValue }) }
                                    } label: {
                                        Image(systemName: "minus.circle")
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }

                                Text(path.path)
                                    .font(.footnote)
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

                Section {
                    ForEach(paths, id: \.self) { path in
                        let headerExecuteStyle = viewModel.headerExecuteStyle(for: path.path)
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundStyle(.green)
                                    .padding(.top, 2)

                                Text("\(path.path) normally ")
                                    .font(.headline) +
                                Text(headerExecuteStyle.title)
                                    .font(.headline)
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    headerConfigExample()
                }

                TipView(HeaderConfigsTip())
            }
            .inspectorColumnWidth(min: 400, ideal: 400, max: 1000)
        }
        .toolbar {
            ToolbarItem {
                if let selected {
                    ToolBarButton(title: "Remove", icon: "trash", backgroundColor: .red) {
                        viewModel.withMutation(keyPath: \.headerConfigs) {
                            viewModel.headerConfigs.removeAll(where: { selected == $0.id })
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
        .navigationTitle("Header Configs")
        .task(id: mockDomain) { viewModel.mockDomainUpdated(mockDomain: mockDomain) }
    }

    @ViewBuilder
    private func headerConfigExample() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Quick Examples", systemImage: "lightbulb.fill")
                .foregroundStyle(.orange)
                .font(.headline)

            ScrollView(.horizontal) {
                HStack(alignment: .top) {
                    Group {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Ignore All Headers", systemImage: "gear.badge.xmark")
                                .foregroundStyle(.blue)

                            Text("/about-us")
                                .monospaced()
                                .foregroundStyle(.green) +
                            Text(" Header: device=ios")
                                .monospaced()
                                .foregroundStyle(.gray)

                            Text("/about-us")
                                .monospaced()
                                .foregroundStyle(.green) +
                            Text(" Header: device=android")
                                .monospaced()
                                .foregroundStyle(.gray)

                            Text("Same mock")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Label("Ignore All Headers and Header Config", systemImage: "gear.badge.xmark")
                                .foregroundStyle(.blue)
                            Text("Config key: `userId`")

                            Text("/about-us")
                                .monospaced()
                                .foregroundStyle(.green) +
                            Text(" Header: userId=1")
                                .monospaced()
                                .foregroundStyle(.blue) +
                            Text(" device=ios")
                                .monospaced()
                                .foregroundStyle(.gray)

                            Text("/about-us")
                                .monospaced()
                                .foregroundStyle(.green) +
                            Text(" Header: userId=2")
                                .monospaced()
                                .foregroundStyle(.blue) +
                            Text(" device=android")
                                .monospaced()
                                .foregroundStyle(.gray)

                            Text("Different mock")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Label("Ignore All Headers and Header Config", systemImage: "gear.badge.xmark")
                                .foregroundStyle(.blue)
                            Text("Config key: `userId` value: `1`")

                            Text("/about-us")
                                .monospaced()
                                .foregroundStyle(.green) +
                            Text(" Header: userId=1")
                                .monospaced()
                                .foregroundStyle(.blue) +
                            Text(" device=ios")
                                .monospaced()
                                .foregroundStyle(.gray)

                            Text("/about-us")
                                .monospaced()
                                .foregroundStyle(.green) +
                            Text(" Header: userId=1")
                                .monospaced()
                                .foregroundStyle(.blue) +
                            Text(" device=android")
                                .monospaced()
                                .foregroundStyle(.gray)

                            Text("Same mock")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Label("Ignore All Headers and Header Config", systemImage: "gear.badge.xmark")
                                .foregroundStyle(.blue)
                            Text("Config key: `userId` value: `1`")

                            Text("/about-us")
                                .monospaced()
                                .foregroundStyle(.green) +
                            Text(" Header: userId=2")
                                .monospaced()
                                .foregroundStyle(.blue) +
                            Text(" device=ios")
                                .monospaced()
                                .foregroundStyle(.gray)

                            Text("/about-us")
                                .monospaced()
                                .foregroundStyle(.green) +
                            Text(" Header: userId=3")
                                .monospaced()
                                .foregroundStyle(.blue) +
                            Text(" device=android")
                                .monospaced()
                                .foregroundStyle(.gray)

                            Text("Same mock")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Label("Ignore All Headers and Header Config", systemImage: "gear.badge.xmark")
                                .foregroundStyle(.blue)
                            Text("Config key: `userId` value: `1`")

                            Text("/about-us")
                                .monospaced()
                                .foregroundStyle(.green) +
                            Text(" Header: userId=1")
                                .monospaced()
                                .foregroundStyle(.red) +
                            Text(" device=ios")
                                .monospaced()
                                .foregroundStyle(.gray)

                            Text("/about-us")
                                .monospaced()
                                .foregroundStyle(.green) +
                            Text(" Header: userId=3")
                                .monospaced()
                                .foregroundStyle(.red) +
                            Text(" device=android")
                                .monospaced()
                                .foregroundStyle(.gray)

                            Text("Different mock")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding()
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            ScrollView(.horizontal) {
                HStack(alignment: .top) {
                    Group {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Match All Headers", systemImage: "gear.badge.checkmark")
                                .foregroundStyle(.blue)

                            Text("/about-us")
                                .monospaced()
                                .foregroundStyle(.green) +
                            Text(" Header: device=ios")
                                .monospaced()
                                .foregroundStyle(.red)

                            Text("/about-us")
                                .monospaced()
                                .foregroundStyle(.green) +
                            Text(" Header: device=android")
                                .monospaced()
                                .foregroundStyle(.red)

                            Text("Different mock")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Label("Match All Headers and Header Configs", systemImage: "gear.badge.checkmark")
                                .foregroundStyle(.blue)
                            Text("Config key: `device`")

                            Text("/about-us")
                                .monospaced()
                                .foregroundStyle(.green) +
                            Text(" Header: device=ios")
                                .monospaced()
                                .foregroundStyle(.blue)

                            Text("/about-us")
                                .monospaced()
                                .foregroundStyle(.green) +
                            Text(" Header: device=android")
                                .monospaced()
                                .foregroundStyle(.blue)

                            Text("Same mock")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Label("Match All Headers and Header Configs", systemImage: "gear.badge.checkmark")
                                .foregroundStyle(.blue)
                            Text("Config key: `device` value: `ios`")

                            Text("/about-us")
                                .monospaced()
                                .foregroundStyle(.green) +
                            Text(" Header: device=ios")
                                .monospaced()
                                .foregroundStyle(.red)

                            Text("/about-us")
                                .monospaced()
                                .foregroundStyle(.green) +
                            Text(" Header: device=android")
                                .monospaced()
                                .foregroundStyle(.red)

                            Text("Different mock")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Label("Match All Headers and Header Configs", systemImage: "gear.badge.checkmark")
                                .foregroundStyle(.blue)
                            Text("Config key: `device` value: `ios`")

                            Text("/about-us")
                                .monospaced()
                                .foregroundStyle(.green) +
                            Text(" Header: device=android")
                                .monospaced()
                                .foregroundStyle(.blue)

                            Text("/about-us")
                                .monospaced()
                                .foregroundStyle(.green) +
                            Text(" Header: device=desktop")
                                .monospaced()
                                .foregroundStyle(.blue)

                            Text("Same mock")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding()
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private func recommendedPaths(for currentPath: String) -> [String] {
        let pathComponents = currentPath.split(separator: "/")

        let paths = viewModel.pathConfigs.map(\.path).filter { mockPath in
            let mockPathComponents = mockPath.split(separator: "/")

            guard !mockPath.isEmpty else { return true }
            guard pathComponents.count < mockPathComponents.count else { return false }
            for (index, component) in pathComponents.enumerated() {
                if !mockPathComponents[index].hasPrefix(component) {
                    return false
                }
            }

            return true
        }
        return Array(Set(paths))
    }

    private func save() {
        guard !key.isEmpty else { return }

        if let selected, let index = viewModel.headerConfigs.firstIndex(where: { $0.id == selected }) {
            viewModel.withMutation(keyPath: \.headerConfigs) {
                viewModel.headerConfigs[index].path = paths.map(\.path)
                viewModel.headerConfigs[index].key = key
                viewModel.headerConfigs[index].value = value
                self.selected = viewModel.headerConfigs[index].id
            }
        } else {
            viewModel.withMutation(keyPath: \.headerConfigs) {
                let config = MockHeaderConfigModel(path: paths.map(\.path),
                                                   key: key,
                                                   value: value)
                viewModel.headerConfigs.append(config)
                selected = config.id
            }
        }
    }
}

#Preview {
    MockHeaderConfigurations(viewModel: .init())
}

struct HeaderConfigsTip: Tip {
    var title: Text {
        Text("Header Configurations")
    }

    var message: Text? {
        Text("You can find more information about header configurations in the Docs.")
    }

    var actions: [Action] {
        Action(title: "Open Documentations") {
            NSWorkspace.shared.open(URL(string: "https://trendyol.github.io/mockingstar/documentation/mockingstar/configurations")!)
        }
    }

    var image: Image? {
        Image(systemName: "questionmark")
    }
}
