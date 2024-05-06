//
//  LogsView.swift
//
//
//  Created by Yusuf Özgül on 8.11.2023.
//

import CommonViewsKit
import SwiftUI
import CommonKit

public struct LogsView: View {
    @Bindable private var viewModel: LogsViewModel = .init()
    @State private var isSearchActive: Bool = false
    @State private var isFollowing: Bool = false
    @Environment(NotificationManager.self) private var alertManager: NotificationManager

    public init() {}

    public var body: some View {
        ScrollViewReader { proxy in
            List(viewModel.filteredLogs, id: \.self) { log in
                VStack(alignment: .leading) {
                    Text(log.message)
                        .textSelection(.enabled)
                    HStack {
                        Text(log.severity.rawValue.uppercased())
                        Text(log.date.formatted())
                        Text(log.category)

                        Spacer()
                    }
                    .textSelection(.enabled)
                    .font(.caption)
                    .foregroundStyle(log.severity.color)
                }
                .id(log.id)
                .padding(.vertical, 6)
                .onAppear {
                    guard log == viewModel.filteredLogs.last else { return }
                    isFollowing = true
                }
                .onDisappear {
                    guard log == viewModel.filteredLogs.last else { return }
                    isFollowing = false
                }
            }
            .onChange(of: viewModel.filteredLogs) {
                if isFollowing, let log = viewModel.filteredLogs.last {
                    DispatchQueue.main.async {
                        proxy.scrollTo(log.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: isFollowing) {
                if isFollowing, let log = viewModel.filteredLogs.last {
                    proxy.scrollTo(log.id, anchor: .bottom)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Toggle("Following", systemImage: "arrow.up.backward", isOn: $isFollowing.animation())
                    .symbolVariant(isFollowing ? SymbolVariants.circle.fill : .circle)

                ToolBarButton(title: "Clear",
                              icon: "xmark.circle",
                              backgroundColor: .secondary) {
                    viewModel.clearLogs()
                }
            }
            ToolbarItem {
                ToolBarButton(title: "Copy Logs",
                              icon: "square.and.arrow.up",
                              backgroundColor: .accentColor) {
                    let logs = viewModel.filteredLogs.map { "\($0.date.formatted(.iso8601)) \($0.severity.rawValue) \($0.message)" }.joined(separator: "\n")
                    let pasteBoard = NSPasteboard.general
                    pasteBoard.clearContents()
                    pasteBoard.setString(logs, forType: .string)
                    alertManager.show(title: "Logs copied to clipboard", color: .green)
                }
            }

            ToolbarItemGroup {
                HStack(spacing: .zero) {
                    VStack(spacing: .zero) {
                        Menu {
                            ForEach(LogSeverity.allCases, id: \.self) { type in
                                Button {
                                    if viewModel.filterType.contains(type) {
                                        viewModel.filterType.remove(type)
                                    } else {
                                        viewModel.filterType.insert(type)
                                    }
                                } label: {
                                    if viewModel.filterType.contains(type) {
                                        Text("\(type.rawValue) \(Image(systemName: "checkmark"))")
                                    } else {
                                        Text(type.rawValue)
                                    }
                                }
                            }
                        } label: {
                            Text("Severity Filter")
                                .font(.caption2)
                        }

                        Menu {
                            Button {
                                viewModel.filterType = Set(LogSeverity.allCases)
                            } label: {
                                Text("Select all")
                            }
                            Button {
                                viewModel.filterType.removeAll()
                            } label: {
                                Text("Unselect all")
                            }

                            Divider()

                            Button {
                                viewModel.filterType = [.critical, .error, .warning, .fault]
                            } label: {
                                Text("Critical Logs")
                            }
                        } label: {
                            Text("active: \(viewModel.filterType.count)")
                                .font(.caption2)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 6)
                    .padding(.vertical, 2)

                    Divider()
                        .padding(.trailing, 6)

                    CustomSearchbar(text: $viewModel.searchTerm, isSearchActive: $isSearchActive)
                        .frame(width: 200)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(viewModel.searchTerm.isEmpty ? Color.secondary : Color.accentColor, lineWidth: 1)
                )
            }
        }
        .task(id: viewModel.filterType) { viewModel.filterLogs() }
        .task(id: viewModel.searchTerm) { viewModel.filterLogs() }
        .task { await viewModel.readLogs() }
    }
}

#Preview {
    LogsView()
}
