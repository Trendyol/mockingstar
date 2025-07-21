//
//  MockTraceScene.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 28.03.2025.
//

import Logs
import SwiftUI

struct MockTraceScene: Scene {
    @AppStorage("isFloatingMockTraceViewEnabled") private var isFloatingMockTraceViewEnabled = false
    private let viewModel = MockTraceOverlayViewModel()

    var body: some Scene {
        Window("Mock Trace", id: "mock-trace") {
            MockTraceOverlayView(viewModel: viewModel)
                .ultraThinMaterialWindow()
        }
        .floatingWindow(isFloatingMockTraceViewEnabled)
        .windowResizability(.contentMinSize)
        .windowStyle(.hiddenTitleBar)
        .windowBackgroundDragEnabled()
    }
}

private extension Scene {
    func floatingWindow(_ isFloatingMockTraceViewEnabled: Bool) -> some Scene {
        if #available(macOS 15.0, *) {
            return self.windowLevel(isFloatingMockTraceViewEnabled ? .floating : .normal)
        } else {
            return self
        }
    }

    func windowBackgroundDragEnabled() -> some Scene {
        if #available(macOS 15.0, *) {
            return self.windowBackgroundDragBehavior(.enabled)
        } else {
            return self
        }
    }
}

private extension View {
    func ultraThinMaterialWindow() -> some View {
        if #available(macOS 15.0, *) {
            return self.containerBackground(.ultraThinMaterial, for: .window)
        } else {
            return self
        }
    }
}
