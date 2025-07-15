//
//  MockDetailViewModel.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 20.09.2023.
//

import AnyCodable
import CommonKit
import CommonViewsKit
import Editor
import MockingStarCore
import PluginCore
import SwiftUI

@Observable
public final class MockDetailViewModel {
    // MARK: Injections
    private let logger = Logger(category: "MockDetailViewModel")
    private let fileManager: FileManagerInterface
    private let notificationManager: NotificationManagerInterface
    private let fileSaver: FileSaverActorInterface
    private let pasteBoard: NSPasteboardInterface
    private let nsWorkspace: NSWorkspaceInterface
    private let mockFolderFilePath = {
        @UserDefaultStorage("workspaces") var workspaces: [Workspace] = []
        return workspaces.current?.path ?? "/MockServer"
    }()

    // MARK: Data Models
    private var originalMockModel: MockModel
    let mockDomain: String
    private let editorContent: EditorContent = .init()
    @ObservationIgnored var selectedEditorType: MockDetailEditorType = .responseBody { didSet { editorModelTypeChanged() }}
    var mockModel: MockModel

    var editorValidationTask: Task<(), Never>? = nil

    // MARK: Alerts & Navigations
    private(set) var shouldDismissView: Bool = false
    private(set) var editorValidationMessage: String? = nil
    var shouldShowAlert = false
    private(set) var alertMessage = ""
    private(set) var alertActionTitle = ""
    private(set) var alertAction: (() -> Void)? = nil
    var shouldShowDeleteConfirmationAlert: Bool = false
    var shouldShowFilePathErrorAlert = false
    var shouldShowUnsavedIndicator: Bool = false

    public init(mockModel: MockModel,
                mockDomain: String,
                fileManager: FileManagerInterface = FileManager.default,
                fileSaver: FileSaverActorInterface = FileSaverActor.shared,
                notificationManager: NotificationManagerInterface = NotificationManager.shared,
                pasteBoard: NSPasteboardInterface = NSPasteboard.general,
                nsWorkspace: NSWorkspaceInterface = NSWorkspace.shared) {
        self.fileManager = fileManager
        self.fileSaver = fileSaver
        self.notificationManager = notificationManager
        self.pasteBoard = pasteBoard
        self.nsWorkspace = nsWorkspace
        self.originalMockModel = mockModel
        self.mockDomain = mockDomain
        self.mockModel = mockModel.copy() as! MockModel

        editorModelTypeChanged()
        registerContentChange()
        JsonEditorCache.shared.content = editorContent
    }

    /// Updates the content of the JSON editor based on the selected editor type.
    func editorModelTypeChanged() {
        editorContent.type = switch selectedEditorType {
        case .responseBody: mockModel.metaData.responseBodyType ?? .json
        case .requestBody: mockModel.metaData.requestBodyType ?? .json
        case .responseHeader, .requestHeader: .json
        }
        editorContent.content = switch selectedEditorType {
        case .responseBody: mockModel.responseBody
        case .responseHeader: mockModel.responseHeader
        case .requestBody: mockModel.requestBody
        case .requestHeader: mockModel.requestHeader
        }
        checkUnsavedChanges()
    }

    /// Registers a callback for content changes in the JSON editor.
    private func registerContentChange() {
        editorContent.onContentDidChange = { [weak self] in
            guard let self else { return }

            let currentContent = switch selectedEditorType {
            case .responseBody: mockModel.responseBody
            case .responseHeader: mockModel.responseHeader
            case .requestBody: mockModel.requestBody
            case .requestHeader: mockModel.requestHeader
            }

            let editorContent = editorContent.content

            guard currentContent != editorContent else { return }

            switch selectedEditorType {
            case .responseBody: mockModel.responseBody = editorContent
            case .responseHeader: mockModel.responseHeader = editorContent
            case .requestBody: mockModel.requestBody = editorContent
            case .requestHeader: mockModel.requestHeader = editorContent
            }
            validateEditor()
        }
    }

