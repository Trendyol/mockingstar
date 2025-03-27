//
//  InitialSettingsView.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 16.10.2023.
//

import SwiftUI
import CommonKit

struct InitialSettingsView: View {
    var continueButtonTapped: () -> Void
    @State private var folderSelectionDone = false
    @State private var isFileImporting: Bool = false
    @State private var messageText: String = ""
    @UserDefaultStorage("workspaces") private var workspaces: [Workspace] = []
    private let logger = Logger(category: "InitialSettingsView")
    private let fileManager: FileManagerInterface = FileManager.default

    var body: some View {
        ScrollView {
            VStack(alignment: .center) {
                Spacer()
                TitleView()

                InformationDetailView(title: "Folders for Mocks",
                                      subTitle: "You can select a folder for mocks or app will use own documents folder. You can change any time.",
                                      imageName: "plus.rectangle.on.folder.fill")

                Spacer(minLength: 30)

                Text(messageText)
                    .font(.title3)
                    .padding()

                if folderSelectionDone {
                    Button(action: {
                        continueButtonTapped()
                    }) {
                        Text("Continue")
                            .foregroundColor(.white)
                            .font(.headline)
                            .padding()
                            .padding(.horizontal, 40)
                            .background(Color.accentColor)
                            .clipShape(.rect(cornerRadius: 15))
                            .padding(.bottom)
                    }
                    .padding(.horizontal)
                    .buttonStyle(.plain)
                } else {
                    Button(action: {
                        messageText = ""
                        isFileImporting = true
                    }) {
                        Text("Select Folder")
                            .foregroundColor(.white)
                            .font(.headline)
                            .padding()
                            .padding(.horizontal, 40)
                            .background(Color.accentColor)
                            .clipShape(.rect(cornerRadius: 15))
                            .padding(.bottom)
                    }
                    .padding(.horizontal)
                    .buttonStyle(.plain)

                    Button("Use Default Folder") {
                        do {
                            let url = URL.documentsDirectory
                            let mockFolderFileBookMark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                            let mockFolderFilePath = url.path(percentEncoded: false)
                            workspaces.append(Workspace(name: "Workspace 1",
                                                        path: mockFolderFilePath,
                                                        bookmark: mockFolderFileBookMark))
                            continueButtonTapped()
                        } catch {
                            logger.error("Update mocks folder path failed. Error: \(error)")
                            messageText = "Update mocks folder path failed. Error: \(error)"
                        }
                    }
                }
            }
        }
        .fileImporter(isPresented: $isFileImporting, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            fileImported(result: result)
        }
    }

    func fileImported(result: Result<[URL], Error>) {
        switch result {
        case .success(let success):
            if let url = success.first {
                do {
                    guard url.startAccessingSecurityScopedResource() else {
                        throw FilePermissionHelperError.fileBookMarkAccessingFailed
                    }
                    let mockFolderFileBookMark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                    let mockFolderFilePath = url.path(percentEncoded: false)
                    workspaces.append(Workspace(name: "Workspace 1",
                                                path: mockFolderFilePath,
                                                bookmark: mockFolderFileBookMark))
                    url.stopAccessingSecurityScopedResource()

                    withAnimation {
                        messageText = "You are ready 🚀"
                        folderSelectionDone = true
                    }
                } catch {
                    logger.error("Update mocks folder path failed. Error: \(error)")
                    messageText = "Update mocks folder path failed. Error: \(error)"
                }
            }
        case .failure(let failure):
            messageText = "Importing files failed. Error: \(failure)"
        }
    }
}

#Preview {
    InitialSettingsView() {}
}
