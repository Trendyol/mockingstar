//
//  MockReloadViewModel.swift
//
//
//  Created by Yusuf Özgül on 25.10.2023.
//

import AnyCodable
import CommonKit
import SwiftUI
import PluginCore
import CommonViewsKit

@Observable
final class MockReloadViewModel {
    var mockModel: MockModel
    var reloadedMockResponse: (data: Data, response: HTTPURLResponse)? = nil
    var isReloadedMockReady: Bool = false
    var isMockReloadingProgress: Bool = false
    var mockReloadSelectedEditorSide: MockReloadViewEditorSide = .both { didSet { updateDiffEditor() }}
    var mockReloadSelectedEditorContentType: MockReloadViewEditorContentType = .body { didSet { updateDiffEditor() }}
    var mockReloadSelectedInspectorState: MockReloadViewInspectorState = .requestSummary
    var showUpdatedRequest: Bool = true
    var didRequestUpdate: Bool {
        let original = mockModel.asURLRequest
        let updated = updatedRequest()
        return updated.url != original.url || updated.allHTTPHeaderFields != original.allHTTPHeaderFields || updated.httpBody != original.httpBody
    }
    private var plugin: PluginInterface? = nil
    private let pluginCoreActor: PluginCoreActorInterface
    private let urlSession: URLSessionInterface
    private let pasteBoard: NSPasteboardInterface
    private let notificationManager: NotificationManagerInterface
    private let mockDomain: String

    init(mockModel: MockModel, 
         mockDomain: String,
         pluginCoreActor: PluginCoreActorInterface = PluginCoreActor.shared,
         urlSession: URLSessionInterface = URLSession.shared,
         pasteBoard: NSPasteboardInterface = NSPasteboard.general,
         notificationManager: NotificationManagerInterface = NotificationManager.shared) {
        self.mockModel = mockModel
        self.pluginCoreActor = pluginCoreActor
        self.urlSession = urlSession
        self.pasteBoard = pasteBoard
        self.notificationManager = notificationManager
        self.mockDomain = mockDomain
    }

    private func updateDiffEditor() {
        guard let response = reloadedMockResponse else { return }

        DiffEditorCache.shared.content.shouldHideLeftSide = mockReloadSelectedEditorSide == .new
        DiffEditorCache.shared.content.shouldHideRightSide = mockReloadSelectedEditorSide == .saved

        do {
            switch mockReloadSelectedEditorContentType {
            case .body:
                DiffEditorCache.shared.content.leftSideContent = mockModel.responseBody
                let json = try JSONDecoder.shared.decode(AnyCodableModel.self, from: response.data)
                DiffEditorCache.shared.content.rightSideContent = json.description
            case .header:
                DiffEditorCache.shared.content.leftSideContent = mockModel.responseHeader
                DiffEditorCache.shared.content.rightSideContent = (response.response.allHeaderFields as? MockModelHeader)?.description ?? ""
            }
        } catch {
            print("updateDiffEditor Error: \(error)")
        }

        DiffEditorCache.shared.content.update()
    }

    func updatedRequest() -> URLRequest {
        guard let plugin else { return mockModel.asURLRequest }
        do {
            let updatedRequest = try plugin.requestReloaderPlugin(request: .init(url: mockModel.metaData.url.absoluteString,
                                                                                 headers: try mockModel.requestHeader.asDictionary(),
                                                                                 body: mockModel.requestBody,
                                                                                 method: mockModel.metaData.method))
            var request = mockModel.asURLRequest
            request.url = URL(string: updatedRequest.url)
            request.allHTTPHeaderFields = updatedRequest.headers
            request.httpBody = updatedRequest.body.data(using: .utf8)
            request.httpMethod = updatedRequest.method
            return request
        } catch {
            return mockModel.asURLRequest
        }
    }

    func reloadMock() async {
        isMockReloadingProgress = true

        let result: (Data, URLResponse)

        do {
            result = try await urlSession.data(for: showUpdatedRequest ? updatedRequest() : mockModel.asURLRequest)
        } catch {
            print("Error: \(error)")
            isMockReloadingProgress = false
            return
        }
        guard let response = result.1 as? HTTPURLResponse else { return }
        reloadedMockResponse = (result.0, response)
        updateDiffEditor()

        withAnimation {
            self.mockReloadSelectedInspectorState = .response
        }

        isReloadedMockReady = true
        isMockReloadingProgress = false
    }

    func saveReloadedMock() {
        switch mockReloadSelectedEditorContentType {
        case .body where mockReloadSelectedEditorSide == .new :
            mockModel.responseBody = DiffEditorCache.shared.content.rightSideContent
        case .body where mockReloadSelectedEditorSide == .saved :
            mockModel.responseBody = DiffEditorCache.shared.content.leftSideContent
        case .header where mockReloadSelectedEditorSide == .new :
            mockModel.responseHeader = DiffEditorCache.shared.content.rightSideContent
        case .header where mockReloadSelectedEditorSide == .saved :
            mockModel.responseHeader = DiffEditorCache.shared.content.leftSideContent
        default: break
        }
    }

    func shareButtonTapped(shareStyle: ShareStyle) {
        switch shareStyle {
        case .curl:
            let curl = mockModel.asURLRequest.cURL(pretty: true)
            pasteBoard.clearContents()
            pasteBoard.setString(curl, forType: .string)
        }
        notificationManager.show(title: "Request copied to clipboard", color: .green)
    }

    func loadPlugin() async {
        plugin = await pluginCoreActor.pluginCore(for: mockDomain)
    }
}
