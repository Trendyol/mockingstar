//
//  MockDetailViewModel.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 20.09.2023.
//

import AnyCodable
import Combine
import CommonKit
import CommonViewsKit
import JSONEditor
import PluginCore
import SwiftUI

@Observable
public final class MockDetailViewModel {
    // MARK: Injections
    private let logger = Logger(category: "MockDetailViewModel")
    private let fileManager: FileManagerInterface
    private let manager: NotificationManager = .shared
    @ObservationIgnored @UserDefaultStorage("mockFolderFilePath") var mockFolderFilePath: String = "/MockServer"

    // MARK: Data Models
    private var originalMockModel: MockModel
    let mockDomain: String
    private let editorContent: JSONEditorContent = .init()
    @ObservationIgnored var selectedEditorType: MockDetailEditorType = .responseBody { didSet { jsonEditorModelTypeChanged() }}
    var mockModel: MockModel

    var jsonValidationTask: Task<(), Never>? = nil

    // MARK: Alerts & Navigations
    let viewDismissalModePublisher = PassthroughSubject<Void, Never>()
    private(set) var jsonValidationMessage: String? = nil
    var shouldShowSaveErrorAlert = false
    private(set) var saveErrorMessage = ""
    var shouldShowDeleteConfirmationAlert: Bool = false
    var shouldShowFilePathErrorAlert = false
    var shouldShowUnsavedIndicator: Bool = false

    public init(mockModel: MockModel,
                mockDomain: String,
                fileManager: FileManagerInterface = FileManager.default) {
        self.fileManager = fileManager
        self.originalMockModel = mockModel
        self.mockDomain = mockDomain
        self.mockModel = mockModel.copy() as! MockModel

        jsonEditorModelTypeChanged()
        registerContentChange()
        JsonEditorCache.shared.content = editorContent
    }

    /// Updates the content of the JSON editor based on the selected editor type.
    func jsonEditorModelTypeChanged() {
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
            validateEditorJson()
        }
    }

    /// Cancels the current JSON validation task and initiates a new validation task.
    private func validateEditorJson() {
        jsonValidationTask?.cancel()
        jsonValidationTask = Task(priority: .utility) { @MainActor in
            let (_, message) = jsonValidator(jsonText: editorContent.content)
            jsonValidationMessage = message
        }
    }

    /// Validates JSON text and returns a tuple indicating validity and an optional error message.
    ///
    /// This function takes a JSON text as input and checks its validity using the `JSONSerialization` class.
    /// If the conversion to data or JSON validation fails, it returns a tuple with `isValid` set to false and
    /// an error message indicating the reason for the failure. Otherwise, it returns a tuple with `isValid` set to true.
    ///
    /// - Parameters:
    ///   - jsonText: The JSON text to be validated.
    /// - Returns: A tuple indicating JSON validity and an optional error message.
    private func jsonValidator(jsonText: String) -> (isValid: Bool, errorMessage: String?) {
        guard !jsonText.isEmpty else { return (true, nil) }
        guard let data = jsonText.data(using: .utf8) else {
            return (false, "Converting to data failed")
        }

        do {
            let _ = try JSONSerialization.jsonObject(with: data)
            return (true, nil)
        } catch {
            let nsError = error as NSError
            return (false, "Json validation failed: \(nsError.userInfo["NSDebugDescription"] ?? "NO DEBUG ERROR")")
        }
    }

    private func showErrorMessage(_ message: String) {
        saveErrorMessage = message
        shouldShowSaveErrorAlert = true
    }

    /// Saves the changes made to the current mock model.
    ///
    /// This function is responsible for saving changes made to the mock model. It performs various checks on the
    /// validity of the JSON content in different sections of the mock model, such as response body, request body,
    /// response headers, and request headers. If any of these sections contain invalid JSON, an error message is
    /// displayed using the `showErrorMessage` function. If the JSON is valid, the function updates the metadata and
    /// content of the original mock model and persists the changes to the file. If the scenario has changed, the file
    /// is moved to the appropriate folder. After the save operation, a success message is displayed.
    func saveChanges() {
        guard originalMockModel != mockModel else { return }
        let shouldMoveFile = originalMockModel.metaData.scenario != mockModel.metaData.scenario

        let (isResponseBodyValid, responseBodyMessage) = jsonValidator(jsonText: mockModel.responseBody)
        let (isRequestBodyValid, requestBodyMessage) = jsonValidator(jsonText: mockModel.requestBody)
        let (isResponseHeaderValid, responseHeaderMessage) = jsonValidator(jsonText: mockModel.responseHeader)
        let (isRequestHeaderValid, requestHeaderMessage) = jsonValidator(jsonText: mockModel.requestHeader)

        guard isResponseBodyValid else { return showErrorMessage("Response Body not valid\n\(responseBodyMessage.orEmpty)") }
        guard isRequestBodyValid else { return showErrorMessage("Request Body not valid\n\(requestBodyMessage.orEmpty)") }
        guard isResponseHeaderValid else { return showErrorMessage("Response Headers not valid\n\(responseHeaderMessage.orEmpty)") }
        guard isRequestHeaderValid else { return showErrorMessage("Request Headers not valid\n\(requestHeaderMessage.orEmpty)") }

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
            manager.show(title: "All changes saved", color: .green)
        } catch {
            showErrorMessage("Mock couldn't saved\n\(error)")
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
            viewDismissalModePublisher.send()
        } catch {
            showErrorMessage("Mock couldn't delete\n\(error)")
        }
    }

    /// Opens the folder containing the current mock in Finder.
    func openInFinder() {
        guard let filePath = mockModel.fileURL?.path(percentEncoded: false) else { return }
        let folderPath = filePath.components(separatedBy: "/").dropLast().joined(separator: "/")
        NSWorkspace.shared.selectFile(filePath, inFileViewerRootedAtPath: folderPath)
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
            showErrorMessage(error.localizedDescription)
        }
    }

    func discardChanges() {
        mockModel = originalMockModel.copy() as! MockModel
        jsonEditorModelTypeChanged()
        validateEditorJson()
    }
    
    func shareButtonTapped(shareStyle: ShareStyle) {
        switch shareStyle {
        case .curl:
            let curl = mockModel.asURLRequest.cURL(pretty: true)
            let pasteBoard = NSPasteboard.general
            pasteBoard.clearContents()
            pasteBoard.setString(curl, forType: .string)
        }
        NotificationManager.shared.show(title: "Request copied to clipboard", color: .green)
    }

    func checkUnsavedChanges() {
        shouldShowUnsavedIndicator = mockModel != originalMockModel
    }
}
