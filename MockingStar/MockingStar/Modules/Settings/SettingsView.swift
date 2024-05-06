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
        Form {
            LabeledContent("Mocks Folder") {
                HStack {
                    Text(viewModel.mockFolderFilePath)
                    Spacer()

                    Button("Change Path") {
                        isFileImporting = true
                    }
                }
            }

            TextField("Server Port", value: $viewModel.httpServerPort, format: .port(), prompt: Text("Server Port"))
            Text("If you change server port, please restart application.")
                .foregroundStyle(.secondary)
                .font(.footnote)

            LabeledContent("Diagnostic") {
                DiagnosticView()
            }

            Spacer()
        }
        .padding()
        .fileImporter(isPresented: $isFileImporting, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            viewModel.fileImported(result: result)
        }
        .background(.background)
    }
}

#Preview {
    SettingsView()
}
