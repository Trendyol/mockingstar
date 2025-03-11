//
//  FileIntegrityCheckView.swift
//  MockList
//
//  Created by Yusuf Özgül on 7.03.2025.
//

import CommonViewsKit
import SwiftUI
import TipKit

public struct FileIntegrityCheckView: View {
    private let viewModel = FileIntegrityCheckViewModel()
    @SceneStorage("mockDomain") var mockDomain: String = ""
    public init() {}

    public var body: some View {
        List {
            TipView(FileIntegrityCheckTip())

            if !viewModel.wrongPathMocks.isEmpty {
                Section("Wrong Path (\(viewModel.wrongPathMocks.count))") {
                    ForEach(viewModel.wrongPathMocks) { mock in
                        Text(mock.mock.filePath)
                    }
                }
            }

            if !viewModel.duplicatedIdMocks.isEmpty {
                Section("Duplicated Id (\(viewModel.duplicatedIdMocks.count))") {
                    ForEach(viewModel.duplicatedIdMocks) { mock in
                        Text(mock.mock.filePath)
                    }
                }
            }
        }
        .overlay {
            if viewModel.isLoading { ProgressView() }

            if viewModel.violatedMocks.isEmpty && !viewModel.isLoading {
                ContentUnavailableView("No Violation Found", systemImage: "party.popper.fill")
            }
        }
        .task { await viewModel.searchFileViolates(mockDomain) }
        .toolbar {
            ToolbarItem {
                ToolBarButton(title: "Fix Violations", icon: "hammer.fill", backgroundColor: .green) {
                    viewModel.fixViolations()
                }
                .disabled(viewModel.isLoading)
            }
        }
        .navigationTitle("File Integrity Check")
    }
}

#Preview {
    FileIntegrityCheckView()
}

struct FileIntegrityCheckTip: Tip {
    var title: Text {
        Text("File Integrity Check")
    }

    var message: Text? {
        Text("Mocking Star can check your mock files integrity. File integrity is crucial for app performance.")
    }

    var image: Image? {
        Image(systemName: "hammer.fill")
    }

    var actions: [Action] {
        Action(title: "Open Documentations") {
            NSWorkspace.shared.open(URL(string: "https://trendyol.github.io/mockingstar/documentation/mockingstar/meetplugins")!)
        }
    }
}
