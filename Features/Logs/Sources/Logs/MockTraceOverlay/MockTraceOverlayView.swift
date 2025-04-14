//
//  MockTraceOverlayView.swift
//  MockList
//
//  Created by Yusuf Özgül on 28.03.2025.
//

import SwiftUI
import CommonKit
import CommonViewsKit

public struct MockTraceOverlayView: View {
    private let viewModel = MockTraceOverlayViewModel()
    @State private var isFollowing: Bool = false
    @AppStorage("isFloatingMockTraceViewEnabled") private var isFloatingMockTraceViewEnabled = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            overlayHeader
            overlayContent
        }
        .frame(minWidth: 350, minHeight: 500)
        .task { await viewModel.readLogs() }
    }
    
    private var overlayHeader: some View {
        HStack {
            Text("Mocking Star Trace")
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()

            if #available(macOS 15.0, *) {
                Button("Floating View", systemImage: isFloatingMockTraceViewEnabled ? "pin.slash" : "pin") {
                    isFloatingMockTraceViewEnabled.toggle()
                }
                .labelStyle(.iconOnly)
                .help("Pin trace view to the top of the screen")
            }

            Button("Clear Logs", systemImage: "trash") {
                viewModel.clearLogs()
            }
            .labelStyle(.iconOnly)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(height: 30)
    }
    
    private var overlayContent: some View {
        VStack(spacing: 0) {
            Divider()
            
            if viewModel.logs.isEmpty {
                VStack {
                    Spacer()
                    Text("No trace logs yet")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollViewReader { proxy in
                    List(viewModel.logs) { log in
                        logEntryView(log)
                            .id(log.id)
                            .onAppear {
                                guard log == viewModel.logs.last else { return }
                                isFollowing = true
                            }
                            .onDisappear {
                                guard log == viewModel.logs.last else { return }
                                isFollowing = false
                            }
                    }
                    .onChange(of: viewModel.logs) {
                        if isFollowing, let log = viewModel.logs.last {
                            DispatchQueue.main.async {
                                proxy.scrollTo(log.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: isFollowing) {
                        if isFollowing, let log = viewModel.logs.last {
                            proxy.scrollTo(log.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
    
    private func logEntryView(_ entry: LogModel) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                Text(entry.date.formatted(date: .omitted, time: .standard))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(entry.metadata["responseType"].orEmpty)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(responseTypeColor(entry.metadata["responseType"].orEmpty))
                    .foregroundColor(.white)
                    .cornerRadius(4)
                
                Spacer()
            }
            
            Text(entry.metadata["traceUrl"].orEmpty)
                .font(.footnote)
                .foregroundColor(.primary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
        .textSelection(.enabled)
        .padding(8)
    }
    
    private func responseTypeColor(_ type: String) -> Color {
        switch type {
        case "live request", "scenario not found and live request", "ignored domain and live request":
            return .blue
        case "mock":
            return .green
        case "error", "no mock and disabled live request", "scenario not found and disabled live request":
            return .red
        default:
            return .gray
        }
    }
}
