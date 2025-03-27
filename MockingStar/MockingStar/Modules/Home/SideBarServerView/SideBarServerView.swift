//
//  SideBarServerView.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 28.09.2023.
//

import CommonViewsKit
import SwiftUI

struct SideBarServerView: View {
    private let viewModel: SideBarServerViewModel

    init(viewModel: SideBarServerViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack {
            ForEach(viewModel.serversUIModel) { server in
                ServerView(server: server, viewModel: viewModel)
            }
        }
    }
}

#Preview {
    SideBarServerView(viewModel: SideBarServerViewModel())
        .padding()
}

private struct ServerView: View {
    let server: ServerUIModel
    let viewModel: SideBarServerViewModel

    var body: some View {
        HStack {
            Circle()
                .frame(width: 15, height: 15)
                .foregroundStyle(server.status.color)

            VStack(alignment: .leading) {
                Text(server.address)
                Text(server.type)
            }
            .font(.callout.monospaced())

            let title: String = switch server.status {
            case .stopped: "Start"
            case .preparing: "Starting"
            case .running: "Stop"
            case .failed: "Restart"
            }

            Spacer()

            ActionSelectableButton(title: title,
                                   icon: "",
                                   backgroundColor: .accentColor) {
                switch server.status {
                case .stopped: viewModel.startServer(serverUIModel: server)
                case .preparing: break
                case .running: viewModel.stopServer(serverUIModel: server)
                case .failed: viewModel.startServer(serverUIModel: server)
                }
            } menuContent: {
                Group {
                    Button("Restart") {
                        viewModel.stopServer(serverUIModel: server)
                        viewModel.startServer(serverUIModel: server)
                    }
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 10)
        .help(server.errorMessage ?? "")
    }
}
