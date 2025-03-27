//
//  SettingsView.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 16.10.2023.
//

import CommonKit
import SwiftUI

struct SettingsView: View {
    @Bindable private var viewModel = SettingsViewModel()
    @State private var isFileImporting: Bool = false

    var body: some View {
        TabView {
            VStack(alignment: .leading) {
                LabeledContent("Server Port") {
                    TextField("Server Port", value: $viewModel.httpServerPort, format: .port(), prompt: Text("Server Port"))
                }
                Text("If you change server port, please restart application.")
                    .foregroundStyle(.secondary)
                    .font(.footnote)
                Spacer()
            }
            .padding()
            .tabItem {
                Label("Settings", systemImage: "rectangle.on.rectangle.badge.gearshape")
            }

            workspaceSettings()
            .tabItem {
                Label("Workspaces", systemImage: "sparkles.rectangle.stack.fill")
            }

            DiagnosticView()
                .tabItem {
                    Label("Diagnostic", systemImage: "gear.badge.checkmark")
                }
        }
        .frame(minWidth: 700, minHeight: 500)
        .fileImporter(isPresented: $isFileImporting, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            viewModel.fileImported(result: result)
        }
        .background(.background)
    }

    @ViewBuilder
    private func workspaceSettings() -> some View {
        ScrollView {
            VStack(alignment: .trailing) {
                ForEach(viewModel.workspaces, id: \.path) { workspace in
                    HStack {
                        TextField("Workspace Name", text: .init(
                            get: { workspace.name },
                            set: { viewModel.workspaceRenamed(workspace: workspace, newName: $0) }
                        ))
                            .textFieldStyle(.roundedBorder)
                            .labelsHidden()
                        Text(workspace.path)
                            .foregroundStyle(.secondary)
                            .layoutPriority(0.8)
                        Button {
                            withAnimation {
                                viewModel.removeWorkspace(workspace)
                            }
                        } label: {
                            Image(systemName: "minus.circle")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }

                Button {
                    isFileImporting = true
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(Color.accentColor)
                }
                .padding(.leading, 4)
            }
        }
        .padding()
        .onChange(of: viewModel.workspaces) {
            NotificationCenter.default.post(name: .workspacesUpdated, object: nil)
        }
    }
}

#Preview {
    SettingsView()
}
