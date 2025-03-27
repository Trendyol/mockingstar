//
//  MockDiscover.swift
//
//
//  Created by Yusuf Özgül on 1.09.2023.
//

import Foundation
import CommonKit

public enum MockDiscoverResult {
    case loading
    case result([MockModel])
}

public protocol MockDiscoverInterface {
    var mockDiscoverResult: AsyncStream<MockDiscoverResult> { get }

    func updateMockDomain(_ mockDomain: String) async throws
    func reloadMocks() async throws
}

public final class MockDiscover: MockDiscoverInterface {
    private let logger = Logger(category: "MockDiscover")
    public private(set) var mockDomain: String = ""
    public let mockDiscoverResult: AsyncStream<MockDiscoverResult>
    private let mockDiscoverResultContinuation: AsyncStream<MockDiscoverResult>.Continuation
    private let fileManager: FileManagerInterface
    private let fileUrlBuilder: FileUrlBuilderInterface
    private var mocks: Set<MockModel> = []
    private var fileStructureMonitor: FileStructureMonitorInterface

    public init(fileManager: FileManagerInterface = FileManager.default,
                fileUrlBuilder: FileUrlBuilderInterface = FileUrlBuilder(),
                fileStructureMonitor: FileStructureMonitorInterface = FileStructureMonitor()) {
        self.fileManager = fileManager
        self.fileUrlBuilder = fileUrlBuilder
        self.fileStructureMonitor = fileStructureMonitor
        (mockDiscoverResult, mockDiscoverResultContinuation) = AsyncStream<MockDiscoverResult>.makeStream()
    }

    /// Updates the mock domain and initiates the process of discovering and monitoring mock changes.
    ///
    /// - Parameter mockDomain: The new mock domain to be set.
    /// - Throws: If any error occurs during the process, it is thrown.
    public func updateMockDomain(_ mockDomain: String) async throws {
        logger.debug("update mock domain: \(mockDomain)")
        guard !mockDomain.isEmpty && self.mockDomain != mockDomain || mocks.isEmpty else {
            logger.notice("update mock domain: \(mockDomain), not necessary.")
            return
        }

        self.mockDomain = mockDomain
        mocks.removeAll()
        mockDiscoverResultContinuation.yield(.loading)
        try await startMockDiscover()

        do {
            fileStructureMonitor.stop()
            let url: URL = try fileUrlBuilder.domainFolder(for: mockDomain)
            try fileStructureMonitor.startMonitoring(url: url)

            fileStructureMonitor.changeHandler = { [weak self] event in
                guard let self else { return }

                switch event {
                case .mockChange(let url): mockChanged(url: url)
                case .mocksFolderChange(let url): mocksFolderChanged(url: url)
                default: break
                }
            }
        } catch {
            return
        }
    }

    public func reloadMocks() async throws {
        mocks.removeAll()
        mockDiscoverResultContinuation.yield(.loading)
        try await startMockDiscover()
    }

    /// Discovers and loads available mocks for the current mock domain.
    ///
    /// - Throws: If any error occurs during the process, it is thrown.
    private func startMockDiscover() async throws {
        let url: URL = try fileUrlBuilder.mocksFolderUrl(for: mockDomain)
        try Task.checkCancellation()

        let mockAvailableFolders = fileManager.enumerator(at: url,
                                                          includingPropertiesForKeys: nil,
                                                          options: [.skipsHiddenFiles, .skipsPackageDescendants]) { [weak self] url, error in
            self?.logger.critical("Mock Discover enumerator failed: \(error.localizedDescription)")
            return false
        }?
            .compactMap { $0 as? URL }
            .filter { $0.isDirectory } ?? []

        let mocks = try await withThrowingTaskGroup(of: [MockModel].self) { taskGroup in
            for mockAvailableFolder in mockAvailableFolders {
                try Task.checkCancellation()

                taskGroup.addTask {
                    [weak self] in
                    guard let self else { return [] }
                    try Task.checkCancellation()
                    return try loadMocks(url: mockAvailableFolder)
                }
            }

            var loadedMocks: [MockModel] = []
            for try await mocks in taskGroup {
                loadedMocks.append(contentsOf: mocks)
            }
            return loadedMocks
        }

        guard self.mocks.map(\.id).sorted() != mocks.map(\.id).sorted() || mocks.isEmpty else {
            logger.info("Mocks Loaded and not changed.")
            return
        }
        self.mocks = Set(mocks)
        mockDiscoverResultContinuation.yield(.result(Array(self.mocks)))
    }

    /// Loads mocks from the specified URL, excluding subdirectories.
    ///
    /// - Parameter url: The URL of the folder containing mock files.
    /// - Returns: An array of loaded `MockModel` instances.
    /// - Throws: If any error occurs during the loading process, it is thrown.
    private func loadMocks(url: URL) throws -> [MockModel] {
        try fileManager
            .folderContent(at: url)
            .filter { !$0.hasDirectoryPath }
            .map { try loadMock(fileURL: $0)}
    }

    /// Loads a mock from the specified file URL.
    ///
    /// - Parameter fileURL: The URL of the file containing the mock data.
    /// - Returns: The loaded `MockModel`.
    /// - Throws: If any error occurs during the loading process, it is thrown.
    private func loadMock(fileURL: URL) throws -> MockModel {
        let mock: MockModel = try mocks.first(where: { $0.fileURL == fileURL }) ?? (fileManager.readJSONFile(at: fileURL))
        mock.fileURL = fileURL
        return mock
    }

    /// Handles changes to a mock file.
    ///
    /// - Parameter url: The URL of the changed mock file.
    private func mockChanged(url: URL) {
        let filePath = url.path(percentEncoded: false)
        let isFileExist = fileManager.fileExist(atPath: filePath)
        let fileURL = URL(filePath: filePath)

        if isFileExist {
            do {
                let mock = try loadMock(fileURL: fileURL)
                if !mocks.contains(where: { $0.id == mock.id }) {
                    mocks.insert(mock)
                }
            } catch {
                logger.error("MockDiscover mockChanged error: \(error)")
            }
        } else {
            mocks = mocks.filter { $0.fileURL?.path(percentEncoded: false) != fileURL.path(percentEncoded: false) }
        }

        mockDiscoverResultContinuation.yield(.result(Array(mocks)))
    }

    /// Handles changes to the "Mocks" folder.
    ///
    /// - Parameter url: The URL of the changed "Mocks" folder.
    private func mocksFolderChanged(url: URL) {
        mocks
            .filter { $0.fileURL?.path().hasPrefix(url.path()) ?? false }
            .filter { !fileManager.fileExist(atPath: URL(filePath: $0.fileURL?.path() ?? "").path()) }
            .forEach { mocks.remove($0) }
        mockDiscoverResultContinuation.yield(.result(Array(mocks)))
    }
}
