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
    case longReadTime(MockModel, readTime: Double)

    var id: String {
        mock.fileURL?.path() ?? ""
    }

    var mock: MockModel {
        switch self {
        case .wrongFilePath(let mockModel), .duplicatedId(let mockModel), .longReadTime(let mockModel, _):
            mockModel
        }
    }

    var mockId: String {
        switch self {
        case .wrongFilePath(let mockModel), .duplicatedId(let mockModel), .longReadTime(let mockModel, _):
            mockModel.id
        }
    }

    var readTine: Double {
        switch self {
        case .longReadTime(_, let mockReadTine):
            mockReadTine
        default:
            0
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

    var isLongReadTime: Bool {
        switch self {
        case .longReadTime: true
        default: false
        }
    }
}

@Observable
final class FileIntegrityCheckViewModel {
    private let logger = Logger(category: "FileIntegrityCheckViewModel")
    private let mockDiscover: MockDiscoverInterface
    private let fileManager: FileManagerInterface
    private var mockDomain: String = ""
    private var mockDiscoverTask: Task<(), Never>? = nil
    private(set) var violatedMocks: [MockViolation] = []
    private(set) var isLoading: Bool = false
    private let mockFolderFilePath = {
        @UserDefaultStorage("workspaces") var workspaces: [Workspace] = []
        return workspaces.current?.path ?? "/MockServer"
    }()

    var wrongPathMocks: [MockViolation] { violatedMocks.filter(\.isWrongPath)}
    var duplicatedIdMocks: [MockViolation] { violatedMocks.filter(\.isDuplicatedId)}
    var longReadTimeMocks: [MockViolation] { violatedMocks.filter(\.isLongReadTime)}

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
                    await violatedMocks.append(contentsOf: checkMockLoadTime(mocks: mocks))
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

    private func checkMockLoadTime(mocks: [MockModel]) async -> [MockViolation] {
        await withTaskGroup(of: MockViolation?.self, returning: [MockViolation?].self) { taskGroup in
            for mock in mocks {
                taskGroup.addTask { [weak self] in
                    if let fileURL = mock.fileURL {
                        let startDate = Date()
                        let loadedMock: MockModel? = try? self?.fileManager.readJSONFile(at: fileURL, userInfo: [.lazyDecoding: true])

                        if loadedMock != nil, startDate.distance(to: Date()) > 0.5 {
                            return MockViolation.longReadTime(mock, readTime: startDate.distance(to: Date()))
                        }
                    }
                    return nil
                }
            }

            var violations: [MockViolation] = []

            for await result in taskGroup {
                guard let result else { continue }
                violations.append(result)
            }
            return violations
        }.compactMap { $0 }
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
            case .longReadTime: break
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