    /// Cancels the current editor content validation task and initiates a new validation task.
    private func validateEditor() {
        editorValidationTask?.cancel()
        editorValidationTask = Task(priority: .utility) { @MainActor in
            do {
                switch selectedEditorType {
                case .responseBody:
                    try mockModel.metaData.responseBodyType.validate(body: editorContent.content)
                case .requestBody:
                    try mockModel.metaData.requestBodyType.validate(body: editorContent.content)
                case .requestHeader, .responseHeader:
                    try MockModelBodyType.json.validate(body: editorContent.content)
                }
                editorValidationMessage = nil
            } catch {
                editorValidationMessage = error.localizedDescription
            }
        }
    }

    private func showAlert(_ message: String, alertActionTitle: String = "", alertAction: (() -> Void)? = nil) {
        alertMessage = message
        self.alertActionTitle = alertActionTitle
        self.alertAction = alertAction
        shouldShowAlert = true
    }

    /// Saves the changes made to the current mock model.
    ///
    /// This function is responsible for saving changes made to the mock model. It performs various checks on the
    /// validity of the  content in different sections of the mock model, such as response body, request body,
    /// response headers, and request headers. If any of these sections contain invalid content, an error message is
    /// displayed using the `showErrorMessage` function. If the content is valid, the function updates the metadata and
    /// content of the original mock model and persists the changes to the file. If the scenario has changed, the file
    /// is moved to the appropriate folder. After the save operation, a success message is displayed.
    func saveChanges() {
        guard originalMockModel != mockModel else { return }
        let shouldMoveFile = originalMockModel.metaData.scenario != mockModel.metaData.scenario || originalMockModel.metaData.url != mockModel.metaData.url

        // Request Body
        do { try mockModel.metaData.requestBodyType.validate(body: mockModel.requestBody) }
        catch {
            return showAlert("Request Body not valid\n" + error.localizedDescription,
                      alertActionTitle: "Discard Changes") { [weak self] in
                self?.discardChanges()
            }
        }

        // Request Header
        do { try MockModelBodyType.json.validate(body: mockModel.requestHeader) }
        catch {
            return showAlert("Request Headers not valid\n" + error.localizedDescription,
                      alertActionTitle: "Discard Changes") { [weak self] in
                self?.discardChanges()
            }
        }

        // Response Body
        do { try mockModel.metaData.responseBodyType.validate(body: mockModel.responseBody) }
        catch {
            return showAlert("Response Body not valid\n" + error.localizedDescription,
                      alertActionTitle: "Discard Changes") { [weak self] in
                self?.discardChanges()
            }
        }

        // Response Header
        do { try MockModelBodyType.json.validate(body: mockModel.responseHeader) }
        catch {
            return showAlert("Response Headers not valid\n" + error.localizedDescription,
                      alertActionTitle: "Discard Changes") { [weak self] in
                self?.discardChanges()
            }
        }

        mockModel.metaData.updateTime = .init()
        let copy = mockModel.copy() as! MockModel

        originalMockModel.metaData = copy.metaData
        originalMockModel.requestHeader = copy.requestHeader
        originalMockModel.responseHeader = copy.responseHeader
        originalMockModel.requestBody = copy.requestBody
        originalMockModel.responseBody = copy.responseBody

        guard let path = mockModel.fileURL?.path(percentEncoded: false) else { return }

        do {
            try fileManager.updateFileContent(path: path, content: mockModel)

            if shouldMoveFile {
                let newPath = mockFolderFilePath + "Domains/" + mockDomain + "/Mocks/" + mockModel.filePath
                try fileManager.moveFile(from: path, to: newPath)
                mockModel.fileURL = URL(filePath: newPath)
                originalMockModel.fileURL = URL(filePath: newPath)
            }
            notificationManager.show(title: "All changes saved", color: .green)
        } catch {
            showAlert("Mock couldn't saved\n\(error.localizedDescription)")
        }
        checkUnsavedChanges()
    }

