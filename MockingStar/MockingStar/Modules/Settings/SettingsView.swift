//
//  SettingsView.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 16.10.2023.
//

import CommonKit
import SwiftUI
import Sparkle

struct SettingsView: View {
    private let updater: SPUUpdater
    @Bindable private var viewModel = SettingsViewModel()
    @State private var isFileImporting: Bool = false
    @State private var automaticallyChecksForUpdates: Bool
    @State private var automaticallyDownloadsUpdates: Bool
    
    init(updater: SPUUpdater) {
        self.updater = updater
        self.automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        self.automaticallyDownloadsUpdates = updater.automaticallyDownloadsUpdates
    }

    var body: some View {
        TabView {
            Form {
                Section {
                    TextField("Server Port", value: $viewModel.httpServerPort, format: .port(), prompt: Text("Server Port"))
                } footer: {
                    Text("If you change server port, please restart application.")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }

                Toggle("Automatically check for updates", isOn: $automaticallyChecksForUpdates)
                    .onChange(of: automaticallyChecksForUpdates) {
                        updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
                    }

                Toggle("Automatically download updates", isOn: $automaticallyDownloadsUpdates)
                    .disabled(!automaticallyChecksForUpdates)
                    .onChange(of: automaticallyDownloadsUpdates) {
                        updater.automaticallyDownloadsUpdates = automaticallyDownloadsUpdates
                    }

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
                ForEach(viewModel.workspaces, id: \.localId) { workspace in
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
    SettingsView(updater: SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil).updater)
}
