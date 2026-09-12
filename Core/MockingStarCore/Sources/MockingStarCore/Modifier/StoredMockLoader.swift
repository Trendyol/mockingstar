import CommonKit
import Foundation

struct StoredMockLoader {
    let fileManager: FileManagerInterface
    let fileUrlBuilder: FileUrlBuilderInterface

    init(
        fileManager: FileManagerInterface = FileManager.default,
        fileUrlBuilder: FileUrlBuilderInterface = FileUrlBuilder()
    ) {
        self.fileManager = fileManager
        self.fileUrlBuilder = fileUrlBuilder
    }

    func load(
        domain: String,
        requestURL: URL,
        method: String,
        scenario: String,
        id: String
    ) throws -> MockModel {
        let root = try fileUrlBuilder.mocksFolderUrl(for: domain)
        let relativePath = MockFileLocation.filePath(
            url: requestURL,
            method: method,
            scenario: scenario,
            id: id
        )
        let fileURL = URL(filePath: root.path() + "/" + relativePath)
        guard fileManager.fileExist(atPath: fileURL.path()) else {
            throw ModifierPreviewError.mockNotFound(id)
        }
        let mock: MockModel = try fileManager.readJSONFile(at: fileURL)
        guard mock.id == id else {
            throw ModifierPreviewError.mockNotFound(id)
        }
        return mock
    }
}