    /// Removes the current mock from the file system.
    ///
    /// This function deletes the file associated with the current mock model. If successful, it sends a signal to dismiss the view.
    func removeMock() {
        guard let filePath = mockModel.fileURL?.path(percentEncoded: false) else { return }

        do {
            try fileManager.removeFile(at: filePath)
            shouldDismissView = true
        } catch {
            showAlert("Mock couldn't delete\n\(error.localizedDescription)")
        }
    }

    /// Opens the folder containing the current mock in Finder.
    func openInFinder() {
        guard let filePath = mockModel.fileURL?.path(percentEncoded: false) else { return }
        let folderPath = filePath.components(separatedBy: "/").dropLast().joined(separator: "/")
        nsWorkspace.selectFile(filePath, inFileViewerRootedAtPath: folderPath)
    }

    /// Checks if the file path of the current mock model matches its expected path.
    func checkFilePath() {
        guard let filePath = mockModel.fileURL?.path(percentEncoded: false), !filePath.hasSuffix(mockModel.filePath) else { return }
        shouldShowFilePathErrorAlert = true
    }

    /// Fixes the file path of the current mock model.
    ///
    /// This function moves the file associated with the current mock model to the correct location based on the mock domain and file path. If the move operation is successful, it updates the file URL of both the current and original mock models.
    func fixFilePath() {
        guard let filePath = mockModel.fileURL?.path(percentEncoded: false) else { return }
        let newPath = mockFolderFilePath + "Domains/" + mockDomain + "/Mocks/" + mockModel.filePath

        do {
            try fileManager.moveFile(from: filePath, to: newPath)
            mockModel.fileURL = URL(filePath: newPath)
            originalMockModel.fileURL = URL(filePath: newPath)
        } catch {
            showAlert(error.localizedDescription)
        }
    }

    func discardChanges() {
        mockModel = originalMockModel.copy() as! MockModel
        editorModelTypeChanged()
        validateEditor()
    }
    
    func shareButtonTapped(shareStyle: ShareStyle) {
        switch shareStyle {
        case .curl:
            let curl = mockModel.asURLRequest.cURL(pretty: true)
            pasteBoard.clearContents()
            pasteBoard.setString(curl, forType: .string)
        case .file:
            do {
                let data = try JSONEncoder.shared.encode(mockModel)
                guard let content = String(data: data, encoding: .utf8) else {
                    return notificationManager.show(title: "Failed to encode mock", color: .red)
                }
                pasteBoard.clearContents()
                pasteBoard.setString(content, forType: .string)
            } catch {
                notificationManager.show(title: "Failed to encode mock", color: .red)
            }
        }
        notificationManager.show(title: "Request copied to clipboard", color: .green)
    }

    func checkUnsavedChanges() {
        shouldShowUnsavedIndicator = mockModel != originalMockModel
    }

    func newMock(mockDomain: String, shouldMove: Bool) async {
        do {
            let copied = try await createCopyMock(mockDomain: mockDomain)
            showAlert("Mock " + (shouldMove ? "Moved" : "Copied") + " Successfully", alertActionTitle: "Open New Mock") {
                DeeplinkStore.shared.deeplinks.append(.openMock(id: copied.id, domain: mockDomain))
                NavigationStore.shared.pop()
            }
            if shouldMove {
                removeMock()
            }
        } catch {
            showAlert("Mock couldn't copied\n\(error.localizedDescription)")
        }
    }

    @discardableResult
    private func createCopyMock(mockDomain: String) async throws -> MockModel {
        let mock = originalMockModel.copy() as! MockModel
        mock.metaData.scenario = .init()
        mock.metaData.id = UUID().uuidString
        let filePath = mockFolderFilePath + "Domains/" + mockDomain + "/Mocks/" + mock.filePath
        mock.fileURL = URL(filePath: filePath)

        try await fileSaver.saveFile(mock: mock, mockDomain: mockDomain)
        return mock
    }
}
