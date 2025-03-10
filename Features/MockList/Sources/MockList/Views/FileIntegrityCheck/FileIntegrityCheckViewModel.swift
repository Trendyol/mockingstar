//
//  FileIntegrityCheckViewModel.swift
//  MockList
//
//  Created by Yusuf Özgül on 7.03.2025.
//

import CommonKit
import CommonViewsKit
import MockingStarCore
import SwiftUI

enum MockViolation: Hashable, Identifiable {
    case wrongFilePath(MockModel)
    case duplicatedId(MockModel)

    var id: String {
        mock.fileURL?.path() ?? ""
    }

    var mock: MockModel {
        switch self {
        case .wrongFilePath(let mockModel), .duplicatedId(let mockModel):
            mockModel
        }
    }

    var mockId: String {
        switch self {
        case .wrongFilePath(let mockModel), .duplicatedId(let mockModel):
            mockModel.id
        }
    }

    var isWrongPath: Bool {
        switch self {
        case .wrongFilePath: true
        default: false
        }
    }

    var isDuplicatedId: Bool {
        switch self {
        case .duplicatedId: true
        default: false
        }
    }
}

@Observable
final class FileIntegrityCheckViewModel {
    @ObservationIgnored @UserDefaultStorage("mockFolderFilePath") var mockFolderFilePath: String = "/MockServer"

    private let logger = Logger(category: "FileIntegrityCheckViewModel")
    private let mockDiscover: MockDiscoverInterface
    private let fileManager: FileManagerInterface
    private var mockDomain: String = ""
    private var mockDiscoverTask: Task<(), Never>? = nil
    private(set) var violatedMocks: [MockViolation] = []
    private(set) var isLoading: Bool = false

    var wrongPathMocks: [MockViolation] { violatedMocks.filter(\.isWrongPath)}
    var duplicatedIdMocks: [MockViolation] { violatedMocks.filter(\.isDuplicatedId)}

    public init(fileManager: FileManagerInterface = FileManager.default,
                mockDiscover: MockDiscoverInterface = MockDiscover()) {
        self.fileManager = fileManager
        self.mockDiscover = mockDiscover
        listenMockDiscover()
    }

    private func listenMockDiscover() {
        mockDiscoverTask = Task {
            for await result in mockDiscover.mockDiscoverResult {
                switch result {
                case .loading:
                    isLoading = true
                    violatedMocks.removeAll()
                case .result(let mocks):
                    violatedMocks = mocks.compactMap {
                        checkMockViolates(for: $0, allMocks: mocks)
                    }
                    isLoading = false
                }
            }
        }
    }

    private func checkMockViolates(for mock: MockModel, allMocks: [MockModel]) -> MockViolation? {
        if let filePath = mock.fileURL?.path(percentEncoded: false),
           !filePath.hasSuffix(mock.filePath) {
            return .wrongFilePath(mock)
        }

        let allIds = allMocks.map(\.id)
        if allIds.count(where: { $0 == mock.id }) > 1 {
            return .duplicatedId(mock)
        }

        return nil
    }

    @MainActor
    func searchFileViolates(_ domain: String) async {
        do {
            isLoading = true
            violatedMocks.removeAll()
            try await mockDiscover.updateMockDomain(domain)
            self.mockDomain = domain
        } catch {
            guard !(error is CancellationError) else { return }
            logger.error("Mock Domain Changed Error: \(error)")
        }
    }

    func fixViolations() {
        isLoading = true
        mockDiscoverTask?.cancel()
        for mock in violatedMocks {
            switch mock {
            case .wrongFilePath(let mockModel):
                fixFilePath(for: mockModel)
            case .duplicatedId(let mockModel):
                generateNewId(for: mockModel)
            }
        }
        isLoading = false
    }

    private func fixFilePath(for mock: MockModel) {
        guard let filePath = mock.fileURL?.path(percentEncoded: false) else { return }
        let newPath = mockFolderFilePath + "Domains/" + mockDomain + "/Mocks/" + mock.filePath

        do {
            try fileManager.moveFile(from: filePath, to: newPath)
            violatedMocks.removeAll(where: { $0.mock == mock })
        } catch {
            logger.error("Failed to move mock file: \(error)")
        }
    }

    private func generateNewId(for mock: MockModel) {
        guard let path = mock.fileURL?.path(percentEncoded: false) else { return }

        mock.metaData.id = UUID().uuidString
        let newPath = mockFolderFilePath + "Domains/" + mockDomain + "/Mocks/" + mock.filePath

        do {
            try fileManager.updateFileContent(path: path, content: mock)
            try fileManager.moveFile(from: path, to: newPath)
            violatedMocks.removeAll(where: { $0.mock == mock })
        } catch {
            logger.error("Failed to save mock file: \(error)")
        }
    }
}
