//
//  Configurations.swift
//
//
//  Created by Yusuf Özgül on 1.09.2023.
//

import CommonKit
import Foundation

public protocol ConfigurationsInterface {
    var configs: ConfigModel { get }
}

public final class Configurations: ConfigurationsInterface {
    private let logger = Logger(category: "Configurations")
    @UserDefaultStorage("mockFolderFilePath") var mockFolderFilePath: String = "/MockServer"

    private(set) public var configs: ConfigModel
    private var mockDomain: String
    private let fileManager: FileManagerInterface
    private var isFileMonitorStarted: Bool = false
    private var fileStructureMonitor: FileStructureMonitorInterface
    private let fileUrlBuilder: FileUrlBuilderInterface

    public init(mockDomain: String,
                fileManager: FileManagerInterface = FileManager.default,
                fileStructureMonitor: FileStructureMonitorInterface = FileStructureMonitor(),
                fileUrlBuilder: FileUrlBuilderInterface = FileUrlBuilder()) {
        self.configs = .init()
        self.mockDomain = mockDomain
        self.fileManager = fileManager
        self.fileStructureMonitor = fileStructureMonitor
        self.fileUrlBuilder = fileUrlBuilder

        _mockFolderFilePath.onChange {  [weak self] _ in
            guard let self else { return }
            do {
                try readConfigs()
            } catch {
                logger.error("Read configs error: \(error)")
            }
        }

        do {
            try readConfigs()
        } catch {
            logger.error("Read configs error: \(error)")
        }
    }

    private func watchConfigs() {
        guard !isFileMonitorStarted else { return }
        isFileMonitorStarted = true
        do {
            fileStructureMonitor.stop()
            let url = try fileUrlBuilder.configsFolderUrl(for: mockDomain)
            try fileStructureMonitor.startMonitoring(url: url)

            fileStructureMonitor.changeHandler = { [weak self] event in
                guard let self, case .configChange = event else { return }
                
                do {
                    try readConfigs()
                } catch {
                    logger.error("Read configs error: \(error)")
                }
            }
        } catch {
            logger.error("Watch configs error: \(error)")
            return
        }
    }

    private func readConfigs() throws {
        let url = try fileUrlBuilder.configUrl(for: mockDomain)
        let configs: ConfigModel

        do {
            configs = try fileManager.readJSONFile(at: url)
            watchConfigs()
        } catch FileManagerError.fileNotFound {
            configs = ConfigModel()
            let folderPath = try fileUrlBuilder.configsFolderUrl(for: mockDomain)
            try fileManager.write(to: folderPath, fileName: url.lastPathComponent, model: configs)
            watchConfigs()
        } catch {
            throw error
        }

        self.configs = configs
    }
}
