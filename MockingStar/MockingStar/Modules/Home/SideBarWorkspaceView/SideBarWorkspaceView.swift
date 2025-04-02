//
//  SideBarWorkspaceView.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 26.03.2025.
//

import SwiftUI
import CommonKit

struct SideBarWorkspaceView: View {
    @State private var workspaces: [Workspace] = []
    @SceneStorage("mockDomain") private var mockDomain: String = ""

    var body: some View {
        Menu {
            ForEach(workspaces) { workspace in
                Button(workspace.name) {
                    guard !workspace.isSelected else { return }

                    let newWorkspaces = self.workspaces
                    newWorkspaces.forEach { $0.isSelected = false }

                    if let index = newWorkspaces.firstIndex(where: { $0.id == workspace.id }) {
                        newWorkspaces[index].isSelected = true
                    }
                    @UserDefaultStorage("workspaces") var workspaces: [Workspace] = []
                    workspaces = newWorkspaces
                    mockDomain = ""
                    OnboardingCompleted.shared.completed = false
                }
            }

            Divider()

            SettingsLink()
        } label: {
            VStack(alignment: .leading, spacing: .zero) {
                Text("workspace")
                    .foregroundStyle(.secondary)
                    .font(.footnote)
                Text(workspaces.current?.name ?? "Workspaces")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
                .padding(6)
                .background(Color.secondary.quinary)
                .clipShape(.rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .onAppear {
            @UserDefaultStorage("workspaces") var workspaces: [Workspace] = []
            self.workspaces = workspaces
        }
        .onReceive(NotificationCenter.default.publisher(for: .workspacesUpdated)) { _ in
            @UserDefaultStorage("workspaces") var workspaces: [Workspace] = []
            self.workspaces = workspaces
        }
    }
}

#Preview {
    SideBarWorkspaceView()
}
